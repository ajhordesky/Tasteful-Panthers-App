import 'package:flutter/material.dart';
import 'package:pdh_recommendation/main.dart';
import 'package:provider/provider.dart';
import 'screens/main_review_screen.dart';       // NEW
import 'screens/main_suggestion_screen.dart';  // NEW
import 'screens/profile_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/search_screen.dart';
import 'widgets/bottom_nav_bar.dart';

class NavigationController extends StatefulWidget {
  final int? initialIndex; // Allow external index control
  
  const NavigationController({super.key, this.initialIndex});
  
  @override
  State<NavigationController> createState() => _NavigationControllerState();
}

class _NavigationControllerState extends State<NavigationController> {
  final List<Widget> _pages = const [
    MainReviewScreen(),       // index 0
    MainSuggestionScreen(),   // index 1
    SearchScreen(),             // index 2
    DashboardPage(),          // index 3
    ProfilePage(),            // index 4
  ];

  @override
  void initState() {
    super.initState();
    // Use initial index if provided, otherwise use the state from MyAppState
    final appState = Provider.of<MyAppState>(context, listen: false);
    if (widget.initialIndex != null) {
      appState.setSelectedIndex(widget.initialIndex!);
    }
  }

  // Public method to change tab externally
  void changeTab(int index) {
    if (index >= 0 && index < _pages.length) {
      final appState = Provider.of<MyAppState>(context, listen: false);
      appState.setSelectedIndex(index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<MyAppState>(context);
    final safeIndex = appState.selectedIndex.clamp(0, _pages.length - 1);

    return Scaffold(
      body: _pages[safeIndex],
      bottomNavigationBar: BottomNavBar(
        currentIndex: safeIndex,
        onTap: (i) => appState.setSelectedIndex(i),
      ),
    );
  }
}