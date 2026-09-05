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

enum ExerciseTrackingType {
  strength, // Weighted resistance exercises (sets, reps, weight, restSeconds)
  reps,     // Bodyweight / calisthenics (sets, reps, restSeconds, no mandatory weight)
  timed,    // Isometric holds (sets, durationSeconds, restSeconds)
  cardio,   // Aerobic / cardio (durationSeconds, optional distance/intervals)
}

extension ExerciseTrackingTypeExtension on ExerciseTrackingType {
  String get displayName {
    switch (this) {
      case ExerciseTrackingType.strength:
        return 'Strength';
      case ExerciseTrackingType.reps:
        return 'Bodyweight Reps';
      case ExerciseTrackingType.timed:
        return 'Timed Hold';
      case ExerciseTrackingType.cardio:
        return 'Cardio';
    }
  }

  Color get color {
    switch (this) {
      case ExerciseTrackingType.strength:
        return const Color(0xFF6366F1); // Indigo
      case ExerciseTrackingType.reps:
        return const Color(0xFF10B981); // Emerald
      case ExerciseTrackingType.timed:
        return const Color(0xFFF59E0B); // Amber
      case ExerciseTrackingType.cardio:
        return const Color(0xFFEC4899); // Pink / Rose
    }
  }

  IconData get icon {
    switch (this) {
      case ExerciseTrackingType.strength:
        return Icons.fitness_center_rounded;
      case ExerciseTrackingType.reps:
        return Icons.repeat_rounded;
      case ExerciseTrackingType.timed:
        return Icons.timer_outlined;
      case ExerciseTrackingType.cardio:
        return Icons.directions_run_rounded;
    }
  }
}

ExerciseTrackingType inferExerciseTrackingType({
  String? name,
  String? target,
  String? bodyPart,
  String? category,
  String? equipment,
  int? durationSeconds,
  String? repsOrDuration,
  String? reps,
  bool? isTimed,
}) {
  final n = (name ?? '').toLowerCase();
  final t = (target ?? category ?? bodyPart ?? '').toLowerCase();
  final eq = (equipment ?? '').toLowerCase();

  // 1. Explicit or keyword-based Cardio detection
  if (t == 'cardio' ||
      n.contains('air bike') ||
      n.contains('bike') ||
      n.contains('cycling') ||
      n.contains('running') ||
      n.contains('treadmill') ||
      n.contains('jogging') ||
      n.contains('rowing') ||
      n.contains('elliptical') ||
      n.contains('stairmaster') ||
      n.contains('jump rope') ||
      n.contains('skipping') ||
      n.contains('jumping jack') ||
      n.contains('burpee') ||
      n.contains('battle rope') ||
      n.contains('sprint')) {
    return ExerciseTrackingType.cardio;
  }

  // 2. Isometric / Timed Hold detection
  if (n.contains('plank') ||
      n.contains('wall sit') ||
      n.contains('dead hang') ||
      n.contains('hollow body') ||
      n.contains('l-sit') ||
      n.contains('static hold') ||
      n.contains('isometric') ||
      (durationSeconds != null && durationSeconds > 0 && !n.contains('bike') && !n.contains('run'))) {
    return ExerciseTrackingType.timed;
  }

  // 3. Bodyweight / Reps detection (Calisthenics / bodyweight)
  final isBodyweightEquip = eq.contains('body') || eq.contains('none') || eq.isEmpty;
  final isCalisthenicName = n.contains('push up') ||
      n.contains('push-up') ||
      n.contains('pull up') ||
      n.contains('pull-up') ||
      n.contains('chin up') ||
      n.contains('chin-up') ||
      n.contains('dip') ||
      n.contains('crunch') ||
      n.contains('sit up') ||
      n.contains('sit-up') ||
      n.contains('leg raise') ||
      n.contains('mountain climber') ||
      (n.contains('squat') && isBodyweightEquip && !n.contains('barbell') && !n.contains('dumbbell'));

  if (isBodyweightEquip || isCalisthenicName) {
    return ExerciseTrackingType.reps;
  }

  // 4. Default to Strength for resistance/weighted exercises
  return ExerciseTrackingType.strength;
}

class ExerciseModel {
  final String id;
  final String name;
  final String targetMuscle;
  final String equipment;
  final FitnessLevel difficulty;
  final int defaultSets;
  final int defaultReps;
  final int restSeconds;
  final int? durationSeconds;
  final ExerciseTrackingType trackingType;
  final String? gifUrl;
  final List<String> instructions;
  final List<String> secondaryMuscles;
  final List<String> alternativeIds;

  bool get isTimed => durationSeconds != null && durationSeconds! > 0;

  const ExerciseModel({
    required this.id,
    required this.name,
    required this.targetMuscle,
    required this.equipment,
    this.difficulty = FitnessLevel.beginner,
    this.defaultSets = 3,
    this.defaultReps = 12,
    this.restSeconds = 60,
    this.durationSeconds,
    this.trackingType = ExerciseTrackingType.strength,
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

    // Parse sets (e.g. 3, or "3 sets x 10 reps", or "3 sets x 45s")
    final rawSets = json['sets'];
    final int parsedSets;
    if (rawSets is num) {
      parsedSets = rawSets.toInt();
    } else if (rawSets is String) {
      final match = RegExp(r'^\s*(\d+)').firstMatch(rawSets);
      parsedSets = match != null ? (int.tryParse(match.group(1)!) ?? 3) : 3;
    } else {
      parsedSets = 3;
    }

    // Parse durationSeconds for cardio or timed isometric exercises (e.g. planks, jumping jacks)
    final rawDuration = json['durationSeconds'] ?? json['duration'];
    int? parsedDuration;
    if (rawDuration is num) {
      parsedDuration = rawDuration.toInt();
    } else if (rawDuration is String) {
      final match = RegExp(r'(\d+)').firstMatch(rawDuration);
      parsedDuration = match != null ? int.tryParse(match.group(1)!) : null;
    }

    // If duration not explicitly provided, extract from sets/reps string (e.g. "3 sets x 45s", "60 seconds", "10 min")
    if (parsedDuration == null && rawSets is String) {
      final secMatch = RegExp(r'(\d+)\s*(?:s|sec|seconds)\b', caseSensitive: false).firstMatch(rawSets);
      if (secMatch != null) {
        parsedDuration = int.tryParse(secMatch.group(1)!);
      } else {
        final minMatch = RegExp(r'(\d+)\s*(?:m|min|minutes)\b', caseSensitive: false).firstMatch(rawSets);
        if (minMatch != null) {
          parsedDuration = (int.tryParse(minMatch.group(1)!) ?? 0) * 60;
        }
      }
    }

    // Parse reps
    final rawReps = json['reps'];
    final int parsedReps;
    if (rawReps is num) {
      parsedReps = rawReps.toInt();
    } else if (rawReps is String) {
      final match = RegExp(r'(\d+)').firstMatch(rawReps);
      parsedReps = match != null ? (int.tryParse(match.group(1)!) ?? 12) : 12;
    } else if (parsedDuration != null && parsedDuration > 0) {
      // For pure timed exercises without specific repetition counts
      parsedReps = 0;
    } else {
      parsedReps = 12;
    }

    // Normalize target muscle (e.g. Abs, Waist, Abdominals -> Core)
    String rawTarget = json['target']?.toString() ?? json['targetMuscle']?.toString() ?? json['bodyPart']?.toString() ?? json['category']?.toString() ?? 'General';
    final lowerTarget = rawTarget.toLowerCase();
    if (lowerTarget == 'abs' || lowerTarget == 'waist' || lowerTarget == 'abdominals') {
      rawTarget = 'Core';
    }

    // Parse trackingType (or infer conservatively if missing)
    final rawTracking = json['trackingType']?.toString().toLowerCase();
    ExerciseTrackingType parsedType;
    if (rawTracking == 'cardio') {
      parsedType = ExerciseTrackingType.cardio;
    } else if (rawTracking == 'timed') {
      parsedType = ExerciseTrackingType.timed;
    } else if (rawTracking == 'reps') {
      parsedType = ExerciseTrackingType.reps;
    } else if (rawTracking == 'strength') {
      parsedType = ExerciseTrackingType.strength;
    } else {
      parsedType = inferExerciseTrackingType(
        name: json['name']?.toString() ?? json['exerciseName']?.toString(),
        target: rawTarget,
        category: json['category']?.toString(),
        bodyPart: json['bodyPart']?.toString(),
        equipment: json['equipment']?.toString(),
        durationSeconds: parsedDuration,
        repsOrDuration: rawReps?.toString(),
      );
    }

    return ExerciseModel(
      id: (json['id'] ?? json['exerciseId'] ?? '').toString().trim(),
      name: json['name']?.toString() ?? json['exerciseName']?.toString() ?? 'Exercise',
      targetMuscle: rawTarget,
      equipment: json['equipment']?.toString() ?? 'Bodyweight',
      defaultSets: parsedSets,
      defaultReps: parsedReps,
      durationSeconds: parsedDuration,
      restSeconds: _parseInt(json['restSeconds'] ?? 60),
      trackingType: parsedType,
      gifUrl: json['gifUrl']?.toString() ?? json['gif_url']?.toString(),
      instructions: parsedInstructions,
      secondaryMuscles: parsedSecondary,
      alternativeIds: parsedAlternatives,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'target': targetMuscle,
      'targetMuscle': targetMuscle,
      'equipment': equipment,
      'difficulty': difficulty.displayName,
      'sets': defaultSets,
      'reps': isTimed ? '${durationSeconds}s' : defaultReps,
      'defaultSets': defaultSets,
      'defaultReps': defaultReps,
      'restSeconds': restSeconds,
      'trackingType': trackingType.name,
      if (durationSeconds != null) 'durationSeconds': durationSeconds,
      if (gifUrl != null) 'gifUrl': gifUrl,
      if (instructions.isNotEmpty) 'instructions': instructions,
      if (secondaryMuscles.isNotEmpty) 'secondaryMuscles': secondaryMuscles,
      if (alternativeIds.isNotEmpty) 'alternativeIds': alternativeIds,
    };
  }

  Map<String, dynamic> toJson() => toMap();
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

  static String generateRoutineSignature({
    required String name,
    required String category,
    required String fitnessLevel,
    required List<String> exerciseNames,
  }) {
    final cleanName = name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    final cleanCategory = category.trim().toLowerCase();
    final cleanLevel = fitnessLevel.trim().toLowerCase();
    final cleanExercises = exerciseNames
        .map((e) => e.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' '))
        .where((e) => e.isNotEmpty)
        .toList();
    return '$cleanName|$cleanCategory|$cleanLevel|${cleanExercises.join(",")}';
  }

  String get signature => generateRoutineSignature(
        name: title,
        category: category,
        fitnessLevel: level.displayName,
        exerciseNames: exercises.map((e) => e.name).toList(),
      );

  /// Set of normalized unique exercise names for similarity comparison
  Set<String> get normalizedExerciseSet => exercises
      .map((e) => e.name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' '))
      .where((e) => e.isNotEmpty)
      .toSet();

  /// Calculates Jaccard similarity between two sets of exercises: |A ∩ B| / |A ∪ B|
  static double calculateExerciseSimilarity(Set<String> set1, Set<String> set2) {
    if (set1.isEmpty && set2.isEmpty) return 1.0;
    if (set1.isEmpty || set2.isEmpty) return 0.0;
    final intersection = set1.intersection(set2).length;
    final union = set1.union(set2).length;
    if (union == 0) return 0.0;
    return intersection / union;
  }

  /// Calculates exercise similarity score (0.0 to 1.0) with another routine.
  /// Considers broad category alignment and fitness level.
  double similarityWith(WorkoutRoutine other) {
    if (level != other.level) return 0.0;

    final cat1 = category.trim().toLowerCase();
    final cat2 = other.category.trim().toLowerCase();
    if (cat1 != cat2) {
      final isBothUpper = (cat1.contains('upper') || cat1.contains('chest') || cat1.contains('arm') || cat1.contains('back')) &&
                          (cat2.contains('upper') || cat2.contains('chest') || cat2.contains('arm') || cat2.contains('back'));
      final isBothLower = (cat1.contains('lower') || cat1.contains('leg')) &&
                          (cat2.contains('lower') || cat2.contains('leg'));
      final isBothCore = (cat1.contains('core') || cat1.contains('abs') || cat1.contains('waist')) &&
                         (cat2.contains('core') || cat2.contains('abs') || cat2.contains('waist'));
      final isBothCardio = (cat1.contains('cardio') || cat1.contains('hiit')) &&
                           (cat2.contains('cardio') || cat2.contains('hiit'));
      if (!isBothUpper && !isBothLower && !isBothCore && !isBothCardio) {
        return 0.0;
      }
    }

    return calculateExerciseSimilarity(normalizedExerciseSet, other.normalizedExerciseSet);
  }

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

  /// Returns the primary equipment requirement across the routine's exercises.
  String get primaryEquipment {
    if (exercises.isEmpty) return 'Bodyweight';
    final equipCounts = <String, int>{};
    for (final ex in exercises) {
      final eq = ex.equipment.trim();
      if (eq.isNotEmpty && eq.toLowerCase() != 'none') {
        equipCounts[eq] = (equipCounts[eq] ?? 0) + 1;
      }
    }
    if (equipCounts.isEmpty) return 'Bodyweight';
    final nonBodyweight = equipCounts.entries
        .where((e) => !e.key.toLowerCase().contains('bodyweight'))
        .toList();
    if (nonBodyweight.isNotEmpty) {
      nonBodyweight.sort((a, b) => b.value.compareTo(a.value));
      return nonBodyweight.first.key;
    }
    return 'Bodyweight';
  }

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

    String category = data['category']?.toString() ?? 'Full Body';
    final lowerCat = category.toLowerCase();
    if (lowerCat == 'abs' || lowerCat == 'waist' || lowerCat == 'abdominals') {
      category = 'Core';
    }

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

  Map<String, dynamic> toMap() {
    return {
      'name': title,
      'title': title,
      'subtitle': subtitle,
      'fitnessLevel': level.displayName,
      'fitnessGoal': goal.displayName,
      'durationMinutes': durationMinutes,
      'estimatedCalories': estimatedCalories,
      'category': category,
      'exercises': exercises.map((e) => e.toMap()).toList(),
      if (bannerImageUrl != null) 'imageUrl': bannerImageUrl,
      'source': isAiGenerated ? 'ai_generated' : 'custom',
      'aiMatchScore': aiMatchScore,
    };
  }
}

/// Represents a cluster of similar routines grouped together to avoid UI clutter
class RoutineCluster {
  final WorkoutRoutine primary;
  final List<WorkoutRoutine> variations;

  const RoutineCluster({
    required this.primary,
    this.variations = const [],
  });

  int get totalCount => 1 + variations.length;
  bool get hasVariations => variations.isNotEmpty;

  /// Groups a list of routines by similarity (similarity >= threshold, same category & level)
  static List<RoutineCluster> clusterRoutines(
    List<WorkoutRoutine> routines, {
    double similarityThreshold = 0.70,
  }) {
    final List<RoutineCluster> clusters = [];

    for (final routine in routines) {
      bool clustered = false;
      for (int i = 0; i < clusters.length; i++) {
        final currentCluster = clusters[i];
        if (currentCluster.primary.similarityWith(routine) >= similarityThreshold) {
          // If the new routine is more complete, make it primary
          if (routine.exercises.length > currentCluster.primary.exercises.length) {
            clusters[i] = RoutineCluster(
              primary: routine,
              variations: [...currentCluster.variations, currentCluster.primary],
            );
          } else {
            clusters[i] = RoutineCluster(
              primary: currentCluster.primary,
              variations: [...currentCluster.variations, routine],
            );
          }
          clustered = true;
          break;
        }
      }
      if (!clustered) {
        clusters.add(RoutineCluster(primary: routine));
      }
    }
    return clusters;
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

  Map<String, dynamic> toMap() => {
    'setNumber': setNumber,
    'weightKg': weightKg,
    'reps': reps,
    'isPersonalRecord': isPersonalRecord,
  };

  factory CompletedSetLog.fromMap(Map<String, dynamic> map) {
    return CompletedSetLog(
      setNumber: (map['setNumber'] as num?)?.toInt() ?? 1,
      weightKg: (map['weightKg'] as num?)?.toDouble() ?? 0.0,
      reps: (map['reps'] as num?)?.toInt() ?? 10,
      isPersonalRecord: (map['isPersonalRecord'] ?? map['isPR'] ?? false) == true,
    );
  }
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

  Map<String, dynamic> toMap() => {
    'exerciseName': exerciseName,
    'targetMuscle': targetMuscle,
    'hasPersonalRecord': hasPersonalRecord,
    'sets': sets.map((s) => s.toMap()).toList(),
  };

  factory CompletedExerciseLog.fromMap(Map<String, dynamic> map) {
    final rawSets = map['sets'] is List ? map['sets'] as List : [];
    return CompletedExerciseLog(
      exerciseName: (map['exerciseName'] ?? map['name'] ?? 'Exercise').toString(),
      targetMuscle: (map['targetMuscle'] ?? map['target'] ?? 'General').toString(),
      hasPersonalRecord: (map['hasPersonalRecord'] ?? false) == true,
      sets: rawSets.map((s) {
        if (s is Map) {
          return CompletedSetLog.fromMap(Map<String, dynamic>.from(s));
        }
        return const CompletedSetLog(setNumber: 1, weightKg: 0, reps: 10);
      }).toList(),
    );
  }
}

class WorkoutHistorySession {
  final String id;
  final String routineName;
  final String? category;
  final DateTime date;
  final int durationMinutes;
  final int caloriesBurned;
  final List<CompletedExerciseLog> exercises;
  final List<String> prBadges;
  final bool isExternal;
  final String? sourceName;
  final double? distanceKm;
  final bool isMerged;
  final bool hasCalories;

  const WorkoutHistorySession({
    required this.id,
    required this.routineName,
    this.category,
    required this.date,
    required this.durationMinutes,
    required this.caloriesBurned,
    required this.exercises,
    this.prBadges = const [],
    this.isExternal = false,
    this.sourceName,
    this.distanceKm,
    this.isMerged = false,
    this.hasCalories = true,
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
