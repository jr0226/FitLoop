import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'exercise_library_screen.dart';
import 'workout_analytics_screen.dart';

class ActiveWorkoutPage extends StatefulWidget {
  final String workoutName;
  final List<Map<String, dynamic>> routine;
  final String? routineId;
  final String? workoutType;
  final String? fitnessGoal;
  final String? fitnessLevel;

  const ActiveWorkoutPage({
    super.key,
    required this.workoutName,
    required this.routine,
    this.routineId,
    this.workoutType,
    this.fitnessGoal,
    this.fitnessLevel,
  });

  @override
  State<ActiveWorkoutPage> createState() => _ActiveWorkoutPageState();
}

class _ActiveWorkoutPageState extends State<ActiveWorkoutPage> {
  // --- WORKOUT STATE ---
  late List<Map<String, dynamic>> _activeRoutine;
  int _currentIndex = 0;
  final List<Map<String, dynamic>> _allCompletedExercises = [];

  // --- TIMERS ---
  Timer? _sessionTimer;
  int _sessionSeconds = 0;

  Timer? _restTimer;
  int _restSeconds = 0;
  int _totalRestTarget = 60;
  bool _isResting = false;
  final int _defaultRestTime = 60;

  // Weight Unit Preference
  final bool _isMetric = true;

  // Current sets for the active exercise
  List<Map<String, dynamic>> _currentSets = [];
  final TextEditingController _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _activeRoutine = List<Map<String, dynamic>>.from(widget.routine);
    if (_activeRoutine.isEmpty) {
      _activeRoutine.add({
        'name': 'Barbell Bench Press',
        'target': 'Chest',
        'equipment': 'Barbell',
        'sets': 3,
        'reps': 10,
      });
    }
    _startSessionTimer();
    _initializeSetsForCurrentExercise();
  }

  @override
  void dispose() {
    _sessionTimer?.cancel();
    _restTimer?.cancel();
    _noteController.dispose();
    super.dispose();
  }

  bool _isCurrentExerciseBodyweight() {
    if (_activeRoutine.isEmpty) return false;
    final currentEx = _activeRoutine[_currentIndex];
    final equip = (currentEx['equipment'] ?? '').toString().toLowerCase();
    final name = (currentEx['name'] ?? '').toString().toLowerCase();
    return equip.contains('body') ||
           equip.contains('none') ||
           name.contains('push up') ||
           name.contains('pull up') ||
           name.contains('squat') && equip.isEmpty ||
           name.contains('crunch') ||
           name.contains('plank');
  }

  void _initializeSetsForCurrentExercise() {
    final rawSets = _activeRoutine[_currentIndex]['sets'];
    int defaultSetsCount = 3;
    if (rawSets is num) {
      defaultSetsCount = rawSets.toInt();
    } else if (rawSets is String) {
      final match = RegExp(r'^\s*(\d+)').firstMatch(rawSets);
      defaultSetsCount = match != null ? (int.tryParse(match.group(1)!) ?? 3) : 3;
    }
    defaultSetsCount = defaultSetsCount.clamp(1, 20);

    final rawReps = _activeRoutine[_currentIndex]['reps'];
    String defaultReps = '10';
    if (rawReps is num) {
      defaultReps = rawReps.toInt().toString();
    } else if (rawReps is String) {
      final match = RegExp(r'(\d+)').firstMatch(rawReps);
      defaultReps = match != null ? match.group(1)! : '10';
    }

    final bool isBodyweight = _isCurrentExerciseBodyweight();
    final String initialWeight = isBodyweight ? "0" : "50";

    _currentSets = List.generate(defaultSetsCount, (i) {
      return {
        "set": i + 1,
        "prev": i == 0 ? (isBodyweight ? "BW × $defaultReps" : "50kg × $defaultReps") : "-",
        "weight": initialWeight,
        "reps": defaultReps,
        "done": false,
      };
    });
    _noteController.clear();
  }

  // --- TIMER LOGIC ---
  void _startSessionTimer() {
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() => _sessionSeconds++);
    });
  }

  void _triggerRestTimer([int? customSeconds]) {
    final rest = customSeconds ?? _defaultRestTime;
    setState(() {
      _isResting = true;
      _totalRestTarget = rest;
      _restSeconds = rest;
    });
    _restTimer?.cancel();
    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_restSeconds > 0) {
        if (mounted) setState(() => _restSeconds--);
      } else {
        _skipRest();
      }
    });
  }

  void _adjustRestTime(int seconds) {
    setState(() {
      _restSeconds += seconds;
      _totalRestTarget += seconds;
      if (_restSeconds < 0) _restSeconds = 0;
      if (_totalRestTarget <= 0) _totalRestTarget = 1;
    });
  }

  void _skipRest() {
    _restTimer?.cancel();
    if (mounted) setState(() => _isResting = false);
  }

  String _formatTime(int seconds) {
    int m = seconds ~/ 60;
    int s = seconds % 60;
    return "${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}";
  }

  int get _estimatedCalories {
    return (_sessionSeconds / 60.0 * 6.2).round();
  }

  double get _overallCompletionProgress {
    if (_activeRoutine.isEmpty) return 0.0;
    int totalDoneSets = _currentSets.where((s) => s['done'] == true).length;
    double currentFraction = _currentSets.isEmpty ? 0.0 : (totalDoneSets / _currentSets.length);
    return ((_currentIndex + currentFraction) / _activeRoutine.length).clamp(0.0, 1.0);
  }

  // --- SAVE & NAVIGATION ---
  void _saveCurrentExerciseData() {
    final completedSets = _currentSets.where((s) => s['done'] == true).toList();
    if (completedSets.isNotEmpty) {
      final currentEx = _activeRoutine[_currentIndex];
      final String exerciseName = currentEx['name'] ?? currentEx['exerciseName'] ?? 'Exercise';
      final String exId = (currentEx['id'] ?? '').toString();

      // Check if already in _allCompletedExercises, replace if so
      final existingIdx = _allCompletedExercises.indexWhere((e) => e['name'] == exerciseName);

      final Map<String, dynamic> record = {
        if (exId.isNotEmpty) 'exerciseId': exId,
        'name': exerciseName,
        'exerciseName': exerciseName,
        'target': currentEx['target'] ?? currentEx['targetMuscle'] ?? 'Full Body',
        'equipment': currentEx['equipment'] ?? 'General',
        'notes': _noteController.text.trim(),
        'sets': completedSets.map((s) {
          final int setNum = (s['set'] as num?)?.toInt() ?? 1;
          final double weight = double.tryParse(s['weight'].toString()) ?? 0.0;
          final int reps = int.tryParse(s['reps'].toString()) ?? 0;
          return {
            'setNumber': setNum,
            'set': setNum,
            'weight': weight,
            'reps': reps,
            'isCompleted': true,
          };
        }).toList(),
      };

      if (existingIdx >= 0) {
        _allCompletedExercises[existingIdx] = record;
      } else {
        _allCompletedExercises.add(record);
      }
    }
  }

  void _nextExercise() {
    _saveCurrentExerciseData();
    if (_currentIndex < _activeRoutine.length - 1) {
      setState(() {
        _currentIndex++;
        _initializeSetsForCurrentExercise();
        _skipRest();
      });
    }
  }

  void _prevExercise() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
        _initializeSetsForCurrentExercise();
        _skipRest();
      });
    }
  }

  void _addSet() {
    setState(() {
      final prevWeight = _currentSets.isNotEmpty ? _currentSets.last['weight'] : (_isCurrentExerciseBodyweight() ? "0" : "50");
      final prevReps = _currentSets.isNotEmpty ? _currentSets.last['reps'] : "10";
      _currentSets.add({
        "set": _currentSets.length + 1,
        "prev": "-",
        "weight": prevWeight,
        "reps": prevReps,
        "done": false,
      });
    });
  }

  void _replaceCurrentExercise() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ExerciseLibraryScreen(
          onSelectExerciseForWorkout: (newEx) {
            Navigator.pop(context);
            setState(() {
              _activeRoutine[_currentIndex] = {
                'id': newEx.id,
                'name': newEx.name,
                'target': newEx.targetMuscle,
                'equipment': newEx.equipment,
                'sets': newEx.defaultSets,
                'reps': newEx.defaultReps,
              };
              _initializeSetsForCurrentExercise();
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("Replaced with ${newEx.name}"),
                backgroundColor: Colors.teal,
              ),
            );
          },
        ),
      ),
    );
  }

  void _requestFinishWorkout() {
    _saveCurrentExerciseData();

    // Calculate total completed sets
    int totalCompletedSets = 0;
    int totalCompletedReps = 0;
    for (final ex in _allCompletedExercises) {
      final sets = ex['sets'] as List<dynamic>? ?? [];
      totalCompletedSets += sets.length;
      for (final s in sets) {
        if (s is Map) {
          totalCompletedReps += (s['reps'] as num?)?.toInt() ?? 0;
        }
      }
    }

    if (totalCompletedSets == 0) {
      showDialog(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text("Discard Session?"),
          content: const Text("No completed sets logged. Do you want to cancel this workout session?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text("Continue Session"),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(c);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
              child: const Text("Discard"),
            ),
          ],
        ),
      );
      return;
    }

    // If there are uncompleted exercises or sets, show confirmation
    final bool hasUnfinishedExercises = _currentIndex < _activeRoutine.length - 1;
    final int uncompletedInCurrent = _currentSets.where((s) => s['done'] != true).length;

    if (hasUnfinishedExercises || uncompletedInCurrent > 0) {
      showDialog(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text("Finish Workout Early?"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "You have completed $totalCompletedSets sets ($totalCompletedReps reps) in ${_formatTime(_sessionSeconds)}.",
                style: const TextStyle(fontSize: 14, height: 1.3),
              ),
              const SizedBox(height: 10),
              const Text(
                "Ready to wrap up and log your progress?",
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text("Keep Going"),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(c);
                _persistAndShowSummary();
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
              child: const Text("Finish & Save"),
            ),
          ],
        ),
      );
    } else {
      _persistAndShowSummary();
    }
  }

  Future<void> _persistAndShowSummary() async {
    _sessionTimer?.cancel();
    _restTimer?.cancel();

    int totalSets = 0;
    int totalReps = 0;
    double totalVolume = 0.0;

    for (final ex in _allCompletedExercises) {
      final sets = ex['sets'] as List<dynamic>? ?? [];
      for (final s in sets) {
        if (s is Map) {
          final reps = (s['reps'] as num?)?.toInt() ?? 0;
          final weight = (s['weight'] as num?)?.toDouble() ?? 0.0;
          totalSets++;
          totalReps += reps;
          if (weight > 0) {
            totalVolume += (weight * reps);
          }
        }
      }
    }

    // Background sync to Firestore
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final now = DateTime.now();
        final startedAt = now.subtract(Duration(seconds: _sessionSeconds));

        final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        final userData = userDoc.data() ?? {};
        final fitnessGoal = widget.fitnessGoal ?? userData['fitnessGoal'] ?? userData['goal'] ?? 'Maintenance';
        final fitnessLevel = widget.fitnessLevel ?? userData['fitnessLevel'] ?? 'Beginner';

        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('workout_logs')
            .add({
          if (widget.routineId != null && widget.routineId!.isNotEmpty)
            'routineId': widget.routineId,
          'routineName': widget.workoutName,
          'workoutType': widget.workoutType ?? 'Strength',
          'fitnessGoal': fitnessGoal,
          'fitnessLevel': fitnessLevel,
          'durationSeconds': _sessionSeconds,
          'caloriesBurned': _estimatedCalories,
          'exercises': _allCompletedExercises,
          'totalSets': totalSets,
          'totalReps': totalReps,
          'totalVolume': totalVolume,
          'notes': _allCompletedExercises.map((e) => e['notes']).where((n) => n != null && n.toString().isNotEmpty).join('; '),
          'startedAt': Timestamp.fromDate(startedAt),
          'completedAt': Timestamp.fromDate(now),
          'timestamp': Timestamp.fromDate(now),
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint("Workout sync notice: $e");
    }

    if (!mounted) return;

    // Show Workout Completion Summary Dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Celebration Badge
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.teal.shade50,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.emoji_events_rounded, color: Colors.teal, size: 36),
              ),
              const SizedBox(height: 16),
              const Text(
                "Workout Completed! 🎉",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 6),
              Text(
                widget.workoutName,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 20),

              // Summary Stats Grid
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildSummaryMetric(Icons.timer_outlined, "Time", _formatTime(_sessionSeconds), Colors.teal),
                        _buildSummaryMetric(Icons.local_fire_department_rounded, "Calories", "~$_estimatedCalories kcal", Colors.orange),
                        _buildSummaryMetric(Icons.checklist_rounded, "Sets", "$totalSets sets", Colors.blue),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Divider(height: 1, color: Colors.grey.shade200),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildSummaryMetric(Icons.repeat_rounded, "Total Reps", "$totalReps", Colors.indigo),
                        _buildSummaryMetric(
                          Icons.fitness_center_rounded,
                          "Volume Lifted",
                          totalVolume > 0 ? "${totalVolume.toInt()} kg" : "Bodyweight",
                          Colors.purple,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Action Buttons: Done & View Progress
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(c); // Close dialog
                    Navigator.pop(context); // Close ActiveWorkoutPage
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text("Done", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  Navigator.pop(c); // Close dialog
                  Navigator.pop(context); // Close ActiveWorkoutPage
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const WorkoutAnalyticsScreen()),
                  );
                },
                child: const Text(
                  "View Progress & History",
                  style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryMetric(IconData icon, String label, String value, Color color) {
    return Column(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  void _confirmCancelWorkout() {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("End Workout Early?"),
        content: const Text("Your current workout session progress will be lost if you discard."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text("Keep Going"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(c);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            child: const Text("End & Discard"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentEx = _activeRoutine[_currentIndex];
    final progress = _overallCompletionProgress;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, size: 24, color: Colors.black87),
          onPressed: _confirmCancelWorkout,
          tooltip: "Cancel Workout",
        ),
        title: Column(
          children: [
            Text(
              widget.workoutName,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              "Exercise ${_currentIndex + 1} of ${_activeRoutine.length}",
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          // Clean Session Timer Chip in Header
          Container(
            margin: const EdgeInsets.only(right: 14),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.teal.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.timer_outlined, size: 14, color: Colors.teal),
                const SizedBox(width: 4),
                Text(
                  _formatTime(_sessionSeconds),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.teal),
                ),
              ],
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey.shade200,
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.teal),
            minHeight: 4,
          ),
        ),
      ),

      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Exercise Title Card (Name, Target, Equipment, Replace)
                _buildExerciseHeaderCard(currentEx),

                // 2. Exercise Sets Tracker Table
                _buildSetsTrackerTable(),

                // 3. Optional Exercise Notes
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: TextField(
                    controller: _noteController,
                    decoration: InputDecoration(
                      hintText: "Add session notes (e.g. seat setting, RPE)...",
                      hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                      prefixIcon: const Icon(Icons.edit_note, color: Colors.teal),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 4. Rest Timer Floating Overlay
          if (_isResting) _buildRestTimerOverlay(),
        ],
      ),

      // 5. Bottom Navigation Bar (Prev / Next / Finish)
      bottomNavigationBar: _buildBottomActionBar(),
    );
  }

  // --- SUB-WIDGETS ---

  Widget _buildExerciseHeaderCard(Map<String, dynamic> currentEx) {
    final bool isBodyweight = _isCurrentExerciseBodyweight();

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      currentEx['name'] ?? 'Exercise',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      children: [
                        Text(
                          currentEx['target'] ?? 'Muscle',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                        ),
                        Text("•", style: TextStyle(color: Colors.grey.shade400)),
                        Text(
                          isBodyweight ? "Bodyweight" : (currentEx['equipment'] ?? 'Equipment'),
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: _replaceCurrentExercise,
                icon: const Icon(Icons.swap_horiz, size: 16),
                label: const Text("Replace", style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.teal,
                  side: const BorderSide(color: Colors.teal),
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSetsTrackerTable() {
    final bool isBodyweight = _isCurrentExerciseBodyweight();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          // Table Headers
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                const SizedBox(
                  width: 36,
                  child: Text("SET", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                ),
                const Expanded(
                  child: Center(
                    child: Text("PREVIOUS", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      isBodyweight ? "ADD WT" : (_isMetric ? "KG" : "LBS"),
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
                    ),
                  ),
                ),
                const Expanded(
                  child: Center(
                    child: Text("REPS", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                  ),
                ),
                const SizedBox(
                  width: 44,
                  child: Center(
                    child: Icon(Icons.check, size: 18, color: Colors.grey),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Set Rows
          ..._currentSets.map((set) {
            final bool isDone = set['done'] == true;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isDone ? Colors.teal.shade50.withValues(alpha: 0.6) : Colors.white,
                border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
              ),
              child: Row(
                children: [
                  // Set Number Pill
                  SizedBox(
                    width: 36,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: isDone ? Colors.teal : Colors.grey.shade200,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          "${set['set']}",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isDone ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Previous Record
                  Expanded(
                    child: Center(
                      child: Text(
                        set['prev'],
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                    ),
                  ),

                  // Weight Input Box
                  Expanded(
                    child: Container(
                      height: 38,
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      child: TextFormField(
                        initialValue: isBodyweight && (set['weight'] == "0" || set['weight'] == 0)
                            ? "BW"
                            : set['weight'].toString(),
                        textAlign: TextAlign.center,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
                        onChanged: (val) {
                          if (val.trim().toLowerCase() == "bw") {
                            set['weight'] = "0";
                          } else {
                            set['weight'] = val;
                          }
                        },
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          contentPadding: EdgeInsets.zero,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Colors.teal, width: 1.5),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Reps Input Box
                  Expanded(
                    child: Container(
                      height: 38,
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      child: TextFormField(
                        initialValue: set['reps'].toString(),
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
                        onChanged: (val) => set['reps'] = val,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          contentPadding: EdgeInsets.zero,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Colors.teal, width: 1.5),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Done Checkbox
                  SizedBox(
                    width: 44,
                    child: Center(
                      child: Checkbox(
                        value: isDone,
                        activeColor: Colors.teal,
                        checkColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        onChanged: (val) {
                          FocusScope.of(context).unfocus();
                          HapticFeedback.lightImpact();
                          setState(() {
                            set['done'] = val;
                            if (val == true) {
                              _triggerRestTimer();
                            }
                          });
                        },
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),

          // Add Set Button
          Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              height: 40,
              child: TextButton.icon(
                onPressed: _addSet,
                icon: const Icon(Icons.add_circle_outline, color: Colors.teal, size: 18),
                label: const Text(
                  "Add Set",
                  style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold, fontSize: 13),
                ),
                style: TextButton.styleFrom(
                  backgroundColor: Colors.teal.shade50,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRestTimerOverlay() {
    double restProgress = _totalRestTarget > 0 ? (_restSeconds / _totalRestTarget).clamp(0.0, 1.0) : 0.0;

    return Positioned(
      bottom: 10,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
          border: Border.all(color: Colors.teal.shade400, width: 1.2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.timelapse_rounded, color: Colors.tealAccent, size: 20),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Rest Timer",
                          style: TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                        Text(
                          _formatTime(_restSeconds),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Row(
                  children: [
                    _buildRestQuickAddBtn("+30s", 30),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _skipRest,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.tealAccent,
                        foregroundColor: Colors.black87,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text("Skip", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: restProgress,
                backgroundColor: Colors.white12,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.tealAccent),
                minHeight: 4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRestQuickAddBtn(String label, int seconds) {
    return InkWell(
      onTap: () => _adjustRestTime(seconds),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white24),
        ),
        child: Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildBottomActionBar() {
    final isLastExercise = _currentIndex >= _activeRoutine.length - 1;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          if (_currentIndex > 0)
            Expanded(
              flex: 1,
              child: OutlinedButton.icon(
                onPressed: _prevExercise,
                icon: const Icon(Icons.arrow_back_ios_rounded, size: 14),
                label: const Text("Prev"),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.black87,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            )
          else
            const SizedBox.shrink(),

          if (_currentIndex > 0) const SizedBox(width: 12),

          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: isLastExercise ? _requestFinishWorkout : _nextExercise,
              icon: Icon(isLastExercise ? Icons.check_circle_rounded : Icons.arrow_forward_ios_rounded, size: 18),
              label: Text(
                isLastExercise ? "Finish Workout" : "Next Exercise",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: isLastExercise ? Colors.teal.shade700 : Colors.teal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}