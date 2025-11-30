import 'package:flutter/material.dart';

class StaffBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const StaffBottomNavBar({super.key, required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.report), label: 'Issues'),
        BottomNavigationBarItem(icon: Icon(Icons.lightbulb), label: 'Suggestions'),
      ],
      currentIndex: currentIndex,
      onTap: onTap,
      selectedItemColor: Theme.of(context).colorScheme.primary,
      unselectedItemColor: Theme.of(context).colorScheme.primaryFixed,
      type: BottomNavigationBarType.fixed,
    );
  }
}
