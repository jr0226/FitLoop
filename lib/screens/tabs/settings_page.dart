import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/app_config.dart';
import '../../services/auth_service.dart';
import '../../widgets/change_password_dialog.dart';
import '../login_page.dart';
import '../setup_profile_page.dart';
import '../progress_measurements_screen.dart';
import '../health_report_screen.dart';
import '../faq_chatbot_screen.dart';
import '../../models/health_models.dart';
import '../../services/health_integration_service.dart';

import '../../services/notification_service.dart';
import '../../services/theme_service.dart';

class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  final User? currentUser = FirebaseAuth.instance.currentUser;

  bool _isLoading = true;
  String _userName = "Athlete";
  int _age = 25;
  String _gender = "Male";
  double _weight = 70.0;
  double _height = 175.0;
  double _targetWeight = 65.0;

  bool _isMetric = true;

  // Training & Fitness
  String _userGoal = "Maintenance";
  String _fitnessLevel = "Beginner";
  String _activityLevel = "Moderate";
  List<String> _preferredWorkoutTypes = [];
  List<String> _equipment = [];

  // Nutrition & Diet
  String _dietPreference = "Standard";
  List<String> _allergies = [];

  // App Preferences
  bool _notificationsEnabled = true;

  // Reminders Configuration State
  bool _workoutReminderEnabled = false;
  TimeOfDay _workoutReminderTime = const TimeOfDay(hour: 19, minute: 0);
  List<int> _workoutReminderDays = [1, 3, 5]; // Mon, Wed, Fri

  bool _breakfastReminderEnabled = false;
  TimeOfDay _breakfastReminderTime = const TimeOfDay(hour: 8, minute: 30);
  bool _lunchReminderEnabled = false;
  TimeOfDay _lunchReminderTime = const TimeOfDay(hour: 12, minute: 30);
  bool _dinnerReminderEnabled = false;
  TimeOfDay _dinnerReminderTime = const TimeOfDay(hour: 19, minute: 30);

  bool _hydrationReminderEnabled = false;
  int _hydrationIntervalHours = 2; // Every 2, 3, or 4 hours

  bool _weeklyProgressReminderEnabled = false;
  int _weeklyProgressDay = 7; // Sunday
  TimeOfDay _weeklyProgressTime = const TimeOfDay(hour: 20, minute: 0);

  // Connected Health
  HealthConnectStatus _healthStatus = HealthConnectStatus.notSupported;
  bool _healthStatusLoading = false;

  // Options Lists
  final List<String> _goals = ["Weight Loss", "Maintenance", "Muscle Gain"];
  final List<String> _fitnessLevels = ["Beginner", "Intermediate", "Advanced"];
  final List<String> _activityLevels = ["Sedentary", "Light", "Moderate", "Active", "Very Active"];
  final List<String> _dietPreferences = ["Standard", "Halal", "Vegetarian", "Vegan", "Pescatarian"];
  final List<String> _allEquipmentOptions = [
    "None / Bodyweight",
    "Dumbbells",
    "Barbell",
    "Bench",
    "Resistance Bands",
    "Kettlebell",
    "Pull-up Bar",
    "Cable Machine",
    "Gym Machines"
  ];
  final List<String> _allWorkoutTypeOptions = [
    "Strength",
    "Cardio",
    "HIIT",
    "Full Body",
    "Upper Body",
    "Lower Body",
    "Core",
    "Mobility"
  ];

  String _normalizeGoal(dynamic raw) {
    if (raw == null) return 'Maintenance';
    final s = raw.toString().trim().toLowerCase();
    if (s.contains('gain') || s.contains('bulk') || s.contains('增肌')) return 'Muscle Gain';
    if (s.contains('loss') || s.contains('cut') || s.contains('减脂') || s.contains('fat')) return 'Weight Loss';
    if (s.contains('main') || s.contains('保持')) return 'Maintenance';
    return 'Maintenance';
  }

  String _normalizeFitnessLevel(dynamic raw) {
    if (raw == null) return 'Beginner';
    final s = raw.toString().trim().toLowerCase();
    if (s.contains('adv')) return 'Advanced';
    if (s.contains('inter')) return 'Intermediate';
    return 'Beginner';
  }

  String _normalizeActivityLevel(dynamic raw) {
    if (raw == null) return 'Moderate';
    final s = raw.toString().trim().toLowerCase();
    if (s.contains('very') || s.contains('非常')) return 'Very Active';
    if (s.contains('sedentary') || s.contains('久坐')) return 'Sedentary';
    if (s.contains('light') || s.contains('轻度')) return 'Light';
    if (s.contains('active') || s.contains('活跃')) return 'Active';
    return 'Moderate';
  }

  @override
  void initState() {
    super.initState();
    _fetchUserProfile();
    _loadHealthStatus();
  }

  Future<void> _loadHealthStatus() async {
    if (!mounted) return;
    setState(() => _healthStatusLoading = true);
    final status = await HealthIntegrationService.instance.checkStatus();
    if (mounted) {
      setState(() {
        _healthStatus = status;
        _healthStatusLoading = false;
      });
    }
  }

  Future<void> _connectHealthConnect() async {
    if (!mounted) return;
    setState(() => _healthStatusLoading = true);
    final granted = await HealthIntegrationService.instance.requestPermissions();
    final newStatus = granted
        ? HealthConnectStatus.connected
        : HealthConnectStatus.permissionRequired;
    if (mounted) {
      setState(() {
        _healthStatus = newStatus;
        _healthStatusLoading = false;
      });
    }
    // Refresh dashboard data in background
    if (granted) {
      HealthIntegrationService.instance.fetchDailySummary();
    }
  }

  Future<void> _fetchUserProfile() async {
    if (currentUser != null) {
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).get();
        if (mounted && doc.exists) {
          final data = doc.data() ?? {};
          setState(() {
            _userName = data['name'] ?? "Athlete";
            _age = (data['age'] as num?)?.toInt() ?? 25;
            _gender = (data['gender'] ?? "Male").toString().toLowerCase().startsWith('f') ? "Female" : "Male";
            _weight = (data['weight'] as num?)?.toDouble() ?? 70.0;
            _height = (data['height'] as num?)?.toDouble() ?? 175.0;
            _targetWeight = (data['targetWeight'] as num?)?.toDouble() ?? _weight;

            // Fitness Goal
            _userGoal = _normalizeGoal(data['fitnessGoal'] ?? data['goal']);

            // Fitness Level
            _fitnessLevel = _normalizeFitnessLevel(data['fitnessLevel'] ?? data['level']);

            // Activity Level
            _activityLevel = _normalizeActivityLevel(data['activityLevel']);

            // Diet Preference
            String fetchedDiet = data['dietPreference'] ?? "Standard";
            if (!_dietPreferences.contains(fetchedDiet)) {
              _dietPreferences.add(fetchedDiet);
            }
            _dietPreference = fetchedDiet;

            // Allergies
            if (data['allergies'] is List) {
              _allergies = List<String>.from(data['allergies'].map((e) => e.toString()));
            }

            // Equipment
            if (data['equipment'] is List) {
              _equipment = List<String>.from(data['equipment'].map((e) => e.toString()));
            }

            // Preferred Workout Types
            if (data['preferredWorkoutTypes'] is List) {
              _preferredWorkoutTypes = List<String>.from(data['preferredWorkoutTypes'].map((e) => e.toString()));
            }

            // Units
            if (data['units'] is Map && data['units']['isMetric'] is bool) {
              _isMetric = data['units']['isMetric'] as bool;
            } else {
              _isMetric = data['isMetric'] ?? true;
            }

            // Settings
            if (data['settings'] is Map) {
              final s = data['settings'] as Map<String, dynamic>;
              if (s['isDarkMode'] is bool) {
                ThemeService.syncFromFirestore(data);
              }
              if (s['notificationsEnabled'] is bool) {
                _notificationsEnabled = s['notificationsEnabled'] as bool;
              }
              if (s['reminders'] is Map) {
                final rem = s['reminders'] as Map<String, dynamic>;
                // Workout
                if (rem['workout'] is Map) {
                  final w = rem['workout'] as Map<String, dynamic>;
                  _workoutReminderEnabled = w['enabled'] == true;
                  final wh = (w['hour'] as num?)?.toInt() ?? 19;
                  final wm = (w['minute'] as num?)?.toInt() ?? 0;
                  _workoutReminderTime = TimeOfDay(hour: wh, minute: wm);
                  if (w['days'] is List) {
                    _workoutReminderDays = (w['days'] as List).map((e) => (e as num).toInt()).toList();
                  }
                }
                // Meals
                if (rem['meals'] is Map) {
                  final m = rem['meals'] as Map<String, dynamic>;
                  _breakfastReminderEnabled = m['breakfastEnabled'] == true;
                  _breakfastReminderTime = TimeOfDay(
                    hour: (m['breakfastHour'] as num?)?.toInt() ?? 8,
                    minute: (m['breakfastMinute'] as num?)?.toInt() ?? 30,
                  );
                  _lunchReminderEnabled = m['lunchEnabled'] == true;
                  _lunchReminderTime = TimeOfDay(
                    hour: (m['lunchHour'] as num?)?.toInt() ?? 12,
                    minute: (m['lunchMinute'] as num?)?.toInt() ?? 30,
                  );
                  _dinnerReminderEnabled = m['dinnerEnabled'] == true;
                  _dinnerReminderTime = TimeOfDay(
                    hour: (m['dinnerHour'] as num?)?.toInt() ?? 19,
                    minute: (m['dinnerMinute'] as num?)?.toInt() ?? 30,
                  );
                }
                // Hydration
                if (rem['hydration'] is Map) {
                  final h = rem['hydration'] as Map<String, dynamic>;
                  _hydrationReminderEnabled = h['enabled'] == true;
                  _hydrationIntervalHours = (h['intervalHours'] as num?)?.toInt() ?? 2;
                }
                // Weekly Progress
                if (rem['weeklyProgress'] is Map) {
                  final wp = rem['weeklyProgress'] as Map<String, dynamic>;
                  _weeklyProgressReminderEnabled = wp['enabled'] == true;
                  _weeklyProgressDay = (wp['dayOfWeek'] as num?)?.toInt() ?? 7;
                  _weeklyProgressTime = TimeOfDay(
                    hour: (wp['hour'] as num?)?.toInt() ?? 20,
                    minute: (wp['minute'] as num?)?.toInt() ?? 0,
                  );
                }
              }
            }

            _isLoading = false;
          });

          // Sync loaded reminders with local NotificationService scheduler
          NotificationService.instance.syncAllReminders(
            _buildRemindersPayload(),
            masterEnabled: _notificationsEnabled,
          );
        } else {
          setState(() => _isLoading = false);
        }
      } catch (e) {
        debugPrint("Error fetching profile: $e");
        setState(() => _isLoading = false);
      }
    }
  }

  Map<String, dynamic> _buildRemindersPayload() {
    return {
      'workout': {
        'enabled': _workoutReminderEnabled,
        'hour': _workoutReminderTime.hour,
        'minute': _workoutReminderTime.minute,
        'days': _workoutReminderDays,
      },
      'meals': {
        'breakfastEnabled': _breakfastReminderEnabled,
        'breakfastHour': _breakfastReminderTime.hour,
        'breakfastMinute': _breakfastReminderTime.minute,
        'lunchEnabled': _lunchReminderEnabled,
        'lunchHour': _lunchReminderTime.hour,
        'lunchMinute': _lunchReminderTime.minute,
        'dinnerEnabled': _dinnerReminderEnabled,
        'dinnerHour': _dinnerReminderTime.hour,
        'dinnerMinute': _dinnerReminderTime.minute,
      },
      'hydration': {
        'enabled': _hydrationReminderEnabled,
        'intervalHours': _hydrationIntervalHours,
      },
      'weeklyProgress': {
        'enabled': _weeklyProgressReminderEnabled,
        'dayOfWeek': _weeklyProgressDay,
        'hour': _weeklyProgressTime.hour,
        'minute': _weeklyProgressTime.minute,
      },
    };
  }

  Future<void> _saveRemindersToFirestoreAndSync() async {
    final payload = _buildRemindersPayload();
    if (currentUser != null) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).update({
          'settings.notificationsEnabled': _notificationsEnabled,
          'settings.reminders': payload,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        debugPrint('Error updating reminder settings: $e');
      }
    }
    await NotificationService.instance.syncAllReminders(
      payload,
      masterEnabled: _notificationsEnabled,
    );
  }

  Future<bool> _ensureNotificationPermission() async {
    final granted = await NotificationService.instance.requestPermissions();
    if (!granted && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Notifications are disabled in system settings. Please enable them to receive reminders."),
          backgroundColor: Colors.orange,
        ),
      );
    }
    return granted;
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  String _weekdayName(int day) {
    switch (day) {
      case 1:
        return 'Mon';
      case 2:
        return 'Tue';
      case 3:
        return 'Wed';
      case 4:
        return 'Thu';
      case 5:
        return 'Fri';
      case 6:
        return 'Sat';
      case 7:
        return 'Sun';
      default:
        return 'Day';
    }
  }

  // --- RECALCULATE ENERGY TARGETS ON GOAL / ACTIVITY UPDATE ---
  Map<String, dynamic> _recalculateTargets({
    required String goal,
    required String activityLevel,
  }) {
    // BMR Calculation (Harris-Benedict)
    double bmr;
    if (_gender == "Female") {
      bmr = (10 * _weight) + (6.25 * _height) - (5 * _age) - 161;
    } else {
      bmr = (10 * _weight) + (6.25 * _height) - (5 * _age) + 5;
    }

    double multiplier = 1.2;
    if (activityLevel.contains("Light")) {
      multiplier = 1.375;
    } else if (activityLevel.contains("Moderate")) {
      multiplier = 1.55;
    } else if (activityLevel.contains("Active")) {
      multiplier = 1.725;
    }

    final double tdee = bmr * multiplier;
    double targetCalories = tdee;

    if (goal.contains("Weight Loss") || goal.contains("Fat Loss") || goal.contains("Cut")) {
      targetCalories -= 500;
    } else if (goal.contains("Muscle Gain") || goal.contains("Bulk")) {
      targetCalories += 300;
    }

    return {
      'bmr': bmr,
      'tdee': tdee,
      'calorieTarget': targetCalories.round(),
      'dailyCaloriesTarget': targetCalories.round(),
    };
  }

  // --- FIREBASE UPDATES ---
  Future<void> _updateGoal(String newGoal) async {
    setState(() => _userGoal = newGoal);
    if (currentUser != null) {
      final targets = _recalculateTargets(goal: newGoal, activityLevel: _activityLevel);
      await FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).update({
        'fitnessGoal': newGoal,
        'goal': newGoal, // Legacy dual-write compatibility
        ...targets,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Fitness goal updated! Calorie targets recalculated.")));
      }
    }
  }

  Future<void> _updateFitnessLevel(String newLevel) async {
    setState(() => _fitnessLevel = newLevel);
    if (currentUser != null) {
      await FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).update({
        'fitnessLevel': newLevel,
        'level': newLevel, // Legacy dual-write compatibility
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Fitness level updated!")));
      }
    }
  }

  Future<void> _updateActivityLevel(String newActivity) async {
    setState(() => _activityLevel = newActivity);
    if (currentUser != null) {
      final targets = _recalculateTargets(goal: _userGoal, activityLevel: newActivity);
      await FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).update({
        'activityLevel': newActivity,
        ...targets,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Activity level updated! TDEE & daily calories adjusted.")));
      }
    }
  }

  Future<void> _updateDietPreference(String newDiet) async {
    setState(() => _dietPreference = newDiet);
    if (currentUser != null) {
      await FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).update({
        'dietPreference': newDiet,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Dietary preference updated!")));
      }
    }
  }

  Future<void> _updateTargetWeight(double newTargetKg) async {
    setState(() => _targetWeight = newTargetKg);
    if (currentUser != null) {
      await FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).update({
        'targetWeight': newTargetKg,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Target weight goal updated!")));
      }
    }
  }

  Future<void> _updateAllergies(List<String> newAllergies) async {
    setState(() => _allergies = newAllergies);
    if (currentUser != null) {
      await FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).update({
        'allergies': newAllergies,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Allergies updated!")));
      }
    }
  }

  Future<void> _updateEquipment(List<String> newEquipment) async {
    setState(() => _equipment = newEquipment);
    if (currentUser != null) {
      await FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).update({
        'equipment': newEquipment,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Available equipment updated!")));
      }
    }
  }

  Future<void> _updatePreferredWorkoutTypes(List<String> newTypes) async {
    setState(() => _preferredWorkoutTypes = newTypes);
    if (currentUser != null) {
      await FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).update({
        'preferredWorkoutTypes': newTypes,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Workout preferences updated!")));
      }
    }
  }

  Future<void> _updateUnitPreference(bool isMetric) async {
    setState(() => _isMetric = isMetric);
    if (currentUser != null) {
      await FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).update({
        'isMetric': isMetric, // Legacy dual-write compatibility
        'units.isMetric': isMetric,
        'units.weight': isMetric ? 'kg' : 'lbs',
        'units.height': isMetric ? 'cm' : 'in',
        'units.distance': isMetric ? 'km' : 'mi',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  // --- EDIT DIALOGS ---
  void _showEditTargetWeightDialog() {
    final String unitLabel = _isMetric ? 'kg' : 'lbs';
    final double displayVal = _isMetric ? _targetWeight : (_targetWeight * 2.20462);
    final textCtrl = TextEditingController(text: displayVal.toStringAsFixed(1));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.track_changes, color: Colors.teal),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                "Edit Target Weight ($unitLabel)",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Current Weight: ${_isMetric ? _weight.toStringAsFixed(1) : (_weight * 2.20462).toStringAsFixed(1)} $unitLabel",
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: TextField(
                      controller: textCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: "Target Weight",
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.teal.shade200),
                    ),
                    child: Text(
                      unitLabel,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal.shade800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _isMetric ? "Acceptable range: 25 - 350 kg" : "Acceptable range: 55 - 770 lbs",
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              final parsed = double.tryParse(textCtrl.text.trim());
              if (parsed == null || parsed <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Please enter a valid positive number.")),
                );
                return;
              }
              final double kg = _isMetric ? parsed : (parsed / 2.20462);
              if (kg < 25 || kg > 350) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Please enter a realistic weight range (${_isMetric ? '25kg - 350kg' : '55lbs - 770lbs'}).")),
                );
                return;
              }
              Navigator.pop(ctx);
              _updateTargetWeight(kg);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  void _showMultiSelectSheet({
    required String title,
    required List<String> allOptions,
    required List<String> selectedOptions,
    required ValueChanged<List<String>> onSave,
    bool allowCustom = false,
  }) {
    final List<String> workingList = List.from(selectedOptions);
    final customCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 12),
              if (allowCustom) ...[
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: customCtrl,
                        decoration: InputDecoration(
                          hintText: "Add specific allergy / tag...",
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        final val = customCtrl.text.trim();
                        if (val.isNotEmpty && !workingList.contains(val)) {
                          setModalState(() => workingList.add(val));
                          customCtrl.clear();
                        }
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                      child: const Text("Add"),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
              ],
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 280),
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: {
                      ...allOptions,
                      ...workingList,
                    }.map((option) {
                      final isSelected = workingList.contains(option);
                      return FilterChip(
                        label: Text(option),
                        selected: isSelected,
                        selectedColor: Colors.teal,
                        checkmarkColor: Colors.white,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : Colors.black87,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                        onSelected: (selected) {
                          setModalState(() {
                            if (selected) {
                              workingList.add(option);
                            } else {
                              workingList.remove(option);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    onSave(workingList);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text("Save Changes", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- ACCOUNT MANAGEMENT ---
  void _confirmSignOut() {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.logout, color: Colors.teal),
            SizedBox(width: 10),
            Text("Sign Out", style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text("Are you sure you want to log out of FitLoop?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text("Cancel", style: TextStyle(color: Colors.grey.shade700)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              _performSignOut();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text("Sign Out"),
          ),
        ],
      ),
    );
  }

  Future<void> _performSignOut() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Colors.teal),
                SizedBox(height: 16),
                Text("Signing out...", style: TextStyle(fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      await AuthService.signOut();
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginPage()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to sign out: $e")));
    }
  }

  void _confirmDeleteAccount() {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Delete Account?", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        content: const Text(
          "This action is permanent and will permanently delete:\n\n"
          "• All workout logs & custom routines\n"
          "• All food & nutrition diary logs\n"
          "• All body measurements & progress history\n"
          "• Favorite exercises and achievements\n"
          "• Your profile and authentication account\n\n"
          "Are you absolutely sure?",
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(c);
              _performAccountDeletion();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text("Delete Everything"),
          ),
        ],
      ),
    );
  }

  Future<void> _performAccountDeletion() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(color: Colors.red),
              SizedBox(width: 20),
              Expanded(child: Text("Permanently deleting your account & data...")),
            ],
          ),
        ),
      ),
    );

    try {
      await AuthService.deleteAccountAndUserData();
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // dismiss loading dialog
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginPage()),
        (route) => false,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Account and personal data deleted successfully.")),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // dismiss loading dialog
      if (e.code == 'requires-recent-login') {
        showDialog(
          context: context,
          builder: (d) => AlertDialog(
            title: const Text("Recent Sign-In Required"),
            content: const Text(
              "For security, account deletion requires recent authentication.\n\n"
              "Please sign out, sign back in with your credentials, and retry deleting your account.",
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(d), child: const Text("Cancel")),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(d);
                  await AuthService.signOut();
                  if (!mounted) return;
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const LoginPage()),
                    (route) => false,
                  );
                },
                child: const Text("Sign Out Now"),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Deletion failed: ${AuthService.getErrorMessage(e)}")),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // dismiss loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error deleting account: $e")),
      );
    }
  }

  Future<void> _openPrivacyPolicy() async {
    final uri = Uri.parse(AppConfig.privacyPolicyUrl);
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        _showPrivacyPolicyFallbackDialog();
      }
    } catch (_) {
      if (mounted) {
        _showPrivacyPolicyFallbackDialog();
      }
    }
  }

  void _showPrivacyPolicyFallbackDialog() {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("FitLoop Privacy Policy"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "FitLoop values your privacy. We do not sell personal data, do not serve ads, and process meal images in-memory solely for nutrition estimates.\n\n"
              "You can view our complete public policy at:",
            ),
            const SizedBox(height: 12),
            SelectableText(
              AppConfig.privacyPolicyUrl,
              style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double displayTargetWeight = _isMetric ? _targetWeight : (_targetWeight * 2.20462);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text("Profile & Settings", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.teal))
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: 20),
              children: [
                // 1. PROFILE HEADER
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 36,
                        backgroundColor: Colors.teal.shade100,
                        child: const Icon(Icons.person, size: 36, color: Colors.teal),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_userName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                            Text(currentUser?.email ?? "No Email", style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_note_rounded, color: Colors.teal, size: 28),
                        tooltip: "Edit Biometrics",
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (c) => const SetupProfilePage(isEditing: true)),
                          );
                          _fetchUserProfile();
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // 2. BIOMETRICS & GOAL TARGETS
                _buildSectionHeader("Biometrics & Targets"),
                Container(
                  color: Colors.white,
                  child: Column(
                    children: [
                      ListTile(
                        leading: _buildIconBox(Icons.show_chart, Colors.teal),
                        title: const Text("Body Measurements & Progress", style: TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: const Text("Log weight, body fat & circumferences"),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const ProgressMeasurementsScreen()),
                          );
                        },
                      ),
                      const Divider(height: 1, indent: 70),
                      ListTile(
                        leading: _buildIconBox(Icons.track_changes, Colors.teal),
                        title: const Text("Target Weight", style: TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text("Goal: ${displayTargetWeight.toStringAsFixed(1)} ${_isMetric ? 'kg' : 'lbs'}"),
                        trailing: const Icon(Icons.edit, size: 18, color: Colors.teal),
                        onTap: _showEditTargetWeightDialog,
                      ),
                      const Divider(height: 1, indent: 70),
                      ListTile(
                        leading: _buildIconBox(Icons.flag, Colors.orange),
                        title: const Text("Fitness Goal", style: TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: const Text("Determines AI training & calorie target"),
                        trailing: DropdownButton<String>(
                          value: _userGoal,
                          underline: const SizedBox(),
                          icon: const Icon(Icons.arrow_drop_down, color: Colors.teal),
                          style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold),
                          onChanged: (String? newValue) {
                            if (newValue != null) _updateGoal(newValue);
                          },
                          items: _goals.map<DropdownMenuItem<String>>((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // 3. TRAINING & FITNESS PROFILE
                _buildSectionHeader("Training & Fitness"),
                Container(
                  color: Colors.white,
                  child: Column(
                    children: [
                      ListTile(
                        leading: _buildIconBox(Icons.fitness_center, Colors.indigo),
                        title: const Text("Fitness Level", style: TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: const Text("Exercise difficulty & progression"),
                        trailing: DropdownButton<String>(
                          value: _fitnessLevel,
                          underline: const SizedBox(),
                          icon: const Icon(Icons.arrow_drop_down, color: Colors.teal),
                          style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold),
                          onChanged: (String? newValue) {
                            if (newValue != null) _updateFitnessLevel(newValue);
                          },
                          items: _fitnessLevels.map<DropdownMenuItem<String>>((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                        ),
                      ),
                      const Divider(height: 1, indent: 70),
                      ListTile(
                        leading: _buildIconBox(Icons.directions_run, Colors.blue),
                        title: const Text("Activity Level", style: TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: const Text("Daily lifestyle movement & TDEE"),
                        trailing: DropdownButton<String>(
                          value: _activityLevel,
                          underline: const SizedBox(),
                          icon: const Icon(Icons.arrow_drop_down, color: Colors.teal),
                          style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold),
                          onChanged: (String? newValue) {
                            if (newValue != null) _updateActivityLevel(newValue);
                          },
                          items: _activityLevels.map<DropdownMenuItem<String>>((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                        ),
                      ),
                      const Divider(height: 1, indent: 70),
                      ListTile(
                        leading: _buildIconBox(Icons.handyman_outlined, Colors.amber.shade800),
                        title: const Text("Available Equipment", style: TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(_equipment.isEmpty ? "All equipment available" : _equipment.join(", "), maxLines: 1, overflow: TextOverflow.ellipsis),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          _showMultiSelectSheet(
                            title: "Select Available Equipment",
                            allOptions: _allEquipmentOptions,
                            selectedOptions: _equipment,
                            onSave: _updateEquipment,
                          );
                        },
                      ),
                      const Divider(height: 1, indent: 70),
                      ListTile(
                        leading: _buildIconBox(Icons.sports_gymnastics, Colors.deepPurple),
                        title: const Text("Preferred Workout Types", style: TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(_preferredWorkoutTypes.isEmpty ? "All workout formats" : _preferredWorkoutTypes.join(", "), maxLines: 1, overflow: TextOverflow.ellipsis),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          _showMultiSelectSheet(
                            title: "Select Preferred Workout Types",
                            allOptions: _allWorkoutTypeOptions,
                            selectedOptions: _preferredWorkoutTypes,
                            onSave: _updatePreferredWorkoutTypes,
                          );
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // 4. NUTRITION & DIETARY PREFERENCES
                _buildSectionHeader("Nutrition & Dietary Preferences"),
                Container(
                  color: Colors.white,
                  child: Column(
                    children: [
                      ListTile(
                        leading: _buildIconBox(Icons.restaurant_menu, Colors.green),
                        title: const Text("Diet Preference", style: TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: const Text("Used to personalize AI food suggestions."),
                        trailing: DropdownButton<String>(
                          value: _dietPreference,
                          underline: const SizedBox(),
                          icon: const Icon(Icons.arrow_drop_down, color: Colors.teal),
                          style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold),
                          onChanged: (String? newValue) {
                            if (newValue != null) _updateDietPreference(newValue);
                          },
                          items: _dietPreferences.map<DropdownMenuItem<String>>((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                        ),
                      ),
                      const Divider(height: 1, indent: 70),
                      ListTile(
                        leading: _buildIconBox(Icons.warning_amber_rounded, Colors.redAccent),
                        title: const Text("Allergies & Intolerances", style: TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          _allergies.isEmpty
                              ? "None reported (Avoids unsuitable AI recommendations)"
                              : "Avoid: ${_allergies.join(', ')}",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          _showMultiSelectSheet(
                            title: "Allergies & Intolerances",
                            allOptions: const ["Nuts", "Dairy", "Gluten", "Shellfish", "Eggs", "Soy", "Fish", "Peanuts"],
                            selectedOptions: _allergies,
                            allowCustom: true,
                            onSave: _updateAllergies,
                          );
                        },
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info_outline, size: 14, color: Colors.grey.shade600),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                "AI suggestions personalize recommendations to avoid unsuitable foods, but cannot guarantee detection of hidden ingredients or cross-contamination.",
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade600, height: 1.3),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // 5. APP PREFERENCES
                _buildSectionHeader("App Preferences"),
                Container(
                  color: Colors.white,
                  child: Column(
                    children: [
                      SwitchListTile(
                        activeThumbColor: Colors.teal,
                        secondary: _buildIconBox(Icons.straighten, Colors.blue),
                        title: const Text("Metric Units", style: TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(_isMetric ? "Kilograms & Kilometers" : "Pounds & Miles"),
                        value: _isMetric,
                        onChanged: _updateUnitPreference,
                      ),
                      const Divider(height: 1, indent: 70),
                      SwitchListTile(
                        activeThumbColor: Colors.teal,
                        secondary: _buildIconBox(Icons.notifications_active, Colors.green),
                        title: const Text("Push Notifications", style: TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: const Text("Master switch for all FitLoop scheduled reminders"),
                        value: _notificationsEnabled,
                        onChanged: (val) async {
                          if (val) {
                            final granted = await _ensureNotificationPermission();
                            if (!granted) return;
                          }
                          setState(() => _notificationsEnabled = val);
                          await _saveRemindersToFirestoreAndSync();
                        },
                      ),
                      if (_notificationsEnabled) ...[
                        const Divider(height: 1),
                        _buildRemindersSection(),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // 6. DATA & REPORTS
                _buildSectionHeader("Data & Reports"),
                Container(
                  color: Colors.white,
                  child: ListTile(
                    leading: _buildIconBox(Icons.picture_as_pdf_rounded, Colors.teal),
                    title: const Text("Export Health & Fitness Report", style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text("Generate, preview, and share PDF progress summaries"),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const HealthReportScreen(),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 20),

                // ─── CONNECTED HEALTH ───────────────────────────────────────
                _buildSectionHeader("Connected Health"),
                Container(
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHealthStatusBanner(),
                        const SizedBox(height: 12),
                        _buildHealthActionButtons(),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // HELP & SUPPORT
                _buildSectionHeader("Help & Support"),
                Container(
                  color: Colors.white,
                  child: ListTile(
                    leading: _buildIconBox(Icons.help_outline_rounded, Colors.teal),
                    title: const Text("FitLoop Assistant & FAQ", style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text("Browse FAQs, feature guides & troubleshooting"),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const FaqChatbotScreen(),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 20),

                // LEGAL & PRIVACY
                _buildSectionHeader("Legal & Privacy"),
                Container(
                  color: Colors.white,
                  child: ListTile(
                    leading: _buildIconBox(Icons.privacy_tip_outlined, Colors.teal),
                    title: const Text("Privacy Policy", style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text("Read our full data protection & privacy disclosures"),
                    trailing: const Icon(Icons.open_in_new_rounded, size: 20, color: Colors.grey),
                    onTap: _openPrivacyPolicy,
                  ),
                ),

                const SizedBox(height: 20),

                // 7. SECURITY & ACCOUNT
                _buildSectionHeader("Account Security"),
                Container(
                  color: Colors.white,
                  child: ListTile(
                    leading: _buildIconBox(Icons.lock_reset, Colors.teal),
                    title: const Text("Change / Reset Password", style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text("Update password or send reset email"),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => ChangePasswordDialog.show(context),
                  ),
                ),

                const SizedBox(height: 24),

                // 7. DANGER ZONE
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: OutlinedButton.icon(
                    onPressed: _confirmSignOut,
                    icon: const Icon(Icons.logout),
                    label: const Text("Sign Out"),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.black87,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: TextButton(
                    onPressed: _confirmDeleteAccount,
                    child: const Text("Delete Account", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
    );
  }

  Widget _buildIconBox(IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
      child: Icon(icon, color: color, size: 20),
    );
  }

  // ─── CONNECTED HEALTH UI HELPERS ─────────────────────────────────────────

  Widget _buildHealthStatusBanner() {
    if (_healthStatusLoading) {
      return const Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.teal),
          ),
          SizedBox(width: 12),
          Text('Checking Health Connect...', style: TextStyle(color: Colors.grey)),
        ],
      );
    }

    final Color iconColor;
    final Color bgColor;
    final Color borderColor;
    final IconData icon;
    final String label;
    final String description;

    switch (_healthStatus) {
      case HealthConnectStatus.connected:
        iconColor = Colors.green.shade700;
        bgColor = Colors.green.shade50;
        borderColor = Colors.green.shade200;
        icon = Icons.check_circle_rounded;
        label = 'Connected';
        description = 'FitLoop is reading your health data.';
      case HealthConnectStatus.noData:
        iconColor = Colors.blue.shade700;
        bgColor = Colors.blue.shade50;
        borderColor = Colors.blue.shade200;
        icon = Icons.info_outline_rounded;
        label = 'Connected — No Data Today';
        description = 'Permissions granted, but no activity data found yet.';
      case HealthConnectStatus.permissionRequired:
        iconColor = Colors.orange.shade700;
        bgColor = Colors.orange.shade50;
        borderColor = Colors.orange.shade200;
        icon = Icons.lock_outline_rounded;
        label = 'Permission Required';
        description = 'Grant FitLoop access in Health Connect.';
      case HealthConnectStatus.notInstalled:
        iconColor = Colors.red.shade700;
        bgColor = Colors.red.shade50;
        borderColor = Colors.red.shade200;
        icon = Icons.warning_amber_rounded;
        label = 'Health Connect Not Installed';
        description = 'Install Health Connect from Google Play to sync data.';
      case HealthConnectStatus.notSupported:
        iconColor = Colors.grey.shade600;
        bgColor = Colors.grey.shade100;
        borderColor = Colors.grey.shade300;
        icon = Icons.devices_other_rounded;
        label = 'Not Supported';
        description = 'Health Connect is not available on this device.';
      case HealthConnectStatus.error:
        iconColor = Colors.red.shade700;
        bgColor = Colors.red.shade50;
        borderColor = Colors.red.shade200;
        icon = Icons.error_outline_rounded;
        label = 'Sync Error';
        description = 'Could not connect to Health Connect.';
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: iconColor,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthActionButtons() {
    final bool isNotInstalled = _healthStatus == HealthConnectStatus.notInstalled;
    final bool canConnect = _healthStatus == HealthConnectStatus.permissionRequired;
    final bool canManage = _healthStatus == HealthConnectStatus.connected ||
        _healthStatus == HealthConnectStatus.noData;
    final bool canRefresh = _healthStatus != HealthConnectStatus.notSupported &&
        _healthStatus != HealthConnectStatus.notInstalled;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (isNotInstalled)
          ElevatedButton.icon(
            onPressed: _healthStatusLoading
                ? null
                : () async {
                    await HealthIntegrationService.instance.installHealthConnect();
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            icon: const Icon(Icons.download_rounded, size: 18),
            label: const Text('Install Health Connect', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        if (canConnect)
          ElevatedButton.icon(
            onPressed: _healthStatusLoading ? null : _connectHealthConnect,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            icon: const Icon(Icons.link_rounded, size: 18),
            label: const Text('Connect', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        if (canManage)
          OutlinedButton.icon(
            onPressed: _healthStatusLoading ? null : _connectHealthConnect,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.teal,
              side: const BorderSide(color: Colors.teal),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            icon: const Icon(Icons.settings_rounded, size: 18),
            label: const Text('Manage Permissions'),
          ),
        if (canRefresh)
          TextButton.icon(
            onPressed: _healthStatusLoading ? null : _loadHealthStatus,
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey.shade700,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Refresh'),
          ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 20, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: Colors.grey.shade500,
          fontWeight: FontWeight.bold,
          fontSize: 12,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildRemindersSection() {
    return Container(
      color: Colors.grey.shade50,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              "SCHEDULED REMINDERS",
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.bold,
                fontSize: 11,
                letterSpacing: 1.1,
              ),
            ),
          ),

          // 1. WORKOUT REMINDER
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  activeThumbColor: Colors.teal,
                  secondary: _buildIconBox(Icons.fitness_center_rounded, Colors.orange),
                  title: const Text("Workout Reminder", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: Text(
                    _workoutReminderEnabled
                        ? "${_workoutReminderDays.map(_weekdayName).join(', ')} at ${_formatTimeOfDay(_workoutReminderTime)}"
                        : "Disabled",
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  value: _workoutReminderEnabled,
                  onChanged: (val) async {
                    if (val) {
                      final granted = await _ensureNotificationPermission();
                      if (!granted) return;
                    }
                    setState(() => _workoutReminderEnabled = val);
                    await _saveRemindersToFirestoreAndSync();
                  },
                ),
                if (_workoutReminderEnabled) ...[
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("Reminder Time", style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
                            OutlinedButton.icon(
                              icon: const Icon(Icons.access_time, size: 16, color: Colors.teal),
                              label: Text(_formatTimeOfDay(_workoutReminderTime), style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.teal),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              ),
                              onPressed: () async {
                                final picked = await showTimePicker(
                                  context: context,
                                  initialTime: _workoutReminderTime,
                                );
                                if (picked != null) {
                                  setState(() => _workoutReminderTime = picked);
                                  await _saveRemindersToFirestoreAndSync();
                                }
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text("Active Days", style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: List.generate(7, (index) {
                            final day = index + 1;
                            final isSelected = _workoutReminderDays.contains(day);
                            return FilterChip(
                              label: Text(_weekdayName(day)),
                              selected: isSelected,
                              selectedColor: Colors.teal.shade100,
                              checkmarkColor: Colors.teal.shade800,
                              labelStyle: TextStyle(
                                fontSize: 11,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                color: isSelected ? Colors.teal.shade900 : Colors.black87,
                              ),
                              onSelected: (selected) async {
                                setState(() {
                                  if (selected) {
                                    if (!_workoutReminderDays.contains(day)) {
                                      _workoutReminderDays.add(day);
                                      _workoutReminderDays.sort();
                                    }
                                  } else {
                                    if (_workoutReminderDays.length > 1) {
                                      _workoutReminderDays.remove(day);
                                    }
                                  }
                                });
                                await _saveRemindersToFirestoreAndSync();
                              },
                            );
                          }),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 10),

          // 2. MEAL LOGGING REMINDERS
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: ExpansionTile(
              leading: _buildIconBox(Icons.restaurant_rounded, Colors.green),
              title: const Text("Meal Logging Reminders", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              subtitle: Text(
                [
                  if (_breakfastReminderEnabled) "Breakfast",
                  if (_lunchReminderEnabled) "Lunch",
                  if (_dinnerReminderEnabled) "Dinner",
                ].isEmpty
                    ? "Disabled"
                    : [
                        if (_breakfastReminderEnabled) "Breakfast",
                        if (_lunchReminderEnabled) "Lunch",
                        if (_dinnerReminderEnabled) "Dinner",
                      ].join(', '),
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              childrenPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                _buildMealReminderRow(
                  label: "Breakfast",
                  enabled: _breakfastReminderEnabled,
                  time: _breakfastReminderTime,
                  onToggle: (val) async {
                    if (val) {
                      final granted = await _ensureNotificationPermission();
                      if (!granted) return;
                    }
                    setState(() => _breakfastReminderEnabled = val);
                    await _saveRemindersToFirestoreAndSync();
                  },
                  onTimeChange: (newTime) async {
                    setState(() => _breakfastReminderTime = newTime);
                    await _saveRemindersToFirestoreAndSync();
                  },
                ),
                const Divider(height: 1),
                _buildMealReminderRow(
                  label: "Lunch",
                  enabled: _lunchReminderEnabled,
                  time: _lunchReminderTime,
                  onToggle: (val) async {
                    if (val) {
                      final granted = await _ensureNotificationPermission();
                      if (!granted) return;
                    }
                    setState(() => _lunchReminderEnabled = val);
                    await _saveRemindersToFirestoreAndSync();
                  },
                  onTimeChange: (newTime) async {
                    setState(() => _lunchReminderTime = newTime);
                    await _saveRemindersToFirestoreAndSync();
                  },
                ),
                const Divider(height: 1),
                _buildMealReminderRow(
                  label: "Dinner",
                  enabled: _dinnerReminderEnabled,
                  time: _dinnerReminderTime,
                  onToggle: (val) async {
                    if (val) {
                      final granted = await _ensureNotificationPermission();
                      if (!granted) return;
                    }
                    setState(() => _dinnerReminderEnabled = val);
                    await _saveRemindersToFirestoreAndSync();
                  },
                  onTimeChange: (newTime) async {
                    setState(() => _dinnerReminderTime = newTime);
                    await _saveRemindersToFirestoreAndSync();
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // 3. HYDRATION REMINDER
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      _buildIconBox(Icons.water_drop_rounded, Colors.blue),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Hydration Reminder',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _hydrationReminderEnabled
                                  ? "Every $_hydrationIntervalHours hours (8:00 AM - 10:00 PM)"
                                  : "Disabled",
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Switch(
                        activeThumbColor: Colors.teal,
                        value: _hydrationReminderEnabled,
                        onChanged: (val) async {
                          if (val) {
                            final granted = await _ensureNotificationPermission();
                            if (!granted) return;
                          }
                          setState(() => _hydrationReminderEnabled = val);
                          await _saveRemindersToFirestoreAndSync();
                        },
                      ),
                    ],
                  ),
                ),
                if (_hydrationReminderEnabled) ...[
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Interval",
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [2, 3, 4].map((hours) {
                            final isSelected = _hydrationIntervalHours == hours;
                            return ChoiceChip(
                              label: Text("Every ${hours}h"),
                              selected: isSelected,
                              selectedColor: Colors.blue.shade100,
                              labelStyle: TextStyle(
                                fontSize: 11,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                color: isSelected ? Colors.blue.shade900 : Colors.black87,
                              ),
                              onSelected: (selected) async {
                                if (selected) {
                                  setState(() => _hydrationIntervalHours = hours);
                                  await _saveRemindersToFirestoreAndSync();
                                }
                              },
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 10),

          // 4. WEEKLY PROGRESS REMINDER
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  activeThumbColor: Colors.teal,
                  secondary: _buildIconBox(Icons.insights_rounded, Colors.purple),
                  title: const Text("Weekly Progress Reminder", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: Text(
                    _weeklyProgressReminderEnabled
                        ? "${_weekdayName(_weeklyProgressDay)} at ${_formatTimeOfDay(_weeklyProgressTime)}"
                        : "Disabled",
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  value: _weeklyProgressReminderEnabled,
                  onChanged: (val) async {
                    if (val) {
                      final granted = await _ensureNotificationPermission();
                      if (!granted) return;
                    }
                    setState(() => _weeklyProgressReminderEnabled = val);
                    await _saveRemindersToFirestoreAndSync();
                  },
                ),
                if (_weeklyProgressReminderEnabled) ...[
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        DropdownButton<int>(
                          value: _weeklyProgressDay,
                          underline: const SizedBox(),
                          icon: const Icon(Icons.arrow_drop_down, color: Colors.teal),
                          style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold, fontSize: 13),
                          items: List.generate(7, (index) {
                            final d = index + 1;
                            return DropdownMenuItem<int>(
                              value: d,
                              child: Text(_weekdayName(d)),
                            );
                          }),
                          onChanged: (newDay) async {
                            if (newDay != null) {
                              setState(() => _weeklyProgressDay = newDay);
                              await _saveRemindersToFirestoreAndSync();
                            }
                          },
                        ),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.access_time, size: 16, color: Colors.teal),
                          label: Text(_formatTimeOfDay(_weeklyProgressTime), style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.teal),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          ),
                          onPressed: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: _weeklyProgressTime,
                            );
                            if (picked != null) {
                              setState(() => _weeklyProgressTime = picked);
                              await _saveRemindersToFirestoreAndSync();
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 10),

          // 5. DIAGNOSTICS & NOTIFICATION TESTING
          Card(
            elevation: 0,
            color: Colors.blue.shade50.withValues(alpha: 0.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.blue.shade100),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.bug_report_outlined, size: 16, color: Colors.blue.shade800),
                      const SizedBox(width: 6),
                      Text(
                        "NOTIFICATION DIAGNOSTICS",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade800,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.notifications_active, size: 14),
                        label: const Text("Send Test Now", style: TextStyle(fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.blue.shade900,
                          side: BorderSide(color: Colors.blue.shade300),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        ),
                        onPressed: () async {
                          final granted = await _ensureNotificationPermission();
                          if (granted) {
                            await NotificationService.instance.sendImmediateTestNotification();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Immediate test notification sent! Check your notification tray."),
                                  backgroundColor: Colors.teal,
                                ),
                              );
                            }
                          }
                        },
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.timer_outlined, size: 14),
                        label: const Text("Schedule in 1 Min", style: TextStyle(fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.blue.shade900,
                          side: BorderSide(color: Colors.blue.shade300),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        ),
                        onPressed: () async {
                          final granted = await _ensureNotificationPermission();
                          if (granted) {
                            await NotificationService.instance.scheduleTestNotification(secondsFromNow: 60);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Test notification scheduled for 1 minute from now. Keep an eye on your status bar!"),
                                  backgroundColor: Colors.teal,
                                ),
                              );
                            }
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMealReminderRow({
    required String label,
    required bool enabled,
    required TimeOfDay time,
    required ValueChanged<bool> onToggle,
    required ValueChanged<TimeOfDay> onTimeChange,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Checkbox(
                value: enabled,
                activeColor: Colors.teal,
                onChanged: (v) => onToggle(v ?? false),
              ),
              Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            ],
          ),
          OutlinedButton.icon(
            icon: Icon(Icons.access_time, size: 14, color: enabled ? Colors.teal : Colors.grey),
            label: Text(
              _formatTimeOfDay(time),
              style: TextStyle(
                color: enabled ? Colors.teal : Colors.grey,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: enabled ? Colors.teal : Colors.grey.shade300),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            ),
            onPressed: enabled
                ? () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: time,
                    );
                    if (picked != null) {
                      onTimeChange(picked);
                    }
                  }
                : null,
          ),
        ],
      ),
    );
  }
}