import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/workout_models.dart';
import '../services/ai_service.dart';
import '../widgets/workout/workout_streak_header.dart';
import '../widgets/workout/daily_routine_card.dart';
import '../widgets/workout/routine_detail_modal.dart';
import 'active_workout_page.dart';
import 'exercise_library_screen.dart';
import 'workout_analytics_screen.dart';

class WorkoutHubScreen extends StatefulWidget {
  const WorkoutHubScreen({super.key});

  @override
  State<WorkoutHubScreen> createState() => _WorkoutHubScreenState();
}

class _WorkoutHubScreenState extends State<WorkoutHubScreen> {
  String _selectedCategory = "All";
  final List<String> _categories = ["All", "Full Body", "Upper Body", "Lower Body", "Core", "Cardio"];
  bool _isGeneratingAi = false;

  void _openRoutineDetails(WorkoutRoutine routine) {
    RoutineDetailModal.show(
      context,
      routine: routine,
      onStart: () => _startRoutine(routine),
      onDelete: () => _deleteRoutine(routine.id),
    );
  }

  void _startRoutine(WorkoutRoutine routine) {
    final convertedExercises = routine.exercises.map((e) => {
      'name': e.name,
      'target': e.targetMuscle,
      'equipment': e.equipment,
      'sets': e.defaultSets,
      'reps': e.defaultReps,
    }).toList();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ActiveWorkoutPage(
          workoutName: routine.title,
          routine: convertedExercises.isEmpty ? [
            {'name': 'Bodyweight Squats', 'target': 'Legs', 'sets': 3, 'reps': 15, 'equipment': 'Bodyweight'},
            {'name': 'Push Ups', 'target': 'Chest', 'sets': 3, 'reps': 12, 'equipment': 'Bodyweight'},
          ] : convertedExercises,
          routineId: routine.id,
          workoutType: routine.category,
          fitnessGoal: routine.goal.displayName,
          fitnessLevel: routine.level.displayName,
        ),
      ),
    );
  }

  void _startBlankWorkout() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ActiveWorkoutPage(
          workoutName: "Freestyle Session",
          routine: [
            {'name': 'Freestyle Movement', 'target': 'Full Body', 'sets': 3, 'reps': 10, 'equipment': 'Bodyweight'}
          ],
        ),
      ),
    );
  }

  void _showExerciseLibraryModal() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ExerciseLibraryScreen(),
      ),
    );
  }

  void _showAnalyticsScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const WorkoutAnalyticsScreen(),
      ),
    );
  }

  Future<void> _deleteRoutine(String routineId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('routines')
            .doc(routineId)
            .delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Routine removed from your list."),
              backgroundColor: Colors.teal,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Unable to delete routine: $e")),
        );
      }
    }
  }

  Future<void> _generateAiPlan(String userGoal, String difficulty) async {
    if (_isGeneratingAi) return;
    setState(() => _isGeneratingAi = true);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.teal),
            SizedBox(height: 16),
            Text(
              "AI is tailoring your workout routine...",
              style: TextStyle(color: Colors.white, decoration: TextDecoration.none, fontSize: 14),
            ),
          ],
        ),
      ),
    );

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("User not authenticated.");

      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final userData = userDoc.data() ?? {};
      final String effectiveGoal = userData['fitnessGoal'] ?? userData['goal'] ?? userGoal;
      final String effectiveDifficulty = userData['fitnessLevel'] ?? userData['level'] ?? difficulty;
      List<String> equipment = [];
      if (userData['equipment'] is List) {
        equipment = List<String>.from((userData['equipment'] as List).map((e) => e.toString()));
      }
      List<String> preferredWorkoutTypes = [];
      if (userData['preferredWorkoutTypes'] is List) {
        preferredWorkoutTypes = List<String>.from((userData['preferredWorkoutTypes'] as List).map((e) => e.toString()));
      }

      // 7-day workout history summary
      String? recentSummary;
      try {
        final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
        final recentLogsSnap = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('workout_logs')
            .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(sevenDaysAgo))
            .limit(15)
            .get();

        if (recentLogsSnap.docs.isNotEmpty) {
          final Map<String, int> counts = {};
          for (var doc in recentLogsSnap.docs) {
            final data = doc.data();
            final String type = (data['workoutType'] ?? data['category'] ?? data['routineName'] ?? 'Workout').toString();
            counts[type] = (counts[type] ?? 0) + 1;
          }
          final parts = counts.entries.map((e) => '${e.key}: ${e.value} session${e.value > 1 ? 's' : ''}').toList();
          recentSummary = 'Recent 7 days: ${parts.join(', ')}';
        }
      } catch (err) {
        debugPrint('Note: Could not query recent workout history for AI: $err');
      }

      final List<Map<String, dynamic>> generatedRoutines = await AiService.generateWorkoutPlan(
        userGoal: effectiveGoal,
        difficulty: effectiveDifficulty,
        equipment: equipment,
        preferredWorkoutTypes: preferredWorkoutTypes,
        recentWorkoutsSummary: recentSummary,
      );

      final batch = FirebaseFirestore.instance.batch();
      for (var routine in generatedRoutines) {
        final docRef = FirebaseFirestore.instance.collection('users').doc(user.uid).collection('routines').doc();
        final String routineName = routine['name'] ?? routine['routineName'] ?? 'Custom Routine';
        final String routineLevel = routine['fitnessLevel'] ?? routine['level'] ?? difficulty;
        final String routineCategory = routine['category'] ?? 'Full Body';
        final String routineImage = routine['imageUrl'] ?? routine['image'] ?? 'https://images.unsplash.com/photo-1517836357463-d25dfeac3438?w=400';
        final List<dynamic> rawExercises = routine['exercises'] ?? [];

        final List<Map<String, dynamic>> normalizedExercises = rawExercises.map((e) {
          if (e is Map) {
            final String exName = e['name'] ?? e['exerciseName'] ?? 'Exercise';
            final String target = e['target'] ?? e['category'] ?? 'Full Body';
            final String exEquipment = e['equipment'] ?? 'General';
            final String setsReps = e['sets']?.toString() ?? '3 sets x 10 reps';
            final String instructions = e['instructions'] ?? e['desc'] ?? '';
            final String exImage = e['imageUrl'] ?? e['image'] ?? '';

            return {
              'name': exName,
              'exerciseName': exName,
              'target': target,
              'category': target,
              'equipment': exEquipment,
              'sets': setsReps,
              'instructions': instructions,
              'desc': instructions,
              if (exImage.isNotEmpty) 'imageUrl': exImage,
              if (exImage.isNotEmpty) 'image': exImage,
            };
          }
          return {'name': e.toString(), 'exerciseName': e.toString()};
        }).toList();

        batch.set(docRef, {
          'name': routineName,
          'routineName': routineName,
          'category': routineCategory,
          'fitnessGoal': userGoal,
          'fitnessLevel': routineLevel,
          'level': routineLevel,
          'source': 'ai_generated',
          'imageUrl': routineImage,
          'image': routineImage,
          'exercises': normalizedExercises,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      if (mounted) {
        Navigator.pop(context); // Dismiss dialog
        setState(() => _isGeneratingAi = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("New AI Routine generated and added to your routines! 🎉"),
            backgroundColor: Colors.teal,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Dismiss dialog
        setState(() => _isGeneratingAi = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Unable to generate plan. Please try again."),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  StreakSummary _buildStreakSummary(Map<String, dynamic> userData, List<QueryDocumentSnapshot> workoutLogs) {
    final int currentStreak = (userData['currentStreak'] is num) ? (userData['currentStreak'] as num).toInt() : int.tryParse(userData['currentStreak']?.toString() ?? '') ?? 0;
    final rawBestStreak = userData['longestStreak'] ?? userData['bestStreak'];
    final int bestStreak = (rawBestStreak is num) ? rawBestStreak.toInt() : int.tryParse(rawBestStreak?.toString() ?? '') ?? currentStreak;
    const int weeklyGoalDays = 4;

    final now = DateTime.now();
    final int currentWeekday = now.weekday; // 1 = Mon, 7 = Sun
    final DateTime monday = DateTime(now.year, now.month, now.day).subtract(Duration(days: currentWeekday - 1));

    final List<bool> pastWeekActiveDays = List.filled(7, false);
    for (var doc in workoutLogs) {
      final data = doc.data() as Map<String, dynamic>;
      final Timestamp? ts = data['timestamp'] ?? data['createdAt'];
      if (ts != null) {
        final DateTime date = ts.toDate();
        final int diffDays = date.difference(monday).inDays;
        if (diffDays >= 0 && diffDays < 7) {
          pastWeekActiveDays[diffDays] = true;
        }
      }
    }

    final int weeklyCompletedDays = pastWeekActiveDays.where((active) => active).length;

    return StreakSummary(
      currentStreakDays: currentStreak,
      bestStreakDays: bestStreak,
      weeklyCompletedDays: weeklyCompletedDays,
      weeklyGoalDays: weeklyGoalDays,
      pastWeekActiveDays: pastWeekActiveDays,
      badges: const [],
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text("Please sign in to access Workout Hub")),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Workout Hub",
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: Colors.black87),
            ),
            Text(
              "Train consistently, track progress",
              style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded, color: Colors.teal),
            tooltip: "Exercise Library",
            onPressed: _showExerciseLibraryModal,
          ),
          IconButton(
            icon: const Icon(Icons.insights_rounded, color: Colors.teal),
            tooltip: "Workout Analytics",
            onPressed: _showAnalyticsScreen,
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
        builder: (context, userSnapshot) {
          final userData = (userSnapshot.data?.data() as Map<String, dynamic>?) ?? {};
          final String userGoal = userData['fitnessGoal'] ?? userData['goal'] ?? "Maintenance";
          final String userLevel = userData['fitnessLevel'] ?? userData['level'] ?? "Beginner";

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .collection('workout_logs')
                .orderBy('timestamp', descending: true)
                .limit(20)
                .snapshots(),
            builder: (context, logsSnapshot) {
              final workoutLogs = logsSnapshot.data?.docs ?? [];
              final streakSummary = _buildStreakSummary(userData, workoutLogs);

              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .collection('routines')
                    .snapshots(),
                builder: (context, routinesSnapshot) {
                  if (routinesSnapshot.connectionState == ConnectionState.waiting && !routinesSnapshot.hasData) {
                    return const Center(child: CircularProgressIndicator(color: Colors.teal));
                  }

                  if (routinesSnapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 48),
                            const SizedBox(height: 12),
                            const Text(
                              "Unable to load workout routines. Please check connection and try again.",
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.redAccent, fontSize: 14),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () => setState(() {}),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                              child: const Text("Retry"),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final routineDocs = routinesSnapshot.data?.docs ?? [];
                  final List<WorkoutRoutine> routines = routineDocs.map((doc) {
                    return WorkoutRoutine.fromFirestore(doc.id, doc.data() as Map<String, dynamic>);
                  }).toList();

                  // Select ONE Featured Routine (Today's / Recommended):
                  // Priority: AI-generated routine matching goal/level, or first routine
                  WorkoutRoutine? featuredRoutine;
                  if (routines.isNotEmpty) {
                    featuredRoutine = routines.firstWhere(
                      (r) => r.isAiGenerated &&
                             (r.goal.displayName.toLowerCase() == userGoal.toLowerCase() ||
                              r.level.displayName.toLowerCase() == userLevel.toLowerCase()),
                      orElse: () => routines.firstWhere(
                        (r) => r.goal.displayName.toLowerCase() == userGoal.toLowerCase(),
                        orElse: () => routines.first,
                      ),
                    );
                  }

                  // Filter for "Your Routines" list
                  final filteredRoutines = _selectedCategory == "All"
                      ? routines
                      : routines.where((r) => r.category.toLowerCase().contains(_selectedCategory.toLowerCase())).toList();

                  return SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 30),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. Compact Streak Header (Sleek & non-intrusive)
                        WorkoutStreakHeader(streakSummary: streakSummary),

                        // 2. Primary Hero Card: Today's / Recommended Routine
                        if (featuredRoutine != null)
                          DailyRoutineCard(
                            routine: featuredRoutine,
                            onStart: () => _startRoutine(featuredRoutine!),
                            onTap: () => _openRoutineDetails(featuredRoutine!),
                          )
                        else
                          _buildEmptyHeroCard(userGoal, userLevel),

                        const SizedBox(height: 16),

                        // 3. Section Header: "Your Routines" + Action to Generate
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                "Your Routines",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              TextButton.icon(
                                onPressed: () => _generateAiPlan(userGoal, userLevel),
                                icon: const Icon(Icons.auto_awesome, size: 15, color: Colors.teal),
                                label: const Text(
                                  "Generate Plan",
                                  style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // 4. Category Filter Chips
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: _categories.map((cat) {
                              final isSelected = _selectedCategory == cat;
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: FilterChip(
                                  selected: isSelected,
                                  label: Text(cat),
                                  labelStyle: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    color: isSelected ? Colors.white : Colors.black87,
                                  ),
                                  selectedColor: Colors.teal,
                                  backgroundColor: Colors.white,
                                  checkmarkColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    side: BorderSide(
                                      color: isSelected ? Colors.teal : Colors.grey.shade300,
                                    ),
                                  ),
                                  onSelected: (selected) {
                                    setState(() => _selectedCategory = cat);
                                  },
                                ),
                              );
                            }).toList(),
                          ),
                        ),

                        const SizedBox(height: 10),

                        // 5. Routines List
                        if (filteredRoutines.isEmpty)
                          _buildEmptyRoutinesList(_selectedCategory, userGoal, userLevel)
                        else
                          ...filteredRoutines.map((routine) => _buildRoutineTile(routine)),

                        const SizedBox(height: 20),

                        // 6. Secondary Quick Tools (Compact Row)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              Expanded(
                                child: _buildQuickToolCard(
                                  icon: Icons.fitness_center_rounded,
                                  title: "Exercise Library",
                                  subtitle: "Explore 1,300+ moves",
                                  color: Colors.blueAccent,
                                  onTap: _showExerciseLibraryModal,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _buildQuickToolCard(
                                  icon: Icons.insights_rounded,
                                  title: "Workout Analytics",
                                  subtitle: "Volume & Progress",
                                  color: Colors.deepPurpleAccent,
                                  onTap: _showAnalyticsScreen,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 12),

                        // 7. Optional Freestyle Quick Action
                        Center(
                          child: TextButton.icon(
                            onPressed: _startBlankWorkout,
                            icon: const Icon(Icons.add_circle_outline, size: 16, color: Colors.grey),
                            label: const Text(
                              "Start Freestyle Workout Session",
                              style: TextStyle(color: Colors.grey, fontSize: 12),
                            ),
                          ),
                        ),
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
  }

  Widget _buildEmptyHeroCard(String goal, String level) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.teal.shade200, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.auto_awesome, color: Colors.teal, size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "No Routines Yet",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
                    ),
                    Text(
                      "Ready to begin your training?",
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            "Let FitLoop AI generate a personalized routine tailored to your $goal goal ($level level).",
            style: TextStyle(color: Colors.grey.shade700, fontSize: 13, height: 1.3),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () => _generateAiPlan(goal, level),
              icon: const Icon(Icons.auto_awesome, size: 20),
              label: const Text(
                "Generate Workout Plan",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyRoutinesList(String category, String goal, String level) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.folder_open_rounded, color: Colors.grey.shade400, size: 36),
            const SizedBox(height: 8),
            Text(
              category == "All" ? "No routines saved yet" : "No routines in '$category'",
              style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              "Tap 'Generate Plan' to create personalized routines.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoutineTile(WorkoutRoutine routine) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => _openRoutineDetails(routine),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // Leading Category Icon
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.teal.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.fitness_center_rounded, color: Colors.teal, size: 22),
                ),
                const SizedBox(width: 14),

                // Main Info (Title + Subtitle + Chips)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        routine.title,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: routine.level.badgeColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              routine.level.displayName,
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: routine.level.badgeColor),
                            ),
                          ),
                          Text(
                            "${routine.durationMinutes} min • ${routine.exercises.length} exercises",
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Outlined Start Button
                OutlinedButton(
                  onPressed: () => _startRoutine(routine),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.teal,
                    side: const BorderSide(color: Colors.teal),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text("Start", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ),

                // Overflow Menu (Delete)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 18, color: Colors.grey),
                  padding: EdgeInsets.zero,
                  onSelected: (val) {
                    if (val == 'delete') {
                      _deleteRoutine(routine.id);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                          SizedBox(width: 8),
                          Text("Delete Routine", style: TextStyle(color: Colors.redAccent, fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickToolCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black87),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
