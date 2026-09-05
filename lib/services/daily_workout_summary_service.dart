import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'health_integration_service.dart';
import 'unified_activity_summary_service.dart';

/// Service responsible for calculating and streaming daily FitLoop workout calories.
///
/// Ensures both HomeDashboard and DietPage share an identical, synchronized
/// source of truth and date boundaries (startOfDay -> endOfDay in device local time).
class DailyWorkoutSummaryService {
  DailyWorkoutSummaryService._();

  /// Parses the completion date from a workout log record.
  /// Checks `completedAt` first, falling back to legacy `timestamp` or `createdAt`.
  static DateTime? parseWorkoutDate(Map<String, dynamic> data) {
    DateTime? checkValue(dynamic val) {
      if (val == null) return null;
      if (val is DateTime) return val;
      if (val is Timestamp) return val.toDate();
      if (val is String) {
        final parsed = DateTime.tryParse(val);
        if (parsed != null) return parsed.toLocal();
      }
      if (val is int) {
        return DateTime.fromMillisecondsSinceEpoch(val).toLocal();
      }
      return null;
    }

    return checkValue(data['completedAt']) ??
        checkValue(data['timestamp']) ??
        checkValue(data['createdAt']) ??
        checkValue(data['startTime']) ??
        checkValue(data['startedAt']) ??
        checkValue(data['date']);
  }

  /// Extracts calories burned from a workout log record.
  static int parseWorkoutCalories(Map<String, dynamic> data) {
    final cals = data['caloriesBurned'] ?? data['calories'] ?? data['burnedCalories'];
    if (cals is num) return cals.toInt();
    if (cals is String) return int.tryParse(cals) ?? 0;
    return 0;
  }

  /// Checks if a workout occurred within the local-day boundaries of [targetDate].
  static bool isWorkoutOnDay(Map<String, dynamic> data, DateTime targetDate) {
    final startOfDay = DateTime(targetDate.year, targetDate.month, targetDate.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final workoutDate = parseWorkoutDate(data);
    if (workoutDate == null) return false;

    return !workoutDate.isBefore(startOfDay) && workoutDate.isBefore(endOfDay);
  }

  /// Synchronously computes the total calories burned on [targetDate] from a list of logs.
  static int calculateDayBurnedCalories(
    List<Map<String, dynamic>> logs,
    DateTime targetDate,
  ) {
    int total = 0;
    for (final log in logs) {
      if (isWorkoutOnDay(log, targetDate)) {
        total += parseWorkoutCalories(log);
      }
    }
    return total;
  }

  /// Real-time stream of today's or selected date's workout calories burned.
  ///
  /// Listens to `users/{uid}/workout_logs` and sums calories for workouts
  /// completed on [targetDate].
  static Stream<int> streamDailyWorkoutCalories(
    String uid,
    DateTime targetDate, {
    FirebaseFirestore? firestore,
  }) {
    final db = firestore ?? FirebaseFirestore.instance;

    return db
        .collection('users')
        .doc(uid)
        .collection('workout_logs')
        .snapshots()
        .map((snapshot) {
          int totalBurned = 0;
          for (final doc in snapshot.docs) {
            final data = doc.data();
            if (isWorkoutOnDay(data, targetDate)) {
              totalBurned += parseWorkoutCalories(data);
            }
          }
          return totalBurned;
        })
        .handleError((error) {
          debugPrint('[DailyWorkoutSummaryService] Error streaming workout logs: $error');
          return 0;
        });
  }

  /// Real-time stream of unified daily exercise calories (FitLoop + Health Connect deduplicated).
  ///
  /// Combines FitLoop workouts and Android Health Connect exercise sessions
  /// using [UnifiedActivitySummaryService].
  static Stream<int> streamDailyUnifiedExerciseCalories(
    String uid,
    DateTime targetDate, {
    FirebaseFirestore? firestore,
    HealthIntegrationService? healthService,
  }) {
    return UnifiedActivitySummaryService.streamDailyActivitySummary(
      uid,
      targetDate,
      firestore: firestore,
      healthService: healthService,
    ).map((summary) => summary.totalExerciseCalories);
  }
}
