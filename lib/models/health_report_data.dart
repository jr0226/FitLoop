import 'package:intl/intl.dart';

enum HealthReportPeriodType {
  last7Days,
  last30Days,
  custom,
}

extension HealthReportPeriodTypeExtension on HealthReportPeriodType {
  String get label {
    switch (this) {
      case HealthReportPeriodType.last7Days:
        return 'Last 7 Days';
      case HealthReportPeriodType.last30Days:
        return 'Last 30 Days';
      case HealthReportPeriodType.custom:
        return 'Custom Range';
    }
  }
}

/// Profile information displayed in the report overview.
/// Strictly excludes sensitive credentials, tokens, and internal Firestore IDs.
class UserProfileReportSummary {
  final String name;
  final String? email;
  final int age;
  final String gender;
  final double heightCm;
  final double currentWeightKg;
  final double targetWeightKg;
  final String fitnessGoal;
  final String fitnessLevel;
  final String activityLevel;
  final String dietPreference;
  final int calorieTarget;
  final bool isMetric;
  final int currentStreak;

  const UserProfileReportSummary({
    required this.name,
    this.email,
    required this.age,
    required this.gender,
    required this.heightCm,
    required this.currentWeightKg,
    required this.targetWeightKg,
    required this.fitnessGoal,
    required this.fitnessLevel,
    required this.activityLevel,
    this.dietPreference = 'Standard',
    required this.calorieTarget,
    required this.isMetric,
    required this.currentStreak,
  });

  String get weightUnit => isMetric ? 'kg' : 'lbs';
  String get heightUnit => isMetric ? 'cm' : 'in';

  double get displayCurrentWeight =>
      isMetric ? currentWeightKg : (currentWeightKg * 2.20462);

  double get displayTargetWeight =>
      isMetric ? targetWeightKg : (targetWeightKg * 2.20462);

  double get displayHeight =>
      isMetric ? heightCm : (heightCm * 0.393701);

  String get formattedCurrentWeight =>
      '${displayCurrentWeight.toStringAsFixed(1)} $weightUnit';

  String get formattedTargetWeight =>
      '${displayTargetWeight.toStringAsFixed(1)} $weightUnit';

  String get formattedHeight =>
      '${displayHeight.toStringAsFixed(1)} $heightUnit';

  /// Calculates progress relative to target weight using neutral, data-driven wording.
  String get goalProgressStatus {
    if (targetWeightKg <= 0 || currentWeightKg <= 0) {
      return 'Target weight not specified';
    }

    final diffKg = (currentWeightKg - targetWeightKg).abs();
    final displayDiff = isMetric ? diffKg : (diffKg * 2.20462);
    final diffFormatted = '${displayDiff.toStringAsFixed(1)} $weightUnit';

    if (diffKg < 0.25) {
      return 'Target weight reached';
    }

    if (currentWeightKg > targetWeightKg) {
      return '$diffFormatted above target';
    } else {
      return '$diffFormatted below target';
    }
  }
}

/// Compact representation of a single logged meal in the report diary.
class NutritionMealItem {
  final String name;
  final String mealType;
  final int calories;
  final double protein;
  final double carbs;
  final double fat;
  final double? score;
  final DateTime date;

  const NutritionMealItem({
    required this.name,
    required this.mealType,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.score,
    required this.date,
  });
}

/// Daily aggregated calories for trend visualization.
class NutritionDailyData {
  final DateTime date;
  final int totalCalories;

  const NutritionDailyData({
    required this.date,
    required this.totalCalories,
  });
}

/// Aggregated nutrition metrics over the report period.
class NutritionReportSummary {
  final int totalMealsLogged;
  final int daysWithLogs;
  final int totalCalories;
  final int avgDailyCalories;
  final double avgProtein;
  final double avgCarbs;
  final double avgFat;
  final double? avgMealScore;
  final int calorieTarget;
  final List<NutritionMealItem> recentMeals;
  final List<NutritionDailyData> dailyCalorieTrend;

  const NutritionReportSummary({
    required this.totalMealsLogged,
    required this.daysWithLogs,
    required this.totalCalories,
    required this.avgDailyCalories,
    required this.avgProtein,
    required this.avgCarbs,
    required this.avgFat,
    this.avgMealScore,
    required this.calorieTarget,
    this.recentMeals = const [],
    this.dailyCalorieTrend = const [],
  });

  bool get hasData => totalMealsLogged > 0;
}

/// Compact representation of a single completed workout in the history list.
class WorkoutSessionItem {
  final DateTime date;
  final String routineName;
  final int durationMinutes;
  final int caloriesBurned;
  final double totalVolumeKg;
  final int totalSets;
  final int totalReps;

  const WorkoutSessionItem({
    required this.date,
    required this.routineName,
    required this.durationMinutes,
    required this.caloriesBurned,
    required this.totalVolumeKg,
    required this.totalSets,
    required this.totalReps,
  });
}

/// Aggregated workout metrics over the report period.
class WorkoutReportSummary {
  final int totalWorkouts;
  final int totalDurationMinutes;
  final int avgDurationMinutes;
  final int totalCaloriesBurned;
  final int totalSets;
  final int totalReps;
  final double totalVolumeKg;
  final int activeWorkoutDays;
  final String? mostFrequentExercise;
  final double? maxWeightLiftedKg;
  final String? highestVolumeExercise;
  final List<WorkoutSessionItem> recentWorkouts;

  const WorkoutReportSummary({
    required this.totalWorkouts,
    required this.totalDurationMinutes,
    required this.avgDurationMinutes,
    required this.totalCaloriesBurned,
    required this.totalSets,
    required this.totalReps,
    required this.totalVolumeKg,
    required this.activeWorkoutDays,
    this.mostFrequentExercise,
    this.maxWeightLiftedKg,
    this.highestVolumeExercise,
    this.recentWorkouts = const [],
  });

  bool get hasData => totalWorkouts > 0;
}

/// Weight point for body trend charts.
class WeightDataPoint {
  final DateTime date;
  final double weightKg;

  const WeightDataPoint({
    required this.date,
    required this.weightKg,
  });
}

/// Aggregated body measurement progress metrics over the report period.
class BodyProgressReportSummary {
  final double? startWeightKg;
  final double? latestWeightKg;
  final double? weightDeltaKg; // latest - start
  final double targetWeightKg;
  final int totalMeasurementLogs;
  final double? startBodyFat;
  final double? latestBodyFat;
  final double? startWaistCm;
  final double? latestWaistCm;
  final List<WeightDataPoint> weightTrend;
  final bool isMetric;

  const BodyProgressReportSummary({
    this.startWeightKg,
    this.latestWeightKg,
    this.weightDeltaKg,
    required this.targetWeightKg,
    required this.totalMeasurementLogs,
    this.startBodyFat,
    this.latestBodyFat,
    this.startWaistCm,
    this.latestWaistCm,
    this.weightTrend = const [],
    required this.isMetric,
  });

  bool get hasData => totalMeasurementLogs > 0 || latestWeightKg != null;
  bool get hasWeightChange =>
      totalMeasurementLogs >= 2 &&
      startWeightKg != null &&
      latestWeightKg != null &&
      weightDeltaKg != null;
}

/// Unlocked achievement record.
class AchievementReportItem {
  final String title;
  final String description;
  final String category;
  final DateTime? unlockedAt;

  const AchievementReportItem({
    required this.title,
    required this.description,
    required this.category,
    this.unlockedAt,
  });
}

/// Top-level container holding all aggregated metrics for the report.
class HealthReportData {
  final UserProfileReportSummary userProfile;
  final NutritionReportSummary nutrition;
  final WorkoutReportSummary workout;
  final BodyProgressReportSummary bodyProgress;
  final List<AchievementReportItem> achievements;
  final DateTime startDate;
  final DateTime endDate;
  final DateTime generatedAt;
  final HealthReportPeriodType periodType;

  const HealthReportData({
    required this.userProfile,
    required this.nutrition,
    required this.workout,
    required this.bodyProgress,
    required this.achievements,
    required this.startDate,
    required this.endDate,
    required this.generatedAt,
    required this.periodType,
  });

  String get defaultFileName {
    final startStr = DateFormat('yyyy-MM-dd').format(startDate);
    final endStr = DateFormat('yyyy-MM-dd').format(endDate);
    return 'FitLoop_Report_${startStr}_to_$endStr.pdf';
  }
}
