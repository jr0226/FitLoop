import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/measurement_model.dart';
import '../services/measurement_service.dart';

class ProgressMeasurementsScreen extends StatefulWidget {
  const ProgressMeasurementsScreen({super.key});

  @override
  State<ProgressMeasurementsScreen> createState() => _ProgressMeasurementsScreenState();
}

class _ProgressMeasurementsScreenState extends State<ProgressMeasurementsScreen> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  String _selectedTimeframe = 'All Time'; // '7 Entries', '30 Days', 'All Time'

  void _showAddMeasurementModal(BuildContext context, {required bool isMetric, required double currentWeightKg}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => _AddMeasurementSheet(
        isMetric: isMetric,
        currentWeightKg: currentWeightKg,
        uid: currentUser!.uid,
      ),
    );
  }

  void _confirmDeleteMeasurement(BuildContext context, BodyMeasurement m) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline, color: Colors.redAccent),
            SizedBox(width: 8),
            Text("Delete Entry?"),
          ],
        ),
        content: Text("Are you sure you want to delete this measurement from ${DateFormat('MMM d, yyyy').format(m.date)}?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              try {
                await MeasurementService.deleteMeasurement(
                  uid: currentUser!.uid,
                  measurementId: m.id,
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Measurement deleted.")));
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to delete: $e")));
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  List<BodyMeasurement> _filterMeasurements(List<BodyMeasurement> all) {
    if (_selectedTimeframe == '7 Entries') {
      return all.take(7).toList();
    } else if (_selectedTimeframe == '30 Days') {
      final cutoff = DateTime.now().subtract(const Duration(days: 30));
      return all.where((m) => m.date.isAfter(cutoff)).toList();
    }
    return all;
  }

  @override
  Widget build(BuildContext context) {
    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Body Progress")),
        body: const Center(child: Text("Please sign in to view measurements.")),
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).snapshots(),
      builder: (context, userSnapshot) {
        if (userSnapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text("Body Progress")),
            body: Center(child: Text("Error loading profile: ${userSnapshot.error}")),
          );
        }

        if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
          return Scaffold(
            appBar: AppBar(title: const Text("Body Progress")),
            body: const Center(child: CircularProgressIndicator(color: Colors.teal)),
          );
        }

        final userData = userSnapshot.data!.data() ?? {};
        final double currentWeightKg = (userData['weight'] as num?)?.toDouble() ?? 70.0;
        final double targetWeightKg = (userData['targetWeight'] as num?)?.toDouble() ?? currentWeightKg;
        final String goal = (userData['fitnessGoal'] ?? userData['goal'] ?? 'Maintenance').toString();

        bool isMetric = true;
        if (userData['units'] is Map && userData['units']['isMetric'] is bool) {
          isMetric = userData['units']['isMetric'] as bool;
        } else if (userData['isMetric'] is bool) {
          isMetric = userData['isMetric'] as bool;
        }

        final String weightUnit = isMetric ? 'kg' : 'lbs';
        final double displayCurrentWeight = isMetric ? currentWeightKg : (currentWeightKg * 2.20462);
        final double displayTargetWeight = isMetric ? targetWeightKg : (targetWeightKg * 2.20462);

        return StreamBuilder<List<BodyMeasurement>>(
          stream: MeasurementService.streamMeasurements(currentUser!.uid),
          builder: (context, measureSnapshot) {
            if (measureSnapshot.hasError) {
              return Scaffold(
                appBar: AppBar(title: const Text("Body Progress")),
                body: Center(child: Text("Error loading measurements: ${measureSnapshot.error}")),
              );
            }

            final List<BodyMeasurement> allMeasurements = measureSnapshot.data ?? [];
            final List<BodyMeasurement> filteredMeasurements = _filterMeasurements(allMeasurements);

            // Calculate starting weight and weight change
            double? startingWeightKg;
            double totalWeightChangeKg = 0.0;
            if (allMeasurements.isNotEmpty) {
              final chronological = List<BodyMeasurement>.from(allMeasurements)
                ..sort((a, b) => a.date.compareTo(b.date));
              final withWeight = chronological.where((m) => m.weight != null && m.weight! > 0).toList();
              if (withWeight.isNotEmpty) {
                startingWeightKg = withWeight.first.weight;
                final latestWeightKg = withWeight.last.weight!;
                totalWeightChangeKg = latestWeightKg - startingWeightKg!;
              }
            }

            final double displayStartingWeight = startingWeightKg != null
                ? (isMetric ? startingWeightKg : (startingWeightKg * 2.20462))
                : displayCurrentWeight;
            final double displayWeightChange = isMetric ? totalWeightChangeKg : (totalWeightChangeKg * 2.20462);

            final theme = Theme.of(context);
            return Scaffold(
              backgroundColor: theme.scaffoldBackgroundColor,
              appBar: AppBar(
                title: const Text(
                  "Body Progress & Metrics",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                ),
                elevation: 0,
                centerTitle: false,
                actions: [
                  IconButton(
                    icon: Icon(Icons.add_circle_outline, color: theme.colorScheme.primary, size: 28),
                    tooltip: "Log Measurement",
                    onPressed: () => _showAddMeasurementModal(
                      context,
                      isMetric: isMetric,
                      currentWeightKg: currentWeightKg,
                    ),
                  ),
                ],
              ),
              floatingActionButton: FloatingActionButton.extended(
                onPressed: () => _showAddMeasurementModal(
                  context,
                  isMetric: isMetric,
                  currentWeightKg: currentWeightKg,
                ),
                backgroundColor: Colors.teal,
                icon: const Icon(Icons.add_rounded, color: Colors.white),
                label: const Text("Log Measurement", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
              body: ListView(
                padding: const EdgeInsets.only(top: 12, bottom: 90),
                children: [
                  // 1. Goal Progress Hero Card
                  _buildGoalHeroCard(
                    goal: goal,
                    currentWeight: displayCurrentWeight,
                    targetWeight: displayTargetWeight,
                    unit: weightUnit,
                    isMetric: isMetric,
                  ),

                  // 2. Stats Summary Row
                  _buildStatsRow(
                    startingWeight: displayStartingWeight,
                    currentWeight: displayCurrentWeight,
                    weightChange: displayWeightChange,
                    totalLogs: allMeasurements.length,
                    unit: weightUnit,
                  ),

                  const SizedBox(height: 14),

                  // 3. Weight Trend Chart Card
                  _buildTrendChartCard(
                    measurements: filteredMeasurements,
                    isMetric: isMetric,
                    unit: weightUnit,
                  ),

                  const SizedBox(height: 14),

                  // 4. Measurement History Section Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "MEASUREMENT HISTORY (${allMeasurements.length})",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 5. History List Cards
                  if (allMeasurements.isEmpty)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: theme.colorScheme.outlineVariant),
                      ),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.monitor_weight_outlined, size: 48, color: theme.colorScheme.onSurfaceVariant),
                            const SizedBox(height: 12),
                            Text(
                              "No Measurements Logged",
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: theme.colorScheme.onSurface),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              "Tap 'Log Measurement' to record your weight, body fat, or body circumferences.",
                              textAlign: TextAlign.center,
                              style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ...allMeasurements.map((m) => _buildMeasurementHistoryTile(
                          m: m,
                          isMetric: isMetric,
                          weightUnit: weightUnit,
                          onDelete: () => _confirmDeleteMeasurement(context, m),
                        )),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // --- 1. GOAL PROGRESS HERO CARD ---
  Widget _buildGoalHeroCard({
    required String goal,
    required double currentWeight,
    required double targetWeight,
    required String unit,
    required bool isMetric,
  }) {
    final double diff = (currentWeight - targetWeight);
    final bool isWeightLoss = goal.toLowerCase().contains("loss") || goal.toLowerCase().contains("cut");
    final bool isMuscleGain = goal.toLowerCase().contains("gain") || goal.toLowerCase().contains("bulk");

    String remainingText = "On Target";
    double progressRatio = 1.0;

    if (isWeightLoss) {
      if (diff > 0) {
        remainingText = "${diff.toStringAsFixed(1)} $unit to lose";
        progressRatio = (targetWeight / currentWeight).clamp(0.0, 1.0);
      } else {
        remainingText = "Goal achieved! 🎉";
        progressRatio = 1.0;
      }
    } else if (isMuscleGain) {
      if (diff < 0) {
        remainingText = "${(-diff).toStringAsFixed(1)} $unit to gain";
        progressRatio = (currentWeight / targetWeight).clamp(0.0, 1.0);
      } else {
        remainingText = "Goal achieved! 🎉";
        progressRatio = 1.0;
      }
    } else {
      remainingText = "Goal: Maintain ${targetWeight.toStringAsFixed(1)} $unit";
      progressRatio = 1.0;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.teal.shade800, Colors.teal.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.teal.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 5),
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
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.track_changes, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    goal.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  remainingText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("CURRENT WEIGHT", style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(
                    "${currentWeight.toStringAsFixed(1)} $unit",
                    style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
              const Icon(Icons.arrow_forward_rounded, color: Colors.white54, size: 24),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text("TARGET GOAL", style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(
                    "${targetWeight.toStringAsFixed(1)} $unit",
                    style: const TextStyle(color: Colors.tealAccent, fontSize: 26, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progressRatio,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.tealAccent),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  // --- 2. STATS SUMMARY ROW ---
  Widget _buildStatsRow({
    required double startingWeight,
    required double currentWeight,
    required double weightChange,
    required int totalLogs,
    required String unit,
  }) {
    final bool isLoss = weightChange < 0;
    final String changeSign = weightChange > 0 ? "+" : "";

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _buildStatTile(
              title: "STARTING",
              value: "${startingWeight.toStringAsFixed(1)} $unit",
              icon: Icons.flag_outlined,
              color: Colors.blueAccent,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildStatTile(
              title: "NET CHANGE",
              value: "$changeSign${weightChange.toStringAsFixed(1)} $unit",
              icon: isLoss ? Icons.trending_down : Icons.trending_up,
              color: isLoss ? Colors.green : Colors.orange,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildStatTile(
              title: "LOGS",
              value: "$totalLogs",
              icon: Icons.history,
              color: Colors.purpleAccent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatTile({required String title, required String value, required IconData icon, required Color color}) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: theme.cardColor,
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
                  title,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: theme.colorScheme.onSurfaceVariant),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
            ),
          ),
        ],
      ),
    );
  }

  // --- 3. WEIGHT TREND CHART ---
  Widget _buildTrendChartCard({
    required List<BodyMeasurement> measurements,
    required bool isMetric,
    required String unit,
  }) {
    final theme = Theme.of(context);
    final withWeight = measurements.where((m) => m.weight != null && m.weight! > 0).toList()
      ..sort((a, b) => a.date.compareTo(b.date)); // Chronological

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: theme.brightness == Brightness.dark
                            ? theme.colorScheme.surfaceContainerHighest
                            : Colors.teal.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.show_chart, color: theme.colorScheme.primary, size: 18),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Weight Progression",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: theme.colorScheme.onSurface),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Timeframe Chips
              Row(
                mainAxisSize: MainAxisSize.min,
                children: ['7 Entries', '30 Days', 'All Time'].map((tf) {
                  final isSelected = _selectedTimeframe == tf;
                  return Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: InkWell(
                      onTap: () => setState(() => _selectedTimeframe = tf),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isSelected ? theme.colorScheme.primary : theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          tf,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? (theme.brightness == Brightness.dark ? Colors.black : Colors.white)
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (withWeight.length < 2)
            Container(
              height: 150,
              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.insights, size: 36, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(height: 8),
                  Text(
                    withWeight.isEmpty
                        ? "No weight entries logged yet"
                        : "Log at least 2 weight entries to visualize your curve",
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12),
                  ),
                ],
              ),
            )
          else
            SizedBox(
              height: 200,
              child: _buildLineChart(withWeight, isMetric: isMetric, unit: unit),
            ),
        ],
      ),
    );
  }

  Widget _buildLineChart(List<BodyMeasurement> points, {required bool isMetric, required String unit}) {
    final theme = Theme.of(context);
    final spots = <FlSpot>[];
    double minWeight = double.infinity;
    double maxWeight = -double.infinity;

    for (int i = 0; i < points.length; i++) {
      final double rawKg = points[i].weight!;
      final double displayVal = isMetric ? rawKg : (rawKg * 2.20462);
      if (displayVal < minWeight) minWeight = displayVal;
      if (displayVal > maxWeight) maxWeight = displayVal;
      spots.add(FlSpot(i.toDouble(), displayVal));
    }

    final double yPadding = (maxWeight - minWeight).abs() < 1.0 ? 2.0 : (maxWeight - minWeight) * 0.2;
    final double minY = (minWeight - yPadding).floorToDouble();
    final double maxY = (maxWeight + yPadding).ceilToDouble();

    return LineChart(
      LineChartData(
        minY: minY,
        maxY: maxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: ((maxY - minY) / 4).clamp(1.0, 50.0),
          getDrawingHorizontalLine: (v) => FlLine(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (val, meta) => SideTitleWidget(
                axisSide: meta.axisSide,
                space: 4,
                child: Text(
                  val.toStringAsFixed(0),
                  textAlign: TextAlign.right,
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 10),
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              interval: (points.length / 4).clamp(1.0, 20.0).floorToDouble(),
              getTitlesWidget: (val, meta) {
                final idx = val.toInt();
                if (idx >= 0 && idx < points.length && (val - idx).abs() < 0.01) {
                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    space: 6,
                    child: Text(
                      DateFormat('MM/dd').format(points[idx].date),
                      style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 10),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: theme.colorScheme.primary,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary.withValues(alpha: 0.25),
                  theme.colorScheme.primary.withValues(alpha: 0.0),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- 4. MEASUREMENT HISTORY TILE ---
  Widget _buildMeasurementHistoryTile({
    required BodyMeasurement m,
    required bool isMetric,
    required String weightUnit,
    required VoidCallback onDelete,
  }) {
    final theme = Theme.of(context);
    final double? displayWeight = m.weight != null ? (isMetric ? m.weight! : (m.weight! * 2.20462)) : null;
    final String lengthUnit = isMetric ? 'cm' : 'in';

    double? toDisplayLength(double? cm) {
      if (cm == null) return null;
      return isMetric ? cm : (cm / 2.54);
    }

    final double? displayWaist = toDisplayLength(m.waist);
    final double? displayChest = toDisplayLength(m.chest);
    final double? displayArms = toDisplayLength(m.arms);
    final double? displayHips = toDisplayLength(m.hips);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: theme.brightness == Brightness.dark
                          ? theme.colorScheme.surfaceContainerHighest
                          : Colors.teal.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.event, color: theme.colorScheme.primary, size: 16),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    DateFormat('MMM d, yyyy').format(m.date),
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: theme.colorScheme.onSurface),
                  ),
                ],
              ),
              IconButton(
                icon: Icon(Icons.delete_outline, size: 20, color: theme.colorScheme.onSurfaceVariant),
                tooltip: "Delete",
                onPressed: onDelete,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (displayWeight != null)
                _buildMetricTag("Weight", "${displayWeight.toStringAsFixed(1)} $weightUnit", theme.colorScheme.primary),
              if (m.bodyFatPercentage != null)
                _buildMetricTag("Body Fat", "${m.bodyFatPercentage!.toStringAsFixed(1)}%", Colors.orange),
              if (displayWaist != null)
                _buildMetricTag("Waist", "${displayWaist.toStringAsFixed(1)} $lengthUnit", Colors.blue),
              if (displayChest != null)
                _buildMetricTag("Chest", "${displayChest.toStringAsFixed(1)} $lengthUnit", Colors.indigo),
              if (displayArms != null)
                _buildMetricTag("Arms", "${displayArms.toStringAsFixed(1)} $lengthUnit", Colors.purple),
              if (displayHips != null)
                _buildMetricTag("Hips", "${displayHips.toStringAsFixed(1)} $lengthUnit", Colors.pink),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTag(String label, String value, Color color) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text("$label: ", style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w500)),
          Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}

// ==========================================
// ADD MEASUREMENT BOTTOM SHEET
// ==========================================
class _AddMeasurementSheet extends StatefulWidget {
  final bool isMetric;
  final double currentWeightKg;
  final String uid;

  const _AddMeasurementSheet({
    required this.isMetric,
    required this.currentWeightKg,
    required this.uid,
  });

  @override
  State<_AddMeasurementSheet> createState() => _AddMeasurementSheetState();
}

class _AddMeasurementSheetState extends State<_AddMeasurementSheet> {
  late DateTime _selectedDate;
  final TextEditingController _weightCtrl = TextEditingController();
  final TextEditingController _bodyFatCtrl = TextEditingController();
  final TextEditingController _waistCtrl = TextEditingController();
  final TextEditingController _chestCtrl = TextEditingController();
  final TextEditingController _armsCtrl = TextEditingController();
  final TextEditingController _hipsCtrl = TextEditingController();

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    final double displayInitialWeight = widget.isMetric
        ? widget.currentWeightKg
        : (widget.currentWeightKg * 2.20462);
    _weightCtrl.text = displayInitialWeight.toStringAsFixed(1);
  }

  @override
  void dispose() {
    _weightCtrl.dispose();
    _bodyFatCtrl.dispose();
    _waistCtrl.dispose();
    _chestCtrl.dispose();
    _armsCtrl.dispose();
    _hipsCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _saveMeasurement() async {
    final weightStr = _weightCtrl.text.trim();
    final bfStr = _bodyFatCtrl.text.trim();
    final waistStr = _waistCtrl.text.trim();
    final chestStr = _chestCtrl.text.trim();
    final armsStr = _armsCtrl.text.trim();
    final hipsStr = _hipsCtrl.text.trim();

    if (weightStr.isEmpty && bfStr.isEmpty && waistStr.isEmpty && chestStr.isEmpty && armsStr.isEmpty && hipsStr.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter at least one measurement value.")),
      );
      return;
    }

    // Parse and convert to canonical metric values (kg, cm, %)
    double? weightKg;
    if (weightStr.isNotEmpty) {
      final parsed = double.tryParse(weightStr);
      if (parsed == null || parsed <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Invalid weight value entered.")));
        return;
      }
      weightKg = widget.isMetric ? parsed : (parsed / 2.20462);
      if (weightKg < 20 || weightKg > 350) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Weight must be between 20kg and 350kg.")));
        return;
      }
    }

    double? bodyFat;
    if (bfStr.isNotEmpty) {
      bodyFat = double.tryParse(bfStr);
      if (bodyFat == null || bodyFat < 3 || bodyFat > 65) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Body Fat % must be between 3% and 65%.")));
        return;
      }
    }

    double? parseLength(String str) {
      if (str.isEmpty) return null;
      final p = double.tryParse(str);
      if (p == null || p <= 0) return null;
      return widget.isMetric ? p : (p * 2.54);
    }

    final waistCm = parseLength(waistStr);
    final chestCm = parseLength(chestStr);
    final armsCm = parseLength(armsStr);
    final hipsCm = parseLength(hipsStr);

    setState(() => _isSaving = true);

    try {
      // 1. Add measurement entry to users/{uid}/measurements
      await MeasurementService.addMeasurement(
        uid: widget.uid,
        weight: weightKg,
        bodyFatPercentage: bodyFat,
        waist: waistCm,
        chest: chestCm,
        arms: armsCm,
        hips: hipsCm,
        date: _selectedDate,
        source: 'manual',
      );

      // 2. Synchronize current weight in users/{uid} if measurement is for today or latest date
      if (weightKg != null) {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(widget.uid).get();
        final userData = userDoc.data() ?? {};
        final now = DateTime.now();
        final bool isTodayOrFuture = _selectedDate.isAfter(now.subtract(const Duration(hours: 24)));

        if (isTodayOrFuture) {
          final int age = (userData['age'] as num?)?.toInt() ?? 25;
          final double height = (userData['height'] as num?)?.toDouble() ?? 175.0;
          final String gender = (userData['gender'] ?? 'Male').toString();
          final String activityLevel = (userData['activityLevel'] ?? 'Moderate').toString();
          final String goal = (userData['fitnessGoal'] ?? userData['goal'] ?? 'Maintenance').toString();

          double bmr;
          if (gender == "Female") {
            bmr = (10 * weightKg) + (6.25 * height) - (5 * age) - 161;
          } else {
            bmr = (10 * weightKg) + (6.25 * height) - (5 * age) + 5;
          }

          double multiplier = 1.2;
          if (activityLevel.contains("Light")) {
            multiplier = 1.375;
          } else if (activityLevel.contains("Moderate")) {
            multiplier = 1.55;
          } else if (activityLevel.contains("Active")) {
            multiplier = 1.725;
          }

          final double tdee = bmr * multiplier;
          double targetCalories = tdee;
          if (goal.contains("Weight Loss") || goal.contains("Cut")) {
            targetCalories -= 500;
          } else if (goal.contains("Muscle Gain") || goal.contains("Bulk")) {
            targetCalories += 300;
          }

          await FirebaseFirestore.instance.collection('users').doc(widget.uid).update({
            'weight': weightKg,
            'bmr': bmr,
            'tdee': tdee,
            'calorieTarget': targetCalories.round(),
            'dailyCaloriesTarget': targetCalories.round(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Measurement recorded successfully! 📊")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error saving measurement: $e")));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String weightUnit = widget.isMetric ? "kg" : "lbs";
    final String lengthUnit = widget.isMetric ? "cm" : "in";

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Log Body Measurement",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const SizedBox(height: 12),

            // Date Picker Row
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.teal.shade200),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.calendar_month, color: Colors.teal, size: 20),
                        const SizedBox(width: 10),
                        Text(
                          "Date: ${DateFormat('MMMM d, yyyy').format(_selectedDate)}",
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal.shade900),
                        ),
                      ],
                    ),
                    const Text("Change", style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold, fontSize: 12)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Weight & Body Fat
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _weightCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: "Weight ($weightUnit)",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _bodyFatCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: "Body Fat (%)",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Circumferences: Waist & Chest
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _waistCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: "Waist ($lengthUnit)",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _chestCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: "Chest ($lengthUnit)",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Circumferences: Arms & Hips
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _armsCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: "Arms ($lengthUnit)",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _hipsCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: "Hips ($lengthUnit)",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Save Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveMeasurement,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSaving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Save Measurement", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
