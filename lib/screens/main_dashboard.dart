import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// 👇 引入你即将分离的 5 个子页面 (Tabs)
import 'tabs/home_dashboard.dart';
import 'tabs/workout_page.dart';
import 'tabs/diet_page.dart';
import 'tabs/scan_food_page.dart';
import 'tabs/settings_page.dart';

// ==========================================
// 4. MAIN DASHBOARD (Tabs)
// ==========================================
class MainDashboard extends StatefulWidget {
  // 注意：我们不再需要从上一页传参数进来了，因为我们会自己去数据库查
  const MainDashboard({super.key, this.caloriesTarget, this.userName});
  
  final int? caloriesTarget; //这俩变可选的了，兼容旧代码
  final String? userName;

  @override
  State<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends State<MainDashboard> {
  int _currentIndex = 0;
Future<void> _syncCaloriesToFirebase(int calories) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // 获取今天的日期 (格式: 2026-04-15)
    String today = DateTime.now().toString().split(' ')[0];

    try {
          // 写入 Firestore 数据
          // 删除了所有 firestore. 前缀，直接使用类名
          await FirebaseFirestore.instance 
              .collection('users')
              .doc(user.uid)
              .collection('daily_logs')
              .doc(today)
              .set({
                'calories_consumed': FieldValue.increment(calories),
                'last_updated': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true)); // 注意：末尾依然只需要两个右括号 ));

          print("Synced $calories kcal to Firebase.");
        } catch (e) {
          print("Sync Error: $e");
       }
    }
  // Updated List of Pages
  final List<Widget> _pages = [
    const HomeTab(),      // Index 0
    const WorkoutTab(),   // Index 1
    const DietPage(),     // Index 2 (New Diet Page)
    // Camera Logic embedded or separate, keeping placeholder for now if you want 5 tabs
    CameraTab(onFoodDetected: (calories) {
  // This updates your local state if needed, though your CameraTab 
  // already logs to Firestore in line 220.
      print("Detected $calories kcal");
    }), 
    const SettingsTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        selectedItemColor: Colors.teal,
        type: BottomNavigationBarType.fixed, // Added this so 5 icons show correctly
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.fitness_center), label: "Workout"),
          BottomNavigationBarItem(icon: Icon(Icons.restaurant_menu), label: "Diet"), // New
          BottomNavigationBarItem(icon: Icon(Icons.camera_alt), label: "Scan"),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: "Settings"), // New
        ],
      ),
    );
  }
}