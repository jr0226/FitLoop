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
    return ExerciseModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      targetMuscle: json['target'] ?? json['targetMuscle'] ?? 'General',
      equipment: json['equipment'] ?? 'Bodyweight',
      defaultSets: json['sets'] ?? 3,
      defaultReps: json['reps'] ?? 12,
      restSeconds: json['restSeconds'] ?? 60,
      gifUrl: json['gifUrl'],
      instructions: json['instructions'],
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
}

