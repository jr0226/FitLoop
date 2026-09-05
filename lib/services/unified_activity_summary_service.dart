import 'dart:async';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/health_models.dart';
import 'daily_workout_summary_service.dart';
import 'health_integration_service.dart';

/// Single source of truth for unified workout summaries across FitLoop.
///
/// Combines internal FitLoop Firestore workout logs with external exercise sessions
/// from Android Health Connect (e.g. Samsung Health, Fitbit, Google Fit, Zepp).
///
/// Deduplication Rule:
/// - Same calendar day
/// - Temporal overlap >= 70% of shorter workout duration
/// - Matching normalized exercise category (e.g. Strength vs Strength)
///
/// Calorie Priority:
/// - Prefer Health Connect recorded calories when valid and > 0 (wearable measurement)
/// - Fallback to FitLoop estimated calories
/// - Never double-count or sum both for the same physical session
class UnifiedActivitySummaryService {
  UnifiedActivitySummaryService._();
  static final UnifiedActivitySummaryService instance = UnifiedActivitySummaryService._();

  /// Suggested overlap ratio threshold for deduplicating the same physical workout.
  static const double overlapThreshold = 0.70;

  /// Multi-day or single-day session deduplication.
  List<UnifiedWorkoutSession> deduplicateSessions({
    required List<Map<String, dynamic>> fitLoopWorkouts,
    required List<ExternalWorkoutSession> externalWorkouts,
  }) {
    if (externalWorkouts.isEmpty) {
      return fitLoopWorkouts.map((fl) {
        final d = DailyWorkoutSummaryService.parseWorkoutDate(fl) ?? DateTime.now();
        final int durSec = (fl['durationSeconds'] as num?)?.toInt() ??
            (((fl['durationMinutes'] as num?)?.toInt() ?? 30) * 60);
        final int durMin = durSec > 0 ? (durSec / 60).round() : 30;
        final start = d.subtract(Duration(seconds: durSec > 0 ? durSec : 1800));
        return UnifiedWorkoutSession(
          id: (fl['id'] ?? fl['routineName'] ?? UniqueKey().toString()).toString(),
          title: (fl['routineName'] ?? fl['workoutName'] ?? fl['name'] ?? 'Workout Session').toString(),
          normalizedCategory: HealthCategoryNormalizer.normalize(fl['category']?.toString()),
          startTime: start,
          endTime: d,
          durationMinutes: durMin,
          caloriesKcal: DailyWorkoutSummaryService.parseWorkoutCalories(fl),
          source: UnifiedWorkoutSource.fitLoop,
          fitLoopLogData: fl,
        );
      }).toList()..sort((a, b) => b.startTime.compareTo(a.startTime));
    }

    final dates = <DateTime>{};
    for (final fl in fitLoopWorkouts) {
      final d = DailyWorkoutSummaryService.parseWorkoutDate(fl);
      if (d != null) {
        dates.add(DateTime(d.year, d.month, d.day));
      }
    }
    for (final ext in externalWorkouts) {
      dates.add(DateTime(ext.startTime.year, ext.startTime.month, ext.startTime.day));
    }
    if (dates.isEmpty) {
      dates.add(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day));
    }

    final allUnified = <UnifiedWorkoutSession>[];
    for (final date in dates) {
      final summary = calculateDailySummary(
        fitLoopLogs: fitLoopWorkouts,
        externalWorkouts: externalWorkouts,
        targetDate: date,
      );
      allUnified.addAll(summary.deduplicatedWorkouts);
    }

    allUnified.sort((a, b) => b.startTime.compareTo(a.startTime));
    return allUnified;
  }

  /// Pure deterministic aggregator for daily activity summaries.
  /// Suitable for unit tests, offline calculation, and runtime rendering.
  static UnifiedDailyActivitySummary calculateDailySummary({
    required List<Map<String, dynamic>> fitLoopLogs,
    required List<ExternalWorkoutSession> externalWorkouts,
    required DateTime targetDate,
  }) {
    // 1. Filter FitLoop workouts for the target calendar day
    final dayFitLoopLogs = <Map<String, dynamic>>[];
    int rawFitLoopCalories = 0;

    for (final log in fitLoopLogs) {
      if (DailyWorkoutSummaryService.isWorkoutOnDay(log, targetDate)) {
        dayFitLoopLogs.add(log);
        rawFitLoopCalories += DailyWorkoutSummaryService.parseWorkoutCalories(log);
      }
    }

    // 2. Filter external workouts for the target calendar day
    final startOfDay = DateTime(targetDate.year, targetDate.month, targetDate.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final dayExternalWorkouts = <ExternalWorkoutSession>[];
    int rawExternalCalories = 0;

    for (final ext in externalWorkouts) {
      final isSameDay = !ext.startTime.isBefore(startOfDay) && ext.startTime.isBefore(endOfDay);
      if (isSameDay) {
        dayExternalWorkouts.add(ext);
        rawExternalCalories += (ext.caloriesKcal ?? 0);
      }
    }

    // 3. Match and Deduplicate
    final List<UnifiedWorkoutSession> deduplicated = [];
    final Set<int> matchedExternalIndices = {};
    final Set<int> matchedFitLoopIndices = {};

    // For each FitLoop workout, see if an external workout matches >= 70% overlap & category
    for (int flIdx = 0; flIdx < dayFitLoopLogs.length; flIdx++) {
      final flLog = dayFitLoopLogs[flIdx];
      final flCompletionDate = DailyWorkoutSummaryService.parseWorkoutDate(flLog) ?? targetDate;
      final int durationSeconds = (flLog['durationSeconds'] as num?)?.toInt() ??
          (((flLog['durationMinutes'] as num?)?.toInt() ?? 30) * 60);
      final int durationMinutes = durationSeconds > 0 ? (durationSeconds / 60).round() : 30;

      final flStart = flCompletionDate.subtract(Duration(seconds: durationSeconds > 0 ? durationSeconds : 1800));
      final flEnd = flCompletionDate;

      final flRoutineName = (flLog['routineName'] ??
          flLog['workoutName'] ??
          flLog['name'] ??
          'Workout Session').toString();
      final flCategory = (flLog['category'] ??
          flLog['targetMuscle'] ??
          flRoutineName).toString();
      final flNormalizedCat = HealthCategoryNormalizer.normalize(flCategory);
      final int flCalories = DailyWorkoutSummaryService.parseWorkoutCalories(flLog);

      int? bestMatchExtIdx;
      double bestMatchOverlap = 0.0;

      for (int extIdx = 0; extIdx < dayExternalWorkouts.length; extIdx++) {
        if (matchedExternalIndices.contains(extIdx)) continue;

        final ext = dayExternalWorkouts[extIdx];

        // Check category match
        final extNormalizedCat = ext.normalizedCategory;
        final bool categoryMatches = (flNormalizedCat == extNormalizedCat) ||
            (flNormalizedCat == HealthCategoryNormalizer.other && extNormalizedCat != HealthCategoryNormalizer.other) ||
            (extNormalizedCat == HealthCategoryNormalizer.other && flNormalizedCat != HealthCategoryNormalizer.other);

        if (!categoryMatches) {
          // Different activity types occurring around same time (e.g. Strength vs Running)
          // are treated as distinct physical workouts (Case E).
          continue;
        }

        // Calculate overlap ratio
        final overlapStart = flStart.isAfter(ext.startTime) ? flStart : ext.startTime;
        final overlapEnd = flEnd.isBefore(ext.endTime) ? flEnd : ext.endTime;
        final overlapMs = math.max(0, overlapEnd.difference(overlapStart).inMilliseconds);

        final flDurationMs = flEnd.difference(flStart).inMilliseconds;
        final extDurationMs = ext.endTime.difference(ext.startTime).inMilliseconds;
        final shorterDurationMs = math.min(flDurationMs, extDurationMs);

        if (shorterDurationMs <= 0) continue;

        final overlapRatio = overlapMs / shorterDurationMs;
        if (overlapRatio >= overlapThreshold && overlapRatio > bestMatchOverlap) {
          bestMatchOverlap = overlapRatio;
          bestMatchExtIdx = extIdx;
        }
      }

      if (bestMatchExtIdx != null) {
        // Merge duplicate session!
        matchedFitLoopIndices.add(flIdx);
        matchedExternalIndices.add(bestMatchExtIdx);
        final ext = dayExternalWorkouts[bestMatchExtIdx];

        // Calorie Priority: Prefer external Health Connect calories if available & > 0
        final int resolvedCalories = (ext.caloriesKcal != null && ext.caloriesKcal! > 0)
            ? ext.caloriesKcal!
            : flCalories;

        deduplicated.add(UnifiedWorkoutSession(
          id: 'merged_${ext.id}_${flLog['id'] ?? flIdx}',
          title: flRoutineName != 'Workout Session' ? flRoutineName : ext.workoutType,
          normalizedCategory: flNormalizedCat,
          startTime: flStart.isBefore(ext.startTime) ? flStart : ext.startTime,
          endTime: flEnd.isAfter(ext.endTime) ? flEnd : ext.endTime,
          durationMinutes: math.max(durationMinutes, ext.durationMinutes),
          caloriesKcal: resolvedCalories,
          hasCalories: true,
          distanceKm: ext.distanceKm,
          source: UnifiedWorkoutSource.merged,
          externalSourceName: ext.displaySource,
          externalSourceId: ext.sourceId,
          fitLoopLogData: flLog,
        ));
      } else {
        // FitLoop-only session
        deduplicated.add(UnifiedWorkoutSession(
          id: flLog['id']?.toString() ?? 'fitloop_$flIdx',
          title: flRoutineName,
          normalizedCategory: flNormalizedCat,
          startTime: flStart,
          endTime: flEnd,
          durationMinutes: durationMinutes,
          caloriesKcal: flCalories,
          hasCalories: true,
          source: UnifiedWorkoutSource.fitLoop,
          fitLoopLogData: flLog,
        ));
      }
    }

    // 4. Add remaining external workouts that were not merged
    for (int extIdx = 0; extIdx < dayExternalWorkouts.length; extIdx++) {
      if (matchedExternalIndices.contains(extIdx)) continue;
      final ext = dayExternalWorkouts[extIdx];

      deduplicated.add(UnifiedWorkoutSession(
        id: 'ext_${ext.id}',
        title: ext.workoutType,
        normalizedCategory: ext.normalizedCategory,
        startTime: ext.startTime,
        endTime: ext.endTime,
        durationMinutes: ext.durationMinutes,
        caloriesKcal: ext.caloriesKcal ?? 0,
        hasCalories: ext.caloriesKcal != null,
        distanceKm: ext.distanceKm,
        source: UnifiedWorkoutSource.externalHealthConnect,
        externalSourceName: ext.displaySource,
        externalSourceId: ext.sourceId,
      ));
    }

    // Sort all sessions: latest first
    deduplicated.sort((a, b) => b.startTime.compareTo(a.startTime));

    // Calculate total deduplicated exercise calories
    final int totalExerciseCalories = deduplicated.fold(0, (acc, s) => acc + s.caloriesKcal);

    return UnifiedDailyActivitySummary(
      fitLoopWorkouts: dayFitLoopLogs,
      externalWorkouts: dayExternalWorkouts,
      deduplicatedWorkouts: deduplicated,
      fitLoopCalories: rawFitLoopCalories,
      externalCalories: rawExternalCalories,
      totalExerciseCalories: totalExerciseCalories,
      totalWorkoutCount: deduplicated.length,
    );
  }

  /// Consolidates Health Connect active calories and unified workout sessions into a
  /// single unified daily burn value.
  ///
  /// Prevents double-counting:
  /// - Health Connect active energy burned already encompasses wearable-recorded workouts.
  /// - Internal FitLoop-only workouts that were NOT tracked by Health Connect are safely added.
  static int calculateEffectiveBurnedCalories({
    required double activeCaloriesFromHealth,
    required UnifiedDailyActivitySummary unifiedSummary,
  }) {
    final int healthActive = activeCaloriesFromHealth.round();
    final int workoutCalories = unifiedSummary.totalExerciseCalories;

    if (healthActive > 0) {
      int nonHealthConnectCalories = 0;
      for (final s in unifiedSummary.deduplicatedWorkouts) {
        if (s.source == UnifiedWorkoutSource.fitLoop) {
          nonHealthConnectCalories += s.caloriesKcal;
        }
      }
      return math.max(healthActive, workoutCalories) + nonHealthConnectCalories;
    } else {
      return workoutCalories;
    }
  }

  /// Real-time stream of unified daily activity summary for [targetDate].
  ///
  /// Combines Firestore `workout_logs` snapshots with dynamic Health Connect
  /// exercise sessions without storing external records permanently in Firestore.
  static Stream<UnifiedDailyActivitySummary> streamDailyActivitySummary(
    String uid,
    DateTime targetDate, {
    FirebaseFirestore? firestore,
    HealthIntegrationService? healthService,
  }) {
    final db = firestore ?? FirebaseFirestore.instance;
    final health = healthService ?? HealthIntegrationService.instance;

    final controller = StreamController<UnifiedDailyActivitySummary>();
    List<ExternalWorkoutSession> cachedExternal = [];
    bool externalFetched = false;

    // Fetch external workouts from Health Connect
    void refreshExternal(List<Map<String, dynamic>> currentLogs) async {
      try {
        cachedExternal = await health.getExternalWorkoutsForDate(targetDate);
        externalFetched = true;
      } catch (e) {
        debugPrint('[UnifiedActivitySummaryService] Failed to get external workouts: $e');
        cachedExternal = [];
        externalFetched = true;
      }
      if (!controller.isClosed) {
        final summary = calculateDailySummary(
          fitLoopLogs: currentLogs,
          externalWorkouts: cachedExternal,
          targetDate: targetDate,
        );
        controller.add(summary);
      }
    }

    List<Map<String, dynamic>> latestLogs = [];

    final sub = db
        .collection('users')
        .doc(uid)
        .collection('workout_logs')
        .snapshots()
        .listen(
      (snapshot) {
        latestLogs = snapshot.docs.map((doc) {
          final data = Map<String, dynamic>.from(doc.data());
          data['id'] = doc.id;
          return data;
        }).toList();

        if (!externalFetched) {
          // Immediately emit FitLoop-only summary so UI does not block
          final initialSummary = calculateDailySummary(
            fitLoopLogs: latestLogs,
            externalWorkouts: const [],
            targetDate: targetDate,
          );
          if (!controller.isClosed) controller.add(initialSummary);
          refreshExternal(latestLogs);
        } else {
          final summary = calculateDailySummary(
            fitLoopLogs: latestLogs,
            externalWorkouts: cachedExternal,
            targetDate: targetDate,
          );
          if (!controller.isClosed) controller.add(summary);
        }
      },
      onError: (error) {
        debugPrint('[UnifiedActivitySummaryService] Firestore error: $error');
        if (!controller.isClosed) {
          controller.add(UnifiedDailyActivitySummary.empty);
        }
      },
    );

    controller.onCancel = () {
      sub.cancel();
    };

    return controller.stream;
  }
}
