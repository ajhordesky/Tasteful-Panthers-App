import 'package:flutter/material.dart';
import 'screens/staff_issues_screen.dart';
import 'screens/staff_suggestion_screen.dart';
import 'widgets/staff_bottom_nav_bar.dart';

class StaffNavigationController extends StatefulWidget {
  const StaffNavigationController({super.key});

  @override
  State<StaffNavigationController> createState() => _StaffNavigationControllerState();
}

class _StaffNavigationControllerState extends State<StaffNavigationController> {
  int _index = 0;
  late final List<Widget> _pages = const [
    StaffIssuesScreen(),
    StaffSuggestionScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final safeIndex = _index.clamp(0, _pages.length - 1);
    return Scaffold(
      body: _pages[safeIndex],
      bottomNavigationBar: StaffBottomNavBar(
        currentIndex: safeIndex,
        onTap: (i) => setState(() => _index = i),
      ),
    );
  }
}
