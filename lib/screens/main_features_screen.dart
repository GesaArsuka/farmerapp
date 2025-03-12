import 'package:flutter/material.dart';
import '../widgets/custom_bottom_nav_bar.dart';

class MainFeaturesScreen extends StatefulWidget {
  const MainFeaturesScreen({Key? key}) : super(key: key);

  @override
  State<MainFeaturesScreen> createState() => _MainFeaturesScreenState();
}

class _MainFeaturesScreenState extends State<MainFeaturesScreen> {
  // If you need to highlight the current tab in the bottom bar, track index here.
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

          // Example navigation logic:
          if (index == 0) {
            // Already on Home. Possibly do nothing.
          } else if (index == 1) {
            // Go to Prompt screen
            Navigator.pushNamed(context, '/promptInput');
          } else if (index == 2) {
            // Go to archived convos
            Navigator.pushNamed(context, '/archivedConversations');
          }
        },
      ),

      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Card 1 - Assessment Kondisi
          _buildFeatureCard(
            title: "Assessment Kondisi",
            description:
                "Saya dapat menilai kondisi tanaman Anda dan memberikan tindakan-tindakan dasar.",
            color: Colors.greenAccent.shade100,
            onTap: () {
              // Example: external link or another route
              // Navigator.pushNamed(context, '/assessment');
            },
          ),
          const SizedBox(height: 16),

          // Card 2 - Rekomendasi Tindakan
          _buildFeatureCard(
            title: "Rekomendasi Tindakan",
            description:
                "Saya dapat memberikan rekomendasi perawatan dan penanggulangan.",
            color: Colors.purpleAccent.shade100,
            onTap: () {
              // Example usage:
              // Navigator.pushNamed(context, '/recommendation');
            },
          ),
          const SizedBox(height: 16),

          // Card 3 - Tindakan Lanjutan
          _buildFeatureCard(
            title: "Tindakan Lanjutan",
            description:
                "Saya akan detail mengenai langkah lanjutan setelah langkah dasar dilakukan.",
            color: Colors.blueAccent.shade100,
            onTap: () {
              // Example usage:
              // Navigator.pushNamed(context, '/followUp');
            },
          ),
          const SizedBox(height: 16),

          // Card 4 - Informasi Tanaman
          _buildFeatureCard(
            title: "Informasi Tanaman",
            description:
                "Saya dapat memberikan data dan informasi lebih mendalam tentang tanaman.",
            color: Colors.yellowAccent.shade100,
            onTap: () {
              // Example usage:
              // Navigator.pushNamed(context, '/plantInfo');
            },
          ),
        ],
      ),
    );
  }

  // Reusable method to build a feature card
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
            // Icon or image placeholder
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

            // Text content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
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
