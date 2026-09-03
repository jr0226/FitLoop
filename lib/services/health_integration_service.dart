// ============================================================
// HEALTH INTEGRATION SERVICE
// Centralizes all Health Connect interactions for FitLoop.
//
// Architecture:
//   Smartwatch / Health App
//     → Android Health Connect
//     → HealthIntegrationService (this file)
//     → Home Dashboard / Settings / Analytics
//
// Key design decisions:
//   1. ONE global Health() instance (required since health v12.0.0)
//   2. Availability check before any permission request
//   3. Permission state check before re-requesting (avoids spamming dialogs)
//   4. Sleep window: previous-day 6 PM → now (covers midnight crossings)
//   5. Active energy kept separate from FitLoop workout calories
//   6. READ-ONLY phase: no data is written back to Health Connect
// ============================================================

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:health/health.dart';

import '../models/health_models.dart';

class HealthIntegrationService {
  // ─── Singleton pattern (required by health v12.0.0) ──────────────────────
  HealthIntegrationService._();
  static final HealthIntegrationService instance = HealthIntegrationService._();

  /// The ONE global Health instance. Must not be recreated per call.
  final Health _health = Health();

  /// Cached summary so the dashboard does not flash on rebuild.
  HealthSummary _cachedSummary = HealthSummary.loading;
  HealthSummary get cachedSummary => _cachedSummary;

  // ─── Data types requested from Health Connect ─────────────────────────────
  // Only valid Android Health Connect record types from HealthConstants.mapToType:
  // STEPS -> StepsRecord
  // ACTIVE_ENERGY_BURNED -> ActiveCaloriesBurnedRecord
  // HEART_RATE -> HeartRateRecord
  // SLEEP_ASLEEP -> SleepSessionRecord
  // WORKOUT -> ExerciseSessionRecord
  // DISTANCE_DELTA -> DistanceRecord
  static const List<HealthDataType> _readTypes = [
    HealthDataType.STEPS,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.HEART_RATE,
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.WORKOUT,
    HealthDataType.DISTANCE_DELTA,
  ];

  // READ-ONLY permissions (must match length of _readTypes)
  static const List<HealthDataAccess> _readAccess = [
    HealthDataAccess.READ,
    HealthDataAccess.READ,
    HealthDataAccess.READ,
    HealthDataAccess.READ,
    HealthDataAccess.READ,
    HealthDataAccess.READ,
  ];

  // ─── Public API ───────────────────────────────────────────────────────────

  /// Full fetch: check availability → check permissions → fetch data.
  /// Returns a typed [HealthSummary] for every possible state.
  Future<HealthSummary> fetchDailySummary() async {
    try {
      // Step 1: Check if Health Connect is available on this device/OS
      final bool available = await _checkAvailability();
      if (!available) {
        // Distinguish "not installed" from "not supported"
        final bool isAndroid = defaultTargetPlatform == TargetPlatform.android;
        _cachedSummary = isAndroid
            ? HealthSummary.notInstalled   // Android but app not installed
            : const HealthSummary(status: HealthConnectStatus.notSupported);
        return _cachedSummary;
      }

      // Step 2: Check existing permissions without prompting
      final bool? alreadyGranted = await _health.hasPermissions(
        _readTypes,
        permissions: _readAccess,
      );

      if (alreadyGranted == null || !alreadyGranted) {
        // Step 3: Request permissions (dialog shows because MainActivity
        // now extends FlutterFragmentActivity)
        final bool granted = await _health.requestAuthorization(
          _readTypes,
          permissions: _readAccess,
        );
        if (!granted) {
          _cachedSummary = HealthSummary.permissionRequired;
          return _cachedSummary;
        }
      }

      // Step 4: Fetch all data types in parallel
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);

      // Sleep window: previous day 6 PM → now
      // Covers midnight-crossing sessions (most common real-world sleep)
      final sleepWindowStart = startOfDay.subtract(const Duration(hours: 18));

      final results = await Future.wait([
        _fetchSteps(startOfDay, now),
        _fetchActiveCalories(startOfDay, now),
        _fetchHeartRate(startOfDay, now),
        _fetchSleepHours(sleepWindowStart, now),
        _fetchDistanceKm(startOfDay, now),
        _fetchWorkoutSessions(startOfDay, now),
      ]);

      final int steps = results[0] as int;
      final double calories = results[1] as double;
      final double? heartRate = results[2] as double?;
      final double sleep = results[3] as double;
      final double distance = results[4] as double;
      final List<HealthWorkoutSession> workouts =
          results[5] as List<HealthWorkoutSession>;

      final hasData = steps > 0 ||
          calories > 0 ||
          heartRate != null ||
          sleep > 0 ||
          distance > 0 ||
          workouts.isNotEmpty;

      _cachedSummary = HealthSummary(
        status: hasData
            ? HealthConnectStatus.connected
            : HealthConnectStatus.noData,
        todaySteps: steps,
        activeCaloriesKcal: calories,
        latestHeartRateBpm: heartRate,
        sleepHours: sleep,
        distanceKm: distance,
        recentWorkouts: workouts,
        fetchedAt: now,
      );
      return _cachedSummary;
    } catch (e, st) {
      debugPrint('HealthIntegrationService.fetchDailySummary error: $e\n$st');
      _cachedSummary = HealthSummary(
        status: HealthConnectStatus.error,
        errorMessage: e.toString(),
      );
      return _cachedSummary;
    }
  }

  /// Request permissions only — useful for the Settings "Connect" button.
  /// Returns true if all permissions were granted.
  Future<bool> requestPermissions() async {
    try {
      final sdkStatus = await _health.getHealthConnectSdkStatus();
      debugPrint('[FitLoop HealthConnect] SDK Status: $sdkStatus');
      final bool available = await _checkAvailability();
      debugPrint('[FitLoop HealthConnect] isHealthConnectAvailable: $available');
      if (!available) {
        debugPrint('[FitLoop HealthConnect] Health Connect not available on this device.');
        return false;
      }
      debugPrint('[FitLoop HealthConnect] Requesting types: ${_readTypes.map((t) => t.name).toList()}');
      final bool granted = await _health.requestAuthorization(
        _readTypes,
        permissions: _readAccess,
      );
      debugPrint('[FitLoop HealthConnect] requestAuthorization result: $granted');
      return granted;
    } on PlatformException catch (pe) {
      debugPrint('[FitLoop HealthConnect] PlatformException: code=${pe.code}, message=${pe.message}, details=${pe.details}');
      return false;
    } catch (e, st) {
      debugPrint('[FitLoop HealthConnect] requestPermissions error: $e\n$st');
      return false;
    }
  }

  /// Check if Health Connect is reachable on this device.
  /// Returns false if not installed or platform doesn't support it.
  Future<bool> _checkAvailability() async {
    try {
      return await _health.isHealthConnectAvailable();
    } catch (_) {
      return false;
    }
  }

  // ─── Individual data fetchers ─────────────────────────────────────────────

  Future<int> _fetchSteps(DateTime start, DateTime end) async {
    try {
      final int? steps = await _health.getTotalStepsInInterval(start, end);
      return steps ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<double> _fetchActiveCalories(DateTime start, DateTime end) async {
    try {
      final List<HealthDataPoint> points = await _health.getHealthDataFromTypes(
        types: [HealthDataType.ACTIVE_ENERGY_BURNED],
        startTime: start,
        endTime: end,
      );
      // Deduplicate (Health Connect may return overlapping records from multiple sources)
      final deduped = _health.removeDuplicates(points);
      double total = 0;
      for (final p in deduped) {
        final v = p.value;
        if (v is NumericHealthValue) {
          total += v.numericValue.toDouble();
        }
      }
      return double.parse(total.toStringAsFixed(1));
    } catch (_) {
      return 0.0;
    }
  }

  Future<double?> _fetchHeartRate(DateTime start, DateTime end) async {
    try {
      final List<HealthDataPoint> points = await _health.getHealthDataFromTypes(
        types: [HealthDataType.HEART_RATE],
        startTime: start,
        endTime: end,
      );
      if (points.isEmpty) return null;
      // Return the most recent reading
      points.sort((a, b) => b.dateFrom.compareTo(a.dateFrom));
      final v = points.first.value;
      if (v is NumericHealthValue) {
        return double.parse(v.numericValue.toDouble().toStringAsFixed(0));
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<double> _fetchSleepHours(DateTime start, DateTime end) async {
    try {
      final List<HealthDataPoint> points = await _health.getHealthDataFromTypes(
        types: [HealthDataType.SLEEP_ASLEEP, HealthDataType.SLEEP_SESSION],
        startTime: start,
        endTime: end,
      );
      // Deduplicate; use SLEEP_ASLEEP for actual sleep, SLEEP_SESSION as fallback
      final deduped = _health.removeDuplicates(points);
      final asleepPoints = deduped
          .where((p) => p.type == HealthDataType.SLEEP_ASLEEP)
          .toList();
      final sourcePoints = asleepPoints.isNotEmpty ? asleepPoints : deduped;

      double totalMinutes = 0;
      for (final p in sourcePoints) {
        totalMinutes += p.dateTo.difference(p.dateFrom).inMinutes;
      }
      if (totalMinutes <= 0) return 0.0;
      return double.parse((totalMinutes / 60).toStringAsFixed(1));
    } catch (_) {
      return 0.0;
    }
  }

  Future<double> _fetchDistanceKm(DateTime start, DateTime end) async {
    try {
      final List<HealthDataPoint> points = await _health.getHealthDataFromTypes(
        types: [HealthDataType.DISTANCE_DELTA],
        startTime: start,
        endTime: end,
      );
      final deduped = _health.removeDuplicates(points);
      double totalMeters = 0;
      for (final p in deduped) {
        final v = p.value;
        if (v is NumericHealthValue) {
          totalMeters += v.numericValue.toDouble();
        }
      }
      return double.parse((totalMeters / 1000).toStringAsFixed(2));
    } catch (_) {
      return 0.0;
    }
  }

  Future<List<HealthWorkoutSession>> _fetchWorkoutSessions(
    DateTime start,
    DateTime end,
  ) async {
    try {
      final List<HealthDataPoint> points = await _health.getHealthDataFromTypes(
        types: [HealthDataType.WORKOUT],
        startTime: start,
        endTime: end,
      );
      final sessions = <HealthWorkoutSession>[];
      for (final p in points) {
        final v = p.value;
        double? calories;
        double? distance;
        if (v is WorkoutHealthValue) {
          calories = v.totalEnergyBurned?.toDouble();
          distance = v.totalDistance != null ? v.totalDistance! / 1000 : null;
          sessions.add(HealthWorkoutSession(
            activityType: v.workoutActivityType.name
                .replaceAll('_', ' ')
                .toLowerCase()
                .split(' ')
                .map((w) => w.isNotEmpty
                    ? w[0].toUpperCase() + w.substring(1)
                    : w)
                .join(' '),
            startTime: p.dateFrom,
            endTime: p.dateTo,
            caloriesBurned: calories,
            distanceKm: distance,
          ));
        }
      }
      // Sort most recent first
      sessions.sort((a, b) => b.startTime.compareTo(a.startTime));
      return sessions;
    } catch (_) {
      return [];
    }
  }

  // ─── Utility helpers for Settings UI ─────────────────────────────────────

  /// Prompts the user to install Health Connect from Google Play (Android only).
  Future<void> installHealthConnect() async {
    try {
      await _health.installHealthConnect();
    } catch (e) {
      debugPrint('Could not launch Health Connect install: $e');
    }
  }

  /// Checks if Health Connect is available without fetching data.
  Future<HealthConnectStatus> checkStatus() async {
    try {
      if (defaultTargetPlatform != TargetPlatform.android) {
        return HealthConnectStatus.notSupported;
      }
      final bool available = await _checkAvailability();
      if (!available) {
        final sdkStatus = await _health.getHealthConnectSdkStatus();
        if (sdkStatus == HealthConnectSdkStatus.sdkUnavailableProviderUpdateRequired ||
            sdkStatus == HealthConnectSdkStatus.sdkUnavailable) {
          return HealthConnectStatus.notInstalled;
        }
        return HealthConnectStatus.notSupported;
      }
      final bool? granted = await _health.hasPermissions(
        _readTypes,
        permissions: _readAccess,
      );
      return (granted == true)
          ? HealthConnectStatus.connected
          : HealthConnectStatus.permissionRequired;
    } catch (_) {
      return HealthConnectStatus.error;
    }
  }
}
