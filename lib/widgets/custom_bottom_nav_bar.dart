// File: lib/widgets/custom_bottom_nav_bar.dart

import 'package:flutter/material.dart';

class CustomBottomNavBar extends StatelessWidget {
  /// The currently selected tab index
  final int currentIndex;

  /// A callback that is triggered when the user taps a nav item.
  /// Typically, you'll handle navigation logic in the parent screen
  /// by calling Navigator.pushNamed(...) or setState(...) in this callback.
  final ValueChanged<int> onTap;

  const CustomBottomNavBar({
    Key? key,
    required this.currentIndex,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: onTap,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.mic),
          label: 'Prompt',
        ),
        // BottomNavigationBarItem(
        //   icon: Icon(Icons.chat),
        //   label: 'Answer',
        // ),
      ],
    );
  }
}
