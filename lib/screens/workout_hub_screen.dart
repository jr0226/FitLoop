import 'package:flutter/material.dart';
import '../models/workout_models.dart';
import '../mock/mock_workout_data.dart';
import '../widgets/workout/workout_streak_header.dart';
import '../widgets/workout/daily_routine_card.dart';
import '../widgets/workout/ai_recommendation_banner.dart';
import '../widgets/workout/workout_quick_action_bar.dart';
import 'active_workout_page.dart';
import 'exercise_library_screen.dart';
import 'workout_analytics_screen.dart';

class WorkoutHubScreen extends StatefulWidget {
  const WorkoutHubScreen({super.key});

  @override
  State<WorkoutHubScreen> createState() => _WorkoutHubScreenState();
}

class _WorkoutHubScreenState extends State<WorkoutHubScreen> {
  late StreakSummary _streakSummary;
  late WorkoutRoutine _dailyRoutine;
  late WorkoutRoutine _aiRoutine;
  late List<WorkoutRoutine> _exploreRoutines;

  String _selectedCategory = "All";
  final List<String> _categories = ["All", "Full Body", "Upper Body", "Core", "Cardio"];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    _streakSummary = MockWorkoutData.mockStreak;
    _dailyRoutine = MockWorkoutData.todayScheduledRoutine;
    _aiRoutine = MockWorkoutData.aiRecommendedRoutine;
    _exploreRoutines = MockWorkoutData.exploreRoutines;
  }

  void _startRoutine(WorkoutRoutine routine) {
    // Convert ExerciseModel list to the format expected by ActiveWorkoutPage
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
            {'name': 'Bodyweight Squats', 'target': 'Legs', 'sets': 3, 'reps': 15},
            {'name': 'Push Ups', 'target': 'Chest', 'sets': 3, 'reps': 12},
          ] : convertedExercises,
        ),
      ),
    );
  }

  void _startBlankWorkout() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ActiveWorkoutPage(
          workoutName: "Freestyle Workout",
          routine: [
            {'name': 'Freestyle Exercise', 'target': 'Full Body', 'sets': 3, 'reps': 10}
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

  @override
  Widget build(BuildContext context) {
    final filteredExplore = _selectedCategory == "All"
        ? _exploreRoutines
        : _exploreRoutines.where((r) => r.category.toLowerCase().contains(_selectedCategory.toLowerCase())).toList();

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.bolt, color: Colors.teal, size: 28),
            SizedBox(width: 8),
            Text(
              "Workout Hub",
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            tooltip: "Search Workouts",
            onPressed: _showExerciseLibraryModal,
          ),
          IconButton(
            icon: const Icon(Icons.bookmark_border_rounded),
            tooltip: "Saved Routines",
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Saved routines folder")),
              );
            },
          ),
        ],
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Header & Consistency Streaks
            WorkoutStreakHeader(streakSummary: _streakSummary),

            // 2. Quick Action Bar
            WorkoutQuickActionBar(
              onStartBlankWorkout: _startBlankWorkout,
              onBrowseLibrary: _showExerciseLibraryModal,
              onViewAnalytics: _showAnalyticsScreen,
            ),

            const SizedBox(height: 8),

            // 3. Daily Scheduled Routine Card
            DailyRoutineCard(
              routine: _dailyRoutine,
              onStart: () => _startRoutine(_dailyRoutine),
              onCustomize: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Customizing routine parameters...")),
                );
              },
            ),

            const SizedBox(height: 8),

            // 4. AI Recommendation Banner
            AiRecommendationBanner(
              routine: _aiRoutine,
              onQuickStart: () => _startRoutine(_aiRoutine),
              onRegenerate: () {
                setState(() {
                  _aiRoutine = MockWorkoutData.aiRecommendedRoutine;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("AI updated workout based on your energy levels!"),
                    backgroundColor: Colors.deepPurple,
                  ),
                );
              },
            ),

            const SizedBox(height: 16),

            // 5. Explore More Workouts Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Explore Routines",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  TextButton(
                    onPressed: _showExerciseLibraryModal,
                    child: const Text("View All", style: TextStyle(color: Colors.teal)),
                  ),
                ],
              ),
            ),

            // Category Filter Pills
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

            const SizedBox(height: 12),

            // Explore Routines List
            ...filteredExplore.map((routine) => _buildExploreRoutineTile(routine)),
          ],
        ),
      ),
    );
  }

  Widget _buildExploreRoutineTile(WorkoutRoutine routine) {
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
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.teal.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.fitness_center_rounded, color: Colors.teal),
        ),
        title: Text(
          routine.title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              routine.subtitle,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: routine.level.badgeColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    routine.level.displayName,
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: routine.level.badgeColor),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  "${routine.durationMinutes} min • ${routine.estimatedCalories} kcal",
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
          ],
        ),
        trailing: ElevatedButton(
          onPressed: () => _startRoutine(routine),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal.shade50,
            foregroundColor: Colors.teal.shade800,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text("Start", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        ),
      ),
    );
  }
}
