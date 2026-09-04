import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/workout_models.dart';
import 'exercise_library_screen.dart';

class ActiveWorkoutPage extends StatefulWidget {
  final String workoutName;
  final List<Map<String, dynamic>> routine;
  final String? routineId;
  final String? workoutType;
  final String? fitnessGoal;
  final String? fitnessLevel;
  final int defaultRestSeconds;
  final int restBetweenExercisesSeconds;

  const ActiveWorkoutPage({
    super.key,
    required this.workoutName,
    required this.routine,
    this.routineId,
    this.workoutType,
    this.fitnessGoal,
    this.fitnessLevel,
    this.defaultRestSeconds = 60,
    this.restBetweenExercisesSeconds = 60,
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

  // Rest Timer
  Timer? _restTimer;
  int _restSeconds = 0;
  int _totalRestTarget = 60;
  bool _isResting = false;
  bool _restFinished = false;
  int _nextSetNumber = 1;

  // Cardio / Timed Activity Timer
  Timer? _cardioTimer;
  int _cardioElapsedSeconds = 0;
  int _cardioTargetSeconds = 300; // default 5 min
  bool _isCardioRunning = false;
  bool _isCardioCompleted = false;

  // Weight Unit Preference
  final bool _isMetric = true;

  // Current sets for the active strength/bodyweight exercise
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
        'restSeconds': widget.defaultRestSeconds,
      });
    }
    _startSessionTimer();
    _initializeExerciseForCurrentIndex();
  }

  @override
  void dispose() {
    _sessionTimer?.cancel();
    _restTimer?.cancel();
    _cardioTimer?.cancel();
    _noteController.dispose();
    super.dispose();
  }

  // --- EXERCISE TRACKING TYPE DETECTION ---
  ExerciseTrackingType _currentTrackingType() {
    if (_activeRoutine.isEmpty) return ExerciseTrackingType.strength;
    final currentEx = _activeRoutine[_currentIndex];
    final rawType = currentEx['trackingType'];
    if (rawType is ExerciseTrackingType) return rawType;
    if (rawType != null) {
      final match = ExerciseTrackingType.values.where((t) => t.name == rawType.toString()).firstOrNull;
      if (match != null) return match;
    }
    return inferExerciseTrackingType(
      name: (currentEx['name'] ?? currentEx['exerciseName'] ?? '').toString(),
      category: (currentEx['category'] ?? currentEx['target'] ?? '').toString(),
      bodyPart: (currentEx['bodyPart'] ?? currentEx['target'] ?? '').toString(),
      equipment: (currentEx['equipment'] ?? '').toString(),
      reps: (currentEx['reps'] ?? '').toString(),
      durationSeconds: currentEx['durationSeconds'] is num ? (currentEx['durationSeconds'] as num).toInt() : null,
      isTimed: currentEx['isTimed'] == true,
    );
  }

  bool _isCurrentExerciseCardio() => _currentTrackingType() == ExerciseTrackingType.cardio;

  void _initializeExerciseForCurrentIndex() {
    _noteController.clear();
    _skipRest();

    final trackingType = _currentTrackingType();

    if (trackingType == ExerciseTrackingType.cardio) {
      _cardioTimer?.cancel();
      _cardioElapsedSeconds = 0;
      _isCardioRunning = false;
      _isCardioCompleted = false;

      final currentEx = _activeRoutine[_currentIndex];
      int targetSec = 300; // 5 min default
      final rawDuration = currentEx['durationSeconds'] ?? currentEx['duration'];
      if (rawDuration is num && rawDuration > 0) {
        targetSec = rawDuration.toInt();
      } else {
        final repsStr = (currentEx['reps'] ?? '').toString();
        final minMatch = RegExp(r'(\d+)\s*(?:m|min)', caseSensitive: false).firstMatch(repsStr);
        final secMatch = RegExp(r'(\d+)\s*(?:s|sec)', caseSensitive: false).firstMatch(repsStr);
        if (minMatch != null) {
          targetSec = (int.tryParse(minMatch.group(1)!) ?? 5) * 60;
        } else if (secMatch != null) {
          targetSec = int.tryParse(secMatch.group(1)!) ?? 300;
        }
      }
      _cardioTargetSeconds = targetSec;
      _currentSets = [];
    } else if (trackingType == ExerciseTrackingType.timed) {
      // Timed Holds (e.g., Plank, Wall Sit, Dead Hang)
      final currentEx = _activeRoutine[_currentIndex];
      final rawSets = currentEx['sets'];
      int defaultSetsCount = 3;
      if (rawSets is num) {
        defaultSetsCount = rawSets.toInt();
      } else if (rawSets is String) {
        final match = RegExp(r'^\s*(\d+)').firstMatch(rawSets);
        defaultSetsCount = match != null ? (int.tryParse(match.group(1)!) ?? 3) : 3;
      }
      defaultSetsCount = defaultSetsCount.clamp(1, 20);

      int targetSec = 45;
      final rawDur = currentEx['durationSeconds'] ?? currentEx['duration'];
      if (rawDur is num && rawDur > 0) {
        targetSec = rawDur.toInt();
      } else {
        final repsStr = (currentEx['reps'] ?? '').toString();
        final secMatch = RegExp(r'(\d+)\s*(?:s|sec)', caseSensitive: false).firstMatch(repsStr);
        if (secMatch != null) {
          targetSec = int.tryParse(secMatch.group(1)!) ?? 45;
        }
      }

      _currentSets = List.generate(defaultSetsCount, (i) {
        return {
          "set": i + 1,
          "targetDuration": targetSec,
          "duration": targetSec.toString(),
          "done": false,
        };
      });
    } else if (trackingType == ExerciseTrackingType.reps) {
      // Bodyweight Reps (e.g. Push-Up, Pull-Up, Crunch) - No mandatory weight
      final currentEx = _activeRoutine[_currentIndex];
      final rawSets = currentEx['sets'];
      int defaultSetsCount = 3;
      if (rawSets is num) {
        defaultSetsCount = rawSets.toInt();
      } else if (rawSets is String) {
        final match = RegExp(r'^\s*(\d+)').firstMatch(rawSets);
        defaultSetsCount = match != null ? (int.tryParse(match.group(1)!) ?? 3) : 3;
      }
      defaultSetsCount = defaultSetsCount.clamp(1, 20);

      final rawReps = currentEx['reps'];
      String defaultReps = '12';
      if (rawReps is num) {
        defaultReps = rawReps.toInt().toString();
      } else if (rawReps is String) {
        final match = RegExp(r'(\d+)').firstMatch(rawReps);
        defaultReps = match != null ? match.group(1)! : '12';
      }

      _currentSets = List.generate(defaultSetsCount, (i) {
        return {
          "set": i + 1,
          "targetReps": defaultReps,
          "reps": defaultReps,
          "done": false,
        };
      });
    } else {
      // Strength (weighted resistance: sets + reps + weight)
      final currentEx = _activeRoutine[_currentIndex];
      final rawSets = currentEx['sets'];
      int defaultSetsCount = 3;
      if (rawSets is num) {
        defaultSetsCount = rawSets.toInt();
      } else if (rawSets is String) {
        final match = RegExp(r'^\s*(\d+)').firstMatch(rawSets);
        defaultSetsCount = match != null ? (int.tryParse(match.group(1)!) ?? 3) : 3;
      }
      defaultSetsCount = defaultSetsCount.clamp(1, 20);

      final rawReps = currentEx['reps'];
      String defaultReps = '10';
      if (rawReps is num) {
        defaultReps = rawReps.toInt().toString();
      } else if (rawReps is String) {
        final match = RegExp(r'(\d+)').firstMatch(rawReps);
        defaultReps = match != null ? match.group(1)! : '10';
      }

      _currentSets = List.generate(defaultSetsCount, (i) {
        return {
          "set": i + 1,
          "targetReps": defaultReps,
          "weight": "20",
          "reps": defaultReps,
          "done": false,
        };
      });
    }
  }

  // --- TIMERS LOGIC ---
  void _startSessionTimer() {
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() => _sessionSeconds++);
    });
  }

  void _triggerRestTimer([int? customSeconds]) {
    final currentEx = _activeRoutine.isNotEmpty ? _activeRoutine[_currentIndex] : null;
    final int exerciseRest = (currentEx != null && currentEx['restSeconds'] is num && currentEx['restSeconds'] > 0)
        ? (currentEx['restSeconds'] as num).toInt()
        : widget.defaultRestSeconds;

    final int rest = customSeconds ?? exerciseRest;
    if (rest <= 0) {
      // Rest timer turned off
      return;
    }

    setState(() {
      _isResting = true;
      _restFinished = false;
      _totalRestTarget = rest;
      _restSeconds = rest;
    });

    _restTimer?.cancel();
    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_restSeconds > 1) {
        if (mounted) setState(() => _restSeconds--);
      } else {
        _restTimer?.cancel();
        if (mounted) {
          HapticFeedback.heavyImpact();
          setState(() {
            _restSeconds = 0;
            _restFinished = true;
          });
        }
      }
    });
  }

  void _adjustRestTime(int seconds) {
    setState(() {
      _restSeconds += seconds;
      if (_restSeconds < 0) _restSeconds = 0;
      if (_restSeconds > _totalRestTarget) _totalRestTarget = _restSeconds;
      if (_restSeconds > 0) _restFinished = false;
    });
  }

  void _skipRest() {
    _restTimer?.cancel();
    if (mounted) {
      setState(() {
        _isResting = false;
        _restFinished = false;
      });
    }
  }

  // --- CARDIO CONTROLS ---
  void _toggleCardioTimer() {
    if (_isCardioRunning) {
      _cardioTimer?.cancel();
      setState(() => _isCardioRunning = false);
    } else {
      setState(() => _isCardioRunning = true);
      _cardioTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() => _cardioElapsedSeconds++);
        }
      });
    }
  }

  void _resetCardioTimer() {
    _cardioTimer?.cancel();
    setState(() {
      _isCardioRunning = false;
      _cardioElapsedSeconds = 0;
    });
  }

  void _completeCardioActivity() {
    _cardioTimer?.cancel();
    HapticFeedback.mediumImpact();
    setState(() {
      _isCardioRunning = false;
      _isCardioCompleted = true;
    });

    // Save cardio activity
    final currentEx = _activeRoutine[_currentIndex];
    final String exerciseName = currentEx['name'] ?? 'Cardio Activity';
    final existingIdx = _allCompletedExercises.indexWhere((e) => e['name'] == exerciseName);

    final Map<String, dynamic> record = {
      'name': exerciseName,
      'exerciseName': exerciseName,
      'target': currentEx['target'] ?? 'Cardio',
      'equipment': currentEx['equipment'] ?? 'Cardio Machine',
      'type': 'cardio',
      'durationSeconds': _cardioElapsedSeconds > 0 ? _cardioElapsedSeconds : _cardioTargetSeconds,
      'notes': _noteController.text.trim(),
      'sets': [
        {
          'setNumber': 1,
          'set': 1,
          'durationSeconds': _cardioElapsedSeconds > 0 ? _cardioElapsedSeconds : _cardioTargetSeconds,
          'isCompleted': true,
        }
      ],
    };

    if (existingIdx >= 0) {
      _allCompletedExercises[existingIdx] = record;
    } else {
      _allCompletedExercises.add(record);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Completed $exerciseName (${_formatTime(_cardioElapsedSeconds)})"),
        backgroundColor: Colors.teal,
        duration: const Duration(seconds: 2),
      ),
    );

    // Trigger rest between exercises if enabled
    if (widget.restBetweenExercisesSeconds > 0 && _currentIndex < _activeRoutine.length - 1) {
      _triggerRestTimer(widget.restBetweenExercisesSeconds);
    }
  }

  // --- SET COMPLETION LOGIC ---
  void _completeSet(int setIndex) {
    FocusScope.of(context).unfocus();
    HapticFeedback.mediumImpact();

    setState(() {
      _currentSets[setIndex]['done'] = true;
      _nextSetNumber = (setIndex + 2).clamp(1, _currentSets.length);
    });

    // Check if more sets remain in this exercise
    final hasRemainingSets = _currentSets.any((s) => s['done'] != true);
    if (hasRemainingSets) {
      _triggerRestTimer();
    } else {
      // Completed all sets for this exercise!
      _saveCurrentExerciseData();
      if (_currentIndex < _activeRoutine.length - 1 && widget.restBetweenExercisesSeconds > 0) {
        _triggerRestTimer(widget.restBetweenExercisesSeconds);
      }
    }
  }

  void _uncompleteSet(int setIndex) {
    setState(() {
      _currentSets[setIndex]['done'] = false;
    });
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
    if (_isCurrentExerciseCardio()) {
      double cardioFraction = _isCardioCompleted ? 1.0 : (_cardioTargetSeconds > 0 ? (_cardioElapsedSeconds / _cardioTargetSeconds).clamp(0.0, 0.95) : 0.0);
      return ((_currentIndex + cardioFraction) / _activeRoutine.length).clamp(0.0, 1.0);
    }
    int totalDoneSets = _currentSets.where((s) => s['done'] == true).length;
    double currentFraction = _currentSets.isEmpty ? 0.0 : (totalDoneSets / _currentSets.length);
    return ((_currentIndex + currentFraction) / _activeRoutine.length).clamp(0.0, 1.0);
  }

  // --- SAVE & NAVIGATION ---
  void _saveCurrentExerciseData() {
    final type = _currentTrackingType();
    if (type == ExerciseTrackingType.cardio) {
      if (_cardioElapsedSeconds > 0 && !_isCardioCompleted) {
        _completeCardioActivity();
      }
      return;
    }

    final completedSets = _currentSets.where((s) => s['done'] == true).toList();
    if (completedSets.isNotEmpty) {
      final currentEx = _activeRoutine[_currentIndex];
      final String exerciseName = currentEx['name'] ?? currentEx['exerciseName'] ?? 'Exercise';
      final String exId = (currentEx['id'] ?? '').toString();

      final existingIdx = _allCompletedExercises.indexWhere((e) => e['name'] == exerciseName);

      final Map<String, dynamic> record;
      if (type == ExerciseTrackingType.timed) {
        int totalHoldSec = 0;
        final setRecords = completedSets.map((s) {
          final int setNum = (s['set'] as num?)?.toInt() ?? 1;
          final int dur = int.tryParse(s['duration'].toString()) ?? int.tryParse(s['targetDuration'].toString()) ?? 45;
          totalHoldSec += dur;
          return {
            'setNumber': setNum,
            'set': setNum,
            'durationSeconds': dur,
            'isCompleted': true,
          };
        }).toList();

        record = {
          if (exId.isNotEmpty) 'exerciseId': exId,
          'name': exerciseName,
          'exerciseName': exerciseName,
          'target': currentEx['target'] ?? currentEx['targetMuscle'] ?? 'Core',
          'equipment': currentEx['equipment'] ?? 'Bodyweight',
          'type': 'timed',
          'trackingType': 'timed',
          'durationSeconds': totalHoldSec,
          'notes': _noteController.text.trim(),
          'sets': setRecords,
        };
      } else if (type == ExerciseTrackingType.reps) {
        final setRecords = completedSets.map((s) {
          final int setNum = (s['set'] as num?)?.toInt() ?? 1;
          final int reps = int.tryParse(s['reps'].toString()) ?? 12;
          return {
            'setNumber': setNum,
            'set': setNum,
            'reps': reps,
            'isCompleted': true,
          };
        }).toList();

        record = {
          if (exId.isNotEmpty) 'exerciseId': exId,
          'name': exerciseName,
          'exerciseName': exerciseName,
          'target': currentEx['target'] ?? currentEx['targetMuscle'] ?? 'Bodyweight',
          'equipment': currentEx['equipment'] ?? 'Bodyweight',
          'type': 'reps',
          'trackingType': 'reps',
          'notes': _noteController.text.trim(),
          'sets': setRecords,
        };
      } else {
        // strength
        final setRecords = completedSets.map((s) {
          final int setNum = (s['set'] as num?)?.toInt() ?? 1;
          final double weight = double.tryParse(s['weight'].toString()) ?? 0.0;
          final int reps = int.tryParse(s['reps'].toString()) ?? 10;
          return {
            'setNumber': setNum,
            'set': setNum,
            if (weight > 0) 'weight': weight,
            'reps': reps,
            'isCompleted': true,
          };
        }).toList();

        record = {
          if (exId.isNotEmpty) 'exerciseId': exId,
          'name': exerciseName,
          'exerciseName': exerciseName,
          'target': currentEx['target'] ?? currentEx['targetMuscle'] ?? 'Strength',
          'equipment': currentEx['equipment'] ?? 'Barbell',
          'type': 'strength',
          'trackingType': 'strength',
          'notes': _noteController.text.trim(),
          'sets': setRecords,
        };
      }

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
        _initializeExerciseForCurrentIndex();
      });
    }
  }

  void _prevExercise() {
    if (_currentIndex > 0) {
      _saveCurrentExerciseData();
      setState(() {
        _currentIndex--;
        _initializeExerciseForCurrentIndex();
      });
    }
  }

  void _skipExercise() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Skip Exercise?"),
        content: Text("Do you want to skip '${_activeRoutine[_currentIndex]['name']}' and move to the next movement?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (_currentIndex < _activeRoutine.length - 1) {
                _nextExercise();
              } else {
                _requestFinishWorkout();
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
            child: const Text("Skip Exercise"),
          ),
        ],
      ),
    );
  }

  void _addSet() {
    final type = _currentTrackingType();
    setState(() {
      if (type == ExerciseTrackingType.timed) {
        final prevDur = _currentSets.isNotEmpty ? _currentSets.last['targetDuration'] : 45;
        _currentSets.add({
          "set": _currentSets.length + 1,
          "targetDuration": prevDur,
          "duration": prevDur.toString(),
          "done": false,
        });
      } else if (type == ExerciseTrackingType.reps) {
        final prevReps = _currentSets.isNotEmpty ? _currentSets.last['reps'] : "12";
        _currentSets.add({
          "set": _currentSets.length + 1,
          "targetReps": prevReps,
          "reps": prevReps,
          "done": false,
        });
      } else {
        final prevWeight = _currentSets.isNotEmpty ? _currentSets.last['weight'] : "20";
        final prevReps = _currentSets.isNotEmpty ? _currentSets.last['reps'] : "10";
        _currentSets.add({
          "set": _currentSets.length + 1,
          "targetReps": prevReps,
          "weight": prevWeight,
          "reps": prevReps,
          "done": false,
        });
      }
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
                'reps': newEx.isTimed ? '${newEx.durationSeconds}s' : newEx.defaultReps,
                'durationSeconds': newEx.durationSeconds,
                'restSeconds': newEx.restSeconds,
              };
              _initializeExerciseForCurrentIndex();
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

  void _addExerciseToSession() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ExerciseLibraryScreen(
          onSelectExerciseForWorkout: (newEx) {
            Navigator.pop(context);
            setState(() {
              _activeRoutine.add({
                'id': newEx.id,
                'name': newEx.name,
                'target': newEx.targetMuscle,
                'equipment': newEx.equipment,
                'sets': newEx.defaultSets,
                'reps': newEx.isTimed ? '${newEx.durationSeconds}s' : newEx.defaultReps,
                'durationSeconds': newEx.durationSeconds,
                'restSeconds': newEx.restSeconds,
              });
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("Added ${newEx.name} to this session"),
                backgroundColor: Colors.teal,
              ),
            );
          },
        ),
      ),
    );
  }

  // --- CONFIRMATION & EARLY FINISH ---
  void _confirmExitWorkout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Leave Workout?"),
        content: const Text(
          "Your current session progress will be lost if you exit without finishing. Are you sure you want to leave?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Resume Workout"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx); // Close dialog
              Navigator.pop(context); // Close ActiveWorkoutPage
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            child: const Text("Leave Session"),
          ),
        ],
      ),
    );
  }

  void _requestFinishWorkout() {
    _saveCurrentExerciseData();

    // Calculate total completed sets & exercises
    int totalCompletedSets = 0;
    for (final ex in _allCompletedExercises) {
      final sets = ex['sets'] as List<dynamic>? ?? [];
      totalCompletedSets += sets.length;
    }

    if (totalCompletedSets == 0 && !_isCardioCompleted) {
      showDialog(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text("Discard Session?"),
          content: const Text("No completed sets or cardio logged. Do you want to cancel this workout session?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text("Continue Workout"),
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

    // Check if workout is unfinished
    final int completedCount = _allCompletedExercises.length;
    final int totalCount = _activeRoutine.length;
    final bool hasRemainingInCurrent = !_isCurrentExerciseCardio() && _currentSets.any((s) => s['done'] != true);
    final bool isEarly = completedCount < totalCount || hasRemainingInCurrent;

    if (isEarly) {
      showDialog(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text("Finish Workout?"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("You still have remaining exercises or sets.", style: TextStyle(color: Colors.black87, fontSize: 13)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Completed: $completedCount of $totalCount exercises",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Total Sets Logged: $totalCompletedSets",
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text("Continue Workout"),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(c);
                _persistAndShowSummary();
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
              child: const Text("Finish Anyway"),
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
    _cardioTimer?.cancel();

    int totalSets = 0;
    int totalReps = 0;
    double totalVolume = 0.0;
    int totalCardioDurationSeconds = 0;

    for (final ex in _allCompletedExercises) {
      final isCardioOrTimed = ex['type'] == 'cardio' || ex['type'] == 'timed';
      if (isCardioOrTimed) {
        totalCardioDurationSeconds += (ex['durationSeconds'] as num?)?.toInt() ?? 0;
      }
      final sets = ex['sets'] as List<dynamic>? ?? [];
      for (final s in sets) {
        if (s is Map) {
          totalSets++;
          if (s.containsKey('reps')) {
            final reps = (s['reps'] as num?)?.toInt() ?? 0;
            totalReps += reps;
            if (s.containsKey('weight')) {
              final weight = (s['weight'] as num?)?.toDouble() ?? 0.0;
              if (weight > 0) {
                totalVolume += (weight * reps);
              }
            }
          }
        }
      }
    }

    // Save session log to Firestore
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
          'cardioDurationSeconds': totalCardioDurationSeconds,
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
                        _buildSummaryItem("DURATION", _formatTime(_sessionSeconds), Icons.timer_outlined, Colors.teal),
                        _buildSummaryItem("EST. BURN", "$_estimatedCalories kcal", Icons.local_fire_department_outlined, Colors.deepOrange),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Divider(height: 1),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildSummaryItem(
                          "EXERCISES",
                          "${_allCompletedExercises.length} / ${_activeRoutine.length}",
                          Icons.fitness_center_rounded,
                          Colors.blueAccent,
                        ),
                        if (totalVolume > 0)
                          _buildSummaryItem(
                            "VOLUME",
                            "${totalVolume.toStringAsFixed(0)} ${_isMetric ? 'kg' : 'lbs'}",
                            Icons.trending_up_rounded,
                            Colors.purple,
                          )
                        else if (totalCardioDurationSeconds > 0)
                          _buildSummaryItem(
                            "CARDIO",
                            "${(totalCardioDurationSeconds / 60).round()} min",
                            Icons.directions_run_rounded,
                            Colors.purple,
                          )
                        else
                          _buildSummaryItem(
                            "SETS / REPS",
                            "$totalSets / $totalReps",
                            Icons.repeat_rounded,
                            Colors.purple,
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text("Return to Workout Hub", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade500)),
      ],
    );
  }

  // --- MAIN BUILD ---
  @override
  Widget build(BuildContext context) {
    final currentEx = _activeRoutine.isNotEmpty ? _activeRoutine[_currentIndex] : <String, dynamic>{};
    final isCardio = _isCurrentExerciseCardio();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _confirmExitWorkout();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.black87),
            tooltip: "Leave Workout",
            onPressed: _confirmExitWorkout,
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.workoutName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.black87, fontSize: 14, fontWeight: FontWeight.bold),
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.timer_outlined, size: 12, color: Colors.teal),
                    const SizedBox(width: 4),
                    Text(
                      _formatTime(_sessionSeconds),
                      style: const TextStyle(fontSize: 11, color: Colors.teal, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 6),
                    Text("•", style: TextStyle(color: Colors.grey.shade400)),
                    const SizedBox(width: 6),
                    Text(
                      "Ex ${_currentIndex + 1} of ${_activeRoutine.length}",
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ],
          ),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.add_circle_outline, color: Colors.teal),
              tooltip: "Add Exercise to Session",
              onPressed: _addExerciseToSession,
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(4),
            child: LinearProgressIndicator(
              value: _overallCompletionProgress,
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Exercise Header Card
                  _buildExerciseHeaderCard(currentEx),

                  // 2. Main Exercise Interface: Cardio vs Strength/Bodyweight
                  if (isCardio)
                    _buildCardioActivityCard(currentEx)
                  else
                    _buildSetsTrackerCard(),

                  // 3. Notes Section
                  _buildNotesCard(),
                ],
              ),
            ),

            // 4. Interactive Rest Timer Docked Card (when active or finished)
            if (_isResting || _restFinished)
              _buildRestTimerDock(),
          ],
        ),
        bottomNavigationBar: _buildBottomActionBar(),
      ),
    );
  }

  // --- SUB-WIDGETS ---

  Widget _buildExerciseHeaderCard(Map<String, dynamic> currentEx) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                      runSpacing: 4,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.teal.shade50,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            currentEx['target'] ?? 'Muscle',
                            style: TextStyle(fontSize: 11, color: Colors.teal.shade700, fontWeight: FontWeight.bold),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            currentEx['equipment'] ?? 'Equipment',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _currentTrackingType().color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: _currentTrackingType().color.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(_currentTrackingType().icon, size: 11, color: _currentTrackingType().color),
                              const SizedBox(width: 3),
                              Text(
                                _currentTrackingType().displayName,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: _currentTrackingType().color,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton.icon(
                    onPressed: _replaceCurrentExercise,
                    icon: const Icon(Icons.swap_horiz, size: 15),
                    label: const Text("Replace", style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.teal,
                      side: const BorderSide(color: Colors.teal),
                      visualDensity: VisualDensity.compact,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    icon: const Icon(Icons.skip_next_rounded, color: Colors.grey),
                    tooltip: "Skip Exercise",
                    onPressed: _skipExercise,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- CARDIO ACTIVITY CARD ---
  Widget _buildCardioActivityCard(Map<String, dynamic> currentEx) {
    final int displaySeconds = _cardioElapsedSeconds > 0 ? _cardioElapsedSeconds : _cardioTargetSeconds;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.directions_run_rounded, color: Colors.teal, size: 24),
              const SizedBox(width: 8),
              Text(
                "Timed Activity",
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            "Target: ${_formatTime(_cardioTargetSeconds)}",
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 16),

          // Big Duration Display
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              _formatTime(displaySeconds),
              style: const TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 2,
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Cardio Action Controls (Start / Pause / Reset)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: _toggleCardioTimer,
                icon: Icon(_isCardioRunning ? Icons.pause_rounded : Icons.play_arrow_rounded),
                label: Text(_isCardioRunning ? "Pause" : "Start"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isCardioRunning ? Colors.amber.shade700 : Colors.teal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: _cardioElapsedSeconds > 0 ? _resetCardioTimer : null,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text("Reset"),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Complete Activity Button
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              onPressed: _isCardioCompleted ? null : _completeCardioActivity,
              icon: Icon(_isCardioCompleted ? Icons.check_circle : Icons.done_all_rounded),
              label: Text(
                _isCardioCompleted ? "Activity Completed ✓" : "Complete Activity",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isCardioCompleted ? Colors.grey.shade400 : Colors.teal.shade700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- STRENGTH / REPS / TIMED SETS CARD ---
  Widget _buildSetsTrackerCard() {
    final trackingType = _currentTrackingType();
    final bool isTimed = trackingType == ExerciseTrackingType.timed;
    final bool isReps = trackingType == ExerciseTrackingType.reps;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                const SizedBox(
                  width: 32,
                  child: Text("SET", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    "TARGET",
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
                  ),
                ),
                if (!isTimed && !isReps) // Only Strength exercises show weight column
                  Expanded(
                    flex: 2,
                    child: Text(
                      _isMetric ? "WEIGHT (KG)" : "WEIGHT (LBS)",
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
                    ),
                  ),
                Expanded(
                  flex: 2,
                  child: Text(
                    isTimed ? "HOLD TIME (SEC)" : "ACTUAL REPS",
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Set Rows with Explicit "Complete Set" Action
          ...List.generate(_currentSets.length, (idx) {
            final set = _currentSets[idx];
            final bool isDone = set['done'] == true;

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isDone ? Colors.teal.shade50.withValues(alpha: 0.5) : Colors.white,
                border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Set Number Badge
                      Container(
                        width: 28,
                        height: 28,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isDone ? Colors.teal : Colors.grey.shade200,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          "${set['set']}",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isDone ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),

                      // Target Display
                      Expanded(
                        flex: 2,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isTimed
                                  ? "${set['targetDuration']}s hold"
                                  : "${set['targetReps'] ?? 10} reps",
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                            ),
                          ),
                        ),
                      ),

                      // Weight Input Box (Only for Strength)
                      if (!isTimed && !isReps)
                        Expanded(
                          flex: 2,
                          child: Container(
                            height: 38,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            child: TextFormField(
                              initialValue: (set['weight'] ?? "20").toString(),
                              textAlign: TextAlign.center,
                              enabled: !isDone,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
                              onChanged: (val) => set['weight'] = val,
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: isDone ? Colors.grey.shade100 : Colors.grey.shade50,
                                contentPadding: EdgeInsets.zero,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.teal, width: 1.5)),
                              ),
                            ),
                          ),
                        ),

                      // Reps or Hold Time Completed Input Box
                      Expanded(
                        flex: 2,
                        child: Container(
                          height: 38,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          child: TextFormField(
                            initialValue: isTimed
                                ? (set['duration'] ?? set['targetDuration'] ?? 45).toString()
                                : (set['reps'] ?? 10).toString(),
                            textAlign: TextAlign.center,
                            enabled: !isDone,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
                            onChanged: (val) {
                              if (isTimed) {
                                set['duration'] = val;
                              } else {
                                set['reps'] = val;
                              }
                            },
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: isDone ? Colors.grey.shade100 : Colors.grey.shade50,
                              contentPadding: EdgeInsets.zero,
                              suffixText: isTimed ? "s" : null,
                              suffixStyle: const TextStyle(fontSize: 11, color: Colors.grey),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.teal, width: 1.5)),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Explicit "Complete Set" Button Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (isDone) ...[
                        Row(
                          children: [
                            const Icon(Icons.check_circle_rounded, color: Colors.teal, size: 18),
                            const SizedBox(width: 4),
                            Text(
                              "Set ${set['set']} completed ✓",
                              style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                            const SizedBox(width: 8),
                            TextButton(
                              onPressed: () => _uncompleteSet(idx),
                              child: const Text("Edit", style: TextStyle(fontSize: 11, color: Colors.grey)),
                            ),
                          ],
                        ),
                      ] else ...[
                        SizedBox(
                          height: 34,
                          child: ElevatedButton.icon(
                            onPressed: () => _completeSet(idx),
                            icon: const Icon(Icons.check_rounded, size: 16),
                            label: Text(
                              "Complete Set ${set['set']}",
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal,
                              foregroundColor: Colors.white,
                              elevation: 1,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                      ],
                    ],
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
                  "+ Add Set",
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

  // --- REST TIMER DOCK ---
  Widget _buildRestTimerDock() {
    double restProgress = _totalRestTarget > 0 ? (_restSeconds / _totalRestTarget).clamp(0.0, 1.0) : 0.0;

    return Positioned(
      bottom: 12,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
          border: Border.all(color: _restFinished ? Colors.amberAccent : Colors.teal.shade400, width: 1.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_restFinished) ...[
              // Prompt when rest finishes
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.notifications_active_rounded, color: Colors.amberAccent, size: 22),
                      const SizedBox(width: 8),
                      Text(
                        "Ready for Set $_nextSetNumber! 🔔",
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ],
                  ),
                  ElevatedButton(
                    onPressed: _skipRest,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amberAccent,
                      foregroundColor: Colors.black87,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    ),
                    child: const Text("Start Next Set", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ],
              ),
            ] else ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.timelapse_rounded, color: Colors.tealAccent, size: 22),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("REST", style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
                          Text(
                            _formatTime(_restSeconds),
                            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // Controls: [-10s], [Skip Rest], [+10s]
                  Row(
                    children: [
                      _buildRestAdjustBtn("-10s", -10),
                      const SizedBox(width: 6),
                      ElevatedButton(
                        onPressed: _skipRest,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.tealAccent,
                          foregroundColor: Colors.black87,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text("Skip Rest", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                      const SizedBox(width: 6),
                      _buildRestAdjustBtn("+10s", 10),
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
          ],
        ),
      ),
    );
  }

  Widget _buildRestAdjustBtn(String label, int seconds) {
    return InkWell(
      onTap: () => _adjustRestTime(seconds),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
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

  Widget _buildNotesCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: TextField(
        controller: _noteController,
        maxLines: 2,
        decoration: const InputDecoration(
          hintText: "Add personal notes or form tips for this exercise...",
          hintStyle: TextStyle(fontSize: 12, color: Colors.grey),
          border: InputBorder.none,
          prefixIcon: Icon(Icons.edit_outlined, size: 18, color: Colors.grey),
        ),
        style: const TextStyle(fontSize: 13),
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
      child: SafeArea(
        top: false,
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
      ),
    );
  }
}