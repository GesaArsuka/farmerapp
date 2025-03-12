import 'dart:convert';
import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    _conversationId = widget.conversationId;

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

  void _loadConversationHistory() async {
  try {
    final messages = await ApiServices.getConversationHistory(_conversationId!);
    // Process the messages: skip system messages and extract text for others.
    List<Map<String, String>> chatBubbles = [];
    for (var m in messages) {
      if (m["role"] == "system") continue; // Skip system prompt
      final List<dynamic> contents = m["content"];
      // Join all text parts from the content list (if there are multiple)
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

    // If it's a list of blocks
    if (contentField is List) {
      return _extractFromBlocks(contentField);
    }
    // If it's a string, try to decode or fallback
    if (contentField is String) {
      try {
        final decoded = jsonDecode(contentField);
        if (decoded is List) {
          return _extractFromBlocks(decoded);
        } else {
          return contentField;
        }
      } catch (_) {
        // Not JSON => just return as is
        return contentField;
      }
    }
    // If it's something else (Map?), fallback
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Verdant"),
        backgroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.archive),
            onPressed: _archiveConversation,
          ),
        ],
      ),
      body: Column(
        children: [
          // Conversation display
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
