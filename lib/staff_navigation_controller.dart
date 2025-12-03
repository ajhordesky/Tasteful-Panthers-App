import 'package:flutter/material.dart';
import 'package:pdh_recommendation/main.dart';
import 'package:provider/provider.dart';
import 'screens/staff_issues_screen.dart';
import 'screens/staff_suggestion_screen.dart';
import 'widgets/staff_bottom_nav_bar.dart';

class StaffNavigationController extends StatefulWidget {
  final int? initialIndex; // Allow external index control
  
  const StaffNavigationController({super.key, this.initialIndex});
  
  @override
  State<StaffNavigationController> createState() => _StaffNavigationControllerState();
}

class _StaffNavigationControllerState extends State<StaffNavigationController> {
  final List<Widget> _pages = const [
    StaffIssuesScreen(),
    StaffSuggestionScreen(),
  ];
  
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    // Don't call setState during initState
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // Initialize after the widget is mounted and dependencies are resolved
    if (!_initialized) {
      _initialized = true;
      
      // Use initial index if provided, otherwise reset to 0 for staff
      final appState = Provider.of<MyAppState>(context, listen: false);
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (widget.initialIndex != null) {
          // Clamp the index to staff bounds
          final clampedIndex = widget.initialIndex!.clamp(0, _pages.length - 1);
          appState.setSelectedIndex(clampedIndex);
        } else {
          // Always reset to first tab for staff when no specific index is provided
          appState.setSelectedIndex(0);
        }
      });
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
    final currentIndex = appState.selectedIndex;
    
    // Always clamp the index to staff screen bounds
    final safeIndex = currentIndex.clamp(0, _pages.length - 1);
    
    // If the current index is out of bounds, reset it
    if (currentIndex != safeIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        appState.setSelectedIndex(safeIndex);
      });
    }

    return Scaffold(
      body: _pages[safeIndex],
      bottomNavigationBar: StaffBottomNavBar(
        currentIndex: safeIndex,
        onTap: (i) => appState.setSelectedIndex(i),
      ),
    );
  }
}