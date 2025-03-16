import 'package:flutter/material.dart';
import '../widgets/custom_bottom_nav_bar.dart';
import 'prompt_input_screen.dart';
import 'archived_conversations_screen.dart';

class MainFeaturesScreen extends StatefulWidget {
  const MainFeaturesScreen({Key? key}) : super(key: key);

  @override
  State<MainFeaturesScreen> createState() => _MainFeaturesScreenState();
}

class _MainFeaturesScreenState extends State<MainFeaturesScreen> {
  // Track the selected index for bottom navigation.
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Tutorial"),
        backgroundColor: Colors.white,
      ),
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
          // Navigation using bottom navbar (no tutorials here).
          if (index == 0) {
            // Already on Home.
          } else if (index == 1) {
            Navigator.pushNamed(context, '/promptInput');
          } else if (index == 2) {
            Navigator.pushNamed(context, '/archivedConversations');
          }
        },
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Cue Card 1 – Plant Consultation Tutorial.
          _buildFeatureCard(
            title: "Plant Consultation",
            description: "Learn how to use the prompt input (mic, text & photo).",
            color: Colors.greenAccent.shade100,
            onTap: () {
              // Navigate to PromptInputScreen with tutorial mode enabled.
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PromptInputScreen(showTutorial: true),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          // Cue Card 2 – Save Current Conversation Tutorial.
          _buildFeatureCard(
            title: "Save Conversation",
            description: "Learn how to archive your current conversation.",
            color: Colors.purpleAccent.shade100,
            onTap: () {
              // Show a modal dialog with a preview image and instructions.
              showDialog(
                context: context,
                barrierDismissible: true,
                builder: (context) {
                  return Dialog(
                    backgroundColor: Colors.transparent,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Ensure this asset exists in your assets folder.
                          Image.asset("assets/answer_display_preview.png"),
                          const SizedBox(height: 16),
                          const Text(
                            "Press the archive button to save the current conversation for later access.",
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 16),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            child: const Text("Got it"),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
          const SizedBox(height: 16),
          // Cue Card 3 – Access Archived Conversations Tutorial.
          _buildFeatureCard(
            title: "Access Archived Conversations",
            description: "Learn how to view and interact with archived chats.",
            color: Colors.blueAccent.shade100,
            onTap: () {
              // Navigate to ArchivedConversationsScreen with tutorial mode enabled.
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ArchivedConversationsScreen(showTutorial: true),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          ],
      ),
    );
  }

  // Reusable method to build a feature card.
  Widget _buildFeatureCard({
    required String title,
    required String description,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            // Icon placeholder.
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black54,
              ),
              child: const Center(
                child: Icon(
                  Icons.question_mark_rounded,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Text content.
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
