import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/measurement_service.dart';
import 'main_dashboard.dart';

// ==========================================
// CANONICAL PROFILE CONSTANTS & NORMALIZERS
// ==========================================
const List<String> canonicalGoals = [
  'Weight Loss',
  'Maintenance',
  'Muscle Gain',
];

const List<String> canonicalActivities = [
  'Sedentary',
  'Light',
  'Moderate',
  'Active',
  'Very Active',
];

const List<String> canonicalGenders = [
  'Male',
  'Female',
];

String normalizeGoal(dynamic raw) {
  if (raw == null) return 'Weight Loss';
  final s = raw.toString().trim().toLowerCase();
  if (s.contains('gain') || s.contains('bulk') || s.contains('增肌')) return 'Muscle Gain';
  if (s.contains('loss') || s.contains('cut') || s.contains('减脂') || s.contains('fat')) return 'Weight Loss';
  if (s.contains('main') || s.contains('保持')) return 'Maintenance';
  return 'Weight Loss';
}

String normalizeActivity(dynamic raw) {
  if (raw == null) return 'Moderate';
  final s = raw.toString().trim().toLowerCase();
  if (s.contains('very') || s.contains('非常')) return 'Very Active';
  if (s.contains('sedentary') || s.contains('久坐')) return 'Sedentary';
  if (s.contains('light') || s.contains('轻度')) return 'Light';
  if (s.contains('active') || s.contains('活跃')) return 'Active';
  if (s.contains('moderate') || s.contains('适度')) return 'Moderate';
  return 'Moderate';
}

String normalizeGender(dynamic raw) {
  if (raw == null) return 'Male';
  final s = raw.toString().trim().toLowerCase();
  if (s.startsWith('f') || s.contains('female') || s.contains('女')) return 'Female';
  return 'Male';
}

// ==========================================
// USER PROFILE SETUP & EDIT
// ==========================================
class SetupProfilePage extends StatefulWidget {
  final bool isEditing;
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
  String _goal = "Weight Loss";
  String _activity = "Moderate";
  bool _isSaving = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.isEditing) {
      _isLoading = true;
      _loadCurrentUserData();
    }
  }

  @override
  void dispose() {
    _ageCtrl.dispose();
    _weightCtrl.dispose();
    _heightCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists && mounted) {
        final data = doc.data() ?? {};
        setState(() {
          _nameCtrl.text = data['name'] ?? "";
          _ageCtrl.text = (data['age'] ?? "").toString();
          _weightCtrl.text = (data['weight'] ?? "").toString();
          _heightCtrl.text = (data['height'] ?? "").toString();
          _gender = normalizeGender(data['gender']);
          _goal = normalizeGoal(data['fitnessGoal'] ?? data['goal']);
          _activity = normalizeActivity(data['activityLevel']);
          _isLoading = false;
        });
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("Error loading profile: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveAndContinue() async {
    if (_ageCtrl.text.trim().isEmpty ||
        _weightCtrl.text.trim().isEmpty ||
        _heightCtrl.text.trim().isEmpty ||
        _nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill all fields")));
      return;
    }

    setState(() => _isSaving = true);
    try {
      int age = int.tryParse(_ageCtrl.text.trim()) ?? 25;
      double weight = double.tryParse(_weightCtrl.text.trim()) ?? 70.0;
      double height = double.tryParse(_heightCtrl.text.trim()) ?? 175.0;

      // BMR Calculation (Harris-Benedict)
      double bmr;
      if (_gender == "Male") {
        bmr = (10 * weight) + (6.25 * height) - (5 * age) + 5;
      } else {
        bmr = (10 * weight) + (6.25 * height) - (5 * age) - 161;
      }

      double activityMultiplier = 1.2;
      if (_activity == "Light") activityMultiplier = 1.375;
      if (_activity == "Moderate") activityMultiplier = 1.55;
      if (_activity == "Active") activityMultiplier = 1.725;
      if (_activity == "Very Active") activityMultiplier = 1.9;

      double tdee = bmr * activityMultiplier;
      double targetCalories = tdee;

      if (_goal == "Weight Loss") targetCalories -= 500;
      if (_goal == "Muscle Gain") targetCalories += 300;

      // Save to Firebase
      final currentUser = FirebaseAuth.instance.currentUser;
      final String uid = currentUser?.uid ?? '';
      final String email = currentUser?.email ?? '';

      final userDocRef = FirebaseFirestore.instance.collection('users').doc(uid);
      final existingDoc = await userDocRef.get();
      final bool isNewUser = !existingDoc.exists;
      final existingData = existingDoc.data() ?? {};

      final Map<String, dynamic> userPayload = {
        'name': _nameCtrl.text.trim(),
        'age': age,
        'weight': weight,
        'height': height,
        'gender': _gender,
        'activityLevel': _activity,
        'fitnessGoal': _goal,
        'goal': _goal, // Legacy dual-write compatibility
        'bmr': bmr,
        'tdee': tdee,
        'calorieTarget': targetCalories.round(),
        'dailyCaloriesTarget': targetCalories.round(), // Legacy dual-write compatibility
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (email.isNotEmpty && existingData['email'] == null) {
        userPayload['email'] = email;
      }

      if (isNewUser) {
        userPayload['fitnessLevel'] = 'Beginner';
        userPayload['targetWeight'] = weight;
        userPayload['dietPreference'] = 'Standard';
        userPayload['allergies'] = <String>[];
        userPayload['equipment'] = <String>[];
        userPayload['preferredWorkoutTypes'] = <String>[];
        userPayload['units'] = {
          'weight': 'kg',
          'height': 'cm',
          'distance': 'km',
          'isMetric': true,
        };
        userPayload['settings'] = {
          'isDarkMode': false,
          'notificationsEnabled': true,
        };
        userPayload['isMetric'] = true;
        userPayload['currentStreak'] = 1;
        userPayload['createdAt'] = FieldValue.serverTimestamp();
      }

      await userDocRef.set(userPayload, SetOptions(merge: true));

      final double? prevWeight = (existingData['weight'] as num?)?.toDouble();
      await MeasurementService.recordWeightIfChanged(
        uid: uid,
        newWeight: weight,
        previousWeight: prevWeight,
        source: isNewUser ? 'initial_setup' : 'profile_update',
      );

      if (!mounted) return;

      if (widget.isEditing) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profile Updated!")));
      } else {
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
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.isEditing ? "Edit Profile" : "Setup Profile")),
        body: const Center(child: CircularProgressIndicator(color: Colors.teal)),
      );
    }

    // Defensive guarantee: ensure selected values exist in dropdown options
    final selectedGender = canonicalGenders.contains(_gender) ? _gender : canonicalGenders.first;
    final selectedGoal = canonicalGoals.contains(_goal) ? _goal : canonicalGoals.first;
    final selectedActivity = canonicalActivities.contains(_activity) ? _activity : canonicalActivities.first;

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
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: "Name", border: OutlineInputBorder()),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: _ageCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Age", border: OutlineInputBorder()),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: _weightCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: "Weight (kg)", border: OutlineInputBorder()),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: _heightCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: "Height (cm)", border: OutlineInputBorder()),
              ),
              const SizedBox(height: 15),
              
              DropdownButtonFormField<String>(
                initialValue: selectedGender,
                items: canonicalGenders
                    .map((e) => DropdownMenuItem<String>(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _gender = v);
                },
                decoration: const InputDecoration(labelText: "Gender", border: OutlineInputBorder()),
              ),
              const SizedBox(height: 15),
              DropdownButtonFormField<String>(
                initialValue: selectedGoal,
                items: canonicalGoals
                    .map((e) => DropdownMenuItem<String>(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _goal = v);
                },
                decoration: const InputDecoration(labelText: "Fitness Goal", border: OutlineInputBorder()),
              ),
              const SizedBox(height: 15),
              DropdownButtonFormField<String>(
                initialValue: selectedActivity,
                items: canonicalActivities
                    .map((e) => DropdownMenuItem<String>(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _activity = v);
                },
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
                  child: _isSaving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("Save & Continue", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
