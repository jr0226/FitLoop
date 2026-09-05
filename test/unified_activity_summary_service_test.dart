import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/models/health_models.dart';
import 'package:flutter_application_1/services/unified_activity_summary_service.dart';

void main() {
  group('HealthCategoryNormalizer Tests', () {
    test('normalizes running variants', () {
      expect(HealthCategoryNormalizer.normalize('running'), HealthCategoryNormalizer.running);
      expect(HealthCategoryNormalizer.normalize('OUTDOOR_RUN'), HealthCategoryNormalizer.running);
      expect(HealthCategoryNormalizer.normalize('Treadmill Jog'), HealthCategoryNormalizer.running);
    });

    test('normalizes walking and hiking variants', () {
      expect(HealthCategoryNormalizer.normalize('walking'), HealthCategoryNormalizer.walking);
      expect(HealthCategoryNormalizer.normalize('Mountain Hike'), HealthCategoryNormalizer.walking);
      expect(HealthCategoryNormalizer.normalize('Evening Stroll'), HealthCategoryNormalizer.walking);
    });

    test('normalizes cycling and biking variants', () {
      expect(HealthCategoryNormalizer.normalize('biking'), HealthCategoryNormalizer.cycling);
      expect(HealthCategoryNormalizer.normalize('Spin Class'), HealthCategoryNormalizer.cycling);
      expect(HealthCategoryNormalizer.normalize('Road Cycling'), HealthCategoryNormalizer.cycling);
    });

    test('normalizes strength training variants', () {
      expect(HealthCategoryNormalizer.normalize('weight_lifting'), HealthCategoryNormalizer.strengthTraining);
      expect(HealthCategoryNormalizer.normalize('Upper Body Dumbbell'), HealthCategoryNormalizer.strengthTraining);
      expect(HealthCategoryNormalizer.normalize('Calisthenics Routine'), HealthCategoryNormalizer.strengthTraining);
      expect(HealthCategoryNormalizer.normalize('Gym Workout'), HealthCategoryNormalizer.strengthTraining);
    });

    test('normalizes HIIT and intervals', () {
      expect(HealthCategoryNormalizer.normalize('hiit'), HealthCategoryNormalizer.hiit);
      expect(HealthCategoryNormalizer.normalize('Tabata interval'), HealthCategoryNormalizer.hiit);
      expect(HealthCategoryNormalizer.normalize('Circuit Training'), HealthCategoryNormalizer.hiit);
    });

    test('normalizes swimming', () {
      expect(HealthCategoryNormalizer.normalize('swimming_pool'), HealthCategoryNormalizer.swimming);
      expect(HealthCategoryNormalizer.normalize('Open Water Swim'), HealthCategoryNormalizer.swimming);
    });

    test('normalizes yoga and pilates', () {
      expect(HealthCategoryNormalizer.normalize('yoga'), HealthCategoryNormalizer.yoga);
      expect(HealthCategoryNormalizer.normalize('Pilates & Stretch'), HealthCategoryNormalizer.yoga);
    });

    test('falls back to Other on null or unknown types', () {
      expect(HealthCategoryNormalizer.normalize(null), HealthCategoryNormalizer.other);
      expect(HealthCategoryNormalizer.normalize(''), HealthCategoryNormalizer.other);
      expect(HealthCategoryNormalizer.normalize('archery'), HealthCategoryNormalizer.other);
    });
  });

  group('ExternalWorkoutSession Model Tests', () {
    test('computes duration and formattedDuration correctly', () {
      final start = DateTime(2026, 9, 5, 8, 0);
      final end = DateTime(2026, 9, 5, 8, 45);
      final session = ExternalWorkoutSession(
        id: 'ext_1',
        sourceId: 'com.sec.android.app.shealth',
        sourceName: 'Samsung Health',
        workoutType: 'Running',
        normalizedCategory: HealthCategoryNormalizer.running,
        startTime: start,
        endTime: end,
        durationMinutes: 45,
        caloriesKcal: 320,
        distanceKm: 5.2,
      );

      expect(session.durationMinutes, 45);
      expect(session.formattedDuration, '45m');
      expect(session.displaySource, 'Samsung Health');
    });

    test('resolves fallback displaySource when sourceName is empty or unknown', () {
      final session = ExternalWorkoutSession(
        id: 'ext_2',
        workoutType: 'Walking',
        normalizedCategory: HealthCategoryNormalizer.walking,
        startTime: DateTime.now(),
        endTime: DateTime.now().add(const Duration(hours: 1, minutes: 15)),
        durationMinutes: 75,
      );

      expect(session.displaySource, 'Health Connect');
      expect(session.formattedDuration, '1h 15m');
    });
  });

  group('UnifiedWorkoutSession Model Tests', () {
    test('formats displaySource based on provenance', () {
      final now = DateTime.now();
      final fitLoopOnly = UnifiedWorkoutSession(
        id: 'fl_1',
        title: 'Push Day',
        normalizedCategory: HealthCategoryNormalizer.strengthTraining,
        startTime: now,
        endTime: now.add(const Duration(minutes: 50)),
        durationMinutes: 50,
        caloriesKcal: 250,
        source: UnifiedWorkoutSource.fitLoop,
      );
      expect(fitLoopOnly.displaySource, 'FitLoop');
      expect(fitLoopOnly.isFitLoopOnly, isTrue);

      final externalOnly = UnifiedWorkoutSession(
        id: 'ext_1',
        title: 'Morning Run',
        normalizedCategory: HealthCategoryNormalizer.running,
        startTime: now,
        endTime: now.add(const Duration(minutes: 30)),
        durationMinutes: 30,
        caloriesKcal: 280,
        source: UnifiedWorkoutSource.externalHealthConnect,
        externalSourceName: 'Samsung Health',
      );
      expect(externalOnly.displaySource, 'Samsung Health');
      expect(externalOnly.isExternalOnly, isTrue);

      final merged = UnifiedWorkoutSession(
        id: 'm_1',
        title: 'Leg Day Heavy',
        normalizedCategory: HealthCategoryNormalizer.strengthTraining,
        startTime: now,
        endTime: now.add(const Duration(minutes: 60)),
        durationMinutes: 60,
        caloriesKcal: 420,
        source: UnifiedWorkoutSource.merged,
        externalSourceName: 'Samsung Health',
      );
      expect(merged.displaySource, 'FitLoop + Samsung Health');
      expect(merged.isMerged, isTrue);
    });

    test('toWorkoutHistorySession maps properties cleanly for UI', () {
      final now = DateTime(2026, 9, 5, 10, 0);
      final u = UnifiedWorkoutSession(
        id: 'fl_100',
        title: 'Upper Body Blast',
        normalizedCategory: HealthCategoryNormalizer.strengthTraining,
        startTime: now,
        endTime: now.add(const Duration(minutes: 40)),
        durationMinutes: 40,
        caloriesKcal: 310,
        source: UnifiedWorkoutSource.merged,
        externalSourceName: 'Fitbit',
        fitLoopLogData: {
          'exercises': [
            {
              'exerciseName': 'Bench Press',
              'targetMuscle': 'Chest',
              'hasPersonalRecord': true,
              'sets': [
                {'setNumber': 1, 'weightKg': 80.0, 'reps': 8, 'isPersonalRecord': true}
              ],
            }
          ],
          'prBadges': ['PR: Bench Press'],
        },
      );

      final history = u.toWorkoutHistorySession();
      expect(history.id, 'fl_100');
      expect(history.routineName, 'Upper Body Blast');
      expect(history.category, HealthCategoryNormalizer.strengthTraining);
      expect(history.caloriesBurned, 310);
      expect(history.durationMinutes, 40);
      expect(history.isMerged, isTrue);
      expect(history.sourceName, 'Fitbit');
      expect(history.exercises.length, 1);
      expect(history.exercises.first.exerciseName, 'Bench Press');
      expect(history.totalVolumeKg, 640.0); // 80.0 * 8
      expect(history.prBadges, contains('PR: Bench Press'));
    });
  });

  group('UnifiedActivitySummaryService Deduplication & Aggregation Tests', () {
    final targetDate = DateTime(2026, 9, 5);

    test('Scenario A: FitLoop workouts only - calculates clean summary', () {
      final fitLoopLogs = [
        {
          'id': 'log_1',
          'routineName': 'Full Body HIIT',
          'completedAt': DateTime(2026, 9, 5, 9, 0),
          'durationMinutes': 30,
          'caloriesBurned': 240,
        },
      ];

      final summary = UnifiedActivitySummaryService.calculateDailySummary(
        fitLoopLogs: fitLoopLogs,
        externalWorkouts: [],
        targetDate: targetDate,
      );

      expect(summary.totalWorkoutCount, 1);
      expect(summary.totalExerciseCalories, 240);
      expect(summary.fitLoopCalories, 240);
      expect(summary.externalCalories, 0);
      expect(summary.deduplicatedWorkouts.length, 1);
      expect(summary.deduplicatedWorkouts.first.source, UnifiedWorkoutSource.fitLoop);
    });

    test('Scenario B: External workouts only (e.g. Samsung Health outdoor run)', () {
      final externalWorkouts = [
        ExternalWorkoutSession(
          id: 'ext_run_1',
          sourceId: 'com.sec.android.app.shealth',
          sourceName: 'Samsung Health',
          workoutType: 'Running',
          normalizedCategory: HealthCategoryNormalizer.running,
          startTime: DateTime(2026, 9, 5, 7, 0),
          endTime: DateTime(2026, 9, 5, 7, 45),
          durationMinutes: 45,
          caloriesKcal: 380,
          distanceKm: 6.0,
        ),
      ];

      final summary = UnifiedActivitySummaryService.calculateDailySummary(
        fitLoopLogs: [],
        externalWorkouts: externalWorkouts,
        targetDate: targetDate,
      );

      expect(summary.totalWorkoutCount, 1);
      expect(summary.totalExerciseCalories, 380);
      expect(summary.externalCalories, 380);
      expect(summary.fitLoopCalories, 0);
      expect(summary.deduplicatedWorkouts.first.isExternalOnly, isTrue);
      expect(summary.deduplicatedWorkouts.first.externalSourceName, 'Samsung Health');
      expect(summary.deduplicatedWorkouts.first.distanceKm, 6.0);
    });

    test('Scenario C: Exact duplicate workout recorded in both FitLoop and Wearable -> Merged into 1 session', () {
      // User logged workout in FitLoop from 17:00 to 17:50
      final fitLoopLogs = [
        {
          'id': 'fl_weights_1',
          'routineName': 'Strength Training Heavy',
          'completedAt': DateTime(2026, 9, 5, 17, 50),
          'durationMinutes': 50,
          'durationSeconds': 50 * 60,
          'caloriesBurned': 260, // FitLoop estimated
          'exercises': [
            {
              'exerciseName': 'Deadlift',
              'targetMuscle': 'Back',
              'sets': [
                {'setNumber': 1, 'weightKg': 100.0, 'reps': 5}
              ],
            }
          ],
        },
      ];

      // Samsung Galaxy Watch recorded workout simultaneously from 17:02 to 17:48
      final externalWorkouts = [
        ExternalWorkoutSession(
          id: 'shealth_101',
          sourceId: 'com.sec.android.app.shealth',
          sourceName: 'Samsung Health',
          workoutType: 'Weight Training',
          normalizedCategory: HealthCategoryNormalizer.strengthTraining,
          startTime: DateTime(2026, 9, 5, 17, 2),
          endTime: DateTime(2026, 9, 5, 17, 48), // 46 mins duration (~92% overlap)
          durationMinutes: 46,
          caloriesKcal: 345, // Device measured heart-rate calories
        ),
      ];

      final summary = UnifiedActivitySummaryService.calculateDailySummary(
        fitLoopLogs: fitLoopLogs,
        externalWorkouts: externalWorkouts,
        targetDate: targetDate,
      );

      // Must be deduplicated to 1 session, NOT 2
      expect(summary.totalWorkoutCount, 1);
      expect(summary.deduplicatedWorkouts.length, 1);

      final mergedSession = summary.deduplicatedWorkouts.first;
      expect(mergedSession.isMerged, isTrue);
      expect(mergedSession.displaySource, 'FitLoop + Samsung Health');

      // Calorie priority: Wearable/Health Connect calories (345) prioritised over FitLoop estimated (260)
      expect(mergedSession.caloriesKcal, 345);
      expect(summary.totalExerciseCalories, 345);

      // FitLoop exercises must be preserved
      expect(mergedSession.fitLoopLogData, isNotNull);
      final history = mergedSession.toWorkoutHistorySession();
      expect(history.exercises.first.exerciseName, 'Deadlift');
      expect(history.totalVolumeKg, 500.0);
    });

    test('Scenario D: Distinct sessions on same day -> Both preserved separately', () {
      // Morning Run at 07:00 recorded on smartwatch
      final externalWorkouts = [
        ExternalWorkoutSession(
          id: 'ext_morning_run',
          sourceName: 'Google Fit',
          workoutType: 'Running',
          normalizedCategory: HealthCategoryNormalizer.running,
          startTime: DateTime(2026, 9, 5, 7, 0),
          endTime: DateTime(2026, 9, 5, 7, 30),
          durationMinutes: 30,
          caloriesKcal: 250,
          distanceKm: 4.5,
        ),
      ];

      // Evening Gym Session at 18:00 recorded in FitLoop
      final fitLoopLogs = [
        {
          'id': 'fl_evening_chest',
          'routineName': 'Chest and Triceps',
          'completedAt': DateTime(2026, 9, 5, 18, 45),
          'durationMinutes': 45,
          'caloriesBurned': 300,
        },
      ];

      final summary = UnifiedActivitySummaryService.calculateDailySummary(
        fitLoopLogs: fitLoopLogs,
        externalWorkouts: externalWorkouts,
        targetDate: targetDate,
      );

      // Overlap is 0%, both must remain distinct!
      expect(summary.totalWorkoutCount, 2);
      expect(summary.deduplicatedWorkouts.length, 2);
      expect(summary.totalExerciseCalories, 550); // 250 + 300
    });

    test('Scenario E: Low overlap (< 70%) at overlapping times -> Kept distinct', () {
      // User worked out 10:00 to 11:00 (60 mins)
      final fitLoopLogs = [
        {
          'id': 'fl_session',
          'routineName': 'Long Strength Session',
          'completedAt': DateTime(2026, 9, 5, 11, 0),
          'durationMinutes': 60,
          'durationSeconds': 3600,
          'caloriesBurned': 350,
        },
      ];

      // External quick activity only from 10:50 to 11:20 (overlap is 10 mins / 30 mins = 33.3%, below 70%)
      final externalWorkouts = [
        ExternalWorkoutSession(
          id: 'ext_short',
          sourceName: 'Samsung Health',
          workoutType: 'Strength Training',
          normalizedCategory: HealthCategoryNormalizer.strengthTraining,
          startTime: DateTime(2026, 9, 5, 10, 50),
          endTime: DateTime(2026, 9, 5, 11, 20),
          durationMinutes: 30,
          caloriesKcal: 120,
        ),
      ];

      final summary = UnifiedActivitySummaryService.calculateDailySummary(
        fitLoopLogs: fitLoopLogs,
        externalWorkouts: externalWorkouts,
        targetDate: targetDate,
      );

      // Should NOT merge because overlap is < 70%
      expect(summary.totalWorkoutCount, 2);
    });

    test('Scenario F: Fallback to FitLoop calories when external calories are 0 or null', () {
      final fitLoopLogs = [
        {
          'id': 'fl_cardio',
          'routineName': 'Stationary Bike',
          'completedAt': DateTime(2026, 9, 5, 14, 0),
          'durationMinutes': 30,
          'caloriesBurned': 200,
        },
      ];

      final externalWorkouts = [
        ExternalWorkoutSession(
          id: 'ext_bike',
          sourceName: 'Fitbit',
          workoutType: 'Cycling',
          normalizedCategory: HealthCategoryNormalizer.cycling,
          startTime: DateTime(2026, 9, 5, 13, 30),
          endTime: DateTime(2026, 9, 5, 14, 0),
          durationMinutes: 30,
          caloriesKcal: null, // No calories provided by wearable
        ),
      ];

      final summary = UnifiedActivitySummaryService.calculateDailySummary(
        fitLoopLogs: fitLoopLogs,
        externalWorkouts: externalWorkouts,
        targetDate: targetDate,
      );

      expect(summary.totalWorkoutCount, 1);
      final merged = summary.deduplicatedWorkouts.first;
      // Because external had null, FitLoop's 200 calories are used as fallback
      expect(merged.caloriesKcal, 200);
      expect(summary.totalExerciseCalories, 200);
    });

    test('deduplicateSessions multi-day method correctly merges across arbitrary dates', () {
      final fitLoopLogs = [
        {
          'id': 'fl_d1',
          'routineName': 'Cardio Day 1',
          'completedAt': DateTime(2026, 9, 4, 10, 0),
          'durationMinutes': 30,
          'caloriesBurned': 210,
        },
        {
          'id': 'fl_d2',
          'routineName': 'Legs Day 2',
          'completedAt': DateTime(2026, 9, 5, 15, 0),
          'durationMinutes': 45,
          'caloriesBurned': 310,
        },
      ];

      final externalWorkouts = [
        ExternalWorkoutSession(
          id: 'ext_d2',
          sourceName: 'Samsung Health',
          workoutType: 'Legs Weightlifting',
          normalizedCategory: HealthCategoryNormalizer.strengthTraining,
          startTime: DateTime(2026, 9, 5, 14, 15),
          endTime: DateTime(2026, 9, 5, 15, 0),
          durationMinutes: 45,
          caloriesKcal: 350,
        ),
      ];

      final sessions = UnifiedActivitySummaryService.instance.deduplicateSessions(
        fitLoopWorkouts: fitLoopLogs,
        externalWorkouts: externalWorkouts,
      );

      // Day 1: 1 session (FitLoop only)
      // Day 2: 1 merged session (FitLoop + Samsung Health)
      // Total = 2 unified sessions
      expect(sessions.length, 2);
      expect(sessions.any((s) => s.isMerged && s.caloriesKcal == 350), isTrue);
      expect(sessions.any((s) => s.isFitLoopOnly && s.caloriesKcal == 210), isTrue);
    });
  });
}
