// ============================================================
// HEALTH MODELS
// Clean data models for the Health Connect integration layer.
// These are app-level models; they do NOT depend on the health
// package so they can be tested without a device.
// ============================================================

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
