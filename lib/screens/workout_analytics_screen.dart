import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/workout_models.dart';
import '../widgets/workout/analytics_summary_cards.dart';
import '../widgets/workout/visual_strength_charts.dart';
import '../widgets/workout/workout_history_list_card.dart';

class WorkoutAnalyticsScreen extends StatefulWidget {
  const WorkoutAnalyticsScreen({super.key});

  @override
  State<WorkoutAnalyticsScreen> createState() => _WorkoutAnalyticsScreenState();
}

class _WorkoutAnalyticsScreenState extends State<WorkoutAnalyticsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedDateRange = '30 Days'; // '7 Days', '30 Days', 'All Time'

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<WorkoutHistorySession> _filterSessionsByDate(List<WorkoutHistorySession> allSessions) {
    final now = DateTime.now();
    if (_selectedDateRange == '7 Days') {
      final cutoff = now.subtract(const Duration(days: 7));
      return allSessions.where((s) => s.date.isAfter(cutoff)).toList();
    } else if (_selectedDateRange == '30 Days') {
      final cutoff = now.subtract(const Duration(days: 30));
      return allSessions.where((s) => s.date.isAfter(cutoff)).toList();
    }
    return allSessions;
  }

  WorkoutAnalyticsSummary _calculateSummary(List<WorkoutHistorySession> sessions) {
    if (sessions.isEmpty) {
      return const WorkoutAnalyticsSummary(
        totalVolumeKg: 0.0,
        totalWorkoutsCompleted: 0,
        totalActiveHours: 0.0,
        totalCaloriesBurned: 0,
        volumeGrowthPercentage: 0.0,
      );
    }

    final double totalVolume = sessions.fold(0.0, (acc, s) => acc + s.totalVolumeKg);
    final int totalCalories = sessions.fold(0, (acc, s) => acc + s.caloriesBurned);
    final int totalMinutes = sessions.fold(0, (acc, s) => acc + s.durationMinutes);
    final double activeHours = double.parse((totalMinutes / 60.0).toStringAsFixed(1));

    // Volume comparison between first half and second half of period
    double growthPercent = 0.0;
    if (sessions.length >= 2) {
      final midpoint = (sessions.length / 2).floor();
      final recentVolume = sessions.sublist(0, midpoint).fold(0.0, (acc, s) => acc + s.totalVolumeKg);
      final previousVolume = sessions.sublist(midpoint).fold(0.0, (acc, s) => acc + s.totalVolumeKg);
      if (previousVolume > 0) {
        growthPercent = double.parse((((recentVolume - previousVolume) / previousVolume) * 100).toStringAsFixed(1));
      }
    }

    return WorkoutAnalyticsSummary(
      totalVolumeKg: totalVolume,
      totalWorkoutsCompleted: sessions.length,
      totalActiveHours: activeHours,
      totalCaloriesBurned: totalCalories,
      volumeGrowthPercentage: growthPercent >= 0 ? growthPercent : 0.0,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Analytics & History")),
        body: const Center(child: Text("Please sign in to view workout analytics.")),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('workout_logs')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text("Analytics & History")),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 48),
                    const SizedBox(height: 12),
                    const Text(
                      "Failed to load workout logs",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "${snapshot.error}",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: Colors.grey.shade50,
            appBar: AppBar(
              title: const Text("Analytics & History", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
              backgroundColor: Colors.white,
              elevation: 0,
            ),
            body: const Center(
              child: CircularProgressIndicator(color: Colors.teal),
            ),
          );
        }

        // Parse Firestore documents into WorkoutHistorySession list
        final docs = snapshot.data?.docs ?? [];
        final allSessions = docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>? ?? {};
          return WorkoutHistorySession.fromFirestore(doc.id, data);
        }).toList()
          ..sort((a, b) => b.date.compareTo(a.date)); // Descending chronological order

        final filteredSessions = _filterSessionsByDate(allSessions);
        final summary = _calculateSummary(filteredSessions);

        return Scaffold(
          backgroundColor: Colors.grey.shade50,
          appBar: AppBar(
            title: const Text(
              "Analytics & History",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
            backgroundColor: Colors.white,
            elevation: 0,
            centerTitle: false,
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: Colors.teal,
              indicatorWeight: 3,
              labelColor: Colors.teal,
              unselectedLabelColor: Colors.grey,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              tabs: const [
                Tab(text: "Progression & Charts"),
                Tab(text: "Workout History"),
              ],
            ),
          ),
          body: Column(
            children: [
              // Date Range Filter Bar
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "TIMEFRAME",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.1,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    Row(
                      children: ['7 Days', '30 Days', 'All Time'].map((range) {
                        final isSelected = _selectedDateRange == range;
                        return Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: ChoiceChip(
                            label: Text(range),
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
                              if (val) setState(() => _selectedDateRange = range);
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Tab Views
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Tab 1: Progression & Visual Charts
                    SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. High Level Summary Metrics (Real Volume, Active Hours, Calories)
                          AnalyticsSummaryCards(summary: summary),

                          const SizedBox(height: 8),

                          // 2. Visual Charts (Progression + Frequency from real logs)
                          VisualStrengthCharts(sessions: filteredSessions),

                          const SizedBox(height: 30),
                        ],
                      ),
                    ),

                    // Tab 2: Expandable History Logs
                    filteredSessions.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.history_rounded, size: 54, color: Colors.grey.shade400),
                                  const SizedBox(height: 14),
                                  const Text(
                                    "No Workouts Logged Yet",
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _selectedDateRange == 'All Time'
                                        ? "Start and complete a workout session in the Workout Hub to see your full workout history."
                                        : "No workouts recorded in the last $_selectedDateRange. Switch to 'All Time' or start a workout.",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.builder(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            itemCount: filteredSessions.length,
                            itemBuilder: (context, index) {
                              return WorkoutHistoryListCard(session: filteredSessions[index]);
                            },
                          ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
