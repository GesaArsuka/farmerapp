import 'package:flutter/material.dart';

// Screens
import 'screens/introduction_screen.dart';
import 'screens/main_features_screen.dart';
import 'screens/prompt_input_screen.dart';

// IMPORTANT: We typically need to push to AnswerDisplayScreen with arguments,
// so we won't define a named route for it here. We'll do it manually as shown below.

void main() {
  runApp(const FarmerApp());
}

class FarmerApp extends StatelessWidget {
  const FarmerApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Farmer App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.green,
      ),
      // We start at the IntroductionScreen by default
      initialRoute: '/',
      routes: {
        '/': (context) => const IntroductionScreen(),
        '/mainFeatures': (context) => const MainFeaturesScreen(),
        '/promptInput': (context) => const PromptInputScreen(),
        // If needed, you can define more named routes here
      },
    );
  }
}
