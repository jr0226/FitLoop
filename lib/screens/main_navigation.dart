import 'package:flutter/material.dart';

// Import all the tabs we just built!
import 'tabs/home_dashboard.dart';
import 'tabs/workout_page.dart';
import 'tabs/scan_food_page.dart';
import 'tabs/analytics_page.dart';
import 'tabs/achievements_page.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    
    // Initialize our pages. 
    // We pass a callback to the CameraTab so that after a successful scan, 
    // it automatically jumps the user back to the Home Dashboard to see their updated macros!
    _pages = [
      const HomeTab(),
      const WorkoutTab(),
      CameraTab(
        onFoodDetected: (calories) {
          setState(() {
            _selectedIndex = 0; // 0 is the index for HomeTab
          });
        },
      ),
      const AnalyticsTab(),
      const AchievementsTab(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // IndexedStack keeps all tabs alive in the background so they don't reload every time you switch
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      
      // Material 3 Navigation Bar
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (int index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        backgroundColor: Colors.white,
        indicatorColor: Colors.teal.shade100,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.space_dashboard_outlined),
            selectedIcon: Icon(Icons.space_dashboard, color: Colors.teal),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.fitness_center_outlined),
            selectedIcon: Icon(Icons.fitness_center, color: Colors.teal),
            label: 'Workout',
          ),
          NavigationDestination(
            icon: Icon(Icons.document_scanner_outlined),
            selectedIcon: Icon(Icons.document_scanner, color: Colors.teal),
            label: 'Scan',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart, color: Colors.teal),
            label: 'Stats',
          ),
          NavigationDestination(
            icon: Icon(Icons.emoji_events_outlined),
            selectedIcon: Icon(Icons.emoji_events, color: Colors.teal),
            label: 'Badges',
          ),
        ],
      ),
    );
  }
}