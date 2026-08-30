import 'package:flutter/material.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/workout/form_detection_preview_modal.dart';
import 'exercise_library_screen.dart';

class ActiveWorkoutPage extends StatefulWidget {
  final String workoutName; // e.g. "Chest & Triceps", "Full Body Blast"
  final List<Map<String, dynamic>> routine; // Array of exercises

  const ActiveWorkoutPage({
    super.key,
    required this.workoutName,
    required this.routine,
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
  bool _isMetric = true;

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

  void _initializeSetsForCurrentExercise() {
    final defaultSetsCount = _activeRoutine[_currentIndex]['sets'] ?? 3;
    final defaultReps = (_activeRoutine[_currentIndex]['reps'] ?? 10).toString();

    _currentSets = List.generate(defaultSetsCount, (i) {
      return {
        "set": i + 1,
        "prev": i == 0 ? "60kg × 10" : "-",
        "weight": "60",
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
    // Standard MET estimate for resistance training: ~6 kcal / min
    return (_sessionSeconds / 60.0 * 6.2).round();
  }

  double get _overallCompletionProgress {
    if (_activeRoutine.isEmpty) return 0.0;
    // Current completed exercises ratio plus fraction of current sets done
    int totalDoneSets = _currentSets.where((s) => s['done'] == true).length;
    double currentFraction = _currentSets.isEmpty ? 0.0 : (totalDoneSets / _currentSets.length);
    return ((_currentIndex + currentFraction) / _activeRoutine.length).clamp(0.0, 1.0);
  }

  // --- SAVE & NAVIGATION ---
  void _saveCurrentExerciseData() {
    final completedSets = _currentSets.where((s) => s['done'] == true).toList();
    if (completedSets.isNotEmpty) {
      _allCompletedExercises.add({
        'exerciseName': _activeRoutine[_currentIndex]['name'],
        'target': _activeRoutine[_currentIndex]['target'] ?? 'Full Body',
        'equipment': _activeRoutine[_currentIndex]['equipment'] ?? 'General',
        'notes': _noteController.text.trim(),
        'sets': completedSets.map((s) => {
          'set': s['set'],
          'weight': double.tryParse(s['weight'].toString()) ?? 0.0,
          'reps': int.tryParse(s['reps'].toString()) ?? 0,
        }).toList(),
      });
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
      final prevWeight = _currentSets.isNotEmpty ? _currentSets.last['weight'] : "50";
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
            Navigator.pop(context); // Close library
            setState(() {
              _activeRoutine[_currentIndex] = {
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

  Future<void> _finishWorkout() async {
    _saveCurrentExerciseData();

    if (_allCompletedExercises.isEmpty) {
      showDialog(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text("Discard Session?"),
          content: const Text("No completed sets logged. Do you want to cancel this workout?"),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: const Text("Continue")),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(c);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              child: const Text("Discard"),
            ),
          ],
        ),
      );
      return;
    }

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
                Text("Saving workout to your profile...", style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('workout_logs')
            .add({
          'routineName': widget.workoutName,
          'durationSeconds': _sessionSeconds,
          'caloriesBurned': _estimatedCalories,
          'exercises': _allCompletedExercises,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }

      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        Navigator.pop(context); // Close ActiveWorkoutPage
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 10),
                Text("Workout Logged! Burned ~$_estimatedCalories kcal 🔥"),
              ],
            ),
            backgroundColor: Colors.teal,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Saved locally. Sync error: $e")),
        );
        Navigator.pop(context);
      }
    }
  }

  void _confirmCancelWorkout() {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("End Workout Early?"),
        content: const Text("Your current workout session progress will be lost."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text("Keep Going")),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(c);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
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
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 28),
          onPressed: () => Navigator.pop(context),
          tooltip: "Minimize",
        ),
        title: Column(
          children: [
            Text(
              widget.workoutName,
              style: const TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w500),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.timer_outlined, size: 14, color: Colors.teal),
                const SizedBox(width: 4),
                Text(
                  _formatTime(_sessionSeconds),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
                ),
              ],
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _confirmCancelWorkout,
            child: const Text("Cancel", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
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
                // 1. Live Stats Header Card (Calories + Exercise index + Progress)
                _buildLiveStatsHeader(progress),

                // 2. Exercise Title Card with AI Assist & Replace buttons
                _buildExerciseHeaderCard(currentEx),

                // 3. Dynamic Exercise Sets Tracker Table
                _buildSetsTrackerTable(),

                // 4. Exercise Notes Field
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: TextField(
                    controller: _noteController,
                    decoration: InputDecoration(
                      hintText: "Add personal cues, seat position, RPE...",
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

          // 5. Rest Timer Floating Overlay
          if (_isResting) _buildRestTimerOverlay(),
        ],
      ),

      // 6. Bottom Floating Navigation Bar (Prev, Next / Finish)
      bottomNavigationBar: _buildBottomActionBar(),
    );
  }

  // --- SUB-WIDGETS ---

  Widget _buildLiveStatsHeader(double progress) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.local_fire_department, color: Colors.orange, size: 20),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "~$_estimatedCalories kcal",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const Text("Burned", style: TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
            ],
          ),

          // Exercise completion count
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.teal.shade50,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              "Exercise ${_currentIndex + 1} of ${_activeRoutine.length}",
              style: TextStyle(
                color: Colors.teal.shade900,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),

          // Unit Switcher (kg / lbs)
          InkWell(
            onTap: () => setState(() => _isMetric = !_isMetric),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _isMetric ? "Unit: KG" : "Unit: LBS",
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseHeaderCard(Map<String, dynamic> currentEx) {
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
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${currentEx['target'] ?? 'Muscle'} • ${currentEx['equipment'] ?? 'Equipment'}",
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              // Replace Exercise Button
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

          const SizedBox(height: 14),

          // AI Camera Form Coach Banner Button
          InkWell(
            onTap: () {
              FormDetectionPreviewModal.show(
                context,
                exerciseName: currentEx['name'] ?? 'Exercise',
              );
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF1E1B4B),
                    Colors.purple.shade900,
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.videocam_rounded, color: Colors.cyanAccent, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "AI Camera Form Detection",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          "Tap to preview real-time posture coaching",
                          style: TextStyle(color: Colors.cyanAccent, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: Colors.white70, size: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSetsTrackerTable() {
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
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
                    child: Text(_isMetric ? "KG" : "LBS", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
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
                color: isDone ? Colors.teal.withValues(alpha: 0.06) : Colors.white,
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
                        initialValue: set['weight'].toString(),
                        textAlign: TextAlign.center,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        onChanged: (val) => set['weight'] = val,
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
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        onChanged: (val) {
                          FocusScope.of(context).unfocus();
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
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(20),
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
                    const Icon(Icons.timelapse_rounded, color: Colors.tealAccent, size: 22),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Resting Interval",
                          style: TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                        Text(
                          _formatTime(_restSeconds),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
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
                    const SizedBox(width: 6),
                    _buildRestQuickAddBtn("+60s", 60),
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
            const SizedBox(height: 10),
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
              onPressed: isLastExercise ? _finishWorkout : _nextExercise,
              icon: Icon(isLastExercise ? Icons.check_circle_rounded : Icons.arrow_forward_ios_rounded, size: 18),
              label: Text(
                isLastExercise ? "Finish Workout" : "Next Exercise",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: isLastExercise ? Colors.green.shade600 : Colors.teal,
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