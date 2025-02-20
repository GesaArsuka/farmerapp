import 'package:flutter/material.dart';

class IntroductionScreen extends StatelessWidget {
  const IntroductionScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Optional background color
      // backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Replace placeholder text with your image
                Image.asset(
                  'assets/images/farmer_icon.jpg',
                  width: 120,   // adjust as needed
                  height: 120,  // adjust as needed
                ),
                const SizedBox(height: 40),
                
                // Main greeting
                const Text(
                  "Hi, Saya Verdant!",
                  style: TextStyle(
                    fontSize: 24, 
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                
                // Secondary text
                const Text(
                  "Ada yang bisa dibantu?",
                  style: TextStyle(
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                
                // Additional descriptive text
                const Text(
                  "Verdant dapat membantu Anda "
                  "memperoleh informasi dan rekomendasi "
                  "terkait tanaman Anda.\n\n"
                  "Mari belajar lebih cepat dalam "
                  "merawat tanaman Anda!",
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                
                // "Mulai" button
                ElevatedButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/mainFeatures');
                  },
                  child: const Text("Mulai"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
