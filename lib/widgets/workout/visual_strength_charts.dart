import 'package:flutter/material.dart';
import '../../models/workout_models.dart';

class VisualStrengthCharts extends StatefulWidget {
  final List<WorkoutHistorySession> sessions;

  const VisualStrengthCharts({super.key, required this.sessions});

  @override
  State<VisualStrengthCharts> createState() => _VisualStrengthChartsState();
}

class _VisualStrengthChartsState extends State<VisualStrengthCharts> {
  int _selectedMovementIndex = 0;
  bool _isWeeklyFrequency = true;

  @override
  Widget build(BuildContext context) {
    if (widget.sessions.isEmpty) {
      final theme = Theme.of(context);
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.query_stats_rounded, size: 48, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(height: 12),
              Text(
                "No Progression Data Yet",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: theme.colorScheme.onSurface),
              ),
              const SizedBox(height: 6),
              Text(
                "Complete workout sessions to unlock strength progression and workout frequency charts.",
                textAlign: TextAlign.center,
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Strength Improvement Trend Card
          _buildStrengthTrendCard(),

          const SizedBox(height: 14),

          // 2. Workout Frequency Breakdown Card
          _buildFrequencyBreakdownCard(),
        ],
      ),
    );
  }

  // --- 1. Strength Progression Chart ---
  Widget _buildStrengthTrendCard() {
    // Extract most frequent movements across all sessions
    final Map<String, int> movementCounts = {};
    for (final s in widget.sessions) {
      for (final ex in s.exercises) {
        if (ex.exerciseName.trim().isNotEmpty) {
          movementCounts[ex.exerciseName] = (movementCounts[ex.exerciseName] ?? 0) + 1;
        }
      }
    }

    final trackedMovements = movementCounts.keys.toList()
      ..sort((a, b) => (movementCounts[b] ?? 0).compareTo(movementCounts[a] ?? 0));

    if (trackedMovements.isEmpty) {
      return const SizedBox.shrink();
    }

    if (_selectedMovementIndex >= trackedMovements.length) {
      _selectedMovementIndex = 0;
    }

    final selectedMovement = trackedMovements[_selectedMovementIndex];

    // Build chronological progression for the selected exercise
    final chronological = List<WorkoutHistorySession>.from(widget.sessions)
      ..sort((a, b) => a.date.compareTo(b.date));

    final List<double> weights = [];
    final List<String> labels = [];
    bool isRepsBased = false;

    for (final s in chronological) {
      for (final ex in s.exercises) {
        if (ex.exerciseName.toLowerCase() == selectedMovement.toLowerCase()) {
          double maxWeightInSession = 0.0;
          for (final set in ex.sets) {
            if (set.weightKg > maxWeightInSession) {
              maxWeightInSession = set.weightKg;
            }
          }
          // If bodyweight or 0 weight, use max reps as fallback metric
          if (maxWeightInSession == 0.0 && ex.sets.isNotEmpty) {
            final maxReps = ex.sets.map((e) => e.reps.toDouble()).reduce((a, b) => a > b ? a : b);
            maxWeightInSession = maxReps;
            isRepsBased = true;
          }
          weights.add(maxWeightInSession);
          labels.add("${s.date.day}/${s.date.month}");
          break;
        }
      }
    }

    final String unitLabel = isRepsBased ? "reps" : "kg";

    // Limit to latest 6 data points
    final displayWeights = weights.length > 6 ? weights.sublist(weights.length - 6) : weights;
    final displayLabels = labels.length > 6 ? labels.sublist(labels.length - 6) : labels;

    final double maxW = displayWeights.isNotEmpty ? displayWeights.reduce((a, b) => a > b ? a : b) : 1.0;
    final double minW = displayWeights.isNotEmpty ? displayWeights.reduce((a, b) => a < b ? a : b) : 0.0;
    final double diff = maxW - minW;

    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: theme.brightness == Brightness.dark ? 0.2 : 0.02),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
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
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.show_chart_rounded, color: Colors.blueAccent, size: 18),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Strength Progression",
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            isRepsBased ? "Max Reps per Session" : "Peak Weight per Session",
                            style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: diff > 0
                      ? (theme.brightness == Brightness.dark ? theme.colorScheme.surfaceContainerHighest : Colors.green.shade50)
                      : theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  diff > 0 ? "+${diff.toStringAsFixed(0)} $unitLabel gained" : "Top: ${maxW.toInt()} $unitLabel",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: diff > 0 ? (theme.brightness == Brightness.dark ? Colors.greenAccent : Colors.green.shade800) : theme.colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Exercise selector chips (top 5 movements)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(trackedMovements.take(5).length, (idx) {
                final isSelected = _selectedMovementIndex == idx;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(trackedMovements[idx]),
                    labelStyle: TextStyle(
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected
                          ? (theme.brightness == Brightness.dark ? Colors.black : Colors.white)
                          : theme.colorScheme.onSurface,
                    ),
                    selected: isSelected,
                    selectedColor: theme.colorScheme.primary,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    visualDensity: VisualDensity.compact,
                    onSelected: (val) {
                      if (val) setState(() => _selectedMovementIndex = idx);
                    },
                  ),
                );
              }),
            ),
          ),

          const SizedBox(height: 16),

          // Visual Chart Bars (Real Progression Bars)
          Container(
            height: 155,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: displayWeights.isEmpty
                ? Center(
                    child: Text(
                      "No logs for this exercise yet",
                      style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: List.generate(displayWeights.length, (index) {
                      final w = displayWeights[index];
                      final safeMax = maxW > 0 ? maxW : 1.0;
                      final normalizedHeight = ((w / safeMax) * 65).clamp(16.0, 65.0);
                      final isLatest = index == displayWeights.length - 1;

                      return Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                "${w.toInt()} $unitLabel",
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isLatest ? Colors.teal : Colors.grey.shade700,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              constraints: const BoxConstraints(maxWidth: 32),
                              height: normalizedHeight,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: isLatest
                                      ? [Colors.tealAccent, Colors.teal]
                                      : [Colors.grey.shade300, Colors.grey.shade400],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            const SizedBox(height: 6),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                displayLabels[index],
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey.shade600,
                                  fontWeight: isLatest ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ),
          ),
        ],
      ),
    );
  }

  // --- 2. Workout Frequency Breakdown ---
  Widget _buildFrequencyBreakdownCard() {
    const days = ["M", "T", "W", "T", "F", "S", "S"];
    final now = DateTime.now();

    // Compute weekly frequency (Monday = 1 to Sunday = 7 of current week)
    final weeklyCounts = List.filled(7, 0);
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final startOfWeek = DateTime(monday.year, monday.month, monday.day);
    final endOfWeek = startOfWeek.add(const Duration(days: 7));

    for (final s in widget.sessions) {
      if (s.date.isAfter(startOfWeek.subtract(const Duration(seconds: 1))) &&
          s.date.isBefore(endOfWeek)) {
        final weekdayIndex = s.date.weekday - 1; // 0 for Mon, 6 for Sun
        if (weekdayIndex >= 0 && weekdayIndex < 7) {
          weeklyCounts[weekdayIndex]++;
        }
      }
    }

    // Compute monthly 4-week breakdown (past 28 days)
    final monthlyWeeks = List.filled(4, 0);
    for (final s in widget.sessions) {
      final daysAgo = now.difference(s.date).inDays;
      if (daysAgo >= 0 && daysAgo < 28) {
        final weekIdx = 3 - (daysAgo ~/ 7); // 0 = 4 wks ago, 3 = this week
        if (weekIdx >= 0 && weekIdx < 4) {
          monthlyWeeks[weekIdx]++;
        }
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
            color: Colors.black.withValues(alpha: theme.brightness == Brightness.dark ? 0.2 : 0.02),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
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
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: Colors.purple.shade50.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.bar_chart_rounded, color: Colors.purpleAccent, size: 18),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Workout Frequency",
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Weekly / Monthly Toggle
              Container(
                height: 30,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildToggleBtn("Weekly", _isWeeklyFrequency, () => setState(() => _isWeeklyFrequency = true)),
                    _buildToggleBtn("Monthly", !_isWeeklyFrequency, () => setState(() => _isWeeklyFrequency = false)),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          if (_isWeeklyFrequency)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (i) {
                final hasWorkout = weeklyCounts[i] > 0;
                return Expanded(
                  child: Column(
                    children: [
                      Container(
                        constraints: const BoxConstraints(maxWidth: 32),
                        height: hasWorkout ? 54 : 14,
                        decoration: BoxDecoration(
                          color: hasWorkout ? theme.colorScheme.primary : theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: hasWorkout
                            ? Center(
                                child: Icon(
                                  Icons.check,
                                  color: theme.brightness == Brightness.dark ? Colors.black : Colors.white,
                                  size: 14,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(height: 6),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          days[i],
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: hasWorkout ? FontWeight.bold : FontWeight.normal,
                            color: hasWorkout ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(4, (i) {
                final count = monthlyWeeks[i];
                final barHeight = (count * 14.0).clamp(14.0, 70.0);
                return Expanded(
                  child: Column(
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          "$count ${count == 1 ? 'day' : 'days'}",
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        constraints: const BoxConstraints(maxWidth: 44),
                        height: barHeight,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [theme.colorScheme.primary.withValues(alpha: 0.7), theme.colorScheme.primary],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      const SizedBox(height: 6),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text("Week ${i + 1}", style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
                      ),
                    ],
                  ),
                );
              }),
            ),
        ],
      ),
    );
  }

  Widget _buildToggleBtn(String label, bool isSelected, VoidCallback onTap) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? theme.colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isSelected
                ? (theme.brightness == Brightness.dark ? Colors.black : Colors.white)
                : theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
