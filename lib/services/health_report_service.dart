import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../models/health_report_data.dart';

/// Aggregates and normalizes Firestore data to generate a FitLoop Health & Fitness Report.
class HealthReportService {
  final FirebaseFirestore _firestore;

  HealthReportService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  static final HealthReportService instance = HealthReportService();

  /// Fetches real user profile, nutrition, workouts, measurements, and achievements,
  /// then calculates comprehensive summaries for the selected period.
  Future<HealthReportData> fetchReportData({
    required String uid,
    required DateTime startDate,
    required DateTime endDate,
    required HealthReportPeriodType periodType,
  }) async {
    final DateTime startOfDay =
        DateTime(startDate.year, startDate.month, startDate.day, 0, 0, 0);
    final DateTime endOfDay =
        DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59, 999);

    debugPrint('Fetching FitLoop report for user $uid from $startOfDay to $endOfDay');

    // 1. Fetch User Profile
    final userProfile = await _fetchUserProfile(uid);

    // 2. Fetch Nutrition Logs in Range
    final nutritionSummary = await _fetchNutritionSummary(
      uid: uid,
      startOfDay: startOfDay,
      endOfDay: endOfDay,
      calorieTarget: userProfile.calorieTarget,
    );

    // 3. Fetch Workout Logs in Range
    final workoutSummary = await _fetchWorkoutSummary(
      uid: uid,
      startOfDay: startOfDay,
      endOfDay: endOfDay,
    );

    // 4. Fetch Body Measurements in Range
    final bodyProgressSummary = await _fetchBodyProgressSummary(
      uid: uid,
      startOfDay: startOfDay,
      endOfDay: endOfDay,
      fallbackCurrentWeight: userProfile.currentWeightKg,
      targetWeightKg: userProfile.targetWeightKg,
      isMetric: userProfile.isMetric,
    );

    // 5. Fetch Unlocked Achievements
    final achievementsList = await _fetchAchievements(
      uid: uid,
      startOfDay: startOfDay,
      endOfDay: endOfDay,
    );

    return HealthReportData(
      userProfile: userProfile,
      nutrition: nutritionSummary,
      workout: workoutSummary,
      bodyProgress: bodyProgressSummary,
      achievements: achievementsList,
      startDate: startOfDay,
      endDate: endOfDay,
      generatedAt: DateTime.now(),
      periodType: periodType,
    );
  }

  // =========================================================================
  // 1. USER PROFILE
  // =========================================================================
  Future<UserProfileReportSummary> _fetchUserProfile(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      final data = doc.data() ?? {};

      final name = (data['name'] ?? 'Athlete').toString();
      final email = data['email']?.toString();
      final age = (data['age'] as num?)?.toInt() ?? 25;
      final gender = (data['gender'] ?? 'Not Specified').toString();
      final heightCm = (data['height'] as num?)?.toDouble() ?? 175.0;
      final currentWeightKg = (data['weight'] as num?)?.toDouble() ?? 70.0;
      final targetWeightKg = (data['targetWeight'] as num?)?.toDouble() ?? 70.0;

      final fitnessGoal =
          (data['fitnessGoal'] ?? data['goal'] ?? 'Maintenance').toString();
      final fitnessLevel =
          (data['fitnessLevel'] ?? data['level'] ?? 'Beginner').toString();
      final rawActivity =
          (data['activityLevel'] ?? 'Moderate').toString();
      final activityLevel = _normalizeActivity(rawActivity);
      final dietPreference =
          (data['dietPreference'] ?? 'Standard').toString();

      final calorieTarget = (data['calorieTarget'] ??
              data['dailyCaloriesTarget'] as num?)
          ?.toInt() ??
          2000;

      // Unit preference check
      bool isMetric = true;
      if (data['units'] is Map) {
        isMetric = (data['units']['isMetric'] != false);
      } else if (data['isMetric'] != null) {
        isMetric = (data['isMetric'] != false);
      }

      final currentStreak =
          (data['currentStreak'] ?? data['streak'] as num?)?.toInt() ?? 0;

      return UserProfileReportSummary(
        name: name,
        email: email,
        age: age,
        gender: gender,
        heightCm: heightCm,
        currentWeightKg: currentWeightKg,
        targetWeightKg: targetWeightKg,
        fitnessGoal: fitnessGoal,
        fitnessLevel: fitnessLevel,
        activityLevel: activityLevel,
        dietPreference: dietPreference,
        calorieTarget: calorieTarget,
        isMetric: isMetric,
        currentStreak: currentStreak,
      );
    } catch (e) {
      debugPrint('Error fetching user profile for report: $e');
      return const UserProfileReportSummary(
        name: 'Athlete',
        age: 25,
        gender: 'Not Specified',
        heightCm: 175.0,
        currentWeightKg: 70.0,
        targetWeightKg: 70.0,
        fitnessGoal: 'Maintenance',
        fitnessLevel: 'Beginner',
        activityLevel: 'Moderate',
        dietPreference: 'Standard',
        calorieTarget: 2000,
        isMetric: true,
        currentStreak: 0,
      );
    }
  }

  String _normalizeActivity(String raw) {
    final s = raw.trim().toLowerCase();
    if (s.contains('very') || s.contains('high')) return 'Very Active';
    if (s.contains('sedentary')) return 'Sedentary';
    if (s.contains('light')) return 'Light';
    if (s.contains('active')) return 'Active';
    return 'Moderate';
  }

  // =========================================================================
  // 2. NUTRITION SUMMARY
  // =========================================================================
  Future<NutritionReportSummary> _fetchNutritionSummary({
    required String uid,
    required DateTime startOfDay,
    required DateTime endOfDay,
    required int calorieTarget,
  }) async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('food_logs')
          .get();

      final List<NutritionMealItem> matchedMeals = [];
      final Map<String, int> dailyCaloriesMap = {};
      final Set<String> uniqueDays = {};

      int totalCalories = 0;
      double totalProtein = 0.0;
      double totalCarbs = 0.0;
      double totalFat = 0.0;
      double totalScore = 0.0;
      int scoredMealsCount = 0;

      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        final date = _parseDate(data['timestamp'] ?? data['createdAt']);
        if (date == null) continue;

        // Date range filter
        if (date.isBefore(startOfDay) || date.isAfter(endOfDay)) continue;

        final name = formatMealDescription(data);
        final mealType = (data['mealType'] ?? 'Snack').toString();
        final calories = (data['calories'] as num?)?.toInt() ?? 0;
        final protein =
            ((data['protein'] ?? data['proteins'] ?? 0) as num).toDouble();
        final carbs = ((data['carbs'] ?? 0) as num).toDouble();
        final fat = ((data['fat'] ?? data['fats'] ?? 0) as num).toDouble();

        final rawScore = data['mealScore'] ?? data['score'];
        final double? score =
            rawScore != null ? (rawScore as num).toDouble() : null;

        matchedMeals.add(NutritionMealItem(
          name: name,
          mealType: mealType,
          calories: calories,
          protein: protein,
          carbs: carbs,
          fat: fat,
          score: score,
          date: date,
        ));

        final dayKey = DateFormat('yyyy-MM-dd').format(date);
        uniqueDays.add(dayKey);
        dailyCaloriesMap[dayKey] = (dailyCaloriesMap[dayKey] ?? 0) + calories;

        totalCalories += calories;
        totalProtein += protein;
        totalCarbs += carbs;
        totalFat += fat;

        if (score != null && score > 0) {
          totalScore += score;
          scoredMealsCount++;
        }
      }

      // Sort meals descending (most recent first)
      matchedMeals.sort((a, b) => b.date.compareTo(a.date));

      final int daysCount = uniqueDays.isEmpty ? 0 : uniqueDays.length;
      final int avgDailyCalories =
          daysCount > 0 ? (totalCalories / daysCount).round() : 0;
      final double avgProtein =
          daysCount > 0 ? (totalProtein / daysCount) : 0.0;
      final double avgCarbs = daysCount > 0 ? (totalCarbs / daysCount) : 0.0;
      final double avgFat = daysCount > 0 ? (totalFat / daysCount) : 0.0;
      final double? avgMealScore = scoredMealsCount > 0
          ? (totalScore / scoredMealsCount)
          : null;

      // Construct daily trend series
      final List<NutritionDailyData> dailyTrend = [];
      DateTime cur = DateTime(startOfDay.year, startOfDay.month, startOfDay.day);
      while (!cur.isAfter(endOfDay)) {
        final key = DateFormat('yyyy-MM-dd').format(cur);
        dailyTrend.add(NutritionDailyData(
          date: cur,
          totalCalories: dailyCaloriesMap[key] ?? 0,
        ));
        cur = cur.add(const Duration(days: 1));
      }

      return NutritionReportSummary(
        totalMealsLogged: matchedMeals.length,
        daysWithLogs: daysCount,
        totalCalories: totalCalories,
        avgDailyCalories: avgDailyCalories,
        avgProtein: avgProtein,
        avgCarbs: avgCarbs,
        avgFat: avgFat,
        avgMealScore: avgMealScore,
        calorieTarget: calorieTarget,
        recentMeals: matchedMeals.take(15).toList(),
        dailyCalorieTrend: dailyTrend,
      );
    } catch (e) {
      debugPrint('Error fetching nutrition logs for report: $e');
      return NutritionReportSummary(
        totalMealsLogged: 0,
        daysWithLogs: 0,
        totalCalories: 0,
        avgDailyCalories: 0,
        avgProtein: 0,
        avgCarbs: 0,
        avgFat: 0,
        calorieTarget: calorieTarget,
      );
    }
  }

  /// Generates a readable meal description from foods[] components when available.
  /// Example:
  /// - 1 food: "Fried Chicken"
  /// - 2 foods: "Nasi Lemak, Fried Chicken"
  /// - 5 foods: "Rice, Chicken, Sambal + 2 more"
  /// Falls back to data['name'] if foods[] is missing or empty.
  static String formatMealDescription(Map<String, dynamic> data) {
    final rawFoods = data['foods'];
    final fallbackName = (data['name'] ?? 'Meal Log').toString().trim();

    if (rawFoods is List && rawFoods.isNotEmpty) {
      final List<String> foodNames = [];
      for (final item in rawFoods) {
        if (item is Map) {
          final n = (item['name'] ?? item['foodName'] ?? '').toString().trim();
          if (n.isNotEmpty && !foodNames.contains(n)) {
            foodNames.add(n);
          }
        } else if (item is String && item.trim().isNotEmpty) {
          final n = item.trim();
          if (!foodNames.contains(n)) {
            foodNames.add(n);
          }
        }
      }

      if (foodNames.length == 1) {
        return foodNames.first;
      } else if (foodNames.length > 1) {
        const int maxShown = 3;
        if (foodNames.length <= maxShown) {
          return foodNames.join(', ');
        } else {
          final shown = foodNames.take(maxShown).join(', ');
          final remaining = foodNames.length - maxShown;
          return '$shown + $remaining more';
        }
      }
    }

    return fallbackName;
  }

  // =========================================================================
  // 3. WORKOUT SUMMARY
  // =========================================================================
  Future<WorkoutReportSummary> _fetchWorkoutSummary({
    required String uid,
    required DateTime startOfDay,
    required DateTime endOfDay,
  }) async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('workout_logs')
          .get();

      final List<WorkoutSessionItem> matchedWorkouts = [];
      final Set<String> activeDays = {};
      final Map<String, int> exerciseFrequency = {};
      final Map<String, double> exerciseVolume = {};

      int totalDurationMinutes = 0;
      int totalCaloriesBurned = 0;
      int totalSets = 0;
      int totalReps = 0;
      double totalVolumeKg = 0.0;
      double maxWeightLiftedKg = 0.0;

      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        final date = _parseDate(
            data['completedAt'] ?? data['timestamp'] ?? data['createdAt']);
        if (date == null) continue;

        if (date.isBefore(startOfDay) || date.isAfter(endOfDay)) continue;

        final routineName = (data['routineName'] ??
                data['workoutName'] ??
                data['name'] ??
                'Workout Session')
            .toString();

        final rawDuration = data['durationMinutes'] ??
            ((data['durationSeconds'] as num?) != null
                ? (data['durationSeconds'] as num).toInt() ~/ 60
                : 0);
        final durationMinutes = (rawDuration as num?)?.toInt() ?? 0;

        final int caloriesBurned =
            ((data['caloriesBurned'] ?? data['calories']) as num?)?.toInt() ?? 0;

        // Parse exercises
        int sessionSets = 0;
        int sessionReps = 0;
        double sessionVolume = 0.0;

        if (data['exercises'] is List) {
          for (final ex in data['exercises'] as List) {
            if (ex is! Map) continue;
            final exName = (ex['exerciseName'] ?? ex['name'] ?? '').toString();
            if (exName.isNotEmpty) {
              exerciseFrequency[exName] =
                  (exerciseFrequency[exName] ?? 0) + 1;
            }

            if (ex['sets'] is List) {
              for (final set in ex['sets'] as List) {
                if (set is! Map) continue;
                sessionSets++;
                final weight =
                    ((set['weightKg'] ?? set['weight'] ?? 0) as num).toDouble();
                final reps = (set['reps'] as num?)?.toInt() ?? 0;

                sessionReps += reps;
                final setVol = weight * reps;
                sessionVolume += setVol;

                if (weight > maxWeightLiftedKg) {
                  maxWeightLiftedKg = weight;
                }

                if (exName.isNotEmpty) {
                  exerciseVolume[exName] =
                      (exerciseVolume[exName] ?? 0.0) + setVol;
                }
              }
            }
          }
        }

        // Top-level overrides if explicit
        final int docSets = (data['totalSets'] as num?)?.toInt() ?? sessionSets;
        final int docReps = (data['totalReps'] as num?)?.toInt() ?? sessionReps;
        final double docVolume =
            (data['totalVolume'] as num?)?.toDouble() ?? sessionVolume;

        matchedWorkouts.add(WorkoutSessionItem(
          date: date,
          routineName: routineName,
          durationMinutes: durationMinutes,
          caloriesBurned: caloriesBurned,
          totalVolumeKg: docVolume,
          totalSets: docSets,
          totalReps: docReps,
        ));

        final dayKey = DateFormat('yyyy-MM-dd').format(date);
        activeDays.add(dayKey);

        totalDurationMinutes += durationMinutes;
        totalCaloriesBurned += caloriesBurned;
        totalSets += docSets;
        totalReps += docReps;
        totalVolumeKg += docVolume;
      }

      // Sort workouts descending
      matchedWorkouts.sort((a, b) => b.date.compareTo(a.date));

      final int workoutsCount = matchedWorkouts.length;
      final int avgDuration = workoutsCount > 0
          ? (totalDurationMinutes / workoutsCount).round()
          : 0;

      // Find top exercises
      String? mostFrequentExercise;
      int highestFreq = 0;
      exerciseFrequency.forEach((name, freq) {
        if (freq > highestFreq) {
          highestFreq = freq;
          mostFrequentExercise = name;
        }
      });

      String? highestVolumeExercise;
      double highestVol = 0.0;
      exerciseVolume.forEach((name, vol) {
        if (vol > highestVol) {
          highestVol = vol;
          highestVolumeExercise = name;
        }
      });

      return WorkoutReportSummary(
        totalWorkouts: workoutsCount,
        totalDurationMinutes: totalDurationMinutes,
        avgDurationMinutes: avgDuration,
        totalCaloriesBurned: totalCaloriesBurned,
        totalSets: totalSets,
        totalReps: totalReps,
        totalVolumeKg: totalVolumeKg,
        activeWorkoutDays: activeDays.length,
        mostFrequentExercise: mostFrequentExercise,
        maxWeightLiftedKg: maxWeightLiftedKg > 0 ? maxWeightLiftedKg : null,
        highestVolumeExercise: highestVolumeExercise,
        recentWorkouts: matchedWorkouts.take(15).toList(),
      );
    } catch (e) {
      debugPrint('Error fetching workout logs for report: $e');
      return const WorkoutReportSummary(
        totalWorkouts: 0,
        totalDurationMinutes: 0,
        avgDurationMinutes: 0,
        totalCaloriesBurned: 0,
        totalSets: 0,
        totalReps: 0,
        totalVolumeKg: 0,
        activeWorkoutDays: 0,
      );
    }
  }

  // =========================================================================
  // 4. BODY PROGRESS SUMMARY
  // =========================================================================
  Future<BodyProgressReportSummary> _fetchBodyProgressSummary({
    required String uid,
    required DateTime startOfDay,
    required DateTime endOfDay,
    required double fallbackCurrentWeight,
    required double targetWeightKg,
    required bool isMetric,
  }) async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('measurements')
          .get();

      final List<Map<String, dynamic>> inRangeMeasurements = [];

      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        final date = _parseDate(data['date'] ?? data['timestamp']);
        if (date == null) continue;

        if (date.isBefore(startOfDay) || date.isAfter(endOfDay)) continue;

        inRangeMeasurements.add({
          'date': date,
          'weight': (data['weight'] as num?)?.toDouble(),
          'bodyFat': (data['bodyFatPercentage'] as num?)?.toDouble(),
          'waist': (data['waist'] as num?)?.toDouble(),
        });
      }

      // Sort chronologically ascending (oldest to latest)
      inRangeMeasurements.sort(
          (a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));

      final weightTrend = inRangeMeasurements
          .where((m) => m['weight'] != null && (m['weight'] as double) > 0)
          .map((m) => WeightDataPoint(
                date: m['date'] as DateTime,
                weightKg: m['weight'] as double,
              ))
          .toList();

      final double? startWeight =
          weightTrend.isNotEmpty ? weightTrend.first.weightKg : null;
      final double latestWeight = weightTrend.isNotEmpty
          ? weightTrend.last.weightKg
          : fallbackCurrentWeight;

      final double? weightDelta = (startWeight != null && weightTrend.length >= 2)
          ? (latestWeight - startWeight)
          : null;

      final bodyFatLogs = inRangeMeasurements
          .where((m) => m['bodyFat'] != null && (m['bodyFat'] as double) > 0)
          .toList();
      final double? startBodyFat =
          bodyFatLogs.isNotEmpty ? (bodyFatLogs.first['bodyFat'] as double) : null;
      final double? latestBodyFat =
          bodyFatLogs.isNotEmpty ? (bodyFatLogs.last['bodyFat'] as double) : null;

      final waistLogs = inRangeMeasurements
          .where((m) => m['waist'] != null && (m['waist'] as double) > 0)
          .toList();
      final double? startWaist =
          waistLogs.isNotEmpty ? (waistLogs.first['waist'] as double) : null;
      final double? latestWaist =
          waistLogs.isNotEmpty ? (waistLogs.last['waist'] as double) : null;

      return BodyProgressReportSummary(
        startWeightKg: startWeight,
        latestWeightKg: latestWeight,
        weightDeltaKg: weightDelta,
        targetWeightKg: targetWeightKg,
        totalMeasurementLogs: inRangeMeasurements.length,
        startBodyFat: startBodyFat,
        latestBodyFat: latestBodyFat,
        startWaistCm: startWaist,
        latestWaistCm: latestWaist,
        weightTrend: weightTrend,
        isMetric: isMetric,
      );
    } catch (e) {
      debugPrint('Error fetching body measurements for report: $e');
      return BodyProgressReportSummary(
        latestWeightKg: fallbackCurrentWeight,
        targetWeightKg: targetWeightKg,
        totalMeasurementLogs: 0,
        isMetric: isMetric,
      );
    }
  }

  // =========================================================================
  // 5. ACHIEVEMENTS
  // =========================================================================
  Future<List<AchievementReportItem>> _fetchAchievements({
    required String uid,
    required DateTime startOfDay,
    required DateTime endOfDay,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('achievements')
          .where('isUnlocked', isEqualTo: true)
          .get();

      final List<AchievementReportItem> list = [];
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final title = (data['title'] ?? 'Achievement Unlocked').toString();
        final description = (data['description'] ?? '').toString();
        final category = (data['category'] ?? 'General').toString();
        final unlockedDate = _parseDate(data['unlockedAt'] ?? data['updatedAt']);

        list.add(AchievementReportItem(
          title: title,
          description: description,
          category: category,
          unlockedAt: unlockedDate,
        ));
      }

      // Sort by unlock date descending (if available)
      list.sort((a, b) {
        if (a.unlockedAt == null && b.unlockedAt == null) return 0;
        if (a.unlockedAt == null) return 1;
        if (b.unlockedAt == null) return -1;
        return b.unlockedAt!.compareTo(a.unlockedAt!);
      });

      return list;
    } catch (e) {
      debugPrint('Error fetching achievements for report: $e');
      return [];
    }
  }

  // =========================================================================
  // HELPER: DATE PARSER
  // =========================================================================
  DateTime? _parseDate(dynamic val) {
    if (val == null) return null;
    if (val is Timestamp) return val.toDate();
    if (val is DateTime) return val;
    if (val is String) return DateTime.tryParse(val);
    if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
    return null;
  }
}
