import 'package:flutter/material.dart';

enum FitnessLevel { beginner, intermediate, advanced }

enum UserGoalTag { weightLoss, muscleGain, maintenance, endurance }

extension FitnessLevelExtension on FitnessLevel {
  String get displayName {
    switch (this) {
      case FitnessLevel.beginner:
        return 'Beginner';
      case FitnessLevel.intermediate:
        return 'Intermediate';
      case FitnessLevel.advanced:
        return 'Advanced';
    }
  }

  Color get badgeColor {
    switch (this) {
      case FitnessLevel.beginner:
        return Colors.green;
      case FitnessLevel.intermediate:
        return Colors.orange;
      case FitnessLevel.advanced:
        return Colors.purple;
    }
  }
}

extension UserGoalTagExtension on UserGoalTag {
  String get displayName {
    switch (this) {
      case UserGoalTag.weightLoss:
        return 'Weight Loss';
      case UserGoalTag.muscleGain:
        return 'Muscle Gain';
      case UserGoalTag.maintenance:
        return 'Maintenance';
      case UserGoalTag.endurance:
        return 'Endurance';
    }
  }

  Color get tagColor {
    switch (this) {
      case UserGoalTag.weightLoss:
        return const Color(0xFFEF4444);
      case UserGoalTag.muscleGain:
        return const Color(0xFF3B82F6);
      case UserGoalTag.maintenance:
        return const Color(0xFF10B981);
      case UserGoalTag.endurance:
        return const Color(0xFFF59E0B);
    }
  }
}

// ─── Safe numeric parsing helpers ────────────────────────────────────────────
// Use these EVERYWHERE instead of (value as num?) to handle String / int / double / null safely.

/// Parses dynamic → double. Returns 0.0 if null or unparseable.
double _parseDouble(dynamic value) {
  if (value == null) return 0.0;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? 0.0;
}

/// Parses dynamic → int. Returns 0 if null or unparseable.
int _parseInt(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString().split('.').first) ?? 0;
}

/// Parses dynamic → double?, returns null if value is null or unparseable.
// ignore: unused_element
double? _parseDoubleOrNull(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

/// Parses dynamic → int?, returns null if value is null or unparseable.
int? _parseIntOrNull(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString().split('.').first);
}
// ─────────────────────────────────────────────────────────────────────────────

class ExerciseModel {
  final String id;
  final String name;
  final String targetMuscle;
  final String equipment;
  final FitnessLevel difficulty;
  final int defaultSets;
  final int defaultReps;
  final int restSeconds;
  final String? gifUrl;
  final List<String> instructions;
  final List<String> secondaryMuscles;
  final List<String> alternativeIds;

  const ExerciseModel({
    required this.id,
    required this.name,
    required this.targetMuscle,
    required this.equipment,
    this.difficulty = FitnessLevel.beginner,
    this.defaultSets = 3,
    this.defaultReps = 12,
    this.restSeconds = 60,
    this.gifUrl,
    this.instructions = const [],
    this.secondaryMuscles = const [],
    this.alternativeIds = const [],
  });

  factory ExerciseModel.fromJson(Map<String, dynamic> json) {
    final rawInstructions = json['instructions'];
    List<String> parsedInstructions = [];
    if (rawInstructions is List) {
      parsedInstructions = rawInstructions.map((e) => e.toString()).toList();
    } else if (rawInstructions is String && rawInstructions.isNotEmpty) {
      parsedInstructions = [rawInstructions];
    }

    final rawSecondary = json['secondaryMuscles'];
    List<String> parsedSecondary = [];
    if (rawSecondary is List) {
      parsedSecondary = rawSecondary.map((e) => e.toString()).toList();
    }

    final rawAlternatives = json['alternativeIds'];
    List<String> parsedAlternatives = [];
    if (rawAlternatives is List) {
      parsedAlternatives = rawAlternatives.map((e) => e.toString()).toList();
    }

    // FIX: json['sets'] can be "3 sets x 10 reps" (String from AI), or 3 (int), or null.
    // Only parse it as a number if it is actually a numeric value.
    final rawSets = json['sets'];
    final int parsedSets;
    if (rawSets is num) {
      parsedSets = rawSets.toInt();
    } else if (rawSets is String) {
      // Try to extract leading integer (e.g. "3 sets x 10 reps" → 3)
      final match = RegExp(r'^\s*(\d+)').firstMatch(rawSets);
      parsedSets = match != null ? (int.tryParse(match.group(1)!) ?? 3) : 3;
    } else {
      parsedSets = 3;
    }

    final rawReps = json['reps'];
    final int parsedReps;
    if (rawReps is num) {
      parsedReps = rawReps.toInt();
    } else if (rawReps is String) {
      final match = RegExp(r'(\d+)').firstMatch(rawReps);
      parsedReps = match != null ? (int.tryParse(match.group(1)!) ?? 12) : 12;
    } else {
      parsedReps = 12;
    }

    return ExerciseModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Exercise',
      targetMuscle: json['target']?.toString() ?? json['targetMuscle']?.toString() ?? json['bodyPart']?.toString() ?? 'General',
      equipment: json['equipment']?.toString() ?? 'Bodyweight',
      defaultSets: parsedSets,
      defaultReps: parsedReps,
      restSeconds: _parseInt(json['restSeconds'] ?? 60),
      gifUrl: json['gifUrl']?.toString() ?? json['gif_url']?.toString(),
      instructions: parsedInstructions,
      secondaryMuscles: parsedSecondary,
      alternativeIds: parsedAlternatives,
    );
  }
}

class WorkoutRoutine {
  final String id;
  final String title;
  final String subtitle;
  final FitnessLevel level;
  final UserGoalTag goal;
  final int durationMinutes;
  final int estimatedCalories;
  final List<ExerciseModel> exercises;
  final String category;
  final String? bannerImageUrl;
  final bool isAiGenerated;
  final double aiMatchScore;

  const WorkoutRoutine({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.level,
    required this.goal,
    required this.durationMinutes,
    required this.estimatedCalories,
    required this.exercises,
    this.category = 'Full Body',
    this.bannerImageUrl,
    this.isAiGenerated = false,
    this.aiMatchScore = 0.95,
  });

  factory WorkoutRoutine.fromFirestore(String id, Map<String, dynamic> data) {
    final String title = data['name'] ?? data['routineName'] ?? 'Workout Routine';
    final String rawLevel = (data['fitnessLevel'] ?? data['level'] ?? 'Beginner').toString().toLowerCase();
    FitnessLevel level = FitnessLevel.beginner;
    if (rawLevel.contains('inter')) {
      level = FitnessLevel.intermediate;
    } else if (rawLevel.contains('adv')) {
      level = FitnessLevel.advanced;
    }

    final String rawGoal = (data['fitnessGoal'] ?? data['goal'] ?? 'Maintenance').toString().toLowerCase();
    UserGoalTag goal = UserGoalTag.maintenance;
    if (rawGoal.contains('loss') || rawGoal.contains('fat')) {
      goal = UserGoalTag.weightLoss;
    } else if (rawGoal.contains('gain') || rawGoal.contains('muscle') || rawGoal.contains('bulk')) {
      goal = UserGoalTag.muscleGain;
    } else if (rawGoal.contains('endur') || rawGoal.contains('cardio') || rawGoal.contains('stamina')) {
      goal = UserGoalTag.endurance;
    }

    final String category = data['category'] ?? 'Full Body';
    final List<dynamic> rawExList = data['exercises'] ?? [];
    final List<ExerciseModel> exercises = rawExList.map((e) {
      if (e is Map<String, dynamic>) {
        return ExerciseModel.fromJson(e);
      } else if (e is Map) {
        return ExerciseModel.fromJson(Map<String, dynamic>.from(e));
      }
      return ExerciseModel(id: '', name: e.toString(), targetMuscle: category, equipment: 'Bodyweight');
    }).toList();

    final int duration = _parseIntOrNull(data['durationMinutes']) ??
        (exercises.isNotEmpty ? (exercises.length * 4).clamp(15, 60) : 30);
    final int calories = _parseIntOrNull(data['estimatedCalories']) ??
        (exercises.isNotEmpty ? (exercises.length * 35).clamp(100, 500) : 220);

    return WorkoutRoutine(
      id: id,
      title: title,
      subtitle: data['subtitle'] ?? '${exercises.length} exercises • $category',
      level: level,
      goal: goal,
      durationMinutes: duration,
      estimatedCalories: calories,
      exercises: exercises,
      category: category,
      bannerImageUrl: data['imageUrl'] ?? data['image'],
      isAiGenerated: (data['source'] == 'ai_generated'),
      aiMatchScore: _parseDouble(data['aiMatchScore'] ?? 0.95),
    );
  }
}

class StreakSummary {
  final int currentStreakDays;
  final int bestStreakDays;
  final int weeklyCompletedDays;
  final int weeklyGoalDays;
  final List<bool> pastWeekActiveDays; // 7 days (Mon-Sun)
  final List<MilestoneBadge> badges;

  const StreakSummary({
    required this.currentStreakDays,
    required this.bestStreakDays,
    required this.weeklyCompletedDays,
    required this.weeklyGoalDays,
    required this.pastWeekActiveDays,
    required this.badges,
  });

  double get weeklyProgress => (weeklyCompletedDays / weeklyGoalDays).clamp(0.0, 1.0);
}

class MilestoneBadge {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final bool isUnlocked;

  const MilestoneBadge({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    this.isUnlocked = false,
  });
}

class WorkoutAnalyticsSummary {
  final double totalVolumeKg;
  final int totalWorkoutsCompleted;
  final double totalActiveHours;
  final int totalCaloriesBurned;
  final double volumeGrowthPercentage;

  const WorkoutAnalyticsSummary({
    required this.totalVolumeKg,
    required this.totalWorkoutsCompleted,
    required this.totalActiveHours,
    required this.totalCaloriesBurned,
    this.volumeGrowthPercentage = 12.5,
  });
}

class CompletedSetLog {
  final int setNumber;
  final double weightKg;
  final int reps;
  final bool isPersonalRecord;

  const CompletedSetLog({
    required this.setNumber,
    required this.weightKg,
    required this.reps,
    this.isPersonalRecord = false,
  });
}

class CompletedExerciseLog {
  final String exerciseName;
  final String targetMuscle;
  final List<CompletedSetLog> sets;
  final bool hasPersonalRecord;

  const CompletedExerciseLog({
    required this.exerciseName,
    required this.targetMuscle,
    required this.sets,
    this.hasPersonalRecord = false,
  });

  double get totalVolume => sets.fold(0.0, (acc, s) => acc + (s.weightKg * s.reps));
}

class WorkoutHistorySession {
  final String id;
  final String routineName;
  final DateTime date;
  final int durationMinutes;
  final int caloriesBurned;
  final List<CompletedExerciseLog> exercises;
  final List<String> prBadges;

  const WorkoutHistorySession({
    required this.id,
    required this.routineName,
    required this.date,
    required this.durationMinutes,
    required this.caloriesBurned,
    required this.exercises,
    this.prBadges = const [],
  });

  int get totalSets => exercises.fold(0, (acc, ex) => acc + ex.sets.length);
  double get totalVolumeKg => exercises.fold(0.0, (acc, ex) => acc + ex.totalVolume);

  factory WorkoutHistorySession.fromFirestore(String id, Map<String, dynamic> data) {
    final String routineName = (data['routineName'] ?? data['workoutName'] ?? data['name'] ?? 'Workout Session').toString();
    final dynamic rawTs = data['completedAt'] ?? data['timestamp'] ?? data['createdAt'] ?? data['startedAt'];
    DateTime date = DateTime.now();
    if (rawTs != null) {
      if (rawTs is DateTime) {
        date = rawTs;
      } else {
        try {
          date = rawTs.toDate();
        } catch (_) {
          if (rawTs is String) {
            date = DateTime.tryParse(rawTs) ?? DateTime.now();
          }
        }
      }
    }

    final int durationSeconds = _parseInt(data['durationSeconds']);
    final int durationMinutes = durationSeconds > 0
        ? (durationSeconds / 60).round()
        : (_parseIntOrNull(data['durationMinutes']) ?? 30);

    // FIX: caloriesBurned may arrive as String ("250") or int (250) or double (250.0)
    final int calories = _parseInt(data['caloriesBurned'] ?? data['calories']);

    final List<dynamic> rawExercises = data['exercises'] is List ? data['exercises'] : [];
    final List<CompletedExerciseLog> exercises = rawExercises.map((e) {
      if (e is Map) {
        final String exName = (e['name'] ?? e['exerciseName'] ?? 'Exercise').toString();
        final String target = (e['target'] ?? e['targetMuscle'] ?? e['category'] ?? 'General').toString();

        // FIX: e['sets'] can be a String like "3 sets x 10 reps" (from AI routines).
        // Only treat it as a list if it actually IS a list.
        final rawSets = e['sets'];
        final List<dynamic> setsList = rawSets is List ? rawSets : [];

        final List<CompletedSetLog> sets = setsList.asMap().entries.map((entry) {
          final setIdx = entry.key + 1;
          final s = entry.value;
          if (s is Map) {
            // FIX: weight may be String "60" or num 60 — use safe parser
            final double weight = _parseDouble(s['weight'] ?? s['weightKg']);
            final int reps = _parseInt(s['reps'] ?? 10);
            final bool isPR = (s['isPR'] ?? s['isPersonalRecord'] ?? false) == true;
            final int setNum = _parseIntOrNull(s['setNumber']) ?? setIdx;
            return CompletedSetLog(setNumber: setNum, weightKg: weight, reps: reps, isPersonalRecord: isPR);
          }
          return CompletedSetLog(setNumber: setIdx, weightKg: 0.0, reps: 10);
        }).toList();

        final bool hasPR = sets.any((s) => s.isPersonalRecord);
        return CompletedExerciseLog(
          exerciseName: exName,
          targetMuscle: target,
          sets: sets.isEmpty ? [const CompletedSetLog(setNumber: 1, weightKg: 0, reps: 10)] : sets,
          hasPersonalRecord: hasPR,
        );
      }
      return CompletedExerciseLog(
        exerciseName: e.toString(),
        targetMuscle: 'General',
        sets: const [CompletedSetLog(setNumber: 1, weightKg: 0, reps: 10)],
      );
    }).toList();

    final List<String> prBadges = [];
    for (var ex in exercises) {
      if (ex.hasPersonalRecord) {
        prBadges.add("PR: ${ex.exerciseName}");
      }
    }

    return WorkoutHistorySession(
      id: id,
      routineName: routineName,
      date: date,
      durationMinutes: durationMinutes,
      caloriesBurned: calories,
      exercises: exercises,
      prBadges: prBadges,
    );
  }
}
