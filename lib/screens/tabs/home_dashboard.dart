import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../../models/measurement_model.dart';
import '../../models/health_models.dart';
import '../../services/measurement_service.dart';
import '../../services/health_integration_service.dart';
import '../../services/daily_workout_summary_service.dart';
import '../../services/unified_activity_summary_service.dart';

// ==========================================
// HOME DASHBOARD - DAILY FITNESS OVERVIEW
// ==========================================
class HomeTab extends StatefulWidget {
  final ValueChanged<int>? onNavigateToTab;

  const HomeTab({super.key, this.onNavigateToTab});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> with WidgetsBindingObserver {
  int _waterMl = 0;

  /// Health summary — typed result from HealthIntegrationService.
  HealthSummary _healthSummary = HealthSummary.loading;
  List<ExternalWorkoutSession> _externalWorkoutsToday = [];
  bool _isSyncingHealth = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fetchHealthData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _fetchHealthData();
    }
  }

  Future<void> _fetchHealthData() async {
    if (_isSyncingHealth) return;
    if (mounted) setState(() => _isSyncingHealth = true);
    try {
      final summary = await HealthIntegrationService.instance.fetchDailySummary();
      final externalWorkouts = await HealthIntegrationService.instance.getExternalWorkoutsForDate(DateTime.now());
      if (mounted) {
        setState(() {
          _healthSummary = summary;
          _externalWorkoutsToday = externalWorkouts;
          _isSyncingHealth = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isSyncingHealth = false);
    }
  }

  void _adjustWater(int delta) {
    setState(() {
      _waterMl += delta;
      if (_waterMl < 0) _waterMl = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text("Please sign in to view your dashboard.")),
      );
    }

    final String uid = user.uid;
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    final startOfWeek = startOfDay.subtract(const Duration(days: 6));

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
        builder: (context, userSnapshot) {
          if (userSnapshot.connectionState == ConnectionState.waiting && !userSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: Colors.teal));
          }

          final userData = userSnapshot.data?.data() ?? {};
          final String name = userData['name']?.toString() ?? "Athlete";
          final int calorieTarget = (userData['calorieTarget'] ?? userData['dailyCaloriesTarget'] as num?)?.toInt() ?? 2000;
          final int streak = (userData['currentStreak'] ?? userData['streak'] as num?)?.toInt() ?? 0;
          final String goal = (userData['fitnessGoal'] ?? userData['goal'] ?? "Maintenance").toString();
          final double userWeightKg = (userData['weight'] as num?)?.toDouble() ?? 70.0;
          final double targetWeightKg = (userData['targetWeight'] as num?)?.toDouble() ?? userWeightKg;

          bool isMetric = true;
          if (userData['units'] is Map && userData['units']['isMetric'] is bool) {
            isMetric = userData['units']['isMetric'] as bool;
          } else if (userData['isMetric'] is bool) {
            isMetric = userData['isMetric'] as bool;
          }

          // Macro target calculation based on fitness goal
          double proRatio = 0.3;
          double carbRatio = 0.4;
          double fatRatio = 0.3;

          final goalLower = goal.toLowerCase();
          if (goalLower.contains("loss") || goalLower.contains("cut") || goalLower.contains("减脂")) {
            proRatio = 0.4;
            carbRatio = 0.3;
            fatRatio = 0.3;
          } else if (goalLower.contains("gain") || goalLower.contains("bulk") || goalLower.contains("增肌")) {
            proRatio = 0.3;
            carbRatio = 0.5;
            fatRatio = 0.2;
          }

          final double targetProGrams = (calorieTarget * proRatio) / 4;
          final double targetCarbGrams = (calorieTarget * carbRatio) / 4;
          final double targetFatGrams = (calorieTarget * fatRatio) / 9;

          return SafeArea(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(uid)
                  .collection('food_logs')
                  .where('timestamp', isGreaterThanOrEqualTo: startOfWeek)
                  .where('timestamp', isLessThan: endOfDay)
                  .snapshots(),
              builder: (context, foodSnapshot) {
                int eatenCalories = 0;
                int totalPro = 0;
                int totalCarbs = 0;
                int totalFat = 0;
                int todayMealsCount = 0;
                int weeklyMealsCount = 0;

                if (foodSnapshot.hasData && foodSnapshot.data!.docs.isNotEmpty) {
                  weeklyMealsCount = foodSnapshot.data!.docs.length;
                  for (var doc in foodSnapshot.data!.docs) {
                    final data = doc.data();
                    DateTime? ts;
                    if (data['timestamp'] is Timestamp) {
                      ts = (data['timestamp'] as Timestamp).toDate();
                    }
                    final bool isToday = ts != null && !ts.isBefore(startOfDay) && ts.isBefore(endOfDay);
                    if (isToday) {
                      todayMealsCount++;
                      eatenCalories += (data['calories'] as num?)?.toInt() ?? 0;
                      totalPro += ((data['protein'] ?? data['proteins'] ?? 0) as num).toInt();
                      totalCarbs += ((data['carbs'] ?? 0) as num).toInt();
                      totalFat += ((data['fat'] ?? data['fats'] ?? 0) as num).toInt();
                    }
                  }
                }

                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(uid)
                      .collection('workout_logs')
                      .where('timestamp', isGreaterThanOrEqualTo: startOfWeek)
                      .where('timestamp', isLessThan: endOfDay)
                      .snapshots(),
                  builder: (context, workoutSnapshot) {
                    final List<Map<String, dynamic>> allLogs = [];
                    int weeklyWorkoutsCount = 0;
                    int weeklyBurnedCalories = 0;

                    if (workoutSnapshot.hasData && workoutSnapshot.data!.docs.isNotEmpty) {
                      weeklyWorkoutsCount = workoutSnapshot.data!.docs.length;
                      for (var doc in workoutSnapshot.data!.docs) {
                        final data = Map<String, dynamic>.from(doc.data());
                        data['id'] = doc.id;
                        allLogs.add(data);
                        weeklyBurnedCalories += DailyWorkoutSummaryService.parseWorkoutCalories(data);
                      }
                    }

                    // Unified workout summary (FitLoop + Health Connect external workouts)
                    final unifiedToday = UnifiedActivitySummaryService.calculateDailySummary(
                      fitLoopLogs: allLogs,
                      externalWorkouts: _externalWorkoutsToday,
                      targetDate: now,
                    );

                    final int burnedCalories = UnifiedActivitySummaryService.calculateEffectiveBurnedCalories(
                      activeCaloriesFromHealth: _healthSummary.activeCaloriesKcal,
                      unifiedSummary: unifiedToday,
                    );

                    // Calories Math
                    final int netCalories = eatenCalories - burnedCalories;
                    final int remainingCalories = calorieTarget - netCalories;
                    final double calorieProgress = calorieTarget > 0 ? (netCalories / calorieTarget).clamp(0.0, 1.0) : 0.0;

                    return StreamBuilder<List<BodyMeasurement>>(
                      stream: MeasurementService.streamMeasurements(uid),
                      builder: (context, measureSnapshot) {
                        final measurements = measureSnapshot.data ?? [];

                        return RefreshIndicator(
                          color: Colors.teal,
                          onRefresh: () async {
                            await _fetchHealthData();
                          },
                          child: ListView(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            children: [
                              // A. GREETING / TODAY HEADER
                              _buildGreetingHeader(
                                name: name,
                                date: now,
                                streak: streak,
                                goal: goal,
                              ),

                              const SizedBox(height: 16),

                              // B & C. TODAY'S NUTRITION & ENERGY SUMMARY
                              _buildNutritionAndEnergySummaryCard(
                                calorieTarget: calorieTarget,
                                eatenCalories: eatenCalories,
                                burnedCalories: burnedCalories,
                                netCalories: netCalories,
                                remainingCalories: remainingCalories,
                                calorieProgress: calorieProgress,
                                todayMealsCount: todayMealsCount,
                                totalPro: totalPro,
                                targetProGrams: targetProGrams,
                                totalCarbs: totalCarbs,
                                targetCarbGrams: targetCarbGrams,
                                totalFat: totalFat,
                                targetFatGrams: targetFatGrams,
                              ),

                              const SizedBox(height: 16),

                              // D. WEIGHT PROGRESS
                              _buildWeightProgressCard(
                                userWeightKg: userWeightKg,
                                targetWeightKg: targetWeightKg,
                                isMetric: isMetric,
                                measurements: measurements,
                                goal: goal,
                              ),

                              const SizedBox(height: 16),

                              // E. ACTIVITY & HEALTH SUMMARY
                              _buildActivityAndHealthSection(
                                streak: streak,
                                unifiedToday: unifiedToday,
                              ),

                              const SizedBox(height: 16),

                              // F. WEEKLY SNAPSHOT
                              _buildWeeklySnapshotCard(
                                weeklyWorkoutsCount: weeklyWorkoutsCount,
                                weeklyMealsCount: weeklyMealsCount,
                                weeklyBurnedCalories: weeklyBurnedCalories,
                                measurements: measurements,
                                isMetric: isMetric,
                              ),

                              const SizedBox(height: 24),
                            ],
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }

  // --- A. GREETING / TODAY HEADER ---
  Widget _buildGreetingHeader({
    required String name,
    required DateTime date,
    required int streak,
    required String goal,
  }) {
    final String formattedDate = DateFormat('EEEE, MMM d').format(date);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Hi, $name 👋",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                  letterSpacing: -0.3,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Text(
                    formattedDate,
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (goal.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Text("•", style: TextStyle(color: Theme.of(context).colorScheme.outlineVariant)),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        goal,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.orange.shade400, Colors.deepOrange.shade500],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.orange.withValues(alpha: 0.25),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.local_fire_department, color: Colors.white, size: 18),
              const SizedBox(width: 4),
              Text(
                "$streak Day${streak == 1 ? '' : 's'}",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- B & C. TODAY'S NUTRITION & ENERGY SUMMARY CARD ---
  Widget _buildNutritionAndEnergySummaryCard({
    required int calorieTarget,
    required int eatenCalories,
    required int burnedCalories,
    required int netCalories,
    required int remainingCalories,
    required double calorieProgress,
    required int todayMealsCount,
    required int totalPro,
    required double targetProGrams,
    required int totalCarbs,
    required double targetCarbGrams,
    required int totalFat,
    required double targetFatGrams,
  }) {
    final bool isOverTarget = remainingCalories < 0;
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: theme.brightness == Brightness.dark ? 0.25 : 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bolt_rounded, color: theme.colorScheme.primary, size: 20),
              const SizedBox(width: 6),
              Text(
                "Today's Energy & Nutrition",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: theme.colorScheme.onSurface),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Calorie Main Ring & Remaining
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isOverTarget ? "Calories Over Target" : "Calories Remaining",
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "${remainingCalories.abs()}",
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          color: isOverTarget
                              ? Colors.redAccent
                              : (theme.brightness == Brightness.dark
                                  ? const Color(0xFF2DD4BF)
                                  : Colors.teal.shade800),
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    Text(
                      "Target: $calorieTarget kcal",
                      style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 76,
                    height: 76,
                    child: CircularProgressIndicator(
                      value: calorieProgress,
                      backgroundColor: theme.colorScheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isOverTarget ? Colors.redAccent : theme.colorScheme.primary,
                      ),
                      strokeWidth: 8,
                      strokeCap: StrokeCap.round,
                    ),
                  ),
                  Text(
                    "${(calorieProgress * 100).toInt()}%",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: theme.colorScheme.onSurface),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Energy Summary Equation: In - Burned = Net
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildEnergyItem("Calories In", "$eatenCalories kcal", Icons.restaurant, Colors.orange),
                Text("-", style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold)),
                _buildEnergyItem("Calories Burned", "$burnedCalories kcal", Icons.local_fire_department, Colors.purple),
                Text("=", style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold)),
                _buildEnergyItem("Net Energy", "$netCalories kcal", Icons.speed, theme.colorScheme.primary),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Empty state or Macro Progress Bars
          if (todayMealsCount == 0)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              alignment: Alignment.center,
              child: Text(
                "No meals logged yet today.",
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12, fontStyle: FontStyle.italic),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: _buildMacroProgress(
                    label: "Protein",
                    current: totalPro.toDouble(),
                    target: targetProGrams,
                    color: Colors.purple,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMacroProgress(
                    label: "Carbs",
                    current: totalCarbs.toDouble(),
                    target: targetCarbGrams,
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMacroProgress(
                    label: "Fat",
                    current: totalFat.toDouble(),
                    target: targetFatGrams,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildEnergyItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 3),
            Text(label, style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
      ],
    );
  }

  Widget _buildMacroProgress({
    required String label,
    required double current,
    required double target,
    required Color color,
  }) {
    final double safeTarget = target > 0 ? target : 1.0;
    final double progress = (current / safeTarget).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
            ),
            Text(
              "${current.toInt()}g",
              style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: color.withValues(alpha: 0.15),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 5,
          ),
        ),
      ],
    );
  }

  // --- D. WEIGHT PROGRESS CARD ---
  Widget _buildWeightProgressCard({
    required double userWeightKg,
    required double targetWeightKg,
    required bool isMetric,
    required List<BodyMeasurement> measurements,
    required String goal,
  }) {
    final String unit = isMetric ? 'kg' : 'lbs';
    final double displayCurrentWeight = isMetric ? userWeightKg : (userWeightKg * 2.20462);
    final double displayTargetWeight = isMetric ? targetWeightKg : (targetWeightKg * 2.20462);

    final double diff = displayCurrentWeight - displayTargetWeight;
    final bool isWeightLoss = goal.toLowerCase().contains("loss") || goal.toLowerCase().contains("cut");
    final bool isMuscleGain = goal.toLowerCase().contains("gain") || goal.toLowerCase().contains("bulk");

    String remainingText = "On Target";
    double progress = 1.0;

    if (isWeightLoss) {
      if (diff > 0) {
        remainingText = "${diff.toStringAsFixed(1)} $unit to lose";
        progress = (displayTargetWeight / displayCurrentWeight).clamp(0.0, 1.0);
      } else {
        remainingText = "Goal achieved! 🎉";
        progress = 1.0;
      }
    } else if (isMuscleGain) {
      if (diff < 0) {
        remainingText = "${(-diff).toStringAsFixed(1)} $unit to gain";
        progress = (displayCurrentWeight / displayTargetWeight).clamp(0.0, 1.0);
      } else {
        remainingText = "Goal achieved! 🎉";
        progress = 1.0;
      }
    }

    // Check recent weight change from measurements
    String? recentChangeText;
    if (measurements.length >= 2) {
      final withWeight = measurements.where((m) => m.weight != null && m.weight! > 0).toList()
        ..sort((a, b) => a.date.compareTo(b.date));
      if (withWeight.length >= 2) {
        final double firstW = isMetric ? withWeight.first.weight! : (withWeight.first.weight! * 2.20462);
        final double lastW = isMetric ? withWeight.last.weight! : (withWeight.last.weight! * 2.20462);
        final double change = lastW - firstW;
        final String sign = change > 0 ? "+" : "";
        recentChangeText = "$sign${change.toStringAsFixed(1)} $unit recent";
      }
    }

    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: theme.brightness == Brightness.dark ? 0.25 : 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.monitor_weight_outlined, color: theme.colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              Text("Weight Progress", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: theme.colorScheme.onSurface)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("CURRENT", style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(
                    "${displayCurrentWeight.toStringAsFixed(1)} $unit",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
                  ),
                ],
              ),
              Icon(Icons.arrow_forward, color: theme.colorScheme.onSurfaceVariant, size: 18),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text("TARGET", style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(
                    "${displayTargetWeight.toStringAsFixed(1)} $unit",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                remainingText,
                style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600),
              ),
              if (recentChangeText != null)
                Text(
                  recentChangeText,
                  style: TextStyle(fontSize: 11, color: theme.colorScheme.primary, fontWeight: FontWeight.w600),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // --- E. ACTIVITY & HEALTH SUMMARY ---
  Widget _buildActivityAndHealthSection({
    required int streak,
    UnifiedDailyActivitySummary? unifiedToday,
  }) {
    final status = _healthSummary.status;
    final bool isConnected = status.isHealthy;
    final theme = Theme.of(context);

    // Derive badge color/icon/label from typed status
    Color badgeBg;
    Color badgeBorder;
    Color badgeTextColor;
    IconData badgeIcon;
    String badgeLabel;
    switch (status) {
      case HealthConnectStatus.connected:
        badgeBg = Colors.green.shade50;
        badgeBorder = Colors.green.shade200;
        badgeTextColor = Colors.green.shade800;
        badgeIcon = Icons.watch_rounded;
        badgeLabel = 'Health Synced';
      case HealthConnectStatus.noData:
        badgeBg = Colors.blue.shade50;
        badgeBorder = Colors.blue.shade200;
        badgeTextColor = Colors.blue.shade800;
        badgeIcon = Icons.watch_rounded;
        badgeLabel = 'No Data Today';
      case HealthConnectStatus.permissionRequired:
        badgeBg = Colors.orange.shade50;
        badgeBorder = Colors.orange.shade200;
        badgeTextColor = Colors.orange.shade800;
        badgeIcon = Icons.lock_outline_rounded;
        badgeLabel = 'Permission Needed';
      case HealthConnectStatus.notInstalled:
        badgeBg = Colors.grey.shade100;
        badgeBorder = Colors.grey.shade300;
        badgeTextColor = Colors.grey.shade700;
        badgeIcon = Icons.watch_off_rounded;
        badgeLabel = 'HC Not Installed';
      case HealthConnectStatus.notSupported:
      case HealthConnectStatus.error:
        badgeBg = Colors.grey.shade100;
        badgeBorder = Colors.grey.shade300;
        badgeTextColor = Colors.grey.shade600;
        badgeIcon = Icons.watch_off_rounded;
        badgeLabel = 'Health Unlinked';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text("Activity & Health", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: theme.colorScheme.onSurface)),
                const SizedBox(width: 6),
                InkWell(
                  onTap: _isSyncingHealth ? null : _fetchHealthData,
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: _isSyncingHealth
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.teal),
                          )
                        : Icon(Icons.sync_rounded, size: 16, color: theme.colorScheme.primary),
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: badgeBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: badgeBorder),
              ),
              child: Row(
                children: [
                  Icon(badgeIcon, size: 12, color: badgeTextColor),
                  const SizedBox(width: 4),
                  Text(
                    badgeLabel,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: badgeTextColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Steps, Sleep, Streak Tracker Row
        Row(
          children: [
            Expanded(
              child: _buildMiniTracker(
                Icons.directions_walk_rounded,
                "Steps Today",
                isConnected && _healthSummary.todaySteps > 0
                    ? '${_healthSummary.todaySteps}'
                    : '--',
                Colors.orange,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildMiniTracker(
                Icons.bedtime_rounded,
                "Sleep",
                isConnected && _healthSummary.sleepHours > 0
                    ? _healthSummary.formattedSleep
                    : '--',
                Colors.purple,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildMiniTracker(
                Icons.local_fire_department,
                "Streak",
                "$streak d",
                Colors.deepOrange,
              ),
            ),
          ],
        ),

        // Heart Rate & Distance row — only shown when connected
        if (isConnected && (_healthSummary.latestHeartRateBpm != null || _healthSummary.distanceKm > 0)) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              if (_healthSummary.latestHeartRateBpm != null)
                Expanded(
                  child: _buildMiniTracker(
                    Icons.favorite_rounded,
                    "Heart Rate",
                    '${_healthSummary.latestHeartRateBpm!.toInt()} bpm',
                    Colors.red,
                  ),
                ),
              if (_healthSummary.latestHeartRateBpm != null && _healthSummary.distanceKm > 0)
                const SizedBox(width: 8),
              if (_healthSummary.distanceKm > 0)
                Expanded(
                  child: _buildMiniTracker(
                    Icons.route_rounded,
                    "Distance",
                    '${_healthSummary.distanceKm} km',
                    theme.colorScheme.primary,
                  ),
                ),
            ],
          ),
        ],

        if (unifiedToday != null && unifiedToday.totalWorkoutCount > 0) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.fitness_center_rounded, size: 16, color: Colors.teal.shade700),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "${unifiedToday.totalWorkoutCount} Workout${unifiedToday.totalWorkoutCount > 1 ? 's' : ''} Today",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "${unifiedToday.totalExerciseCalories} kcal burned • Unified activity",
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (unifiedToday.externalWorkouts.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.watch_rounded, size: 10, color: Colors.green.shade800),
                        const SizedBox(width: 3),
                        Text(
                          "Synced",
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green.shade800),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 10),

        // Hydration Card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.water_drop, color: Colors.blueAccent, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Hydration", style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w500)),
                          Text(
                            "${(_waterMl / 1000).toStringAsFixed(2)}L / 2.5L",
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: theme.colorScheme.onSurface),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildWaterButton("+100 ml", 100),
                    const SizedBox(width: 8),
                    _buildWaterButton("+250 ml", 250),
                    const SizedBox(width: 8),
                    _buildWaterButton("+500 ml", 500),
                    const SizedBox(width: 8),
                    _buildWaterButton("-100 ml", -100, isSubtract: true),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- F. WEEKLY SNAPSHOT CARD ---
  Widget _buildWeeklySnapshotCard({
    required int weeklyWorkoutsCount,
    required int weeklyMealsCount,
    required int weeklyBurnedCalories,
    required List<BodyMeasurement> measurements,
    required bool isMetric,
  }) {
    final theme = Theme.of(context);
    final String unit = isMetric ? 'kg' : 'lbs';
    String weightChangeText = "--";

    if (measurements.length >= 2) {
      final withWeight = measurements.where((m) => m.weight != null && m.weight! > 0).toList()
        ..sort((a, b) => a.date.compareTo(b.date));
      if (withWeight.length >= 2) {
        final double firstW = isMetric ? withWeight.first.weight! : (withWeight.first.weight! * 2.20462);
        final double lastW = isMetric ? withWeight.last.weight! : (withWeight.last.weight! * 2.20462);
        final double change = lastW - firstW;
        final String sign = change > 0 ? "+" : "";
        weightChangeText = "$sign${change.toStringAsFixed(1)} $unit";
      }
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: theme.brightness == Brightness.dark ? 0.25 : 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.calendar_view_week_rounded, color: theme.colorScheme.primary, size: 20),
                  const SizedBox(width: 8),
                  Text("Weekly Snapshot", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: theme.colorScheme.onSurface)),
                ],
              ),
              Text(
                "Past 7 Days",
                style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildWeeklyMetric(
                  icon: Icons.fitness_center_rounded,
                  label: "Workouts",
                  value: "$weeklyWorkoutsCount",
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildWeeklyMetric(
                  icon: Icons.restaurant_menu_rounded,
                  label: "Meals Logged",
                  value: "$weeklyMealsCount",
                  color: Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildWeeklyMetric(
                  icon: Icons.local_fire_department_rounded,
                  label: "Calories Burned",
                  value: "$weeklyBurnedCalories kcal",
                  color: Colors.purple,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildWeeklyMetric(
                  icon: Icons.show_chart_rounded,
                  label: "Weight Change",
                  value: weightChangeText,
                  color: Colors.blueAccent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyMetric({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaterButton(String label, int amount, {bool isSubtract = false}) {
    return InkWell(
      onTap: () => _adjustWater(amount),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSubtract ? Colors.red.shade50 : Colors.blue.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSubtract ? Colors.red.shade200 : Colors.blue.shade200),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isSubtract ? Colors.red.shade700 : Colors.blue.shade700,
          ),
        ),
      ),
    );
  }

  Widget _buildMiniTracker(IconData icon, String title, String value, Color color) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(
            title,
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 10, fontWeight: FontWeight.w500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}