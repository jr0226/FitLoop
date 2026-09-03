import 'package:flutter/material.dart';

// 5 Main Tab Screens
import 'tabs/home_dashboard.dart';
import 'workout_hub_screen.dart';
import 'tabs/diet_page.dart';
import 'tabs/scan_food_page.dart';
import 'tabs/settings_page.dart';

// ==========================================
// 4. MAIN DASHBOARD (Tabs)
// ==========================================
class MainDashboard extends StatefulWidget {
  const MainDashboard({super.key, this.caloriesTarget, this.userName});
  
  final int? caloriesTarget; // Optional for backward compatibility
  final String? userName;

  @override
  State<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends State<MainDashboard> {
  int _currentIndex = 0;

  late final List<Widget> _pages = [
    HomeTab(onNavigateToTab: (index) => setState(() => _currentIndex = index)), // Index 0: Home Dashboard
    const WorkoutHubScreen(),   // Index 1: Training Hub
    const DietPage(),           // Index 2: Diet & Food Diary
    CameraTab(onFoodDetected: (calories) {
      // Scanned food is saved directly to users/{uid}/food_logs
    }),                         // Index 3: Food Scanner
    const SettingsTab(),        // Index 4: Settings & Preferences
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        backgroundColor: theme.bottomNavigationBarTheme.backgroundColor ?? theme.cardColor,
        selectedItemColor: theme.bottomNavigationBarTheme.selectedItemColor ?? Colors.teal,
        unselectedItemColor: theme.bottomNavigationBarTheme.unselectedItemColor ?? Colors.grey.shade500,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.fitness_center), label: "Workout"),
          BottomNavigationBarItem(icon: Icon(Icons.restaurant_menu), label: "Diet"),
          BottomNavigationBarItem(icon: Icon(Icons.camera_alt), label: "Scan"),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: "Settings"),
        ],
      ),
    );
  }
}