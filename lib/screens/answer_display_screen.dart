import 'package:flutter/material.dart';

class AnswerDisplayScreen extends StatefulWidget {
  final String plantName;
  final String complaint;

  /// This should be the ChatGPT (Verdant) answer already fetched in PromptInputScreen.
  final String? initialAnswer;

  const AnswerDisplayScreen({
    Key? key,
    required this.plantName,
    required this.complaint,
    this.initialAnswer,
  }) : super(key: key);

  @override
  State<AnswerDisplayScreen> createState() => _AnswerDisplayScreenState();
}

class _AnswerDisplayScreenState extends State<AnswerDisplayScreen> {
  // We'll store the final ChatGPT answer here
  String? _chatAnswer;

  @override
  void initState() {
    super.initState();
    // If we already have the answer, just use it. No new server call required.
    _chatAnswer = widget.initialAnswer;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Verdant"),
        backgroundColor: Colors.black,
      ),

      // Wrap everything in a SingleChildScrollView to avoid overflow
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // 1) Show the user's input in a green "bubble"
            _buildUserBubble(),
            const SizedBox(height: 12),

            // 2) If there's no answer yet, show a "thinking" widget
            //    Otherwise, show the black bubble with the GPT response.
            if (_chatAnswer == null || _chatAnswer!.isEmpty)
              _buildThinkingWidget()
            else
              _buildVerdantBubble(_chatAnswer!),
          ],
        ),
      ),
    );
  }

  // Green bubble to display the user's original input (plantName + complaint)
  Widget _buildUserBubble() {
    final userText =
        "${widget.plantName.isNotEmpty ? widget.plantName : "Tanaman tidak diketahui"}\n"
        "${widget.complaint.isNotEmpty ? widget.complaint : "Keluhan belum diisi"}";

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Flexible(
          child: Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(left: 60),
            decoration: BoxDecoration(
              color: Colors.green.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              userText,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // User avatar placeholder ("U")
        CircleAvatar(
          radius: 16,
          backgroundColor: Colors.grey.shade300,
          child: const Text(
            "U",
            style: TextStyle(color: Colors.black),
          ),
        ),
      ],
    );
  }

  // Shown if no answer is available
  Widget _buildThinkingWidget() {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0),
      child: Column(
        children: const [
          SizedBox(height: 10),
          Text("Sedang berpikir..."),
          SizedBox(height: 10),
          CircularProgressIndicator(),
        ],
      ),
    );
  }

  // Black bubble for Verdant's (ChatGPT) response
  Widget _buildVerdantBubble(String answerText) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // "Farmer" or "Verdant" avatar
        CircleAvatar(
          radius: 20,
          backgroundColor: Colors.black54,
          child: const Icon(
            Icons.person,
            color: Colors.white,
            size: 20,
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              answerText,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
