import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AchievementsTab extends StatefulWidget {
  const AchievementsTab({super.key});

  @override
  State<AchievementsTab> createState() => _AchievementsTabState();
}

class _AchievementsTabState extends State<AchievementsTab> {
  final String uid = FirebaseAuth.instance.currentUser!.uid;
  bool _isLoading = true;

  // --- PROGRESS DATA ---
  int _totalWorkouts = 0;
  int _currentStreak = 0;
  double _totalWeightLifted = 0.0;
  int _maxCaloriesOneSession = 0;
  int _longestWorkoutSecs = 0;

  // --- PERSONAL RECORDS (Exercise Name -> Max Weight) ---
  final Map<String, double> _personalRecords = {};

  @override
  void initState() {
    super.initState();
    _calculateAchievementsAndPRs();
  }

  Future<void> _calculateAchievementsAndPRs() async {
    try {
      // 1. Get User Profile Data (for Streak)
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      _currentStreak = userDoc.data()?['currentStreak'] ?? 0;

      // 2. Get All Workout Logs
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('workout_logs')
          .get();

      _totalWorkouts = snapshot.docs.length;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        
        // Check Session PRs
        final int cals = (data['caloriesBurned'] as num?)?.toInt() ?? 0;
        final int duration = (data['durationSeconds'] as num?)?.toInt() ?? 0;
        
        if (cals > _maxCaloriesOneSession) _maxCaloriesOneSession = cals;
        if (duration > _longestWorkoutSecs) _longestWorkoutSecs = duration;

        // Calculate Lifting PRs and Total Volume
        final List<dynamic> exercises = data['exercises'] ?? [];
        for (var ex in exercises) {
          final String exName = ex['exerciseName'] ?? 'Unknown';
          final List<dynamic> sets = ex['sets'] ?? [];
          
          for (var s in sets) {
            final double weight = (s['weight'] as num?)?.toDouble() ?? 0.0;
            final int reps = (s['reps'] as num?)?.toInt() ?? 0;
            
            // Add to total volume
            _totalWeightLifted += (weight * reps);

            // Check if this is the heaviest lift for this specific exercise
            if (weight > 0) {
              if (!_personalRecords.containsKey(exName) || weight > _personalRecords[exName]!) {
                _personalRecords[exName] = weight;
              }
            }
          }
        }
      }

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("Error calculating achievements: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatDuration(int seconds) {
    int m = seconds ~/ 60;
    return "$m min";
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          title: const Text("Trophy Room", style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.white,
          elevation: 0,
          bottom: const TabBar(
            labelColor: Colors.teal,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.teal,
            tabs: [
              Tab(icon: Icon(Icons.emoji_events), text: "Badges"),
              Tab(icon: Icon(Icons.military_tech), text: "Records (PRs)"),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.teal))
            : TabBarView(
                children: [
                  _buildBadgesTab(),
                  _buildPersonalRecordsTab(),
                ],
              ),
      ),
    );
  }

  // ==========================================
  // TAB 1: ACHIEVEMENTS & BADGES
  // ==========================================
  Widget _buildBadgesTab() {
    // Define the conditions for badges based on your feature list
    final List<Map<String, dynamic>> badges = [
      {
        "title": "First Steps",
        "desc": "Complete your first workout.",
        "icon": Icons.directions_run,
        "unlocked": _totalWorkouts >= 1,
        "color": Colors.blue,
      },
      {
        "title": "Dedicated",
        "desc": "Reach a 7-Day Workout Streak.",
        "icon": Icons.local_fire_department,
        "unlocked": _currentStreak >= 7,
        "color": Colors.orange,
      },
      {
        "title": "Iron Club",
        "desc": "Lift over 1,000 kg total volume.",
        "icon": Icons.fitness_center,
        "unlocked": _totalWeightLifted >= 1000,
        "color": Colors.grey.shade800,
      },
      {
        "title": "Calorie Crusher",
        "desc": "Burn 500+ kcal in one session.",
        "icon": Icons.whatshot,
        "unlocked": _maxCaloriesOneSession >= 500,
        "color": Colors.redAccent,
      },
      {
        "title": "Century Mark",
        "desc": "Complete 100 workouts.",
        "icon": Icons.workspace_premium,
        "unlocked": _totalWorkouts >= 100,
        "color": Colors.amber,
      },
      {
        "title": "Endurance Master",
        "desc": "Workout for over 60 minutes.",
        "icon": Icons.timer,
        "unlocked": _longestWorkoutSecs >= 3600,
        "color": Colors.purple,
      },
    ];

    return GridView.builder(
      padding: const EdgeInsets.all(20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.85,
      ),
      itemCount: badges.length,
      itemBuilder: (context, index) {
        final badge = badges[index];
        final bool isUnlocked = badge['unlocked'];

        return Container(
          decoration: BoxDecoration(
            color: isUnlocked ? Colors.white : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isUnlocked ? badge['color'].withOpacity(0.5) : Colors.grey.shade300,
              width: 2,
            ),
            boxShadow: isUnlocked 
              ? [BoxShadow(color: badge['color'].withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))] 
              : [],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: isUnlocked ? badge['color'].withOpacity(0.2) : Colors.grey.shade300,
                child: Icon(
                  isUnlocked ? badge['icon'] : Icons.lock,
                  color: isUnlocked ? badge['color'] : Colors.grey.shade500,
                  size: 30,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                badge['title'],
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: isUnlocked ? Colors.black87 : Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: Text(
                  badge['desc'],
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ==========================================
  // TAB 2: PERSONAL RECORDS (PRs)
  // ==========================================
  Widget _buildPersonalRecordsTab() {
    if (_personalRecords.isEmpty && _maxCaloriesOneSession == 0) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.military_tech, size: 60, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text("No records yet.", style: TextStyle(fontSize: 18, color: Colors.grey.shade600)),
            const Text("Log weights in your workouts to set PRs!"),
          ],
        ),
      );
    }

    // Sort PRs alphabetically by exercise name
    final sortedPRs = _personalRecords.entries.toList()..sort((a, b) => a.key.compareTo(b.key));

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Overall Session Bests
        const Text("Session Bests", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildSessionStatCard("Max Calories", "$_maxCaloriesOneSession kcal", Icons.local_fire_department, Colors.orange)),
            const SizedBox(width: 12),
            Expanded(child: _buildSessionStatCard("Longest Session", _formatDuration(_longestWorkoutSecs), Icons.timer, Colors.blue)),
          ],
        ),
        
        const SizedBox(height: 30),
        const Text("Heaviest Lifts (1RM Estimation)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        
        ...sortedPRs.map((entry) {
          return Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.teal.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.fitness_center, color: Colors.teal),
              ),
              title: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.bold)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "${entry.value} kg", 
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal)
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.emoji_events, color: Colors.amber, size: 20),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildSessionStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          Text(title, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
        ],
      ),
    );
  }
} 