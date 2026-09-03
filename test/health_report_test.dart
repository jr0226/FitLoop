import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/models/health_report_data.dart';
import 'package:flutter_application_1/services/health_report_pdf_builder.dart';
import 'package:flutter_application_1/services/health_report_service.dart';

void main() {
  group('HealthReport Models & Calculations', () {
    test('formatMealDescription generates readable summaries from foods[]', () {
      // 1 item: displays food name
      expect(
        HealthReportService.formatMealDescription({
          'name': 'Mixed Meal (1 items)',
          'foods': [
            {'name': 'Fried Chicken'}
          ],
        }),
        equals('Fried Chicken'),
      );

      // 2 items: displays both food names
      expect(
        HealthReportService.formatMealDescription({
          'name': 'Mixed Meal (2 items)',
          'foods': [
            {'name': 'Nasi Lemak'},
            {'name': 'Fried Chicken'},
          ],
        }),
        equals('Nasi Lemak, Fried Chicken'),
      );

      // 5 items: displays top 3 + remaining count
      expect(
        HealthReportService.formatMealDescription({
          'name': 'Mixed Meal (5 items)',
          'foods': [
            {'name': 'Rice'},
            {'name': 'Chicken'},
            {'name': 'Sambal'},
            {'name': 'Egg'},
            {'name': 'Cucumber'},
          ],
        }),
        equals('Rice, Chicken, Sambal + 2 more'),
      );

      // Missing foods[] falls back to name
      expect(
        HealthReportService.formatMealDescription({
          'name': 'Beef Rendang with Rice',
        }),
        equals('Beef Rendang with Rice'),
      );
    });

    test('Goal direction: weight loss remaining calculated correctly', () {
      const profile = UserProfileReportSummary(
        name: 'Test Athlete',
        age: 28,
        gender: 'Male',
        heightCm: 180.0,
        currentWeightKg: 80.0,
        targetWeightKg: 70.0,
        fitnessGoal: 'Weight Loss',
        fitnessLevel: 'Intermediate',
        activityLevel: 'Moderate',
        calorieTarget: 2000,
        isMetric: true,
        currentStreak: 5,
      );

      expect(profile.goalProgressStatus, equals('10.0 kg above target'));
    });

    test('Goal direction: weight below target calculated correctly', () {
      const profile = UserProfileReportSummary(
        name: 'Test Athlete',
        age: 24,
        gender: 'Female',
        heightCm: 165.0,
        currentWeightKg: 65.0,
        targetWeightKg: 72.0,
        fitnessGoal: 'Muscle Gain',
        fitnessLevel: 'Beginner',
        activityLevel: 'High',
        calorieTarget: 2400,
        isMetric: true,
        currentStreak: 3,
      );

      expect(profile.goalProgressStatus, equals('7.0 kg below target'));
    });

    test('Goal direction: goal reached when within 0.2 kg', () {
      const profile = UserProfileReportSummary(
        name: 'Test Athlete',
        age: 30,
        gender: 'Male',
        heightCm: 175.0,
        currentWeightKg: 70.1,
        targetWeightKg: 70.0,
        fitnessGoal: 'Maintenance',
        fitnessLevel: 'Advanced',
        activityLevel: 'Moderate',
        calorieTarget: 2100,
        isMetric: true,
        currentStreak: 10,
      );

      expect(profile.goalProgressStatus,
          equals('Target weight reached'));
    });

    test('safeAscii replaces dashes, bullets, and strips non-ASCII/emojis', () {
      expect(
        HealthReportPdfBuilder.safeAscii('Aug 28 – Sep 3 • 2026 🔥 ≥ 2'),
        equals('Aug 28 - Sep 3 | 2026  >= 2'),
      );
      expect(
        HealthReportPdfBuilder.safeAscii('FitLoop — AI • Health'),
        equals('FitLoop - AI | Health'),
      );
    });

    test('Unit conversions for Imperial preference', () {
      const profileMetric = UserProfileReportSummary(
        name: 'Test Athlete',
        age: 25,
        gender: 'Male',
        heightCm: 175.0,
        currentWeightKg: 70.0,
        targetWeightKg: 65.0,
        fitnessGoal: 'Weight Loss',
        fitnessLevel: 'Beginner',
        activityLevel: 'Moderate',
        calorieTarget: 2000,
        isMetric: true,
        currentStreak: 4,
      );

      expect(profileMetric.formattedCurrentWeight, equals('70.0 kg'));
      expect(profileMetric.formattedHeight, equals('175.0 cm'));

      const profileImperial = UserProfileReportSummary(
        name: 'Test Athlete',
        age: 25,
        gender: 'Male',
        heightCm: 175.0,
        currentWeightKg: 70.0,
        targetWeightKg: 65.0,
        fitnessGoal: 'Weight Loss',
        fitnessLevel: 'Beginner',
        activityLevel: 'Moderate',
        calorieTarget: 2000,
        isMetric: false,
        currentStreak: 4,
      );

      // 70 kg * 2.20462 = ~154.3 lbs
      expect(profileImperial.formattedCurrentWeight, equals('154.3 lbs'));
      // 175 cm * 0.393701 = ~68.9 in
      expect(profileImperial.formattedHeight, equals('68.9 in'));
      expect(profileImperial.goalProgressStatus, contains('lbs above target'));
    });

    test('NutritionReportSummary handles empty data gracefully', () {
      const summary = NutritionReportSummary(
        totalMealsLogged: 0,
        daysWithLogs: 0,
        totalCalories: 0,
        avgDailyCalories: 0,
        avgProtein: 0.0,
        avgCarbs: 0.0,
        avgFat: 0.0,
        calorieTarget: 2000,
      );

      expect(summary.hasData, isFalse);
      expect(summary.recentMeals, isEmpty);
      expect(summary.dailyCalorieTrend, isEmpty);
    });

    test('WorkoutReportSummary handles empty data gracefully', () {
      const summary = WorkoutReportSummary(
        totalWorkouts: 0,
        totalDurationMinutes: 0,
        avgDurationMinutes: 0,
        totalCaloriesBurned: 0,
        totalSets: 0,
        totalReps: 0,
        totalVolumeKg: 0.0,
        activeWorkoutDays: 0,
      );

      expect(summary.hasData, isFalse);
      expect(summary.recentWorkouts, isEmpty);
    });

    test('BodyProgressReportSummary requires >= 2 logs for weight delta', () {
      const singleLogSummary = BodyProgressReportSummary(
        startWeightKg: 75.0,
        latestWeightKg: 75.0,
        weightDeltaKg: null,
        targetWeightKg: 70.0,
        totalMeasurementLogs: 1,
        isMetric: true,
      );

      expect(singleLogSummary.hasWeightChange, isFalse);

      const multiLogSummary = BodyProgressReportSummary(
        startWeightKg: 76.5,
        latestWeightKg: 75.0,
        weightDeltaKg: -1.5,
        targetWeightKg: 70.0,
        totalMeasurementLogs: 3,
        isMetric: true,
      );

      expect(multiLogSummary.hasWeightChange, isTrue);
      expect(multiLogSummary.weightDeltaKg, equals(-1.5));
    });
  });

  group('PDF Generation Engine (HealthReportPdfBuilder)', () {
    test('buildPdf generates non-empty byte buffer with empty/minimal data', () async {
      final now = DateTime.now();
      final reportData = HealthReportData(
        userProfile: const UserProfileReportSummary(
          name: 'Minimal User',
          age: 22,
          gender: 'Female',
          heightCm: 160.0,
          currentWeightKg: 55.0,
          targetWeightKg: 55.0,
          fitnessGoal: 'Maintenance',
          fitnessLevel: 'Beginner',
          activityLevel: 'Light',
          calorieTarget: 1800,
          isMetric: true,
          currentStreak: 0,
        ),
        nutrition: const NutritionReportSummary(
          totalMealsLogged: 0,
          daysWithLogs: 0,
          totalCalories: 0,
          avgDailyCalories: 0,
          avgProtein: 0,
          avgCarbs: 0,
          avgFat: 0,
          calorieTarget: 1800,
        ),
        workout: const WorkoutReportSummary(
          totalWorkouts: 0,
          totalDurationMinutes: 0,
          avgDurationMinutes: 0,
          totalCaloriesBurned: 0,
          totalSets: 0,
          totalReps: 0,
          totalVolumeKg: 0,
          activeWorkoutDays: 0,
        ),
        bodyProgress: const BodyProgressReportSummary(
          targetWeightKg: 55.0,
          totalMeasurementLogs: 0,
          isMetric: true,
        ),
        achievements: const [],
        startDate: now.subtract(const Duration(days: 6)),
        endDate: now,
        generatedAt: now,
        periodType: HealthReportPeriodType.last7Days,
      );

      final Uint8List pdfBytes = await HealthReportPdfBuilder.buildPdf(reportData);

      expect(pdfBytes, isNotNull);
      expect(pdfBytes.isNotEmpty, isTrue);
      // Valid PDF files begin with %PDF
      final header = String.fromCharCodes(pdfBytes.sublist(0, 4));
      expect(header, equals('%PDF'));
    });

    test('buildPdf generates multi-page PDF with rich populated data', () async {
      final now = DateTime.now();
      final reportData = HealthReportData(
        userProfile: const UserProfileReportSummary(
          name: 'Jane Doe',
          email: 'jane@fitloop.com',
          age: 26,
          gender: 'Female',
          heightCm: 168.0,
          currentWeightKg: 64.0,
          targetWeightKg: 60.0,
          fitnessGoal: 'Weight Loss',
          fitnessLevel: 'Intermediate',
          activityLevel: 'Moderate',
          calorieTarget: 1950,
          isMetric: true,
          currentStreak: 7,
        ),
        nutrition: NutritionReportSummary(
          totalMealsLogged: 14,
          daysWithLogs: 7,
          totalCalories: 13650,
          avgDailyCalories: 1950,
          avgProtein: 120.5,
          avgCarbs: 185.0,
          avgFat: 55.0,
          avgMealScore: 8.8,
          calorieTarget: 1950,
          recentMeals: [
            NutritionMealItem(
              name: 'Oatmeal & Berries',
              mealType: 'Breakfast',
              calories: 420,
              protein: 18,
              carbs: 65,
              fat: 8,
              score: 9.2,
              date: now.subtract(const Duration(days: 1)),
            ),
            NutritionMealItem(
              name: 'Grilled Chicken Salad',
              mealType: 'Lunch',
              calories: 580,
              protein: 48,
              carbs: 22,
              fat: 16,
              score: 8.9,
              date: now.subtract(const Duration(days: 1)),
            ),
          ],
          dailyCalorieTrend: List.generate(
            7,
            (i) => NutritionDailyData(
              date: now.subtract(Duration(days: 6 - i)),
              totalCalories: 1900 + (i * 20),
            ),
          ),
        ),
        workout: WorkoutReportSummary(
          totalWorkouts: 4,
          totalDurationMinutes: 190,
          avgDurationMinutes: 48,
          totalCaloriesBurned: 1450,
          totalSets: 42,
          totalReps: 420,
          totalVolumeKg: 8500.0,
          activeWorkoutDays: 4,
          mostFrequentExercise: 'Dumbbell Bench Press',
          maxWeightLiftedKg: 65.0,
          highestVolumeExercise: 'Barbell Squat',
          recentWorkouts: [
            WorkoutSessionItem(
              date: now.subtract(const Duration(days: 2)),
              routineName: 'Upper Body Hypertrophy',
              durationMinutes: 52,
              caloriesBurned: 390,
              totalVolumeKg: 4200.0,
              totalSets: 20,
              totalReps: 200,
            ),
          ],
        ),
        bodyProgress: BodyProgressReportSummary(
          startWeightKg: 65.2,
          latestWeightKg: 64.0,
          weightDeltaKg: -1.2,
          targetWeightKg: 60.0,
          totalMeasurementLogs: 3,
          startBodyFat: 24.5,
          latestBodyFat: 23.8,
          startWaistCm: 74.0,
          latestWaistCm: 72.5,
          weightTrend: [
            WeightDataPoint(
                date: now.subtract(const Duration(days: 6)), weightKg: 65.2),
            WeightDataPoint(
                date: now.subtract(const Duration(days: 3)), weightKg: 64.6),
            WeightDataPoint(date: now, weightKg: 64.0),
          ],
          isMetric: true,
        ),
        achievements: [
          AchievementReportItem(
            title: 'Early Bird Grinder',
            description: 'Completed 5 morning workouts.',
            category: 'workout',
            unlockedAt: now.subtract(const Duration(days: 3)),
          ),
          AchievementReportItem(
            title: '7-Day Streak Master',
            description: 'Maintained activity for 7 consecutive days.',
            category: 'streak',
            unlockedAt: now.subtract(const Duration(days: 1)),
          ),
        ],
        startDate: now.subtract(const Duration(days: 6)),
        endDate: now,
        generatedAt: now,
        periodType: HealthReportPeriodType.last7Days,
      );

      final Uint8List pdfBytes = await HealthReportPdfBuilder.buildPdf(reportData);

      expect(pdfBytes, isNotNull);
      expect(pdfBytes.length, greaterThan(1000));
      final header = String.fromCharCodes(pdfBytes.sublist(0, 4));
      expect(header, equals('%PDF'));
    });
  });
}
