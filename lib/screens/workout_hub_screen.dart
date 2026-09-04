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
import 'build_routine_screen.dart';
import '../widgets/workout/workout_setup_sheet.dart';
import '../utils/routine_category_classifier.dart';

class WorkoutHubScreen extends StatefulWidget {
  const WorkoutHubScreen({super.key});

  @override
  State<WorkoutHubScreen> createState() => _WorkoutHubScreenState();
}

class _WorkoutHubScreenState extends State<WorkoutHubScreen> {
  String _selectedCategory = "All";
  final List<String> _categories = ["All", "Full Body", "Upper Body", "Lower Body", "Core", "Cardio"];
  bool _isGeneratingAi = false;
  bool _showAllRoutines = false;

  void _openRoutineDetails(WorkoutRoutine routine) {
    RoutineDetailModal.show(
      context,
      routine: routine,
      onStart: () => _startRoutine(routine),
      onDelete: () => _deleteRoutine(routine.id),
    );
  }

  void _startRoutine(WorkoutRoutine routine) {
    WorkoutSetupSheet.show(
      context,
      routine: routine,
    );
  }

  void _openBuildMyOwnRoutine([WorkoutRoutine? copyFrom]) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BuildRoutineScreen(initialRoutine: copyFrom),
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

  Future<void> _generateAiPlan(String userGoal, String difficulty, {String? targetCategory}) async {
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
        targetCategory: targetCategory,
        recentWorkoutsSummary: recentSummary,
      );

      // Fetch existing routines to check signatures and prevent duplicate AI saves
      final existingRoutinesSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('routines')
          .get();

      final existingRoutinesList = existingRoutinesSnap.docs
          .map((d) => WorkoutRoutine.fromFirestore(d.id, d.data()))
          .toList();

      final existingSignatures = existingRoutinesList.map((r) => r.signature).toSet();

      final batch = FirebaseFirestore.instance.batch();
      int validRoutinesCount = 0;
      int skippedDuplicatesCount = 0;
      bool dialogDismissed = false;

      for (var routine in generatedRoutines) {
        final String routineName = routine['name'] ?? routine['routineName'] ?? 'Custom Routine';
        final String routineLevel = routine['fitnessLevel'] ?? routine['level'] ?? difficulty;

        // Normalize routine category
        String routineCategory = routine['category'] ?? 'Full Body';
        if (targetCategory != null && targetCategory.isNotEmpty && targetCategory != "All") {
          routineCategory = targetCategory;
        } else {
          final lowerCat = routineCategory.toLowerCase();
          if (lowerCat == 'waist' || lowerCat == 'abs' || lowerCat == 'abdominals') {
            routineCategory = 'Core';
          }
        }

        final String routineImage = routine['imageUrl'] ?? routine['image'] ?? 'https://images.unsplash.com/photo-1517836357463-d25dfeac3438?w=400';
        final List<dynamic> rawExercises = routine['exercises'] ?? [];

        final List<Map<String, dynamic>> normalizedExercises = [];
        for (var e in rawExercises) {
          if (e is Map) {
            final String exName = e['name'] ?? e['exerciseName'] ?? '';
            if (exName.trim().isEmpty) continue;

            String target = e['target'] ?? e['category'] ?? routineCategory;
            final lowerTarget = target.toLowerCase();
            if (lowerTarget == 'abs' || lowerTarget == 'waist' || lowerTarget == 'abdominals') {
              target = 'Core';
            }

            final String exEquipment = e['equipment'] ?? 'Bodyweight';
            final String setsReps = e['sets']?.toString() ?? '3 sets x 10 reps';
            final String instructions = e['instructions'] ?? e['desc'] ?? '';
            final String exImage = e['imageUrl'] ?? e['image'] ?? '';
            final dynamic durationSec = e['durationSeconds'] ?? e['duration'];

            final exData = <String, dynamic>{
              'name': exName,
              'exerciseName': exName,
              'target': target,
              'category': target,
              'equipment': exEquipment,
              'sets': setsReps,
              'instructions': instructions,
              'desc': instructions,
            };
            if (durationSec != null) exData['durationSeconds'] = durationSec;
            if (exImage.isNotEmpty) {
              exData['imageUrl'] = exImage;
              exData['image'] = exImage;
            }
            normalizedExercises.add(exData);
          } else if (e != null && e.toString().trim().isNotEmpty) {
            normalizedExercises.add({
              'name': e.toString(),
              'exerciseName': e.toString(),
              'target': routineCategory,
              'category': routineCategory,
              'equipment': 'Bodyweight',
              'sets': '3 sets x 10 reps',
            });
          }
        }

        // Validation gate: Never persist empty routines
        if (normalizedExercises.isEmpty) {
          debugPrint("Validation gate: Skipping empty routine '$routineName'");
          continue;
        }

        // 1. Calculate routine signature to check for exact duplicates
        final candidateSignature = WorkoutRoutine.generateRoutineSignature(
          name: routineName,
          category: routineCategory,
          fitnessLevel: routineLevel,
          exerciseNames: normalizedExercises.map((e) => e['name'].toString()).toList(),
        );

        if (existingSignatures.contains(candidateSignature)) {
          debugPrint("[WorkoutHub] Routine '$routineName' ($candidateSignature) already exists. Skipping duplicate save.");
          skippedDuplicatesCount++;
          continue;
        }

        // 2. Near-duplicate similarity check (Jaccard similarity >= 0.70)
        final candidateExSet = normalizedExercises
            .map((e) => e['name'].toString().trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' '))
            .where((e) => e.isNotEmpty)
            .toSet();

        WorkoutRoutine? nearDuplicateRoutine;
        double maxSimilarity = 0.0;
        for (final existing in existingRoutinesList) {
          final catMatch = RoutineCategoryClassifier.matchesCategory(existing.category, routineCategory) ||
              existing.category.trim().toLowerCase() == routineCategory.trim().toLowerCase();
          if (catMatch && existing.level.displayName.toLowerCase() == routineLevel.toLowerCase()) {
            final sim = WorkoutRoutine.calculateExerciseSimilarity(candidateExSet, existing.normalizedExerciseSet);
            if (sim >= 0.70 && sim > maxSimilarity) {
              maxSimilarity = sim;
              nearDuplicateRoutine = existing;
            }
          }
        }

        if (nearDuplicateRoutine != null) {
          debugPrint("[WorkoutHub] Near duplicate detected: '$routineName' vs '${nearDuplicateRoutine.title}' (Similarity: ${(maxSimilarity * 100).toStringAsFixed(1)}%)");
          if (mounted) {
            if (!dialogDismissed) {
              Navigator.pop(context); // Dismiss loading dialog
              dialogDismissed = true;
            }
            final bool? saveAnyway = await showDialog<bool>(
              context: context,
              barrierDismissible: false,
              builder: (ctx) => AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                title: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange),
                    SizedBox(width: 8),
                    Text("Similar Routine Exists", style: TextStyle(fontSize: 16)),
                  ],
                ),
                content: Text(
                  "A very similar routine ('${nearDuplicateRoutine!.title}') already exists in your library with ${(maxSimilarity * 100).toInt()}% matching exercises.\n\nWould you like to use your existing routine or save this new variation anyway?",
                  style: const TextStyle(fontSize: 13, height: 1.4),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text("Use Existing", style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text("Save Anyway"),
                  ),
                ],
              ),
            );

            if (saveAnyway != true) {
              // User chose "Use Existing"
              setState(() => _isGeneratingAi = false);
              _openRoutineDetails(nearDuplicateRoutine);
              return;
            }
          }
        }

        existingSignatures.add(candidateSignature);

        final docRef = FirebaseFirestore.instance.collection('users').doc(user.uid).collection('routines').doc();
        validRoutinesCount++;

        batch.set(docRef, {
          'name': routineName,
          'routineName': routineName,
          'category': routineCategory,
          'fitnessGoal': effectiveGoal,
          'goal': effectiveGoal,
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

      if (validRoutinesCount == 0) {
        if (skippedDuplicatesCount > 0) {
          if (mounted) {
            if (!dialogDismissed) {
              Navigator.pop(context); // Dismiss dialog
              dialogDismissed = true;
            }
            setState(() => _isGeneratingAi = false);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("A similar routine already exists in Your Routines."),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return;
        }
        throw Exception("AI service could not generate valid exercises. Please try again.");
      }

      await batch.commit();

      if (mounted) {
        if (!dialogDismissed) {
          Navigator.pop(context); // Dismiss dialog
          dialogDismissed = true;
        }
        setState(() => _isGeneratingAi = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(skippedDuplicatesCount > 0
                ? "Personalized routine saved! (Skipped $skippedDuplicatesCount existing duplicate) 🎉"
                : "New AI Routine generated and added to your routines! 🎉"),
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
            content: Text("Unable to generate a suitable workout for your current preferences. Try adjusting equipment or workout type."),
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
          List<String> preferredWorkoutTypes = [];
          if (userData['preferredWorkoutTypes'] is List) {
            preferredWorkoutTypes = List<String>.from(
              (userData['preferredWorkoutTypes'] as List).map((e) => e.toString()),
            );
          }

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
                  final List<WorkoutRoutine> rawRoutines = routineDocs.map((doc) {
                    return WorkoutRoutine.fromFirestore(doc.id, doc.data() as Map<String, dynamic>);
                  }).toList();

                  // Deduplicate routines by deterministic signature:
                  // Prevents duplicate display when duplicate Firestore documents exist.
                  // Prefers the most complete routine (most exercises or valid banner image).
                  final Map<String, WorkoutRoutine> uniqueRoutinesMap = {};
                  final List<String> duplicateDocIds = [];

                  for (final r in rawRoutines) {
                    final sig = r.signature;
                    if (!uniqueRoutinesMap.containsKey(sig)) {
                      uniqueRoutinesMap[sig] = r;
                    } else {
                      duplicateDocIds.add(r.id);
                      final existing = uniqueRoutinesMap[sig]!;
                      // Prefer routine with more exercises or non-empty banner image
                      if (r.exercises.length > existing.exercises.length ||
                          ((r.bannerImageUrl != null && r.bannerImageUrl!.isNotEmpty) &&
                           (existing.bannerImageUrl == null || existing.bannerImageUrl!.isEmpty))) {
                        uniqueRoutinesMap[sig] = r;
                      }
                    }
                  }

                  if (duplicateDocIds.isNotEmpty) {
                    debugPrint("[WorkoutHub] Deduplicated ${duplicateDocIds.length} duplicate routines from view: $duplicateDocIds");
                  }

                  final List<WorkoutRoutine> routines = uniqueRoutinesMap.values.toList();

                  // Select ONE Featured Routine (Today's / Recommended):
                  // Real Level & Preference Priority:
                  // 1. Strict Level Enforcement: routines matching user's current fitnessLevel
                  // 2. Prioritize routines matching preferredWorkoutTypes
                  // 3. Prioritize routines matching userGoal
                  WorkoutRoutine? featuredRoutine;
                  if (routines.isNotEmpty) {
                    final cleanUserLevel = userLevel.toLowerCase();
                    final sameLevelRoutines = routines.where(
                      (r) => r.level.displayName.toLowerCase() == cleanUserLevel,
                    ).toList();

                    // Candidate pool: strictly matching level if any exist; otherwise fallback to all
                    final candidatePool = sameLevelRoutines.isNotEmpty ? sameLevelRoutines : routines;

                    // Rank within candidate pool
                    featuredRoutine = candidatePool.firstWhere(
                      (r) => r.isAiGenerated &&
                             preferredWorkoutTypes.any((pref) => RoutineCategoryClassifier.matchesRoutine(r, pref)) &&
                             r.goal.displayName.toLowerCase() == userGoal.toLowerCase(),
                      orElse: () => candidatePool.firstWhere(
                        (r) => r.isAiGenerated &&
                               preferredWorkoutTypes.any((pref) => RoutineCategoryClassifier.matchesRoutine(r, pref)),
                        orElse: () => candidatePool.firstWhere(
                          (r) => r.isAiGenerated &&
                                 r.goal.displayName.toLowerCase() == userGoal.toLowerCase(),
                          orElse: () => candidatePool.firstWhere(
                            (r) => r.isAiGenerated,
                            orElse: () => candidatePool.first,
                          ),
                        ),
                      ),
                    );
                  }

                  // Filter for "Your Routines" list using centralized multi-tier classifier
                  final filteredRoutines = _selectedCategory == "All"
                      ? routines
                      : routines.where((r) => RoutineCategoryClassifier.matchesRoutine(r, _selectedCategory)).toList();

                  // Cluster routines by exercise similarity (Jaccard similarity >= 0.70)
                  final clusters = RoutineCluster.clusterRoutines(filteredRoutines);

                  // Restructure "All" information density:
                  // Show max 5 routine clusters initially, with expandable "View All X Routines" button
                  final displayedClusters = (_selectedCategory == "All" && !_showAllRoutines && clusters.length > 5)
                      ? clusters.take(5).toList()
                      : clusters;

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

                        // 3. Section Header: "Your Routines" + Actions (Build My Own & Generate)
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
                              Row(
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: () => _openBuildMyOwnRoutine(),
                                    icon: const Icon(Icons.add, size: 14),
                                    label: const Text(
                                      "Build My Own",
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.teal,
                                      side: const BorderSide(color: Colors.teal),
                                      visualDensity: VisualDensity.compact,
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  TextButton.icon(
                                    onPressed: () => _generateAiPlan(
                                      userGoal,
                                      userLevel,
                                      targetCategory: _selectedCategory != "All" ? _selectedCategory : null,
                                    ),
                                    icon: const Icon(Icons.auto_awesome, size: 14, color: Colors.teal),
                                    label: const Text(
                                      "Generate",
                                      style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold, fontSize: 12),
                                    ),
                                    style: TextButton.styleFrom(
                                      visualDensity: VisualDensity.compact,
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                    ),
                                  ),
                                ],
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

                        // 5. Routines List (Clustered to avoid endlessly long flat lists)
                        if (clusters.isEmpty)
                          _buildEmptyRoutinesList(_selectedCategory, userGoal, userLevel)
                        else ...[
                          ...displayedClusters.map((cluster) => _buildRoutineTile(
                                cluster.primary,
                                variationCount: cluster.variations.length,
                                variations: cluster.variations,
                              )),
                          if (_selectedCategory == "All" && clusters.length > 5)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              child: Center(
                                child: !_showAllRoutines
                                    ? OutlinedButton.icon(
                                        onPressed: () => setState(() => _showAllRoutines = true),
                                        icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
                                        label: Text(
                                          "View All (${clusters.length}) Routines",
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.teal,
                                          side: BorderSide(color: Colors.teal.shade300),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                        ),
                                      )
                                    : TextButton.icon(
                                        onPressed: () => setState(() => _showAllRoutines = false),
                                        icon: const Icon(Icons.keyboard_arrow_up_rounded, size: 18, color: Colors.grey),
                                        label: const Text(
                                          "Show Less",
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey),
                                        ),
                                      ),
                              ),
                            ),
                        ],

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
              onPressed: () => _generateAiPlan(
                goal,
                level,
                targetCategory: _selectedCategory != "All" ? _selectedCategory : null,
              ),
              icon: const Icon(Icons.auto_awesome, size: 20),
              label: Text(
                _selectedCategory != "All" ? "Generate $_selectedCategory Plan" : "Generate Workout Plan",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
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
              category == "All"
                  ? "Tap 'Generate Plan' to create personalized routines."
                  : "Tap below to create a personalized $category workout.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: () => _generateAiPlan(
                goal,
                level,
                targetCategory: category != "All" ? category : null,
              ),
              icon: const Icon(Icons.auto_awesome, size: 16),
              label: Text(category == "All" ? "Generate Workout Plan" : "Generate $category Plan"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                elevation: 1,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showVariationsModal(WorkoutRoutine primary, List<WorkoutRoutine> variations) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Similar Variations (${variations.length + 1})",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              "Variations of '${primary.title}' with high exercise overlap:",
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(primary.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: Text("${primary.exercises.length} exercises • Primary"),
                    trailing: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _openRoutineDetails(primary);
                      },
                      child: const Text("View", style: TextStyle(fontSize: 12)),
                    ),
                  ),
                  const Divider(height: 1),
                  ...variations.map((v) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(v.title, style: const TextStyle(fontSize: 14)),
                    subtitle: Text("${v.exercises.length} exercises"),
                    trailing: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _openRoutineDetails(v);
                      },
                      child: const Text("View", style: TextStyle(fontSize: 12)),
                    ),
                  )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoutineTile(
    WorkoutRoutine routine, {
    int variationCount = 0,
    List<WorkoutRoutine>? variations,
  }) {
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
                      Text(
                        "${routine.level.displayName} • ${routine.category} • ${routine.primaryEquipment}",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (variationCount > 0) ...[
                        const SizedBox(height: 4),
                        GestureDetector(
                          onTap: variations != null && variations.isNotEmpty ? () => _showVariationsModal(routine, variations) : null,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.teal.shade50,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.teal.shade200),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.copy_all_rounded, size: 11, color: Colors.teal.shade700),
                                const SizedBox(width: 3),
                                Text(
                                  "+$variationCount similar variation${variationCount > 1 ? 's' : ''}",
                                  style: TextStyle(fontSize: 10, color: Colors.teal.shade800, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
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

                // Overflow Menu (Customize/Copy & Delete & Variations)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 18, color: Colors.grey),
                  padding: EdgeInsets.zero,
                  onSelected: (val) {
                    if (val == 'customize') {
                      _openBuildMyOwnRoutine(routine);
                    } else if (val == 'delete') {
                      _deleteRoutine(routine.id);
                    } else if (val == 'variations' && variations != null && variations.isNotEmpty) {
                      _showVariationsModal(routine, variations);
                    }
                  },
                  itemBuilder: (context) => [
                    if (variationCount > 0 && variations != null && variations.isNotEmpty)
                      PopupMenuItem(
                        value: 'variations',
                        child: Row(
                          children: [
                            const Icon(Icons.copy_all_rounded, color: Colors.teal, size: 18),
                            const SizedBox(width: 8),
                            Text("Variations ($variationCount)", style: const TextStyle(color: Colors.black87, fontSize: 13)),
                          ],
                        ),
                      ),
                    const PopupMenuItem(
                      value: 'customize',
                      child: Row(
                        children: [
                          Icon(Icons.edit_note_rounded, color: Colors.teal, size: 18),
                          SizedBox(width: 8),
                          Text("Customize / Copy", style: TextStyle(color: Colors.black87, fontSize: 13)),
                        ],
                      ),
                    ),
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
