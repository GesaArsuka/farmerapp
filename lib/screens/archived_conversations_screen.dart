import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import '../services/api_services.dart';
import 'answer_display_screen.dart';

class ArchivedConversationsScreen extends StatefulWidget {
  final bool showTutorial;
  const ArchivedConversationsScreen({Key? key, this.showTutorial = false}) : super(key: key);

  @override
  _ArchivedConversationsScreenState createState() =>
      _ArchivedConversationsScreenState();
}

class _ArchivedConversationsScreenState extends State<ArchivedConversationsScreen> {
  bool _isLoading = true;
  List<dynamic> _conversations = [];
  String? _error;

  // Predefined list of colors for the cards.
  final List<Color> cardColors = [
    Colors.blue.shade100,
    Colors.green.shade100,
    Colors.orange.shade100,
    Colors.purple.shade100,
    Colors.red.shade100,
    Colors.teal.shade100,
  ];

  // Global key for the first conversation card to highlight.
  final GlobalKey _firstCardKey = GlobalKey();

  TutorialCoachMark? tutorialCoachMark;
  List<TargetFocus> targets = [];

  @override
  void initState() {
    super.initState();
    _fetchConversations();

    if (widget.showTutorial) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _initTargets();
        _showTutorialCoachMark();
      });
    }
  }

  void _initTargets() {
    targets.clear();
    if (_conversations.isNotEmpty) {
      targets.add(
        TargetFocus(
          identify: "FirstCard",
          keyTarget: _firstCardKey,
          contents: [
            TargetContent(
              align: ContentAlign.bottom,
              child: Container(
                child: const Text(
                  "Kartu ini memiliki informasi singkat dari percakapan yang telah disimpan, seperti tanggal dan preview isi percakapan. Tekan untuk mengakses percakapannya kembali atau gunakan tombol hapus untuk menghapus percakapan.",
                  style: TextStyle(color: Colors.black, fontSize: 18),
                ),
              ),
            ),
          ],
        ),
      );
    }
  }

  void _showTutorialCoachMark() {
    if (targets.isNotEmpty) {
      tutorialCoachMark = TutorialCoachMark(
         // Pass context as a positional argument.
        targets: targets,
        colorShadow: Colors.black,
        textSkip: "SKIP",
        paddingFocus: 10,
        opacityShadow: 0.8,
        onFinish: () {
          print("Archived Conversation Tutorial finished");
          return true;
        },
        onSkip: () {
          print("Archived Conversation Tutorial skipped");
          return true;
        },
      )..show(context:context);
    }
  }

  Future<void> _fetchConversations() async {
    try {
      final convs = await ApiServices.getArchivedConversations();
      setState(() {
        _conversations = convs;
        _isLoading = false;
      });
      if (widget.showTutorial) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _initTargets();
          _showTutorialCoachMark();
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteConversation(String conversationId) async {
    try {
      await ApiServices.deleteConversation(conversationId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Conversation deleted")),
      );
      _fetchConversations(); // Refresh the list after deletion.
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Delete error: $e")),
      );
    }
  }

  // Helper: Joins text blocks from JSON content.
  String extractText(dynamic content) {
    if (content is List) {
      return content.map((item) => item["text"].toString()).join("\n");
    } else if (content is String) {
      return content;
    }
    return "";
  }

  void _openConversation(String conversationId) async {
    try {
      final messages = await ApiServices.getConversationHistory(conversationId);
      String plantName = "";
      String complaint = "";

      if (messages.isNotEmpty) {
        final firstUser = messages.firstWhere((msg) => msg["role"] == "user", orElse: () => null);
        if (firstUser != null) {
          final text = extractText(firstUser["content"]);
          final regex = RegExp(r"Plant Name:\s*(.+)\nComplaint:\s*(.+)", dotAll: true);
          final match = regex.firstMatch(text);
          if (match != null) {
            plantName = match.group(1)?.trim() ?? "";
            complaint = match.group(2)?.trim() ?? "";
          } else {
            plantName = text;
            complaint = text;
          }
        }
      }

      String? lastAssistant;
      for (var msg in messages.reversed) {
        if (msg["role"] == "assistant") {
          lastAssistant = extractText(msg["content"]);
          break;
        }
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AnswerDisplayScreen(
            plantName: plantName,
            complaint: complaint,
            initialAnswer: lastAssistant,
            conversationId: conversationId,
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error loading conversation: $e")),
      );
    }
  }

  String formatDate(String isoDate) {
    try {
      DateTime date = DateTime.parse(isoDate);
      return DateFormat('yyyy-MM-dd HH:mm').format(date);
    } catch (e) {
      return isoDate;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Arsip Percakapan"),
        backgroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text("Error: $_error"))
              : ListView.builder(
                  itemCount: _conversations.length,
                  itemBuilder: (context, index) {
                    final conv = _conversations[index];
                    final cardColor = cardColors[index % cardColors.length];
                    return Card(
                      key: index == 0 ? _firstCardKey : null,
                      color: cardColor,
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: ListTile(
                        title: Text("Conversation #${index + 1}"),
                        subtitle: Text(
                          "Tanggal : ${formatDate(conv["created_at"])}\nSummary: ${conv["summary"]}",
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () => _deleteConversation(conv["conversation_id"]),
                        ),
                        onTap: () => _openConversation(conv["conversation_id"]),
                      ),
                    );
                  },
                ),
    );
  }
}
