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

      // Step 4: Log raw Health Connect records for debug audit
      await debugLogRawHealthConnectRecords();

      // Step 5: Fetch all data types in parallel
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day, 0, 0, 0);

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

  /// Logs raw Health Connect records for TODAY.
  /// Meets requirement 1:
  /// - HealthDataType.STEPS
  /// - HealthDataType.ACTIVE_ENERGY_BURNED
  /// - HealthDataType.WORKOUT
  /// - HealthDataType.DISTANCE_DELTA
  /// - HealthDataType.HEART_RATE
  Future<void> debugLogRawHealthConnectRecords() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day, 0, 0, 0);

    debugPrint('==================================================');
    debugPrint('FITLOOP HEALTH CONNECT REAL DEVICE RAW READ DEBUG');
    debugPrint('Local Time: $now (Timezone: ${now.timeZoneName}, Offset: ${now.timeZoneOffset})');
    debugPrint('Local Query Window: $startOfDay -> $now');
    debugPrint('UTC Query Window: ${startOfDay.toUtc()} -> ${now.toUtc()}');
    debugPrint('==================================================');

    // 1. STEPS
    try {
      final stepPoints = await _health.getHealthDataFromTypes(
        types: [HealthDataType.STEPS],
        startTime: startOfDay,
        endTime: now,
      );
      final aggregatedSteps = await _health.getTotalStepsInInterval(startOfDay, now);
      double rawStepSum = 0;
      for (final p in stepPoints) {
        final v = p.value;
        final numVal = v is NumericHealthValue ? v.numericValue.toDouble() : 0.0;
        rawStepSum += numVal;
        debugPrint('[RAW STEP] val=$numVal, start=${p.dateFrom}, end=${p.dateTo}, src=${p.sourceName}, id=${p.sourceId}');
      }
      final dedupedSteps = _health.removeDuplicates(stepPoints);
      double dedupedStepSum = 0;
      for (final p in dedupedSteps) {
        final v = p.value;
        if (v is NumericHealthValue) dedupedStepSum += v.numericValue.toDouble();
      }
      debugPrint('[STEPS SUMMARY] Raw Points: ${stepPoints.length}, Raw Sum: $rawStepSum, Deduped Sum: $dedupedStepSum, Native Aggregated: $aggregatedSteps');
    } catch (e, st) {
      debugPrint('[STEPS ERROR] $e\n$st');
    }

    // 2. ACTIVE ENERGY BURNED
    try {
      final activeEnergyPoints = await _health.getHealthDataFromTypes(
        types: [HealthDataType.ACTIVE_ENERGY_BURNED],
        startTime: startOfDay,
        endTime: now,
      );
      double rawActiveEnergySum = 0;
      for (final p in activeEnergyPoints) {
        final v = p.value;
        final numVal = v is NumericHealthValue ? v.numericValue.toDouble() : 0.0;
        rawActiveEnergySum += numVal;
        debugPrint('[RAW ACTIVE ENERGY] val=$numVal kcal, start=${p.dateFrom}, end=${p.dateTo}, src=${p.sourceName}, id=${p.sourceId}');
      }
      final dedupedActiveEnergy = _health.removeDuplicates(activeEnergyPoints);
      double dedupedActiveEnergySum = 0;
      for (final p in dedupedActiveEnergy) {
        final v = p.value;
        if (v is NumericHealthValue) dedupedActiveEnergySum += v.numericValue.toDouble();
      }
      debugPrint('[ACTIVE ENERGY SUMMARY] Raw Points: ${activeEnergyPoints.length}, Raw Sum: $rawActiveEnergySum kcal, Deduped Sum: $dedupedActiveEnergySum kcal');
    } catch (e, st) {
      debugPrint('[ACTIVE ENERGY ERROR] $e\n$st');
    }

    // 3. WORKOUT / EXERCISE SESSION
    try {
      final workoutPoints = await _health.getHealthDataFromTypes(
        types: [HealthDataType.WORKOUT],
        startTime: startOfDay,
        endTime: now,
      );
      debugPrint('[WORKOUT SUMMARY] Raw Workout Points: ${workoutPoints.length}');
      for (final p in workoutPoints) {
        final v = p.value;
        if (v is WorkoutHealthValue) {
          final dur = p.dateTo.difference(p.dateFrom).inMinutes;
          debugPrint('[RAW WORKOUT] type=${v.workoutActivityType.name}, dur=$dur min, energy=${v.totalEnergyBurned} kcal, dist=${v.totalDistance} m, steps=${v.totalSteps}, start=${p.dateFrom}, end=${p.dateTo}, src=${p.sourceName}, id=${p.sourceId}');
        } else {
          debugPrint('[RAW WORKOUT] Non-workout value: $v, start=${p.dateFrom}, end=${p.dateTo}, src=${p.sourceName}');
        }
      }
    } catch (e, st) {
      debugPrint('[WORKOUT ERROR] $e\n$st');
    }

    // 4. DISTANCE DELTA
    try {
      final distancePoints = await _health.getHealthDataFromTypes(
        types: [HealthDataType.DISTANCE_DELTA],
        startTime: startOfDay,
        endTime: now,
      );
      double rawDistMeters = 0;
      for (final p in distancePoints) {
        final v = p.value;
        final numVal = v is NumericHealthValue ? v.numericValue.toDouble() : 0.0;
        rawDistMeters += numVal;
        debugPrint('[RAW DISTANCE] val=$numVal m, start=${p.dateFrom}, end=${p.dateTo}, src=${p.sourceName}');
      }
      debugPrint('[DISTANCE SUMMARY] Raw Points: ${distancePoints.length}, Total: ${(rawDistMeters / 1000).toStringAsFixed(2)} km');
    } catch (e, st) {
      debugPrint('[DISTANCE ERROR] $e\n$st');
    }

    // 5. HEART RATE
    try {
      final hrPoints = await _health.getHealthDataFromTypes(
        types: [HealthDataType.HEART_RATE],
        startTime: startOfDay,
        endTime: now,
      );
      debugPrint('[HEART RATE SUMMARY] Raw Points: ${hrPoints.length}');
      for (final p in hrPoints) {
        final v = p.value;
        final numVal = v is NumericHealthValue ? v.numericValue.toDouble() : 0.0;
        debugPrint('[RAW HEART RATE] bpm=$numVal, time=${p.dateFrom}, src=${p.sourceName}');
      }
    } catch (e, st) {
      debugPrint('[HEART RATE ERROR] $e\n$st');
    }

    debugPrint('==================================================');
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
      if (steps != null && steps > 0) return steps;

      // Fallback: query raw step points and sum deduplicated
      final points = await _health.getHealthDataFromTypes(
        types: [HealthDataType.STEPS],
        startTime: start,
        endTime: end,
      );
      final deduped = _health.removeDuplicates(points);
      int sum = 0;
      for (final p in deduped) {
        final v = p.value;
        if (v is NumericHealthValue) sum += v.numericValue.toInt();
      }
      return sum;
    } catch (e, st) {
      debugPrint('[FitLoop HealthConnect] _fetchSteps error: $e\n$st');
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
    } catch (e, st) {
      debugPrint('[FitLoop HealthConnect] _fetchActiveCalories error: $e\n$st');
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
    } catch (e, st) {
      debugPrint('[FitLoop HealthConnect] _fetchHeartRate error: $e\n$st');
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
    } catch (e, st) {
      debugPrint('[FitLoop HealthConnect] _fetchSleepHours error: $e\n$st');
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
    } catch (e, st) {
      debugPrint('[FitLoop HealthConnect] _fetchDistanceKm error: $e\n$st');
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
      final activeEnergyPoints = await _health.getHealthDataFromTypes(
        types: [HealthDataType.ACTIVE_ENERGY_BURNED],
        startTime: start,
        endTime: end,
      ).catchError((e) {
        debugPrint('[FitLoop HealthConnect] _fetchWorkoutSessions active energy error: $e');
        return <HealthDataPoint>[];
      });

      final sessions = <HealthWorkoutSession>[];
      for (final p in points) {
        final v = p.value;
        double? calories;
        double? distance;
        if (v is WorkoutHealthValue) {
          if (v.totalEnergyBurned != null && v.totalEnergyBurned! > 0) {
            calories = v.totalEnergyBurned?.toDouble();
          } else if (activeEnergyPoints.isNotEmpty) {
            double overlapping = 0.0;
            for (final ep in activeEnergyPoints) {
              if (!ep.dateTo.isBefore(p.dateFrom) && !ep.dateFrom.isAfter(p.dateTo)) {
                final ev = ep.value;
                if (ev is NumericHealthValue) overlapping += ev.numericValue.toDouble();
              }
            }
            if (overlapping > 0) calories = overlapping;
          }
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
    } catch (e, st) {
      debugPrint('[FitLoop HealthConnect] _fetchWorkoutSessions error: $e\n$st');
      return [];
    }
  }

  // ─── Unified External Workout Ingestion ───────────────────────────────────

  /// For unit testing: allows injecting external workouts without a physical Health Connect instance.
  @visibleForTesting
  List<ExternalWorkoutSession>? mockWorkoutsForTesting;

  /// Fetches all external workout sessions recorded for the given [date].
  /// Start of day: 00:00:00.000, End of day: current time (if today) or 23:59:59.999.
  /// Reads WORKOUT data points, extracts source metadata, attributes calories
  /// (preferring direct workout calories, falling back to overlapping ACTIVE_ENERGY_BURNED),
  /// and normalizes workout categories.
  Future<List<ExternalWorkoutSession>> getExternalWorkoutsForDate(DateTime date) async {
    if (mockWorkoutsForTesting != null) {
      return List<ExternalWorkoutSession>.from(mockWorkoutsForTesting!);
    }

    final now = DateTime.now();
    final isToday = date.year == now.year && date.month == now.month && date.day == now.day;
    final start = DateTime(date.year, date.month, date.day, 0, 0, 0);
    final end = isToday ? now : DateTime(date.year, date.month, date.day, 23, 59, 59, 999);

    try {
      final bool available = await _checkAvailability();
      if (!available) {
        debugPrint('[FitLoop HealthConnect] getExternalWorkoutsForDate: Health Connect not available');
        return [];
      }

      List<HealthDataPoint> workoutPoints = [];
      try {
        workoutPoints = await _health.getHealthDataFromTypes(
          types: [HealthDataType.WORKOUT],
          startTime: start,
          endTime: end,
        );
        debugPrint('[FitLoop HealthConnect] getExternalWorkoutsForDate: got ${workoutPoints.length} WORKOUT points');
      } catch (e, st) {
        debugPrint('[FitLoop HealthConnect] getExternalWorkoutsForDate WORKOUT error: $e\n$st');
      }

      List<HealthDataPoint> activeEnergyPoints = [];
      try {
        activeEnergyPoints = await _health.getHealthDataFromTypes(
          types: [HealthDataType.ACTIVE_ENERGY_BURNED],
          startTime: start,
          endTime: end,
        );
        debugPrint('[FitLoop HealthConnect] getExternalWorkoutsForDate: got ${activeEnergyPoints.length} ACTIVE_ENERGY_BURNED points');
      } catch (e, st) {
        debugPrint('[FitLoop HealthConnect] getExternalWorkoutsForDate ACTIVE_ENERGY error: $e\n$st');
      }

      return parseExternalWorkouts(
        workoutPoints: workoutPoints,
        activeEnergyPoints: activeEnergyPoints,
      );
    } catch (e, st) {
      debugPrint('[FitLoop HealthConnect] getExternalWorkoutsForDate error: $e\n$st');
      return [];
    }
  }

  /// Fetches external workout sessions recorded between [start] and [end].
  Future<List<ExternalWorkoutSession>> getExternalWorkoutsForDateRange(
    DateTime start,
    DateTime end,
  ) async {
    if (mockWorkoutsForTesting != null) {
      return List<ExternalWorkoutSession>.from(mockWorkoutsForTesting!);
    }

    try {
      final bool available = await _checkAvailability();
      if (!available) return [];

      List<HealthDataPoint> workoutPoints = [];
      try {
        workoutPoints = await _health.getHealthDataFromTypes(
          types: [HealthDataType.WORKOUT],
          startTime: start,
          endTime: end,
        );
      } catch (e, st) {
        debugPrint('[FitLoop HealthConnect] getExternalWorkoutsForDateRange WORKOUT error: $e\n$st');
      }

      List<HealthDataPoint> activeEnergyPoints = [];
      try {
        activeEnergyPoints = await _health.getHealthDataFromTypes(
          types: [HealthDataType.ACTIVE_ENERGY_BURNED],
          startTime: start,
          endTime: end,
        );
      } catch (e, st) {
        debugPrint('[FitLoop HealthConnect] getExternalWorkoutsForDateRange ACTIVE_ENERGY error: $e\n$st');
      }

      return parseExternalWorkouts(
        workoutPoints: workoutPoints,
        activeEnergyPoints: activeEnergyPoints,
      );
    } catch (e, st) {
      debugPrint('[FitLoop HealthConnect] getExternalWorkoutsForDateRange error: $e\n$st');
      return [];
    }
  }

  /// Pure parser helper separating Health Connect point extraction from platform calls.
  /// Deduplicates duplicate representations and attributes active energy bounded by workout window.
  static List<ExternalWorkoutSession> parseExternalWorkouts({
    required List<HealthDataPoint> workoutPoints,
    List<HealthDataPoint> activeEnergyPoints = const [],
  }) {
    final List<ExternalWorkoutSession> sessions = [];
    final Set<String> seenIdentifiers = {};

    for (final p in workoutPoints) {
      final v = p.value;
      if (v is! WorkoutHealthValue) continue;

      final workoutType = v.workoutActivityType.name
          .replaceAll('_', ' ')
          .toLowerCase()
          .split(' ')
          .map((w) => w.isNotEmpty ? w[0].toUpperCase() + w.substring(1) : w)
          .join(' ');

      final normalizedCat = HealthCategoryNormalizer.normalize(workoutType);

      final startTime = p.dateFrom;
      final endTime = p.dateTo;
      final durationMins = endTime.difference(startTime).inMinutes;
      final duration = durationMins > 0 ? durationMins : 1;

      // Unique identifier deduplication across duplicate points
      final dedupeKey = '${p.uuid}_${startTime.millisecondsSinceEpoch}_${endTime.millisecondsSinceEpoch}_$workoutType';
      if (seenIdentifiers.contains(dedupeKey)) continue;
      seenIdentifiers.add(dedupeKey);

      // Calorie attribution:
      // 1. Prefer direct workout calories if available and > 0
      int? calories;
      final directCal = v.totalEnergyBurned;
      if (directCal != null && directCal > 0) {
        calories = directCal.round();
      } else if (activeEnergyPoints.isNotEmpty) {
        // 2. Fallback: attribute overlapping ACTIVE_ENERGY_BURNED records
        // Record overlaps if: energy.dateTo > workout.startTime AND energy.dateFrom < workout.endTime
        double overlappingEnergy = 0.0;
        for (final ep in activeEnergyPoints) {
          if (ep.dateTo.isAfter(startTime) && ep.dateFrom.isBefore(endTime)) {
            final ev = ep.value;
            if (ev is NumericHealthValue) {
              overlappingEnergy += ev.numericValue.toDouble();
            }
          }
        }
        if (overlappingEnergy > 0) {
          calories = overlappingEnergy.round();
        }
      }

      // Distance in kilometers
      final double? distanceKm = (v.totalDistance != null && v.totalDistance! > 0)
          ? (v.totalDistance! / 1000.0)
          : null;

      // Source metadata preserved for display
      final String? sourceName = p.sourceName.isNotEmpty ? p.sourceName : null;
      final String? sourceId = p.sourceId.isNotEmpty ? p.sourceId : null;

      sessions.add(ExternalWorkoutSession(
        id: p.uuid.isNotEmpty ? p.uuid : '${startTime.millisecondsSinceEpoch}_$workoutType',
        workoutType: workoutType,
        normalizedCategory: normalizedCat,
        startTime: startTime,
        endTime: endTime,
        durationMinutes: duration,
        caloriesKcal: calories,
        distanceKm: distanceKm,
        sourceName: sourceName,
        sourceId: sourceId,
      ));
    }

    // Sort most recent first
    sessions.sort((a, b) => b.startTime.compareTo(a.startTime));
    return sessions;
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
