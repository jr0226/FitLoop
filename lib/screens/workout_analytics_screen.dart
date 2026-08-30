import 'package:flutter/material.dart';
import '../models/workout_models.dart';
import '../mock/mock_workout_data.dart';
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

  late WorkoutAnalyticsSummary _summary;
  late List<WorkoutHistorySession> _historySessions;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _summary = MockWorkoutData.mockAnalyticsSummary;
    _historySessions = MockWorkoutData.mockHistorySessions;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: "Export Report",
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Exporting full workout volume report (PDF/CSV)..."),
                  backgroundColor: Colors.teal,
                ),
              );
            },
          ),
        ],
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
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Progression & Visual Charts
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. High Level Summary Metrics
                AnalyticsSummaryCards(summary: _summary),

                const SizedBox(height: 8),

                // 2. Visual Charts (Progression + Frequency)
                const VisualStrengthCharts(),

                const SizedBox(height: 30),
              ],
            ),
          ),

          // Tab 2: Expandable History Logs
          ListView.builder(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: 12),
            itemCount: _historySessions.length,
            itemBuilder: (context, index) {
              return WorkoutHistoryListCard(session: _historySessions[index]);
            },
          ),
        ],
      ),
    );
  }
}
