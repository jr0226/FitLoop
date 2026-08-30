import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';

class AnalyticsTab extends StatefulWidget {
  const AnalyticsTab({super.key});

  @override
  State<AnalyticsTab> createState() => _AnalyticsTabState();
}

class _AnalyticsTabState extends State<AnalyticsTab> {
  final String uid = FirebaseAuth.instance.currentUser!.uid;
  
  bool _isLoading = true;
  int _totalWorkouts = 0;
  int _totalMinutes = 0;
  int _totalCalories = 0;
  
  // Maps a weekday index (1-7) to calories burned that day
  final Map<int, int> _weeklyCalories = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0, 7: 0};

  @override
  void initState() {
    super.initState();
    _fetchWeeklyData();
  }

  Future<void> _fetchWeeklyData() async {
    DateTime now = DateTime.now();
    // Get the date 7 days ago
    DateTime sevenDaysAgo = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('workout_logs')
          .where('timestamp', isGreaterThanOrEqualTo: sevenDaysAgo)
          .get();

      int workouts = 0;
      int minutes = 0;
      int calories = 0;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final DateTime date = (data['timestamp'] as Timestamp).toDate();
        final int burned = (data['caloriesBurned'] as num?)?.toInt() ?? 0;
        final int durationSecs = (data['durationSeconds'] as num?)?.toInt() ?? 0;

        workouts++;
        minutes += (durationSecs / 60).round();
        calories += burned;

        // Add calories to the specific day of the week (1 = Monday, 7 = Sunday)
        _weeklyCalories[date.weekday] = (_weeklyCalories[date.weekday] ?? 0) + burned;
      }

      if (mounted) {
        setState(() {
          _totalWorkouts = workouts;
          _totalMinutes = minutes;
          _totalCalories = calories;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching analytics: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text("Progress & Analytics", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Colors.teal))
        : SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Last 7 Days", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                
                // Top Summary Cards
                Row(
                  children: [
                    Expanded(child: _buildSummaryCard("Workouts", _totalWorkouts.toString(), Icons.fitness_center, Colors.blue)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildSummaryCard("Minutes", _totalMinutes.toString(), Icons.timer, Colors.orange)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildSummaryCard("Calories", _totalCalories.toString(), Icons.local_fire_department, Colors.redAccent)),
                  ],
                ),
                
                const SizedBox(height: 30),
                const Text("Calories Burned", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                
                // FL Chart - Weekly Calories
                Container(
                  height: 300,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 10, offset: const Offset(0, 5))],
                  ),
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: _getMaxY(),
                      barTouchData: BarTouchData(enabled: true),
                      titlesData: FlTitlesData(
                        show: true,
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                              return Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(
                                  days[value.toInt() - 1],
                                  style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              );
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 40,
                            getTitlesWidget: (value, meta) {
                              return Text(
                                value.toInt().toString(),
                                style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                              );
                            },
                          ),
                        ),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: 100,
                        getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.shade200, strokeWidth: 1),
                      ),
                      borderData: FlBorderData(show: false),
                      barGroups: _buildBarGroups(),
                    ),
                  ),
                ),
                
                const SizedBox(height: 30),
                
                // Strength Improvement Placeholder
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [Colors.teal.shade800, Colors.teal.shade500]),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.trending_up, color: Colors.white),
                          SizedBox(width: 10),
                          Text("Strength Progression", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        "Keep tracking your weights in the Active Session. Your 1-Rep Max insights will appear here soon!",
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.teal),
                        child: const Text("View Exercise Records"),
                      )
                    ],
                  ),
                )
              ],
            ),
          ),
    );
  }

  // Generate the bars for the chart
  List<BarChartGroupData> _buildBarGroups() {
    return List.generate(7, (index) {
      int day = index + 1;
      int calories = _weeklyCalories[day] ?? 0;
      
      // Highlight today's bar
      bool isToday = day == DateTime.now().weekday;

      return BarChartGroupData(
        x: day,
        barRods: [
          BarChartRodData(
            toY: calories.toDouble(),
            color: isToday ? Colors.orange : Colors.teal.shade300,
            width: 16,
            borderRadius: BorderRadius.circular(4),
            backDrawRodData: BackgroundBarChartRodData(
              show: true,
              toY: _getMaxY(),
              color: Colors.grey.shade100,
            ),
          ),
        ],
      );
    });
  }

  // Dynamically scale the Y-axis based on max calories
  double _getMaxY() {
    int maxCal = 0;
    for (var val in _weeklyCalories.values) {
      if (val > maxCal) maxCal = val;
    }
    // Add padding to the top of the chart, default to 500 if empty
    return maxCal == 0 ? 500.0 : (maxCal + 100).toDouble();
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          Text(title, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
        ],
      ),
    );
  }
}