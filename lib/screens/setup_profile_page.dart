import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// 👇 引入你的主仪表盘页面
import 'main_dashboard.dart';
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

  // --- 💡 新增：初始化时加载当前数据 ---
  @override
  void initState() {
    super.initState();
    if (widget.isEditing) {
      _loadCurrentUserData();
    }
  }

  Future<void> _loadCurrentUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    if (doc.exists) {
      final data = doc.data()!;
      setState(() {
        _nameCtrl.text = data['name'] ?? "";
        _ageCtrl.text = (data['age'] ?? "").toString();
        _weightCtrl.text = (data['weight'] ?? "").toString();
        _heightCtrl.text = (data['height'] ?? "").toString();
        _gender = data['gender'] ?? "Male";
        _goal = data['goal'] ?? "Weight Loss (减脂)";
        _activity = data['activityLevel'] ?? "Moderate (适度运动)";
      });
    }
  }

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
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              const Icon(Icons.person, size: 60, color: Colors.teal),
              const SizedBox(height: 20),
              
              // Form Fields
              TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: "Name", border: OutlineInputBorder())),
              const SizedBox(height: 15),
              TextField(controller: _ageCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Age", border: OutlineInputBorder())),
              const SizedBox(height: 15),
              TextField(controller: _weightCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Weight (kg)", border: OutlineInputBorder())),
              const SizedBox(height: 15),
              TextField(controller: _heightCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Height (cm)", border: OutlineInputBorder())),
              const SizedBox(height: 15),
              
              DropdownButtonFormField(
                value: _gender,
                items: ["Male", "Female"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (v) => setState(() => _gender = v.toString()),
                decoration: const InputDecoration(labelText: "Gender", border: OutlineInputBorder()),
              ),
              const SizedBox(height: 15),
              DropdownButtonFormField(
                value: _goal,
                items: ["Weight Loss (减脂)", "Muscle Gain (增肌)", "Maintenance (保持)"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (v) => setState(() => _goal = v.toString()),
                decoration: const InputDecoration(labelText: "Goal", border: OutlineInputBorder()),
              ),
              const SizedBox(height: 15),
              DropdownButtonFormField(
                value: _activity,
                items: ["Sedentary (久坐)", "Light (轻度运动)", "Moderate (适度运动)", "Active (活跃)", "Very Active (非常活跃)"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (v) => setState(() => _activity = v.toString()),
                decoration: const InputDecoration(labelText: "Activity Level", border: OutlineInputBorder()),
              ),
              
              const SizedBox(height: 30),
              
              // Save Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveAndContinue,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                  child: _isSaving ? const CircularProgressIndicator(color: Colors.white) : const Text("Save & Continue", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
