import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/services/daily_workout_summary_service.dart';

void main() {
  group('DailyWorkoutSummaryService Tests', () {
    final today = DateTime(2026, 9, 4, 14, 30);
    final yesterday = DateTime(2026, 9, 3, 20, 0);
    final tomorrow = DateTime(2026, 9, 5, 8, 0);

    test('parseWorkoutDate parses completedAt Timestamp first', () {
      final data = {
        'completedAt': Timestamp.fromDate(today),
        'timestamp': Timestamp.fromDate(yesterday),
      };
      final parsed = DailyWorkoutSummaryService.parseWorkoutDate(data);
      expect(parsed, isNotNull);
      expect(parsed!.day, equals(4));
    });

    test('parseWorkoutDate falls back to timestamp if completedAt is missing', () {
      final data = {
        'timestamp': Timestamp.fromDate(today),
      };
      final parsed = DailyWorkoutSummaryService.parseWorkoutDate(data);
      expect(parsed, isNotNull);
      expect(parsed!.day, equals(4));
    });

    test('parseWorkoutDate parses ISO8601 string and epoch integer', () {
      final dataString = {'completedAt': '2026-09-04T12:00:00Z'};
      final parsedStr = DailyWorkoutSummaryService.parseWorkoutDate(dataString);
      expect(parsedStr, isNotNull);

      final epoch = today.millisecondsSinceEpoch;
      final dataEpoch = {'completedAt': epoch};
      final parsedEpoch = DailyWorkoutSummaryService.parseWorkoutDate(dataEpoch);
      expect(parsedEpoch, isNotNull);
    });

    test('parseWorkoutCalories extracts numeric values from various keys', () {
      expect(
        DailyWorkoutSummaryService.parseWorkoutCalories({'caloriesBurned': 250}),
        equals(250),
      );
      expect(
        DailyWorkoutSummaryService.parseWorkoutCalories({'calories': 180.5}),
        equals(180),
      );
      expect(
        DailyWorkoutSummaryService.parseWorkoutCalories({'burnedCalories': '320'}),
        equals(320),
      );
      expect(
        DailyWorkoutSummaryService.parseWorkoutCalories({}),
        equals(0),
      );
    });

    test('isWorkoutOnDay matches only within local date boundaries', () {
      final workoutToday = {'completedAt': Timestamp.fromDate(today)};
      final workoutYesterday = {'completedAt': Timestamp.fromDate(yesterday)};
      final workoutTomorrow = {'completedAt': Timestamp.fromDate(tomorrow)};

      expect(DailyWorkoutSummaryService.isWorkoutOnDay(workoutToday, today), isTrue);
      expect(DailyWorkoutSummaryService.isWorkoutOnDay(workoutYesterday, today), isFalse);
      expect(DailyWorkoutSummaryService.isWorkoutOnDay(workoutTomorrow, today), isFalse);
    });

    test('calculateDayBurnedCalories sums multiple workouts on the same day and ignores other days', () {
      final logs = [
        {
          'completedAt': Timestamp.fromDate(DateTime(2026, 9, 4, 7, 0)),
          'caloriesBurned': 200,
        },
        {
          'completedAt': Timestamp.fromDate(DateTime(2026, 9, 4, 18, 30)),
          'caloriesBurned': 150,
        },
        {
          'completedAt': Timestamp.fromDate(DateTime(2026, 9, 3, 19, 0)), // yesterday
          'caloriesBurned': 500,
        },
        {
          'completedAt': Timestamp.fromDate(DateTime(2026, 9, 5, 6, 0)), // tomorrow
          'caloriesBurned': 300,
        },
      ];

      final burnedToday = DailyWorkoutSummaryService.calculateDayBurnedCalories(logs, today);
      expect(burnedToday, equals(350)); // 200 + 150

      final burnedYesterday = DailyWorkoutSummaryService.calculateDayBurnedCalories(logs, yesterday);
      expect(burnedYesterday, equals(500));
    });
  });
}
