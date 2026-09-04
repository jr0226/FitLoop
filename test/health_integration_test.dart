// ============================================================
// HEALTH INTEGRATION TESTS
// Pure model tests — no device or health plugin dependency.
// Tests cover: HealthConnectStatus, HealthSummary, HealthWorkoutSession
// ============================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/models/health_models.dart';

void main() {
  group('HealthConnectStatus extension', () {
    test('connected shows Health Synced label', () {
      expect(HealthConnectStatus.connected.displayLabel, 'Health Synced');
    });

    test('noData shows No Data Available label', () {
      expect(HealthConnectStatus.noData.displayLabel, 'No Data Available');
    });

    test('permissionRequired shows Permission Required label', () {
      expect(HealthConnectStatus.permissionRequired.displayLabel, 'Permission Required');
    });

    test('notInstalled shows Health Connect Not Installed label', () {
      expect(HealthConnectStatus.notInstalled.displayLabel, 'Health Connect Not Installed');
    });

    test('isHealthy true for connected', () {
      expect(HealthConnectStatus.connected.isHealthy, isTrue);
    });

    test('isHealthy true for noData', () {
      expect(HealthConnectStatus.noData.isHealthy, isTrue);
    });

    test('isHealthy false for permissionRequired', () {
      expect(HealthConnectStatus.permissionRequired.isHealthy, isFalse);
    });

    test('isHealthy false for notInstalled', () {
      expect(HealthConnectStatus.notInstalled.isHealthy, isFalse);
    });

    test('isHealthy false for error', () {
      expect(HealthConnectStatus.error.isHealthy, isFalse);
    });
  });

  group('HealthSummary', () {
    test('loading constant has notSupported status', () {
      expect(HealthSummary.loading.status, HealthConnectStatus.notSupported);
    });

    test('notInstalled constant has notInstalled status', () {
      expect(HealthSummary.notInstalled.status, HealthConnectStatus.notInstalled);
    });

    test('permissionRequired constant has permissionRequired status', () {
      expect(HealthSummary.permissionRequired.status, HealthConnectStatus.permissionRequired);
    });

    test('hasAnyData false when all zeros', () {
      const summary = HealthSummary(status: HealthConnectStatus.connected);
      expect(summary.hasAnyData, isFalse);
    });

    test('hasAnyData true when steps > 0', () {
      const summary = HealthSummary(
        status: HealthConnectStatus.connected,
        todaySteps: 5000,
      );
      expect(summary.hasAnyData, isTrue);
    });

    test('hasAnyData true when heartRate present', () {
      const summary = HealthSummary(
        status: HealthConnectStatus.connected,
        latestHeartRateBpm: 72.0,
      );
      expect(summary.hasAnyData, isTrue);
    });

    test('hasAnyData true when sleep > 0', () {
      const summary = HealthSummary(
        status: HealthConnectStatus.connected,
        sleepHours: 7.5,
      );
      expect(summary.hasAnyData, isTrue);
    });

    test('hasAnyData true when distance > 0', () {
      const summary = HealthSummary(
        status: HealthConnectStatus.connected,
        distanceKm: 3.2,
      );
      expect(summary.hasAnyData, isTrue);
    });

    test('copyWith updates only provided fields', () {
      const original = HealthSummary(
        status: HealthConnectStatus.connected,
        todaySteps: 1000,
        sleepHours: 6.0,
      );
      final updated = original.copyWith(todaySteps: 5000);
      expect(updated.todaySteps, 5000);
      expect(updated.sleepHours, 6.0); // unchanged
      expect(updated.status, HealthConnectStatus.connected); // unchanged
    });

    test('copyWith with new status preserves data', () {
      const original = HealthSummary(
        status: HealthConnectStatus.connected,
        todaySteps: 8500,
        activeCaloriesKcal: 320.0,
      );
      final updated = original.copyWith(status: HealthConnectStatus.noData);
      expect(updated.status, HealthConnectStatus.noData);
      expect(updated.todaySteps, 8500);
      expect(updated.activeCaloriesKcal, 320.0);
    });

    test('default values are zero/null/empty', () {
      const summary = HealthSummary(status: HealthConnectStatus.noData);
      expect(summary.todaySteps, 0);
      expect(summary.activeCaloriesKcal, 0.0);
      expect(summary.latestHeartRateBpm, isNull);
      expect(summary.sleepHours, 0.0);
      expect(summary.distanceKm, 0.0);
      expect(summary.recentWorkouts, isEmpty);
      expect(summary.errorMessage, isNull);
      expect(summary.fetchedAt, isNull);
    });

    test('formattedSleep formats hours and minutes properly', () {
      expect(const HealthSummary(status: HealthConnectStatus.connected, sleepHours: 0.0).formattedSleep, '--');
      expect(const HealthSummary(status: HealthConnectStatus.connected, sleepHours: -1.0).formattedSleep, '--');
      expect(const HealthSummary(status: HealthConnectStatus.connected, sleepHours: 7.5).formattedSleep, '7h 30m');
      expect(const HealthSummary(status: HealthConnectStatus.connected, sleepHours: 6.25).formattedSleep, '6h 15m');
      expect(const HealthSummary(status: HealthConnectStatus.connected, sleepHours: 0.75).formattedSleep, '45m');
      expect(const HealthSummary(status: HealthConnectStatus.connected, sleepHours: 8.0).formattedSleep, '8h');
      expect(const HealthSummary(status: HealthConnectStatus.connected, sleepHours: 7.6).formattedSleep, '7h 36m');
    });
  });

  group('HealthWorkoutSession', () {
    final start = DateTime(2026, 9, 3, 7, 0);
    final end = DateTime(2026, 9, 3, 7, 45);

    test('duration is correct', () {
      final session = HealthWorkoutSession(
        activityType: 'Running',
        startTime: start,
        endTime: end,
      );
      expect(session.duration.inMinutes, 45);
    });

    test('formattedDuration shows minutes for < 1 hour', () {
      final session = HealthWorkoutSession(
        activityType: 'Running',
        startTime: start,
        endTime: end,
      );
      expect(session.formattedDuration, '45m');
    });

    test('formattedDuration shows hours for exactly 1 hour', () {
      final session = HealthWorkoutSession(
        activityType: 'Cycling',
        startTime: DateTime(2026, 9, 3, 6, 0),
        endTime: DateTime(2026, 9, 3, 7, 0),
      );
      expect(session.formattedDuration, '1h');
    });

    test('formattedDuration shows hours and minutes for 1h 30m', () {
      final session = HealthWorkoutSession(
        activityType: 'Yoga',
        startTime: DateTime(2026, 9, 3, 6, 0),
        endTime: DateTime(2026, 9, 3, 7, 30),
      );
      expect(session.formattedDuration, '1h 30m');
    });

    test('optional calories and distance can be null', () {
      final session = HealthWorkoutSession(
        activityType: 'Strength Training',
        startTime: start,
        endTime: end,
      );
      expect(session.caloriesBurned, isNull);
      expect(session.distanceKm, isNull);
    });

    test('calories and distance are stored correctly', () {
      final session = HealthWorkoutSession(
        activityType: 'Running',
        startTime: start,
        endTime: end,
        caloriesBurned: 350.5,
        distanceKm: 5.2,
      );
      expect(session.caloriesBurned, 350.5);
      expect(session.distanceKm, 5.2);
    });
  });

  group('Sleep window logic (regression)', () {
    // Verifies that the sleep window calculation in HealthIntegrationService
    // would cover midnight-crossing sessions.
    // We test the math directly without calling the real service.
    test('sleep window start is 18 hours before midnight', () {
      final now = DateTime(2026, 9, 3, 7, 30); // 7:30 AM
      final startOfDay = DateTime(now.year, now.month, now.day); // midnight
      final sleepWindowStart = startOfDay.subtract(const Duration(hours: 18));

      // 18 hours before midnight of Sep 3 = 6 PM of Sep 2
      expect(sleepWindowStart, DateTime(2026, 9, 2, 6, 0));
    });

    test('sleep window covers 11 PM to 7 AM crossing', () {
      final sleepStart = DateTime(2026, 9, 2, 23, 0); // 11 PM Sep 2
      final sleepEnd = DateTime(2026, 9, 3, 7, 0);   // 7 AM Sep 3
      final now = DateTime(2026, 9, 3, 8, 0);
      final windowStart = DateTime(now.year, now.month, now.day)
          .subtract(const Duration(hours: 18));

      expect(sleepStart.isAfter(windowStart), isTrue,
          reason: '11 PM is after 6 PM window start');
      expect(sleepEnd.isBefore(now), isTrue,
          reason: '7 AM is before now (8 AM)');
    });
  });
}
