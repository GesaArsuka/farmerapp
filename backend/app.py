import os
import json
import uuid
import base64
import tempfile
from datetime import datetime

import openai
import whisper
from flask import Flask, request, jsonify
from flask_sqlalchemy import SQLAlchemy
from werkzeug.utils import secure_filename

########################################
# Flask Config
########################################
app = Flask(__name__)
openai.api_key = os.getenv("OPENAI_API_KEY")

app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///conversations.db'
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

db = SQLAlchemy(app)

########################################
# Database Models
########################################
class Conversation(db.Model):
    id = db.Column(db.String(36), primary_key=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    archived = db.Column(db.Boolean, default=False)
    messages = db.relationship(
        'Message',
        backref='conversation',
        lazy=True,
        cascade="all, delete-orphan"
    )

class Message(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    conversation_id = db.Column(db.String(36), db.ForeignKey('conversation.id'), nullable=False)
    role = db.Column(db.String(20), nullable=False)  # "system", "user", or "assistant"
    content = db.Column(db.Text, nullable=False)     # JSON string (only text blocks stored)
    timestamp = db.Column(db.DateTime, default=datetime.utcnow)

with app.app_context():
    db.create_all()

########################################
# Whisper Initialization
########################################
print("Loading Whisper model (medium)...")
whisper_model = whisper.load_model("medium")
print("Whisper model loaded.")

########################################
# Helper: System Prompt
########################################
SYSTEM_PROMPT = (
    "Respond as a Professional Farm consultant by providing concise plant information "
    "(scientific name, estimated harvest selling price locally, and normal harvest period), "
    "a brief summary of the possible diagnosis of the complaint, and specific countermeasure recommendations. "
    "Explain in simple terms. The answer should be in Bahasa Indonesia. Separate each section (plant description, "
    "diagnosis, recommendation) using a clear-cut line like =========."
)

def remove_image_blocks(blocks):
    """
    Given a list of blocks, remove any where block["type"] == "image_url".
    Returns only text blocks.
    """
    filtered = []
    for b in blocks:
        if b.get("type") == "text":
            filtered.append(b)
    return filtered

########################################
# /chat Endpoint
########################################
@app.route("/chat", methods=["POST"])
def chat():
    """
    Expects multipart/form-data with:
      - plantName
      - complaint
      - conversation_id (optional)
      - file (the image, optional)
    We'll build a user content array with text + image, pass it to GPT,
    but store only the text blocks in the DB.
    """
    try:
        # 1) Extract fields
        plant_name = request.form.get("plantName", "")
        complaint = request.form.get("complaint", "")
        conv_id = request.form.get("conversation_id", None)

        image_file = request.files.get("file", None)

        # 2) Build the user content array
        user_content = []
        if plant_name or complaint:
            user_content.append({
                "type": "text",
                "text": f"Plant Name: {plant_name}\nComplaint: {complaint}"
            })
        if image_file:
            # read the bytes & base64-encode for GPT
            raw_bytes = image_file.read()
            b64_str = base64.b64encode(raw_bytes).decode("utf-8")
            user_content.append({
                "type": "image_url",
                "image_url": {"url": f"data:image/jpeg;base64,{b64_str}"}
            })

        # 3) Create or get conversation
        if not conv_id:
            conv_id = str(uuid.uuid4())
            conversation = Conversation(id=conv_id)
            db.session.add(conversation)

            # Insert system prompt as first message
            system_blocks = [{"type": "text", "text": SYSTEM_PROMPT}]
            system_msg = Message(
                conversation_id=conv_id,
                role="system",
                content=json.dumps(system_blocks)  # only text
            )
            db.session.add(system_msg)
        else:
            conversation = Conversation.query.get(conv_id)
            if not conversation:
                return jsonify({"error": "Conversation not found"}), 404

        db.session.commit()

        # 4) Insert the user message: 
        #    We'll store only text blocks. But pass the full content to GPT.
        #    So we copy user_content, remove images for DB storage, store that.
        blocks_for_db = remove_image_blocks(user_content)
        user_msg = Message(
            conversation_id=conv_id,
            role="user",
            content=json.dumps(blocks_for_db)  # store only text blocks
        )
        db.session.add(user_msg)
        db.session.commit()

        # 5) Reconstruct entire conversation for GPT (including image blocks).
        #    We'll fetch from DB, then re-inject the image block for this new message?
        #    Or simpler approach: We'll just combine DB content with the *original* user_content 
        #    for the last message. This is simpler, but we must parse DB messages, add user_content in memory.

        # Let's fetch from DB, parse each, build a messages array
        conversation_messages = _build_gpt_messages(conv_id)
        # Then append the full user_content (including image block) to the last user message:
        # Actually, we can just treat it as a new user message. We'll do that below.

        # The final user message is the entire user_content
        conversation_messages.append({
            "role": "user",
            "content": user_content  # the full blocks, with image
        })

        # 6) Call GPT
        completion = openai.chat.completions.create(
            model="gpt-4o-2024-11-20",  # or whichever GPT-4 Vision model
            store=True,
            messages=conversation_messages
        )
        assistant_reply = completion.choices[0].message.content

        # 7) Store the assistant's reply (text only, no images)
        assistant_blocks = [{"type": "text", "text": assistant_reply}]
        assistant_msg = Message(
            conversation_id=conv_id,
            role="assistant",
            content=json.dumps(assistant_blocks)
        )
        db.session.add(assistant_msg)
        db.session.commit()

        return jsonify({"answer": assistant_reply, "conversation_id": conv_id})

    except Exception as e:
        return jsonify({"error": str(e)}), 500

def _build_gpt_messages(conv_id):
    """
    Loads all messages from DB in chronological order, returns an array of:
    {
      "role": "user"/"assistant"/"system",
      "content": [ { "type":"text","text":"..."}, ... ]
    }
    ignoring images since we don't store them in DB. 
    """
    msgs = Message.query.filter_by(conversation_id=conv_id).order_by(Message.timestamp).all()
    out = []
    for m in msgs:
        content_blocks = json.loads(m.content)  # only text
        out.append({
            "role": m.role,
            "content": content_blocks
        })
    return out

########################################
# Archiving, Deleting, etc.
########################################

@app.route("/conversation/<conv_id>", methods=["GET", "DELETE"])
def conversation_ops(conv_id):
    if request.method == "GET":
        convo = Conversation.query.get(conv_id)
        if not convo:
            return jsonify({"error": "Conversation not found"}), 404
        msgs = Message.query.filter_by(conversation_id=conv_id).order_by(Message.timestamp).all()
        output = []
        for m in msgs:
            output.append({
                "role": m.role,
                "content": json.loads(m.content),
                "timestamp": m.timestamp.isoformat()
            })
        return jsonify({"conversation_id": conv_id, "messages": output})

    elif request.method == "DELETE":
        convo = Conversation.query.get(conv_id)
        if not convo:
            return jsonify({"error": "Conversation not found"}), 404
        db.session.delete(convo)
        db.session.commit()
        return jsonify({"status": "Conversation deleted"})

@app.route("/conversations", methods=["GET"])
def list_conversations():
    archived_param = request.args.get("archived", "true").lower() == "true"
    convs = Conversation.query.filter_by(archived=archived_param).order_by(Conversation.created_at.desc()).all()
    out = []
    for c in convs:
        # The first user message is often a summary
        first_user = next((m for m in c.messages if m.role == "user"), None)
        summary = ""
        if first_user:
            blocks = json.loads(first_user.content)
            # blocks is only text blocks
            text_concat = "\n".join(b.get("text","") for b in blocks if b.get("type")=="text")
            summary = text_concat[:100]  # up to 100 chars
        out.append({
            "conversation_id": c.id,
            "created_at": c.created_at.isoformat(),
            "summary": summary
        })
    return jsonify({"conversations": out})

@app.route("/archive", methods=["POST"])
def archive_conversation():
    data = request.get_json()
    if not data or "conversation_id" not in data:
        return jsonify({"error": "Missing conversation_id"}), 400
    conv_id = data["conversation_id"]
    convo = Conversation.query.get(conv_id)
    if not convo:
        return jsonify({"error": "Conversation not found"}), 404
    convo.archived = True
    db.session.commit()
    return jsonify({"status": "Conversation archived"})

@app.route("/transcribe", methods=["POST"])
def transcribe_audio():
    if "file" not in request.files:
        return jsonify({"error": "No audio file provided"}), 400
    audio_file = request.files["file"]
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
        temp_filename = tmp.name
        audio_file.save(temp_filename)
    try:
        result = whisper_model.transcribe(temp_filename, language="id", fp16=False)
        return jsonify({"transcription": result["text"]})
    except Exception as e:
        return jsonify({"error": str(e)}), 500
    finally:
        if os.path.exists(temp_filename):
            os.remove(temp_filename)

if __name__ == "__main__":
    app.run(debug=True, host="0.0.0.0", port=5000)
