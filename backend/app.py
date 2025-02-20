import os
import json
import http.client  # still used for chat route
import tempfile
import whisper
from flask import Flask, request, jsonify

app = Flask(__name__)

########################################
# 1) Separate RapidAPI keys & hosts for ChatGPT os.getenv("RAPIDAPI_CHAT_KEY") or
########################################
RAPIDAPI_CHAT_KEY = os.getenv("RAPIDAPI_CHAT_KEY")
RAPIDAPI_CHAT_HOST = "chatgpt-42.p.rapidapi.com"

########################################
# 2) Chat Endpoint (RapidAPI GPT-4): /chat
########################################
@app.route("/chat", methods=["POST"])
def chat():
    """
    Expects a JSON body like:
    {
       "messages": [
         { "role": "user", "content": "hi" }
       ],
       "web_access": false
    }
    """
    data = request.get_json()
    if not data or "messages" not in data:
        return jsonify({"error": "Invalid JSON structure"}), 400

    try:
        # Convert entire data to JSON for the payload
        payload_json = json.dumps(data)

        # Create HTTPS connection to chatgpt-42
        conn = http.client.HTTPSConnection(RAPIDAPI_CHAT_HOST)

        # Build headers for ChatGPT endpoint
        headers = {
            "x-rapidapi-key": RAPIDAPI_CHAT_KEY,
            "x-rapidapi-host": RAPIDAPI_CHAT_HOST,
            "Content-Type": "application/json",
        }

        # Send request to /gpt4
        conn.request("POST", "/gpt4", payload_json, headers)

        # Get the response and parse
        res = conn.getresponse()
        raw_data = res.read()
        text_data = raw_data.decode("utf-8")

        # Example RapidAPI GPT-4 response structure:
        # {
        #   "result": "Hello! How can I assist you today?",
        #   "status": true,
        #   "server_code": "dg"
        # }
        response_data = json.loads(text_data)
        answer = response_data.get("result", "No answer found in response.")

        return jsonify({"answer": answer})

    except Exception as e:
        return jsonify({"error": str(e)}), 500

########################################
# 3) Local Whisper Model Setup
########################################
# Choose "tiny", "base", "small", "medium", or "large" per your hardware needs.
print("Loading local Whisper model (base)...")
model = whisper.load_model("small")  # or "tiny", "small", etc.
print("Whisper model loaded.")

########################################
# 4) Whisper Endpoint: /transcribe (LOCAL)
########################################
@app.route("/transcribe", methods=["POST"])
def transcribe_audio():
    """
    Expects multipart/form-data with 'file' field for the audio.
    We'll run local Whisper to transcribe it.
    """
    print("==== /transcribe endpoint called ====")
    print("request method:", request.method)
    print("request url:", request.url)
    print("request.files keys:", request.files.keys())

    if "file" not in request.files:
        print("==> NO FILE KEY FOUND, returning 400")
        return jsonify({"error": "No audio file provided"}), 400

    audio_file = request.files["file"]

    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
        temp_filename = tmp.name
        audio_file.save(temp_filename)

    try:
        # Transcribe using local Whisper
        # If you only have CPU, set fp16=False for better compatibility.
        result = model.transcribe(temp_filename, language="id", fp16=False)
        text = result["text"]

        return jsonify({"transcription": text})

    except Exception as e:
        return jsonify({"error": str(e)}), 500

    finally:
        # Cleanup the temp file
        if os.path.exists(temp_filename):
            os.remove(temp_filename)

########################################
# 5) Run Flask
########################################
if __name__ == "__main__":
    # Typically runs on localhost:5000
    app.run(debug=True, host="0.0.0.0", port=5000)
