import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_sound/flutter_sound.dart';
import '../services/api_services.dart';

class AnswerDisplayScreen extends StatefulWidget {
  final String plantName;
  final String complaint;
  final String? initialAnswer;
  final String? conversationId;

  const AnswerDisplayScreen({
    Key? key,
    required this.plantName,
    required this.complaint,
    this.initialAnswer,
    this.conversationId,
  }) : super(key: key);

  @override
  State<AnswerDisplayScreen> createState() => _AnswerDisplayScreenState();
}

class _AnswerDisplayScreenState extends State<AnswerDisplayScreen> {
  List<Map<String, String>> conversationHistory = [];
  final TextEditingController followUpController = TextEditingController();
  bool _isLoading = false;
  String? _conversationId;

  // Recorder for follow-up voice input.
  FlutterSoundRecorder? _recorder;
  bool _isRecorderInitialized = false;
  bool _isRecordingMic = false;

  @override
  void initState() {
    super.initState();
    _conversationId = widget.conversationId;
    _initRecorder();

    if (_conversationId != null) {
      _loadConversationHistory();
    } else {
      conversationHistory.add({
        "role": "user",
        "content": "${widget.plantName}\n${widget.complaint}",
      });
      if (widget.initialAnswer != null && widget.initialAnswer!.isNotEmpty) {
        conversationHistory.add({
          "role": "assistant",
          "content": widget.initialAnswer!,
        });
      }
    }
  }

  Future<void> _initRecorder() async {
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) return;
    _recorder = FlutterSoundRecorder();
    await _recorder!.openRecorder();
    setState(() {
      _isRecorderInitialized = true;
    });
  }

  @override
  void dispose() {
    _recorder?.closeRecorder();
    _recorder = null;
    followUpController.dispose();
    super.dispose();
  }

  void _loadConversationHistory() async {
    try {
      final messages = await ApiServices.getConversationHistory(_conversationId!);
      // Process messages: skip system messages and join text parts.
      List<Map<String, String>> chatBubbles = [];
      for (var m in messages) {
        if (m["role"] == "system") continue;
        final List<dynamic> contents = m["content"];
        final messageText = contents
            .map<String>((contentBlock) => contentBlock["text"].toString())
            .join("\n");
        chatBubbles.add({
          "role": m["role"].toString(),
          "content": messageText,
        });
      }
      setState(() {
        conversationHistory = chatBubbles;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error loading conversation: $e")),
      );
    }
  }

  String _extractTextOnly(dynamic contentField) {
    if (contentField == null) return "";
    if (contentField is List) {
      return _extractFromBlocks(contentField);
    }
    if (contentField is String) {
      try {
        final decoded = jsonDecode(contentField);
        if (decoded is List) {
          return _extractFromBlocks(decoded);
        } else {
          return contentField;
        }
      } catch (_) {
        return contentField;
      }
    }
    return contentField.toString();
  }

  String _extractFromBlocks(List<dynamic> blocks) {
    final sb = StringBuffer();
    for (var block in blocks) {
      if (block is Map && block["type"] == "text") {
        sb.write(block["text"]);
        sb.write("\n");
      }
    }
    return sb.toString().trim();
  }

  Future<void> _sendFollowUp() async {
    final followUpText = followUpController.text.trim();
    if (followUpText.isEmpty) return;

    setState(() => _isLoading = true);
    conversationHistory.add({"role": "user", "content": followUpText});

    try {
      final userMessage = {"role": "user", "content": followUpText};
      final result = await ApiServices.sendChatPromptWithConversation(
        [userMessage],
        conversationId: _conversationId,
      );
      setState(() {
        conversationHistory.add({
          "role": "assistant",
          "content": result["answer"] ?? "No answer returned"
        });
        _conversationId = result["conversation_id"];
        followUpController.clear();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _archiveConversation() async {
    if (_conversationId == null) return;
    try {
      final status = await ApiServices.archiveConversation(_conversationId!);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Archived: $status")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Archive error: $e")),
      );
    }
  }

  // New: Toggle recording for follow-up message using whisper for transcription.
  Future<void> _toggleRecordingMic() async {
    if (!_isRecorderInitialized) return;
    if (!_isRecordingMic) {
      await _recorder!.startRecorder(toFile: "followup_message.aac");
      setState(() {
        _isRecordingMic = true;
      });
    } else {
      final path = await _recorder!.stopRecorder();
      setState(() {
        _isRecordingMic = false;
      });
      if (path != null) {
        final file = File(path);
        try {
          // This call uses your backend's Whisper-based transcription.
          final transcription = await ApiServices.transcribeAudio(file);
          followUpController.text = transcription;
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Transcription error: $e")),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Verdant"),
        backgroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.archive),
            onPressed: _archiveConversation,
          ),
        ],
      ),
      body: Column(
        children: [
          // Conversation display.
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: conversationHistory.map((msg) {
                  if (msg["role"] == "user") {
                    return _buildUserBubble(msg["content"]!);
                  } else {
                    return _buildAssistantBubble(msg["content"]!);
                  }
                }).toList(),
              ),
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: CircularProgressIndicator(),
            ),
          _buildFollowUpInput(),
        ],
      ),
    );
  }

  Widget _buildFollowUpInput() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: followUpController,
              decoration: const InputDecoration(
                hintText: "Enter follow-up message...",
                border: OutlineInputBorder(),
              ),
            ),
          ),
          // New mic record button for follow-up voice input.
          IconButton(
            icon: Icon(_isRecordingMic ? Icons.mic : Icons.mic_none),
            onPressed: _isRecorderInitialized ? _toggleRecordingMic : null,
          ),
          IconButton(
            icon: const Icon(Icons.send),
            onPressed: _isLoading ? null : _sendFollowUp,
          ),
        ],
      ),
    );
  }

  Widget _buildUserBubble(String text) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Flexible(
          child: Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(left: 60, top: 8, bottom: 8),
            decoration: BoxDecoration(
              color: Colors.green.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(text, style: const TextStyle(fontSize: 14)),
          ),
        ),
        const SizedBox(width: 8),
        CircleAvatar(
          radius: 16,
          backgroundColor: Colors.grey.shade300,
          child: const Text("U", style: TextStyle(color: Colors.black)),
        ),
      ],
    );
  }

  Widget _buildAssistantBubble(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: Colors.black54,
          child: const Icon(Icons.person, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(top: 8, bottom: 8),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              text,
              style: const TextStyle(fontSize: 14, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}
