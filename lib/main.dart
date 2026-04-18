import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart'; // ✅ 新增：引入 Firebase 核心
import 'firebase_options.dart'; // ✅ 新增：引入配置文件
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert'; // For converting JSON
import 'package:http/http.dart' as http; // For making internet requests
import 'package:simple_barcode_scanner/simple_barcode_scanner.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'dart:async';
import 'dart:io';
// Import scanner
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);
// ✅ 修改：把 main 变成 async，并初始化 Firebase
void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // 必须加这行，确保 Flutter 引擎先启动
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform, // 读取你刚才生成的配置
  );
  
  runApp(const MyApp());
}

// ==========================================
// 下面的代码保持不变
// ==========================================
class MyApp extends StatelessWidget { 
  const MyApp({super.key});

@override
  Widget build(BuildContext context) {
    // ✅ 2. WRAP MATERIALAPP IN ValueListenableBuilder
    // This makes the app rebuild whenever 'themeNotifier' changes
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, ThemeMode currentMode, _) {
        return MaterialApp(
          title: 'Personalized Diet & Workout Planner',
          debugShowCheckedModeBanner: false, // Removes the "Debug" banner
          
          // Define Light Theme
          theme: ThemeData(
            primarySwatch: Colors.teal,
            useMaterial3: true,
            brightness: Brightness.light,
            scaffoldBackgroundColor: Colors.grey[50],
          ),
          
          // Define Dark Theme (Cooler colors)
          darkTheme: ThemeData(
            primarySwatch: Colors.teal,
            useMaterial3: true,
            brightness: Brightness.dark,
            scaffoldBackgroundColor: const Color(0xFF121212), // Nice dark grey
            appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF1F1F1F)),
            cardColor: const Color(0xFF1E1E1E),
          ),

          // Use the current mode from the notifier
          themeMode: currentMode, 
          
          home: const LoginPage(),
        );
      },
    );
  }
}

// ==========================================
// 2. LOGIN MODULE
// ==========================================

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoginMode = true;
  bool _isLoading = false;

  Future<void> _submitAuth() async {
    setState(() => _isLoading = true);
    try {
      if (_isLoginMode) {
        // === LOGIN ===
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      } else {
        // === REGISTER ===
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Registration Successful! Logging in...')),
        );
      }

      // === NEW LOGIC: Check where to send the user ===
      if (mounted) {
        bool hasData = await checkUserHasData(); // Check Firestore
        
        if (!mounted) return;

        if (hasData) {
          // User has data -> Go to Dashboard
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const MainDashboard()),
          );
        } else {
          // New user -> Go to Setup Profile
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const SetupProfilePage(isEditing: false)),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      String message = "Operation Failed";
      if (e.code == 'user-not-found') message = "User not found.";
      if (e.code == 'wrong-password') message = "Wrong password.";
      if (e.code == 'email-already-in-use') message = "Email already registered.";
      if (e.code == 'weak-password') message = "Password too weak.";
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // === HELPER: Check Firestore for User Document ===
  Future<bool> checkUserHasData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      return doc.exists;
    } catch (e) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.fitness_center, size: 80, color: Colors.teal),
                const SizedBox(height: 20),
                Text(
                  _isLoginMode ? 'Welcome Back' : 'Create Account',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 40),
                TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder(), prefixIcon: Icon(Icons.email)),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder(), prefixIcon: Icon(Icons.lock)),
                ),
                const SizedBox(height: 24),
                if (_isLoading)
                  const CircularProgressIndicator()
                else
                  Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _submitAuth,
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                          child: Text(_isLoginMode ? 'LOGIN' : 'REGISTER'),
                        ),
                      ),
                      const SizedBox(height: 15),
                      TextButton(
                        onPressed: () => setState(() => _isLoginMode = !_isLoginMode),
                        child: Text(_isLoginMode ? 'No account? Register here' : 'Have an account? Login here'),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ==========================================
// 3. USER PROFILE LOGIC (HARRIS-BENEDICT)
// ==========================================
class SetupProfilePage extends StatefulWidget {
  final bool isEditing; // New: Controls if we are editing or creating
  const SetupProfilePage({super.key, this.isEditing = false}); 

  @override
  State<SetupProfilePage> createState() => _SetupProfilePageState();
}

class _SetupProfilePageState extends State<SetupProfilePage> {
  final TextEditingController _ageCtrl = TextEditingController();
  final TextEditingController _weightCtrl = TextEditingController();
  final TextEditingController _heightCtrl = TextEditingController();
  final TextEditingController _nameCtrl = TextEditingController();

  String _gender = "Male";
  String _goal = "Weight Loss (减脂)";
  String _activity = "Moderate (适度运动)";
  bool _isSaving = false;

  Future<void> _saveAndContinue() async {
    if (_ageCtrl.text.isEmpty || _weightCtrl.text.isEmpty || _heightCtrl.text.isEmpty || _nameCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill all fields")));
      return;
    }

    setState(() => _isSaving = true);
    try {
      int age = int.parse(_ageCtrl.text);
      double weight = double.parse(_weightCtrl.text);
      double height = double.parse(_heightCtrl.text);

      // BMR Calculation (Harris-Benedict)
      double bmr;
      if (_gender == "Male") {
        bmr = (10 * weight) + (6.25 * height) - (5 * age) + 5;
      } else {
        bmr = (10 * weight) + (6.25 * height) - (5 * age) - 161;
      }

      double activityMultiplier = 1.2;
      if (_activity.contains("Light")) activityMultiplier = 1.375;
      if (_activity.contains("Moderate")) activityMultiplier = 1.55;
      if (_activity.contains("Active")) activityMultiplier = 1.725;

      double tdee = bmr * activityMultiplier;
      double targetCalories = tdee;

      if (_goal.contains("Weight Loss")) targetCalories -= 500;
      if (_goal.contains("Muscle Gain")) targetCalories += 300;

      // Save to Firebase
      String uid = FirebaseAuth.instance.currentUser!.uid;
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'name': _nameCtrl.text.trim(),
        'age': age,
        'weight': weight,
        'height': height,
        'gender': _gender,
        'activityLevel': _activity,
        'goal': _goal,
        'bmr': bmr,
        'tdee': tdee,
        'dailyCaloriesTarget': targetCalories.round(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      // === NAVIGATION LOGIC ===
      if (widget.isEditing) {
        // If editing, just go back to Settings
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profile Updated!")));
      } else {
        // If first time setup, go to Main Dashboard
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MainDashboard()),
        );
      }

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.isEditing ? "Edit Profile" : "Setup Profile")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text("Enter your details to calculate your daily calorie plan.", style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 20),
            TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: "Name", border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: _ageCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Age", border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: _weightCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Weight (kg)", border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: _heightCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Height (cm)", border: OutlineInputBorder())),
            const SizedBox(height: 10),
            DropdownButtonFormField(
              initialValue: _gender,
              items: ["Male", "Female"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) => setState(() => _gender = v.toString()),
              decoration: const InputDecoration(labelText: "Gender", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField(
              initialValue: _goal,
              items: ["Weight Loss (减脂)", "Maintain (保持)", "Muscle Gain (增肌)"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) => setState(() => _goal = v.toString()),
              decoration: const InputDecoration(labelText: "Goal", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField(
              initialValue: _activity,
              items: ["Sedentary (久坐不动)", "Light (轻度运动)", "Moderate (适度运动)", "Active (高强度运动)"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) => setState(() => _activity = v.toString()),
              decoration: const InputDecoration(labelText: "Activity Level", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveAndContinue,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                child: _isSaving 
                  ? const CircularProgressIndicator(color: Colors.white) 
                  : Text(widget.isEditing ? "Save Changes" : "Generate Plan & Continue"),
              ),
            )
          ],
        ),
      ),
    );
  }
}

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
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('daily_logs')
          .doc(today)
          .set({
            'calories_consumed': FieldValue.increment(calories),
            'last_updated': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
      
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
    const SettingsPage(),
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

// ==========================================
// 5. 首页 TAB (HOME TAB) - 真正的核心
// ==========================================
class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  // --- MOCK STATE FOR UI DEMO ---
  int _waterMl = 1250; // Current water in ml
  int _stepCount = 4200;
  double _sleepHours = 7.5;
  
  // Fake Calendar Data (Green = Workout Done, Red = Rest/Missed)
  final List<Map<String, dynamic>> _weekData = [
    {"day": "Mon", "status": "done"},
    {"day": "Tue", "status": "done"},
    {"day": "Wed", "status": "rest"},
    {"day": "Thu", "status": "today"}, // Today
    {"day": "Fri", "status": "future"},
    {"day": "Sat", "status": "future"},
    {"day": "Sun", "status": "future"},
  ];

  @override
  Widget build(BuildContext context) {
    final String uid = FirebaseAuth.instance.currentUser!.uid;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasData && snapshot.data!.exists) {
          var userData = snapshot.data!.data() as Map<String, dynamic>;
          String name = userData['name'] ?? "User";
          int target = userData['dailyCaloriesTarget'] ?? 2000;
          
          // Mock Consumption Data
          int consumed = 850;
          int remaining = target - consumed;
          double progress = (target > 0) ? consumed / target : 0;

          return Scaffold(
            backgroundColor: Colors.grey[50], // Light background
            
            // === 1. HEADER & QUICK ADD ===
            appBar: AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("👋 Hi, $name", style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 22)),
                  const Text("Let's crush today's goals!", style: TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
              actions: [
                // Quick Add Button (Meal)
                Container(
                  margin: const EdgeInsets.only(right: 16),
                  decoration: BoxDecoration(color: Colors.teal.shade50, borderRadius: BorderRadius.circular(10)),
                  child: IconButton(
                    icon: const Icon(Icons.add, color: Colors.teal),
                    tooltip: "Quick Log Meal",
                    onPressed: () {
                      // Navigate to Diet Page
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Quick Log: Opening Diet Page...")));
                    },
                  ),
                )
              ],
            ),

            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  
                  // === 2. CALENDAR STRIP & STREAK ===
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("This Week", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(20)),
                        child: Row(
                          children: const [
                            Icon(Icons.local_fire_department, color: Colors.orange, size: 16),
                            SizedBox(width: 4),
                            Text("3 Day Streak", style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12)),
                          ],
                        ),
                      )
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: _weekData.map((d) => _buildDayBubble(d)).toList(),
                  ),

                  const SizedBox(height: 20),

                  // === 3. NUTRI-RING CARD ===
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 10, offset: const Offset(0, 5))],
                    ),
                    child: Row(
                      children: [
                        // Left: Macro Text
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Calories Remaining", style: TextStyle(color: Colors.grey, fontSize: 12)),
                              Text("$remaining", style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.teal)),
                              const Text("kcal left", style: TextStyle(color: Colors.grey)),
                              const SizedBox(height: 15),
                              // Macro Chips
                              Row(
                                children: [
                                  _buildMacroChip("🥩 80g Pro"),
                                  const SizedBox(width: 8),
                                  _buildMacroChip("🍞 120g Carb"),
                                ],
                              )
                            ],
                          ),
                        ),
                        // Right: Ring Chart
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 100, height: 100,
                              child: CircularProgressIndicator(
                                value: progress,
                                backgroundColor: Colors.grey.shade100,
                                color: Colors.teal,
                                strokeWidth: 10,
                                strokeCap: StrokeCap.round,
                              ),
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text("${(progress * 100).toInt()}%", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                              ],
                            )
                          ],
                        )
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // === 4. WORKOUT CARD ===
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF2C3E50), Color(0xFF4CA1AF)]), // Cool Blue-Grey Gradient
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: Colors.blueGrey.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(5)),
                              child: const Text("TODAY'S PLAN", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                            const Icon(Icons.fitness_center, color: Colors.white70)
                          ],
                        ),
                        const SizedBox(height: 10),
                        const Text("Leg Day - Hypertrophy", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 5),
                        const Text("⏳ 60 min  •  High Intensity", style: TextStyle(color: Colors.white70)),
                        const SizedBox(height: 15),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              // Switch to Workout Tab logic
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Starting Workout...")));
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white, 
                              foregroundColor: Colors.teal,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                            ),
                            child: const Text("Start Workout"),
                          ),
                        )
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // === 5. DAILY TRACKERS ROW (Water, Steps, Sleep) ===
                  const Align(alignment: Alignment.centerLeft, child: Text("Daily Trackers", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                  const SizedBox(height: 10),
                  
                  // Water Tracker (Interactive)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(10)),
                          child: const Icon(Icons.water_drop, color: Colors.blue),
                        ),
                        const SizedBox(width: 15),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Hydration", style: TextStyle(fontSize: 14, color: Colors.grey)),
                            RichText(
                              text: TextSpan(
                                children: [
                                  TextSpan(text: "${(_waterMl / 1000).toStringAsFixed(1)}L", style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18)),
                                  const TextSpan(text: " / 2.5L", style: TextStyle(color: Colors.grey)),
                                ]
                              )
                            ),
                          ],
                        ),
                        const Spacer(),
                        InkWell(
                          onTap: () {
                            setState(() => _waterMl += 250);
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Glug glug! +250ml added 💧")));
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(color: Colors.blue, borderRadius: BorderRadius.circular(20)),
                            child: const Text("+ 250ml", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                        )
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 10),

                  // Steps & Sleep Row
                  Row(
                    children: [
                      // Steps
                      Expanded(
                        child: _buildMiniTracker(Icons.directions_walk, "Steps", "$_stepCount", Colors.orange),
                      ),
                      const SizedBox(width: 10),
                      // Sleep
                      Expanded(
                        child: _buildMiniTracker(Icons.bedtime, "Sleep", "${_sleepHours}h", Colors.purple),
                      ),
                    ],
                  ),

                  const SizedBox(height: 30),
                ],
              ),
            ),
          );
        }
        return const Center(child: Text("Loading Dashboard..."));
      },
    );
  }

  // --- HELPER WIDGETS ---

  // 1. Day Bubble (For Calendar Strip)
  Widget _buildDayBubble(Map<String, dynamic> data) {
    Color bg = Colors.transparent;
    Color text = Colors.grey;
    BoxBorder? border = Border.all(color: Colors.grey.shade300);
    Widget content = Text(data['day'], style: const TextStyle(fontSize: 12));

    if (data['status'] == 'done') {
      bg = Colors.green;
      text = Colors.white;
      border = null;
      content = const Icon(Icons.check, color: Colors.white, size: 16);
    } else if (data['status'] == 'rest') {
      bg = Colors.red.shade100;
      text = Colors.red;
      border = null;
      content = const Icon(Icons.close, color: Colors.red, size: 16);
    } else if (data['status'] == 'today') {
      bg = Colors.teal;
      text = Colors.white;
      border = null;
      content = Text(data['day'], style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white));
    }

    return Column(
      children: [
        Container(
          width: 35, height: 35,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: bg, shape: BoxShape.circle, border: border),
          child: content,
        ),
        const SizedBox(height: 4),
        if (data['status'] != 'today')
           Text(data['day'], style: const TextStyle(color: Colors.grey, fontSize: 10))
      ],
    );
  }

  // 2. Macro Chip (Small pills for Protein/Carbs)
  Widget _buildMacroChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(5)),
      child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87)),
    );
  }

  // 3. Mini Tracker (Steps/Sleep Box)
  Widget _buildMiniTracker(IconData icon, String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

// ==========================================
// 5. DASHBOARD TAB
// ==========================================
class HomeTabScreen extends StatelessWidget {
  final int target;
  final int consumed;
  final String user;

  const HomeTabScreen({super.key, required this.target, required this.consumed, required this.user});

  @override
  Widget build(BuildContext context) {
    double progress = consumed / target;
    if (progress > 1.0) progress = 1.0;

    return Scaffold(
      appBar: AppBar(title: Text("Hi, $user")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Calorie Card
            Card(
              color: Colors.teal,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Calories Remaining", style: TextStyle(color: Colors.white70)),
                        Text("${target - consumed} kcal", style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    CircularProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.white30,
                      color: Colors.white,
                      strokeWidth: 8,
                    )
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text("Your Diet Plan (Generated)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            // Mock Diet List based on Report Logic
            Expanded(
              child: ListView(
                children: const [
                  ListTile(
                    leading: Icon(Icons.breakfast_dining, color: Colors.orange),
                    title: Text("Breakfast"),
                    subtitle: Text("Oatmeal & Berries (350 kcal) - Carbs Focus"),
                  ),
                  ListTile(
                    leading: Icon(Icons.lunch_dining, color: Colors.orange),
                    title: Text("Lunch"),
                    subtitle: Text("Grilled Chicken & Rice (550 kcal) - Protein Focus"),
                  ),
                  ListTile(
                    leading: Icon(Icons.dinner_dining, color: Colors.orange),
                    title: Text("Dinner"),
                    subtitle: Text("Salmon Salad (400 kcal) - Low Fat"),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 6. WORKOUT TAB (Logic-Based Filtering)
// ==========================================
class WorkoutTab extends StatefulWidget {
  const WorkoutTab({super.key});

  @override
  State<WorkoutTab> createState() => _WorkoutTabState();
}

class _WorkoutTabState extends State<WorkoutTab> {
  // Toggle between "Featured" (Local) and "Search" (API)
  bool _showSearch = false; 
  
  // --- API STATE ---
  List<dynamic> _apiExercises = [];
  bool _isLoading = false;
  final TextEditingController _searchController = TextEditingController();

  // --- LOCAL DATA ---
  String _difficulty = "Beginner";
  final List<Map<String, dynamic>> _localExercises = [
    {
      "name": "Push Ups",
      "level": "Beginner",
      "sets": "3 sets x 10 reps",
      "image": "https://images.unsplash.com/photo-1599058945522-28d584b6f0ff?w=400",
      "desc": "Keep body straight, lower chest to floor."
    },
    {
      "name": "Burpees",
      "level": "Advanced",
      "sets": "4 sets x 15 reps",
      "image": "https://images.unsplash.com/photo-1544367563-12123d896889?w=400",
      "desc": "Squat, kick back, push up, jump."
    },
    {
      "name": "Plank",
      "level": "Intermediate",
      "sets": "3 sets x 45 sec",
      "image": "https://images.unsplash.com/photo-1517836357463-d25dfeac3438?w=400",
      "desc": "Hold core tight on elbows."
    },
     {
      "name": "Squats",
      "level": "Beginner",
      "sets": "3 sets x 15 reps",
      "image": "https://images.unsplash.com/photo-1574680096145-d05b474e2155?w=400",
      "desc": "Lower hips back and down."
    },
  ];

  // --- API FUNCTION ---
  Future<void> _searchExercises(String muscle) async {
    if (muscle.isEmpty) return;
    setState(() => _isLoading = true);
    
    // ⚠️ REPLACE 'YOUR_API_KEY' WITH YOUR ACTUAL KEY FROM API-NINJAS
    const String apiKey = '8alHG9q8gsGcxiDeckmVdPI0Crn8ScxrgKnYA0z7'; 
    
    try {
      // Searching by muscle (e.g., biceps, chest, lats)
      final url = Uri.parse('https://api.api-ninjas.com/v1/exercises?muscle=$muscle');
      final response = await http.get(url, headers: {'X-Api-Key': apiKey});

      if (response.statusCode == 200) {
        setState(() {
          _apiExercises = json.decode(response.body);
          _isLoading = false;
        });
      } else {
        throw Exception("Failed to load");
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error fetching workouts. Check API Key.")));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Filter Local List
    List<Map<String, dynamic>> filteredLocal = _localExercises
        .where((ex) => ex["level"] == _difficulty)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Workout Coach"),
        actions: [
          // Toggle Button
          TextButton.icon(
            onPressed: () {
              setState(() => _showSearch = !_showSearch);
            },
            icon: Icon(_showSearch ? Icons.star : Icons.search, color: Colors.teal),
            label: Text(_showSearch ? "Show Featured" : "Search Library", style: const TextStyle(color: Colors.teal)),
          )
        ],
      ),
      body: _showSearch ? _buildApiSearch() : _buildLocalList(filteredLocal),
    );
  }

  // VIEW 1: API SEARCH UI
  Widget _buildApiSearch() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: "Search Muscle (e.g., biceps, chest)",
              suffixIcon: IconButton(
                icon: const Icon(Icons.search), 
                onPressed: () => _searchExercises(_searchController.text.trim())
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onSubmitted: (val) => _searchExercises(val.trim()),
          ),
        ),
        if (_isLoading) const LinearProgressIndicator(),
        Expanded(
          child: _apiExercises.isEmpty 
          ? const Center(child: Text("Enter a muscle group to search (e.g. 'abs')"))
          : ListView.builder(
              itemCount: _apiExercises.length,
              itemBuilder: (context, index) {
                final ex = _apiExercises[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                  child: ListTile(
                    leading: const CircleAvatar(backgroundColor: Colors.teal, child: Icon(Icons.fitness_center, color: Colors.white)),
                    title: Text(ex['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text("Difficulty: ${ex['difficulty']} | Type: ${ex['type']}"),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      // Convert API data to our App's format
                      Map<String, dynamic> convertedData = {
                        "name": ex['name'],
                        "level": ex['difficulty'],
                        "sets": "3 sets x 10 reps", // Default since API doesn't give this
                        "image": "https://images.unsplash.com/photo-1517836357463-d25dfeac3438?w=400", // Placeholder Image
                        "desc": ex['instructions'] ?? "No instructions provided."
                      };
                      
                      // Go to Active Workout
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ActiveWorkoutPage(
                            exerciseData: convertedData, 
                            totalExercises: 1, 
                            currentExerciseIndex: 0
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
        )
      ],
    );
  }

  // VIEW 2: LOCAL FEATURED UI (Your pretty cards)
  Widget _buildLocalList(List<Map<String, dynamic>> filteredLocal) {
    return Column(
      children: [
         Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: ["Beginner", "Intermediate", "Advanced"].map((level) {
                return ChoiceChip(
                  label: Text(level),
                  selected: _difficulty == level,
                  selectedColor: Colors.teal,
                  labelStyle: TextStyle(color: _difficulty == level ? Colors.white : Colors.black),
                  onSelected: (selected) {
                    if (selected) setState(() => _difficulty = level);
                  },
                );
              }).toList(),
            ),
          ),
        Expanded(
          child: ListView.builder(
            itemCount: filteredLocal.length,
            itemBuilder: (context, index) {
              final ex = filteredLocal[index];
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ActiveWorkoutPage(
                        exerciseData: ex, 
                        totalExercises: filteredLocal.length, 
                        currentExerciseIndex: index
                      ),
                    ),
                  );
                },
                child: Container(
                  margin: const EdgeInsets.all(12),
                  height: 140,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    image: DecorationImage(
                      image: NetworkImage(ex["image"]), 
                      fit: BoxFit.cover,
                      colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.6), BlendMode.darken), 
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(ex["name"], style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            const Icon(Icons.timer, color: Colors.tealAccent, size: 18),
                            const SizedBox(width: 5),
                            Text(ex["sets"], style: const TextStyle(color: Colors.white, fontSize: 16)),
                          ],
                        )
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ==========================================
// 7. MOCK CAMERA TAB (Simulated AI)
// ==========================================
class CameraTab extends StatefulWidget {
  final Function(int) onFoodDetected;

  const CameraTab({super.key, required this.onFoodDetected});

  @override
  State<CameraTab> createState() => _CameraTabState();
}

class _CameraTabState extends State<CameraTab> {
  bool _scanning = false;
  String? _result;
  File? _capturedImage; // 新增：用于存储拍到的照片
  final ImagePicker _picker = ImagePicker(); // 新增：相机控制器
  final _model = GenerativeModel(
    model: 'gemini-3-flash-preview',
    apiKey: 'AIzaSyB9TDChx2b_oQ4ntM_MGjOYGM27UGAjZCE', 
  );
  // 将原本的 _simulateScan 修改为真实的拍照逻辑
Future<void> _takePhotoAndScan() async {
final XFile? photo = await _picker.pickImage(
  source: ImageSource.camera,
  maxWidth: 1024,      // 稍微增加到 1024，给 AI 更多细节
  maxHeight: 1024,
  imageQuality: 85,    // 质量提高到 85，清晰度更佳
); if (photo == null) return;

  // 1. Give the phone OS a second to finish writing the file
  await Future.delayed(const Duration(milliseconds: 500)); 

  setState(() {
    _scanning = true;
    _capturedImage = File(photo.path); 
  });

  try {
    final bytes = await photo.readAsBytes();
    
    // Use the multi-part content correctly
    final content = [
      Content.multi([
        TextPart("Identify food and total calories. Reply ONLY in this format: Food: [name], Calories: [number] kcal"),
        DataPart('image/jpeg', bytes),
      ])
    ];

    // Increase safety by checking for response validity
    final response = await _model.generateContent(content);
    
    if (response.text == null || response.text!.isEmpty) {
       throw Exception("Gemini returned an empty response.");
    }

    final responseText = response.text!;

    // Regular Expression to pull out just the number
    final regExp = RegExp(r'(\d+)');
    final match = regExp.firstMatch(responseText);
    int detectedCalories = match != null ? int.parse(match.group(0)!) : 0;

    if (mounted) {
      setState(() {
        _scanning = false;
        _result = responseText;
      });

      widget.onFoodDetected(detectedCalories); 

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("AI Detected: $detectedCalories kcal!")),
      );
    }
  } catch (e) {
    setState(() => _scanning = false);
    // This will print the exact error (e.g., 400, 403, 404, or 500)
    print("---------- GEMINI DEBUG INFO ----------");
    print("Error Type: ${e.runtimeType}");
    print("Error Message: $e");
    print("---------------------------------------");
  
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("API Failed: $e")),
    );
  }
}
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("AI Food Scanner")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 修改后的显示区域：拍了照就显示照片，没拍就显示图标
            Container(
              height: 300,
              width: 300,
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(15),
              ),
              child: _scanning
                  ? const Center(child: CircularProgressIndicator())
                  : (_capturedImage != null 
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(15),
                          child: Image.file(_capturedImage!, fit: BoxFit.cover),
                        )
                      : const Icon(Icons.camera_alt, size: 100, color: Colors.grey)),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              // 点击后调用真实的相机
              onPressed: _scanning ? null : _takePhotoAndScan,
              icon: const Icon(Icons.camera),
              label: const Text("Capture Real Food"),
            ),
            const SizedBox(height: 20),
            if (_result != null)
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.green[50], 
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(_result!, style: const TextStyle(fontSize: 16, color: Colors.green)),
              )
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 8. DIET PAGE (MAIN LOG & DASHBOARD)
// ==========================================
class DietPage extends StatefulWidget {
  const DietPage({super.key});

  @override
  State<DietPage> createState() => _DietPageState();
}

class _DietPageState extends State<DietPage> {
  // --- STATE ---
  DateTime _selectedDate = DateTime.now();
  bool _showPercentage = false; // Toggle for Macros
  int _dailyTarget = 2000;
  int _exerciseBurn = 350; // Mocked exercise burn

  // Mocked Food Log (In a real app, this comes from Firebase)
  // We use lists for each "Bucket"
  List<Map<String, dynamic>> _breakfast = [
    {"name": "Oatmeal", "qty": "1 cup", "cals": 150, "pro": 5, "carbs": 27, "fat": 3},
    {"name": "Boiled Egg", "qty": "1 large", "cals": 78, "pro": 6, "carbs": 0.6, "fat": 5},
  ];
  List<Map<String, dynamic>> _lunch = [];
  List<Map<String, dynamic>> _dinner = [];
  List<Map<String, dynamic>> _snacks = [];

  // --- HELPERS ---
  void _changeDate(int days) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: days));
    });
  }

  // Calculate Totals
  Map<String, double> _calculateTotals() {
    double totalCals = 0, totalPro = 0, totalCarbs = 0, totalFat = 0;
    for (var list in [_breakfast, _lunch, _dinner, _snacks]) {
      for (var item in list) {
        totalCals += item['cals'];
        totalPro += item['pro'];
        totalCarbs += item['carbs'];
        totalFat += item['fat'];
      }
    }
    return {"cals": totalCals, "pro": totalPro, "carbs": totalCarbs, "fat": totalFat};
  }

  // Navigate to Add Food Page
  void _goToAddFood(String mealCategory) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AddFoodPage(mealCategory: mealCategory)),
    );

    // If user added a food, update the list
    if (result != null && result is Map<String, dynamic>) {
      setState(() {
        if (mealCategory == "Breakfast") _breakfast.add(result);
        if (mealCategory == "Lunch") _lunch.add(result);
        if (mealCategory == "Dinner") _dinner.add(result);
        if (mealCategory == "Snack") _snacks.add(result);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final totals = _calculateTotals();
    final int foodEaten = totals['cals']!.toInt();
    final int remaining = _dailyTarget - foodEaten + _exerciseBurn;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.calendar_today, color: Colors.teal), onPressed: () {}),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(icon: const Icon(Icons.arrow_back_ios, size: 16, color: Colors.black), onPressed: () => _changeDate(-1)),
            Text(
              "${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}",
              style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16),
            ),
            IconButton(icon: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.black), onPressed: () => _changeDate(1)),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(icon: const Icon(Icons.more_horiz, color: Colors.black), onPressed: () {}),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 1. SUMMARY CARD (Equation)
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10)]),
              child: Column(
                children: [
                  // The Math Equation
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildMathColumn("Goal", "$_dailyTarget"),
                      const Text("-", style: TextStyle(fontSize: 20, color: Colors.grey)),
                      _buildMathColumn("Food", "$foodEaten"),
                      const Text("+", style: TextStyle(fontSize: 20, color: Colors.grey)),
                      _buildMathColumn("Exercise", "$_exerciseBurn"),
                      const Text("=", style: TextStyle(fontSize: 20, color: Colors.grey)),
                      _buildMathColumn("Remaining", "$remaining", isBold: true),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 10),
                  
                  // Macro Bars (Toggleable)
                  InkWell(
                    onTap: () => setState(() => _showPercentage = !_showPercentage),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildMacroBar("Protein", totals['pro']!, 150, Colors.purple),
                        _buildMacroBar("Carbs", totals['carbs']!, 250, Colors.orange),
                        _buildMacroBar("Fat", totals['fat']!, 65, Colors.blue),
                      ],
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Center(child: Text("Tap bars to toggle %", style: TextStyle(color: Colors.grey, fontSize: 10))),
                ],
              ),
            ),

            // 2. MEAL BUCKETS
            _buildMealBucket("Breakfast", _breakfast),
            _buildMealBucket("Lunch", _lunch),
            _buildMealBucket("Dinner", _dinner),
            _buildMealBucket("Snack", _snacks),
            
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // --- WIDGET BUILDERS ---

  Widget _buildMathColumn(String label, String value, {bool isBold = false}) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 5),
        Text(value, style: TextStyle(fontSize: 16, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: isBold ? Colors.teal : Colors.black)),
      ],
    );
  }

  Widget _buildMacroBar(String label, double current, double target, Color color) {
    double progress = current / target;
    if (progress > 1) progress = 1;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 5),
        SizedBox(
          width: 90,
          child: LinearProgressIndicator(value: progress, backgroundColor: color.withOpacity(0.1), color: color, minHeight: 6, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(height: 5),
        Text(
          _showPercentage ? "${(progress * 100).toInt()}%" : "${(target - current).toInt()}g left",
          style: const TextStyle(fontSize: 10, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildMealBucket(String title, List<Map<String, dynamic>> items) {
    double bucketCals = items.fold(0, (sum, item) => sum + (item['cals'] as num).toDouble());

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text("${bucketCals.toInt()} kcal", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
              ],
            ),
          ),
          const Divider(height: 1),
          
          // Food List
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return Dismissible(
                key: Key(item['name'] + index.toString()),
                background: Container(color: Colors.green, alignment: Alignment.centerLeft, padding: const EdgeInsets.only(left: 20), child: const Icon(Icons.copy, color: Colors.white)),
                secondaryBackground: Container(color: Colors.red, alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), child: const Icon(Icons.delete, color: Colors.white)),
                confirmDismiss: (direction) async {
                   if (direction == DismissDirection.startToEnd) {
                     ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Copied ${item['name']} to Tomorrow")));
                     return false; // Don't delete, just copy action
                   } else {
                     setState(() => items.removeAt(index));
                     return true; // Delete
                   }
                },
                child: ListTile(
                  title: Text(item['name'], style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text("${item['qty']} • ${item['cals']} kcal"),
                  onTap: () {
                    // Show Nutrition Analysis (Dialog)
                     showDialog(context: context, builder: (c) => AlertDialog(
                       title: Text(item['name']),
                       content: Text("Protein: ${item['pro']}g\nCarbs: ${item['carbs']}g\nFat: ${item['fat']}g\n\nFull analysis data would appear here."),
                       actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text("Close"))],
                     ));
                  },
                ),
              );
            },
          ),
          
          // Add Button
          InkWell(
            onTap: () => _goToAddFood(title),
            child: Container(
              padding: const EdgeInsets.all(16),
              alignment: Alignment.centerLeft,
              child: const Row(
                children: [
                  Icon(Icons.add, color: Colors.teal),
                  SizedBox(width: 8),
                  Text("ADD FOOD", style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// NEW PAGE: ADD FOOD INTERFACE
// ==========================================
class AddFoodPage extends StatefulWidget {
  final String mealCategory;
  const AddFoodPage({super.key, required this.mealCategory});

  @override
  State<AddFoodPage> createState() => _AddFoodPageState();
}

class _AddFoodPageState extends State<AddFoodPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // Local Database List
  List<dynamic> _allFoods = []; 
  List<dynamic> _searchResults = [];
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadFoods(); // Load local json
  }

  Future<void> _loadFoods() async {
    try {
      final String response = await rootBundle.loadString('assets/data/foods.json');
      final data = json.decode(response);
      setState(() {
        _allFoods = data;
        _searchResults = data; // Show all initially
      });
    } catch (e) { print("Error loading foods: $e"); }
  }

  void _filterFoods(String query) {
    if (query.isEmpty) {
      setState(() => _searchResults = _allFoods);
    } else {
      setState(() {
        _searchResults = _allFoods.where((food) => 
          food['product_name'].toString().toLowerCase().contains(query.toLowerCase())
        ).toList();
      });
    }
  }

  // When a food is selected, return it to the Diet Page
  void _selectFood(dynamic food) {
    // Convert to the map format expected by DietPage
    Map<String, dynamic> addedItem = {
      "name": food['product_name'],
      "qty": "1 serving",
      "cals": food['nutriments']['energy-kcal_100g'],
      "pro": food['nutriments']['proteins_100g'],
      "carbs": 20, // Mocked for demo if JSON missing this
      "fat": 5,    // Mocked for demo
    };
    Navigator.pop(context, addedItem); // Go back with data
  }

  // Simulate AI Scan
  void _simulateAIScan() async {
    showDialog(context: context, barrierDismissible: false, builder: (c) => const Center(child: CircularProgressIndicator()));
    await Future.delayed(const Duration(seconds: 2)); // Fake delay
    if (mounted) {
      Navigator.pop(context); // Close spinner
      // Fake Result
      Map<String, dynamic> aiResult = {
        "name": "Grilled Chicken Salad",
        "qty": "1 bowl",
        "cals": 350,
        "pro": 30, "carbs": 12, "fat": 15
      };
      // Show confirmation
      showDialog(context: context, builder: (c) => AlertDialog(
        title: const Text("AI Detected"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 50),
            const SizedBox(height: 10),
            const Text("Grilled Chicken Salad (350 kcal)"),
          ],
        ),
        actions: [
          TextButton(onPressed: () {
            Navigator.pop(c); // Close dialog
            Navigator.pop(context, aiResult); // Return result
          }, child: const Text("Add to Log"))
        ],
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Add to ${widget.mealCategory}"),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.teal,
          indicatorColor: Colors.teal,
          tabs: const [
            Tab(text: "Search"),
            Tab(text: "Recent"),
            Tab(text: "Scan"),
            Tab(text: "AI Cam"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // TAB 1: SEARCH (Local Database)
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: _filterFoods,
                  decoration: InputDecoration(
                    hintText: "Search food (e.g. Rice, Apple)",
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    filled: true,
                    fillColor: Colors.grey[100],
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final food = _searchResults[index];
                    return ListTile(
                      leading: Image.network(food['image'], width: 40, errorBuilder: (c,o,s)=>const Icon(Icons.fastfood)),
                      title: Text(food['product_name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text("${food['nutriments']['energy-kcal_100g']} kcal • ${food['nutriments']['proteins_100g']}g Protein"),
                      trailing: const Icon(Icons.add_circle_outline, color: Colors.teal),
                      onTap: () => _selectFood(food),
                    );
                  },
                ),
              )
            ],
          ),

          // TAB 2: RECENT (Mocked)
          ListView(
            children: [
              _buildRecentTile("Oatmeal", 150),
              _buildRecentTile("Banana", 90),
              _buildRecentTile("Coffee (Black)", 5),
            ],
          ),

          // TAB 3: BARCODE (Placeholder for Demo)
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.qr_code_scanner, size: 80, color: Colors.grey),
                const SizedBox(height: 20),
                const Text("Align barcode within frame"),
                const SizedBox(height: 20),
                ElevatedButton(onPressed: () => _selectFood({"product_name": "Scanned Oreo", "nutriments": {"energy-kcal_100g": 140, "proteins_100g": 1}, "image": ""}), child: const Text("Simulate Scan"))
              ],
            ),
          ),

          // TAB 4: AI CAMERA
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.camera_alt, size: 80, color: Colors.teal),
                const SizedBox(height: 20),
                const Text("Take a photo of your meal"),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _simulateAIScan,
                  icon: const Icon(Icons.camera),
                  label: const Text("Snap Photo"),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentTile(String name, int cals) {
    return ListTile(
      title: Text(name),
      subtitle: Text("$cals kcal"),
      trailing: const Icon(Icons.history, color: Colors.grey),
      onTap: () => _selectFood({"product_name": name, "nutriments": {"energy-kcal_100g": cals, "proteins_100g": 0}, "image": ""}),
    );
  }
}


// ==========================================
// 9. Setting page
// ==========================================

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // --- STATE VARIABLES ---
  bool _isDarkMode = false;
  bool _keepScreenAwake = false;
  
  // Units
  String _weightUnit = "kg";
  String _distanceUnit = "km";
  String _energyUnit = "kcal";
  final String _waterUnit = "ml";

  // Notifications
  bool _workoutReminder = true;
  bool _mealReminder = true;
  bool _hydrationReminder = false;
  bool _weighInReminder = false;

  String _selectedLanguage = "English";

  // --- HELPER FUNCTIONS ---

  // 1. Language Picker
  void _showLanguageDialog() {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Select Language'),
        children: ["English 🇺🇸", "Chinese (中文) 🇨🇳", "Malay (Bahasa) 🇲🇾"]
            .map((lang) => SimpleDialogOption(
                  onPressed: () {
                    setState(() => _selectedLanguage = lang);
                    Navigator.pop(context);
                  },
                  child: Text(lang),
                ))
            .toList(),
      ),
    );
  }

  // 2. Unit Picker (Generic)
  void _showUnitPicker(String title, List<String> options, Function(String) onSelect) {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('Select $title Unit'),
        children: options
            .map((opt) => SimpleDialogOption(
                  onPressed: () {
                    onSelect(opt);
                    Navigator.pop(context);
                  },
                  child: Text(opt),
                ))
            .toList(),
      ),
    );
  }

  // 3. Quick Update Weight Dialog
  void _showUpdateWeightDialog() {
    final TextEditingController weightCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Log Current Weight"),
        content: TextField(
          controller: weightCtrl,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: "Current Weight ($_weightUnit)", border: const OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              // TODO: Save this to Firestore history
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Logged: ${weightCtrl.text} $_weightUnit")));
              Navigator.pop(context);
            },
            child: const Text("Update"),
          )
        ],
      ),
    );
  }

  // 4. Physical Calculator (BMI/TDEE Sandbox)
  void _openCalculator() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        height: 600,
        child: Column(
          children: [
            const Text("Quick Calculator (Sandbox)", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            const Text("Check BMI/TDEE without changing your profile.", style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 20),
            // Add inputs here in the future
            const TextField(decoration: InputDecoration(labelText: "Weight", border: OutlineInputBorder())),
            const SizedBox(height: 10),
            const TextField(decoration: InputDecoration(labelText: "Height", border: OutlineInputBorder())),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                 // Calculate logic here
                 Navigator.pop(context);
                 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Result: BMI 22.5 (Normal)")));
              }, 
              child: const Text("Calculate")
            )
          ],
        ),
      ),
    );
  }

  // 5. Destructive Action Confirm
  Future<void> _confirmDestructiveAction(String title, String content, VoidCallback onConfirm) async {
    bool confirm = await showDialog(
      context: context, 
      builder: (context) => AlertDialog(
        title: Text(title, style: const TextStyle(color: Colors.red)),
        content: Text(content),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Confirm", style: TextStyle(color: Colors.red))),
        ],
      )
    ) ?? false;

    if (confirm) onConfirm();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Settings")),
      body: ListView(
        children: [
          // ==========================
          // 1. ACCOUNT & GOALS
          // ==========================
          _buildHeader("Account & Goals"),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text("Edit Profile"),
            subtitle: const Text("Goals, Micro-Splits, Frequency"),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SetupProfilePage(isEditing: true))),
          ),
          ListTile(
            leading: const Icon(Icons.monitor_weight_outlined),
            title: const Text("Quick Weight Log"),
            subtitle: const Text("Update current weight only"),
            trailing: const Icon(Icons.add_circle_outline, color: Colors.teal),
            onTap: _showUpdateWeightDialog,
          ),
          ListTile(
            leading: const Icon(Icons.calculate_outlined),
            title: const Text("Physical Calculator"),
            subtitle: const Text("Check BMI/TDEE scenarios"),
            onTap: _openCalculator,
          ),

          const Divider(),

          // ==========================
          // 2. UNITS & PREFERENCES
          // ==========================
          _buildHeader("Units & Display"),
          ListTile(
            title: const Text("Weight Unit"),
            trailing: Text(_weightUnit.toUpperCase(), style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
            onTap: () => _showUnitPicker("Weight", ["kg", "lbs"], (val) => setState(() => _weightUnit = val)),
          ),
          ListTile(
            title: const Text("Distance Unit"),
            trailing: Text(_distanceUnit.toUpperCase(), style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
            onTap: () => _showUnitPicker("Distance", ["km", "miles"], (val) => setState(() => _distanceUnit = val)),
          ),
          ListTile(
            title: const Text("Energy Unit"),
            trailing: Text(_energyUnit.toUpperCase(), style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
            onTap: () => _showUnitPicker("Energy", ["kcal", "kJ"], (val) => setState(() => _energyUnit = val)),
          ),
          SwitchListTile(
            title: const Text("Keep Screen Awake"),
            subtitle: const Text("Prevent locking during workouts"),
            value: _keepScreenAwake,
            onChanged: (val) => setState(() => _keepScreenAwake = val),
          ),
          SwitchListTile(
            title: const Text("Dark Mode"),
            secondary: Icon(_isDarkMode ? Icons.dark_mode : Icons.light_mode),
            value: _isDarkMode,
            onChanged: (val) {
              setState(() => _isDarkMode = val);
              themeNotifier.value = val ? ThemeMode.dark : ThemeMode.light;
            },
          ),
          ListTile(
            leading: const Icon(Icons.language),
            title: const Text("Language"),
            subtitle: Text(_selectedLanguage),
            onTap: _showLanguageDialog,
          ),

          const Divider(),

          // ==========================
          // 3. NOTIFICATIONS
          // ==========================
          _buildHeader("Notifications"),
          SwitchListTile(title: const Text("Workout Reminders"), value: _workoutReminder, onChanged: (v) => setState(() => _workoutReminder = v)),
          SwitchListTile(title: const Text("Meal Logging"), value: _mealReminder, onChanged: (v) => setState(() => _mealReminder = v)),
          SwitchListTile(title: const Text("Hydration Alerts"), value: _hydrationReminder, onChanged: (v) => setState(() => _hydrationReminder = v)),
          SwitchListTile(title: const Text("Weekly Weigh-in"), value: _weighInReminder, onChanged: (v) => setState(() => _weighInReminder = v)),

          const Divider(),

          // ==========================
          // 4. DATA & PRIVACY
          // ==========================
          _buildHeader("Data & Support"),
          ListTile(
            leading: const Icon(Icons.download),
            title: const Text("Export Data"),
            subtitle: const Text("Download PDF/CSV Report"),
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Generating Report... (Demo Only)"))),
          ),
          ListTile(
            leading: const Icon(Icons.delete_sweep),
            title: const Text("Clear History"),
            onTap: () => _confirmDestructiveAction("Clear History?", "This will delete all past workout and meal logs.", () {
               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("History Cleared")));
            }),
          ),
          ListTile(
            leading: const Icon(Icons.bug_report),
            title: const Text("Report a Bug"),
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Thank you for your report!"))),
          ),
          ListTile(
            leading: const Icon(Icons.help),
            title: const Text("Help Center"),
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Opening FAQ..."))),
          ),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text("Version"),
            subtitle: Text("v1.0.2 (Beta)"),
          ),

          const SizedBox(height: 20),
          
          // ==========================
          // 5. DANGER ZONE (LOGOUT / DELETE)
          // ==========================
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red[50], foregroundColor: Colors.red, elevation: 0),
              icon: const Icon(Icons.logout),
              label: const Text("Log Out"),
              onPressed: () => _confirmDestructiveAction("Log Out?", "Are you sure you want to exit?", () async {
                await FirebaseAuth.instance.signOut();
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const LoginPage()),
                    (route) => false,
                  );
                }
              }),
            ),
          ),
          TextButton(
            onPressed: () => _confirmDestructiveAction("Delete Account?", "This action is PERMANENT. All data will be lost.", () {
               // Add delete logic here
               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Account deletion request sent.")));
            }),
            child: const Text("Delete Account", style: TextStyle(color: Colors.grey, fontSize: 12)),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(title, style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold, fontSize: 14)),
    );
  }
}


// ==========================================
// 10. .。
// ==========================================
class ActiveWorkoutPage extends StatefulWidget {
  final Map<String, dynamic> exerciseData; // The exercise we are doing
  final int totalExercises;
  final int currentExerciseIndex;

  const ActiveWorkoutPage({
    super.key,
    required this.exerciseData,
    required this.totalExercises,
    required this.currentExerciseIndex,
  });

  @override
  State<ActiveWorkoutPage> createState() => _ActiveWorkoutPageState();
}

class _ActiveWorkoutPageState extends State<ActiveWorkoutPage> {
  // --- TIMERS ---
  Timer? _sessionTimer;
  int _sessionSeconds = 0;
  
  Timer? _restTimer;
  int _restSeconds = 0;
  bool _isResting = false;
  final int _defaultRestTime = 60; // Default 60s rest

  // --- LOGGING DATA ---
  // Mocking "Previous Session" data for "Progressive Overload"
  final List<Map<String, dynamic>> _sets = [
    {"set": 1, "prev": "20kg x 10", "weight": "20", "reps": "10", "done": false},
    {"set": 2, "prev": "20kg x 10", "weight": "20", "reps": "10", "done": false},
    {"set": 3, "prev": "20kg x 8",  "weight": "20", "reps": "8",  "done": false},
  ];

  final TextEditingController _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _startSessionTimer();
  }

  @override
  void dispose() {
    _sessionTimer?.cancel();
    _restTimer?.cancel();
    super.dispose();
  }

  // --- TIMER LOGIC ---
  void _startSessionTimer() {
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() => _sessionSeconds++);
    });
  }

  void _triggerRestTimer() {
    setState(() {
      _isResting = true;
      _restSeconds = _defaultRestTime;
    });
    _restTimer?.cancel();
    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_restSeconds > 0) {
        setState(() => _restSeconds--);
      } else {
        _skipRest(); // Timer finished
      }
    });
  }

  void _adjustRestTime(int seconds) {
    setState(() {
      _restSeconds += seconds;
      if (_restSeconds < 0) _restSeconds = 0;
    });
  }

  void _skipRest() {
    _restTimer?.cancel();
    setState(() => _isResting = false);
  }

  // --- FORMATTERS ---
  String _formatTime(int seconds) {
    int m = seconds ~/ 60;
    int s = seconds % 60;
    return "${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}";
  }

  // --- NAVIGATION LOGIC ---
  void _minimize() {
    // In a real app, this would minimize to a floating bubble.
    // For FYP, we pop but show a message.
    Navigator.pop(context); 
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Workout minimized (Session continues in background)")));
  }

  void _finishWorkout() {
    // TODO: Save all logs to Firestore here
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Workout Complete! Great Job! 🎉")));
  }

  @override
  Widget build(BuildContext context) {
    double progress = (widget.currentExerciseIndex + 1) / widget.totalExercises;

    return Scaffold(
      // === APP BAR (Minimize / Cancel) ===
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.keyboard_arrow_down), onPressed: _minimize),
        title: Text("Active Session  ${_formatTime(_sessionSeconds)}"),
        actions: [
          TextButton(
            onPressed: () {
              // Confirm Exit Dialog
              showDialog(context: context, builder: (c) => AlertDialog(
                title: const Text("End Workout?"),
                content: const Text("All unsaved progress will be lost."),
                actions: [
                  TextButton(onPressed: ()=>Navigator.pop(c), child: const Text("Cancel")),
                  TextButton(onPressed: (){ Navigator.pop(c); Navigator.pop(context); }, child: const Text("End", style: TextStyle(color: Colors.red))),
                ],
              ));
            },
            child: const Text("End", style: TextStyle(color: Colors.red)),
          )
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(value: progress, backgroundColor: Colors.grey[300], color: Colors.teal),
        ),
      ),
      
      body: Column(
        children: [
          // === SCROLLABLE CONTENT ===
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // 1. VISUAL GUIDANCE & INFO
                  Container(
                    height: 200,
                    width: double.infinity,
                    color: Colors.black,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(widget.exerciseData['image'], fit: BoxFit.cover, errorBuilder: (c,o,s)=>const Icon(Icons.image_not_supported, color: Colors.white)),
                        Container(decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.transparent, Colors.black.withOpacity(0.8)], begin: Alignment.topCenter, end: Alignment.bottomCenter))),
                        Positioned(
                          bottom: 10, left: 15,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(widget.exerciseData['name'], style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                              const Text("Target: Chest, Triceps, Shoulders", style: TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.bold)), // Muscle Highlight
                            ],
                          ),
                        ),
                        // SUBSTITUTE BUTTON
                        Positioned(
                          top: 10, right: 10,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Substitute: Machine Press selected")));
                            }, 
                            icon: const Icon(Icons.swap_horiz, size: 16), 
                            label: const Text("Swap"),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.black54, foregroundColor: Colors.white),
                          ),
                        )
                      ],
                    ),
                  ),

                  // 2. TEXT INSTRUCTIONS (Expandable)
                  const ExpansionTile(
                    title: Text("Instructions & Form Cues"),
                    children: [
                      Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text("Keep your back flat against the bench. Lower the weight slowly to your chest, pause, and explode up. Do not lock your elbows at the top."),
                      )
                    ],
                  ),

                  const Divider(),

                  // 3. THE LOGGING GRID (THE MEAT)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Column(
                      children: [
                        // Header
                        Row(
                          children: const [
                            SizedBox(width: 30, child: Text("Set", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
                            Expanded(child: Center(child: Text("Previous", style: TextStyle(color: Colors.grey, fontSize: 12)))),
                            Expanded(child: Center(child: Text("kg", style: TextStyle(fontWeight: FontWeight.bold)))),
                            Expanded(child: Center(child: Text("Reps", style: TextStyle(fontWeight: FontWeight.bold)))),
                            SizedBox(width: 40, child: Icon(Icons.check, color: Colors.grey)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        
                        // Dynamic Set Rows
                        ..._sets.map((set) {
                          bool isDone = set['done'];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: isDone ? Colors.teal.withOpacity(0.1) : Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade300)
                            ),
                            child: Row(
                              children: [
                                // Set Number
                                SizedBox(width: 30, child: Center(child: Text("${set['set']}", style: const TextStyle(fontWeight: FontWeight.bold)))),
                                
                                // Previous Data
                                Expanded(child: Center(child: Text(set['prev'], style: const TextStyle(color: Colors.grey, fontSize: 12)))),
                                
                                // Weight Input
                                Expanded(
                                  child: Container(
                                    margin: const EdgeInsets.symmetric(horizontal: 4),
                                    height: 40,
                                    child: TextFormField(
                                      initialValue: set['weight'],
                                      textAlign: TextAlign.center,
                                      keyboardType: TextInputType.number,
                                      decoration: InputDecoration(
                                        contentPadding: const EdgeInsets.only(bottom: 10),
                                        filled: true,
                                        fillColor: Colors.grey[100],
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(5), borderSide: BorderSide.none),
                                      ),
                                    ),
                                  ),
                                ),
                                
                                // Reps Input
                                Expanded(
                                  child: Container(
                                    margin: const EdgeInsets.symmetric(horizontal: 4),
                                    height: 40,
                                    child: TextFormField(
                                      initialValue: set['reps'],
                                      textAlign: TextAlign.center,
                                      keyboardType: TextInputType.number,
                                      decoration: InputDecoration(
                                        contentPadding: const EdgeInsets.only(bottom: 10),
                                        filled: true,
                                        fillColor: Colors.grey[100],
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(5), borderSide: BorderSide.none),
                                      ),
                                    ),
                                  ),
                                ),
                                
                                // Check Button
                                SizedBox(
                                  width: 40,
                                  child: Checkbox(
                                    activeColor: Colors.teal,
                                    value: isDone,
                                    onChanged: (val) {
                                      setState(() {
                                        set['done'] = val;
                                        if (val == true) _triggerRestTimer(); // AUTO TRIGGER REST
                                      });
                                    },
                                  ),
                                )
                              ],
                            ),
                          );
                        }).toList(),

                        // Add Set Button
                        TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _sets.add({"set": _sets.length + 1, "prev": "-", "weight": "-", "reps": "-", "done": false});
                            });
                          }, 
                          icon: const Icon(Icons.add), 
                          label: const Text("Add Set")
                        ),
                      ],
                    ),
                  ),

                  // 4. NOTES
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: TextField(
                      controller: _noteController,
                      decoration: const InputDecoration(
                        labelText: "Exercise Notes",
                        hintText: "e.g., Seat height 4, shoulder pain...",
                        prefixIcon: Icon(Icons.edit_note),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  
                  // Spacer for the Rest Timer Panel
                  const SizedBox(height: 100), 
                ],
              ),
            ),
          ),

          // === BOTTOM NAVIGATION ===
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: const Offset(0, -5))]
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (widget.currentExerciseIndex > 0)
                  TextButton.icon(
                    onPressed: () => Navigator.pop(context), 
                    icon: const Icon(Icons.arrow_back_ios, size: 16), 
                    label: const Text("Prev")
                  )
                else 
                  const SizedBox(width: 80), // Spacer

                // Finish or Next Button
                if (widget.currentExerciseIndex < widget.totalExercises - 1)
                  ElevatedButton.icon(
                    onPressed: () {
                      // Navigate to Next Exercise Logic (Demo: just pops for now)
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Next Exercise Loaded...")));
                    },
                    icon: const Icon(Icons.arrow_forward_ios, size: 16),
                    label: const Text("Next Exercise"),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
                  )
                else
                  ElevatedButton.icon(
                    onPressed: _finishWorkout,
                    icon: const Icon(Icons.check_circle),
                    label: const Text("Finish Workout"),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
                  )
              ],
            ),
          )
        ],
      ),

      // === REST TIMER OVERLAY (Appears when Resting) ===
      bottomSheet: _isResting ? Container(
        color: Colors.teal,
        padding: const EdgeInsets.all(16),
        height: 120,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Rest Timer", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                Text(_formatTime(_restSeconds), style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                ElevatedButton(
                  onPressed: _skipRest, 
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.teal),
                  child: const Text("Skip")
                )
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton(onPressed: () => _adjustRestTime(-10), style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white)), child: const Text("-10s")),
                const SizedBox(width: 20),
                OutlinedButton(onPressed: () => _adjustRestTime(30), style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white)), child: const Text("+30s")),
              ],
            )
          ],
        ),
      ) : null,
    );
  }
}