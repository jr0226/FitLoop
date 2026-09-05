// ============================================================
// HEALTH MODELS
// Clean data models for the Health Connect integration layer.
// These are app-level models; they do NOT depend on the health
// package so they can be tested without a device.
// ============================================================

import 'workout_models.dart';

/// All possible states for the Health Connect connection.
enum HealthConnectStatus {
  /// Health Connect is available, all requested permissions granted, data loaded.
  connected,

  /// Health Connect is available and permissions are granted, but no data was
  /// found in the requested time window.
  noData,

  /// Health Connect is available but at least one requested permission
  /// has not been granted. User needs to go to Health Connect settings.
  permissionRequired,

  /// Health Connect is not installed (Android <= 13 without the separate app).
  /// Guide user to Play Store to install it.
  notInstalled,

  /// The device does not support Health Connect at all (very old Android).
  notSupported,

  /// An unexpected error occurred during a Health Connect operation.
  error,
}

/// Human-readable label for a [HealthConnectStatus].
extension HealthConnectStatusLabel on HealthConnectStatus {
  String get displayLabel {
    switch (this) {
      case HealthConnectStatus.connected:
        return 'Health Synced';
      case HealthConnectStatus.noData:
        return 'No Data Available';
      case HealthConnectStatus.permissionRequired:
        return 'Permission Required';
      case HealthConnectStatus.notInstalled:
        return 'Health Connect Not Installed';
      case HealthConnectStatus.notSupported:
        return 'Not Supported';
      case HealthConnectStatus.error:
        return 'Sync Error';
    }
  }

  String get description {
    switch (this) {
      case HealthConnectStatus.connected:
        return 'FitLoop is reading your health data from Health Connect.';
      case HealthConnectStatus.noData:
        return 'Health Connect is connected but no data was found for today.';
      case HealthConnectStatus.permissionRequired:
        return 'Please grant FitLoop access in Health Connect settings.';
      case HealthConnectStatus.notInstalled:
        return 'Install Health Connect from Google Play to sync your health data.';
      case HealthConnectStatus.notSupported:
        return 'Your device does not support Health Connect.';
      case HealthConnectStatus.error:
        return 'Could not read health data. Please try again.';
    }
  }

  bool get isHealthy =>
      this == HealthConnectStatus.connected ||
      this == HealthConnectStatus.noData;
}

/// A single workout session read from Health Connect.
class HealthWorkoutSession {
  final String activityType;
  final DateTime startTime;
  final DateTime endTime;
  final double? caloriesBurned;
  final double? distanceKm;

  const HealthWorkoutSession({
    required this.activityType,
    required this.startTime,
    required this.endTime,
    this.caloriesBurned,
    this.distanceKm,
  });

  Duration get duration => endTime.difference(startTime);

  String get formattedDuration {
    final mins = duration.inMinutes;
    if (mins < 60) return '${mins}m';
    final h = mins ~/ 60;
    final m = mins % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }
}

/// Category normalization helper mapping diverse Health Connect and FitLoop
/// workout types to broad standardized categories.
class HealthCategoryNormalizer {
  HealthCategoryNormalizer._();

  static const String running = 'Running';
  static const String walking = 'Walking';
  static const String cycling = 'Cycling';
  static const String cardio = 'Cardio';
  static const String strengthTraining = 'Strength Training';
  static const String hiit = 'HIIT';
  static const String yoga = 'Yoga';
  static const String swimming = 'Swimming';
  static const String other = 'Other';

  static String normalize(String? rawType) {
    if (rawType == null || rawType.trim().isEmpty) return other;
    final lower = rawType.toLowerCase().replaceAll('_', ' ').trim();

    if (lower.contains('run') || lower.contains('jog') || lower.contains('treadmill')) {
      return running;
    }
    if (lower.contains('walk') || lower.contains('hike') || lower.contains('hiking') || lower.contains('stroll')) {
      return walking;
    }
    if (lower.contains('cycl') || lower.contains('bike') || lower.contains('biking') || lower.contains('spin')) {
      return cycling;
    }
    if (lower.contains('swim')) {
      return swimming;
    }
    if (lower.contains('yoga') || lower.contains('pilates') || lower.contains('stretch') || lower.contains('flexibility')) {
      return yoga;
    }
    if (lower.contains('hiit') || lower.contains('tabata') || lower.contains('interval') || lower.contains('circuit')) {
      return hiit;
    }
    if (lower.contains('strength') ||
        lower.contains('weight') ||
        lower.contains('lifting') ||
        lower.contains('bodyweight') ||
        lower.contains('calisthenic') ||
        lower.contains('gym') ||
        lower.contains('crossfit') ||
        lower.contains('upper body') ||
        lower.contains('lower body') ||
        lower.contains('full body') ||
        lower.contains('chest') ||
        lower.contains('back') ||
        lower.contains('legs') ||
        lower.contains('arms') ||
        lower.contains('shoulder') ||
        lower.contains('core') ||
        lower.contains('abs')) {
      return strengthTraining;
    }
    if (lower.contains('cardio') ||
        lower.contains('aerobic') ||
        lower.contains('elliptical') ||
        lower.contains('rowing') ||
        lower.contains('stair') ||
        lower.contains('rope')) {
      return cardio;
    }

    return other;
  }
}

/// Normalized representation of an external exercise session read from Android Health Connect.
/// Source-independent: preserves sourceName / sourceId for display only.
class ExternalWorkoutSession {
  final String id;
  final String workoutType;
  final String normalizedCategory;
  final DateTime startTime;
  final DateTime endTime;
  final int durationMinutes;
  final int? caloriesKcal;
  final double? distanceKm;
  final String? sourceName;
  final String? sourceId;

  const ExternalWorkoutSession({
    required this.id,
    required this.workoutType,
    required this.normalizedCategory,
    required this.startTime,
    required this.endTime,
    required this.durationMinutes,
    this.caloriesKcal,
    this.distanceKm,
    this.sourceName,
    this.sourceId,
  });

  /// Formatted duration (e.g., "36m", "1h 15m").
  String get formattedDuration {
    if (durationMinutes < 60) return '${durationMinutes}m';
    final h = durationMinutes ~/ 60;
    final m = durationMinutes % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }

  /// Reliable source display label (e.g. "Samsung Health" or fallback "Health Connect").
  String get displaySource {
    final src = sourceName?.trim();
    if (src != null && src.isNotEmpty && src.toLowerCase() != 'unknown') {
      return src;
    }
    return 'Health Connect';
  }
}

/// Provenance of a unified workout session.
enum UnifiedWorkoutSource {
  fitLoop,
  externalHealthConnect,
  merged,
}

/// A unified workout session (either FitLoop-only, HealthConnect-only, or merged duplicate).
class UnifiedWorkoutSession {
  final String id;
  final String title;
  final String normalizedCategory;
  final DateTime startTime;
  final DateTime endTime;
  final int durationMinutes;
  final int caloriesKcal;
  final bool hasCalories;
  final double? distanceKm;
  final UnifiedWorkoutSource source;
  final String? externalSourceName;
  final String? externalSourceId;
  final Map<String, dynamic>? fitLoopLogData;

  const UnifiedWorkoutSession({
    required this.id,
    required this.title,
    required this.normalizedCategory,
    required this.startTime,
    required this.endTime,
    required this.durationMinutes,
    required this.caloriesKcal,
    this.hasCalories = true,
    this.distanceKm,
    required this.source,
    this.externalSourceName,
    this.externalSourceId,
    this.fitLoopLogData,
  });

  bool get isExternalOnly => source == UnifiedWorkoutSource.externalHealthConnect;
  bool get isFitLoopOnly => source == UnifiedWorkoutSource.fitLoop;
  bool get isMerged => source == UnifiedWorkoutSource.merged;

  String get displaySource {
    switch (source) {
      case UnifiedWorkoutSource.fitLoop:
        return 'FitLoop';
      case UnifiedWorkoutSource.externalHealthConnect:
        final src = externalSourceName?.trim();
        if (src != null && src.isNotEmpty && src.toLowerCase() != 'unknown') {
          return src;
        }
        return 'Health Connect';
      case UnifiedWorkoutSource.merged:
        final src = externalSourceName?.trim();
        if (src != null && src.isNotEmpty && src.toLowerCase() != 'unknown') {
          return 'FitLoop + $src';
        }
        return 'FitLoop + Health Connect';
    }
  }

  String get formattedDuration {
    if (durationMinutes < 60) return '${durationMinutes}m';
    final h = durationMinutes ~/ 60;
    final m = durationMinutes % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }

  /// Converts this unified session into a [WorkoutHistorySession] for UI rendering.
  WorkoutHistorySession toWorkoutHistorySession() {
    final exercisesRaw = fitLoopLogData?['exercises'] as List?;
    final exercises = exercisesRaw != null
        ? exercisesRaw
            .map((e) => CompletedExerciseLog.fromMap(Map<String, dynamic>.from(e)))
            .toList()
        : <CompletedExerciseLog>[];

    final prBadgesRaw = fitLoopLogData?['prBadges'] as List?;
    final prBadges = prBadgesRaw != null
        ? prBadgesRaw.map((e) => e.toString()).toList()
        : <String>[];

    return WorkoutHistorySession(
      id: id,
      routineName: title,
      category: normalizedCategory,
      date: startTime,
      durationMinutes: durationMinutes,
      caloriesBurned: caloriesKcal,
      exercises: exercises,
      prBadges: prBadges,
      isExternal: isExternalOnly,
      sourceName: externalSourceName ?? (isExternalOnly ? 'Health Connect' : null),
      distanceKm: distanceKm,
      isMerged: isMerged,
      hasCalories: hasCalories,
    );
  }
}

/// Aggregated unified daily activity summary. Single source of truth for exercise data.
class UnifiedDailyActivitySummary {
  final List<Map<String, dynamic>> fitLoopWorkouts;
  final List<ExternalWorkoutSession> externalWorkouts;
  final List<UnifiedWorkoutSession> deduplicatedWorkouts;
  final int fitLoopCalories;
  final int externalCalories;
  final int totalExerciseCalories;
  final int totalWorkoutCount;

  const UnifiedDailyActivitySummary({
    this.fitLoopWorkouts = const [],
    this.externalWorkouts = const [],
    this.deduplicatedWorkouts = const [],
    this.fitLoopCalories = 0,
    this.externalCalories = 0,
    this.totalExerciseCalories = 0,
    this.totalWorkoutCount = 0,
  });

  static const UnifiedDailyActivitySummary empty = UnifiedDailyActivitySummary();
}

/// Aggregated health summary for display in the Home Dashboard and Settings.
class HealthSummary {
  final HealthConnectStatus status;
  final int todaySteps;
  final double activeCaloriesKcal;
  final double? latestHeartRateBpm;
  final double sleepHours;
  final double distanceKm;
  final List<HealthWorkoutSession> recentWorkouts;
  final String? errorMessage;
  final DateTime? fetchedAt;

  const HealthSummary({
    required this.status,
    this.todaySteps = 0,
    this.activeCaloriesKcal = 0.0,
    this.latestHeartRateBpm,
    this.sleepHours = 0.0,
    this.distanceKm = 0.0,
    this.recentWorkouts = const [],
    this.errorMessage,
    this.fetchedAt,
  });

  /// Empty loading placeholder.
  static const HealthSummary loading = HealthSummary(
    status: HealthConnectStatus.notSupported,
  );

  /// Not-installed state.
  static const HealthSummary notInstalled = HealthSummary(
    status: HealthConnectStatus.notInstalled,
  );

  /// Permission-denied state.
  static const HealthSummary permissionRequired = HealthSummary(
    status: HealthConnectStatus.permissionRequired,
  );

  bool get hasAnyData =>
      todaySteps > 0 ||
      activeCaloriesKcal > 0 ||
      latestHeartRateBpm != null ||
      sleepHours > 0 ||
      distanceKm > 0 ||
      recentWorkouts.isNotEmpty;

  /// Formats sleep duration to human-friendly hours and minutes (e.g. 7h 30m, 45m, 8h).
  /// Avoids awkward decimal representations (e.g. 7.5h or 7.6h).
  String get formattedSleep {
    if (sleepHours <= 0) return '--';
    final totalMinutes = (sleepHours * 60).round();
    if (totalMinutes <= 0) return '--';

    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;

    if (h == 0) {
      return '${m}m';
    } else if (m == 0) {
      return '${h}h';
    } else {
      return '${h}h ${m}m';
    }
  }

  HealthSummary copyWith({
    HealthConnectStatus? status,
    int? todaySteps,
    double? activeCaloriesKcal,
    double? latestHeartRateBpm,
    double? sleepHours,
    double? distanceKm,
    List<HealthWorkoutSession>? recentWorkouts,
    String? errorMessage,
    DateTime? fetchedAt,
  }) {
    return HealthSummary(
      status: status ?? this.status,
      todaySteps: todaySteps ?? this.todaySteps,
      activeCaloriesKcal: activeCaloriesKcal ?? this.activeCaloriesKcal,
      latestHeartRateBpm: latestHeartRateBpm ?? this.latestHeartRateBpm,
      sleepHours: sleepHours ?? this.sleepHours,
      distanceKm: distanceKm ?? this.distanceKm,
      recentWorkouts: recentWorkouts ?? this.recentWorkouts,
      errorMessage: errorMessage ?? this.errorMessage,
      fetchedAt: fetchedAt ?? this.fetchedAt,
    );
  }
}
