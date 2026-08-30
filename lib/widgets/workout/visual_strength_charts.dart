import 'package:flutter/material.dart';

class VisualStrengthCharts extends StatefulWidget {
  const VisualStrengthCharts({super.key});

  @override
  State<VisualStrengthCharts> createState() => _VisualStrengthChartsState();
}

class _VisualStrengthChartsState extends State<VisualStrengthCharts> {
  int _selectedMovementIndex = 0;
  final List<String> _trackedMovements = ["Bench Press", "Squat", "Deadlift", "Lat Pulldown"];

  bool _isWeeklyFrequency = true;

  // Mock data points for strength improvements (4 weeks progression)
  final Map<String, List<double>> _progressionWeight = {
    "Bench Press": [85.0, 90.0, 95.0, 100.0],
    "Squat": [115.0, 125.0, 130.0, 140.0],
    "Deadlift": [130.0, 140.0, 150.0, 160.0],
    "Lat Pulldown": [70.0, 75.0, 80.0, 85.0],
  };

  // Mock weekly frequency (Mon-Sun workout counts or past 4 weeks)
  final List<int> _weeklyCounts = [1, 1, 0, 1, 1, 1, 0]; // Mon-Sun
  final List<int> _monthlyWeeks = [4, 5, 4, 5]; // Week 1 to 4

  @override
  Widget build(BuildContext context) {
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

  Widget _buildStrengthTrendCard() {
    final movement = _trackedMovements[_selectedMovementIndex];
    final weights = _progressionWeight[movement] ?? [80, 85, 90, 95];
    final maxWeight = weights.reduce((a, b) => a > b ? a : b);
    final minWeight = weights.reduce((a, b) => a < b ? a : b);
    final diff = maxWeight - minWeight;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.show_chart_rounded, color: Colors.blueAccent, size: 18),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    "Strength Progression",
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  "+${diff.toStringAsFixed(0)} kg gained",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade800,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Exercise selector chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(_trackedMovements.length, (idx) {
                final isSelected = _selectedMovementIndex == idx;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(_trackedMovements[idx]),
                    labelStyle: TextStyle(
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? Colors.white : Colors.black87,
                    ),
                    selected: isSelected,
                    selectedColor: Colors.teal,
                    backgroundColor: Colors.grey.shade100,
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

          // Visual Chart Bars (Mocked UI Line/Bar Visualization)
          Container(
            height: 130,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(weights.length, (index) {
                final w = weights[index];
                final normalizedHeight = (w / (maxWeight * 1.15)) * 90;
                final isLatest = index == weights.length - 1;

                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      "${w.toInt()}kg",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isLatest ? Colors.teal : Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: 38,
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
                    Text(
                      "Wk ${index + 1}",
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade600,
                        fontWeight: isLatest ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFrequencyBreakdownCard() {
    const days = ["M", "T", "W", "T", "F", "S", "S"];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: Colors.purple.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.bar_chart_rounded, color: Colors.purpleAccent, size: 18),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    "Workout Frequency",
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                ],
              ),
              // Weekly / Monthly Toggle
              Container(
                height: 30,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
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
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (i) {
                final hasWorkout = _weeklyCounts[i] > 0;
                return Column(
                  children: [
                    Container(
                      width: 32,
                      height: hasWorkout ? 54 : 12,
                      decoration: BoxDecoration(
                        color: hasWorkout ? Colors.teal : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: hasWorkout
                          ? const Center(child: Icon(Icons.check, color: Colors.white, size: 14))
                          : null,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      days[i],
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: hasWorkout ? FontWeight.bold : FontWeight.normal,
                        color: hasWorkout ? Colors.teal.shade800 : Colors.grey,
                      ),
                    ),
                  ],
                );
              }),
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(4, (i) {
                final count = _monthlyWeeks[i];
                return Column(
                  children: [
                    Text(
                      "$count days",
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.teal),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: 44,
                      height: count * 12.0,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.teal.shade300, Colors.teal],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text("Week ${i + 1}", style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                  ],
                );
              }),
            ),
        ],
      ),
    );
  }

  Widget _buildToggleBtn(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? Colors.teal : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }
}
