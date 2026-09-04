import 'package:flutter/material.dart';
import '../../models/workout_models.dart';
import '../../screens/active_workout_page.dart';
import '../../screens/exercise_library_screen.dart';

class WorkoutSetupSheet extends StatefulWidget {
  final WorkoutRoutine routine;
  final VoidCallback? onWorkoutStarted;

  const WorkoutSetupSheet({
    super.key,
    required this.routine,
    this.onWorkoutStarted,
  });

  static Future<void> show(
    BuildContext context, {
    required WorkoutRoutine routine,
    VoidCallback? onWorkoutStarted,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => WorkoutSetupSheet(
        routine: routine,
        onWorkoutStarted: onWorkoutStarted,
      ),
    );
  }

  @override
  State<WorkoutSetupSheet> createState() => _WorkoutSetupSheetState();
}

class _WorkoutSetupSheetState extends State<WorkoutSetupSheet> {
  late List<Map<String, dynamic>> _exercises;
  int _restBetweenSets = 60; // default 60 sec
  int _restBetweenExercises = 60; // default 60 sec

  static const List<int> _setRestOptions = [0, 30, 45, 60, 90, 120];
  static const List<int> _exerciseRestOptions = [30, 60, 90];

  @override
  void initState() {
    super.initState();
    _exercises = widget.routine.exercises.map((e) {
      return {
        'id': e.id,
        'name': e.name,
        'target': e.targetMuscle,
        'equipment': e.equipment,
        'sets': e.defaultSets,
        'reps': e.isTimed ? '${e.durationSeconds}s' : e.defaultReps,
        'durationSeconds': e.durationSeconds,
        'restSeconds': e.restSeconds,
      };
    }).toList();

    if (_exercises.isEmpty) {
      _exercises.add({
        'name': 'Bodyweight Squats',
        'target': 'Legs',
        'equipment': 'Bodyweight',
        'sets': 3,
        'reps': 15,
      });
      _exercises.add({
        'name': 'Push Ups',
        'target': 'Chest',
        'equipment': 'Bodyweight',
        'sets': 3,
        'reps': 12,
      });
    }
  }

  void _onAddExercise() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => ExerciseLibraryScreen(
          onSelectExerciseForWorkout: (newEx) {
            Navigator.pop(ctx);
            setState(() {
              _exercises.add({
                'id': newEx.id,
                'name': newEx.name,
                'target': newEx.targetMuscle,
                'equipment': newEx.equipment,
                'sets': newEx.defaultSets,
                'reps': newEx.isTimed ? '${newEx.durationSeconds}s' : newEx.defaultReps,
                'durationSeconds': newEx.durationSeconds,
                'restSeconds': newEx.restSeconds,
              });
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("Added ${newEx.name}"),
                backgroundColor: Colors.teal,
                duration: const Duration(seconds: 2),
              ),
            );
          },
        ),
      ),
    );
  }

  void _onRemoveExercise(int index) {
    if (_exercises.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("A workout must have at least 1 exercise."),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    final removed = _exercises[index];
    setState(() {
      _exercises.removeAt(index);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Removed ${removed['name']}"),
        action: SnackBarAction(
          label: "Undo",
          textColor: Colors.tealAccent,
          onPressed: () {
            setState(() {
              _exercises.insert(index, removed);
            });
          },
        ),
      ),
    );
  }

  void _startWorkout() {
    if (_exercises.isEmpty) return;

    Navigator.pop(context); // Close setup sheet
    widget.onWorkoutStarted?.call();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ActiveWorkoutPage(
          workoutName: widget.routine.title,
          routine: _exercises,
          routineId: widget.routine.id,
          workoutType: widget.routine.category,
          fitnessGoal: widget.routine.goal.displayName,
          fitnessLevel: widget.routine.level.displayName,
          defaultRestSeconds: _restBetweenSets,
          restBetweenExercisesSeconds: _restBetweenExercises,
        ),
      ),
    );
  }

  String _formatRestLabel(int seconds) {
    if (seconds == 0) return 'Off';
    return '${seconds}s';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.88,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            children: [
              // Drag Handle
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Title Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.teal.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  widget.routine.category,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.teal.shade700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: widget.routine.level.badgeColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  widget.routine.level.displayName,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: widget.routine.level.badgeColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            widget.routine.title,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Overview Chips (Exercise count, Guidance Duration)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildOverviewStat(
                        Icons.fitness_center_rounded,
                        "${_exercises.length} Exercises",
                        "Routine",
                        Colors.teal,
                      ),
                      Container(height: 28, width: 1, color: Colors.grey.shade300),
                      _buildOverviewStat(
                        Icons.schedule_rounded,
                        "~${widget.routine.durationMinutes} min",
                        "Est. Duration",
                        Colors.blueAccent,
                      ),
                      Container(height: 28, width: 1, color: Colors.grey.shade300),
                      _buildOverviewStat(
                        Icons.local_fire_department_rounded,
                        "~${widget.routine.estimatedCalories} kcal",
                        "Est. Burn",
                        Colors.deepOrange,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Main Scrollable Setup Form
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    // Rest Between Sets Section
                    const Text(
                      "Default Rest Between Sets",
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Applied automatically after completing each set. You can always skip.",
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _setRestOptions.map((seconds) {
                        final isSelected = _restBetweenSets == seconds;
                        return ChoiceChip(
                          label: Text(
                            seconds == 0 ? "Off" : (seconds == 60 ? "60s (Default)" : "${seconds}s"),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: Colors.teal,
                          backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.grey.shade100,
                          onSelected: (val) {
                            if (val) setState(() => _restBetweenSets = seconds);
                          },
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 16),

                    // Rest Between Exercises Section
                    const Text(
                      "Rest Between Exercises (Optional)",
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: _exerciseRestOptions.map((seconds) {
                        final isSelected = _restBetweenExercises == seconds;
                        return ChoiceChip(
                          label: Text(
                            _formatRestLabel(seconds),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: Colors.teal.shade700,
                          backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.grey.shade100,
                          onSelected: (val) {
                            if (val) setState(() => _restBetweenExercises = seconds);
                          },
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 20),

                    // Exercises Header with Add Button and drag hint
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Exercises (${_exercises.length})",
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              "Long-press and drag to reorder",
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                            ),
                          ],
                        ),
                        TextButton.icon(
                          onPressed: _onAddExercise,
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text("+ Add Exercise", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.teal,
                            backgroundColor: Colors.teal.shade50,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // Reorderable Exercise List
                    Theme(
                      data: theme.copyWith(canvasColor: Colors.transparent),
                      child: ReorderableListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _exercises.length,
                        // ignore: deprecated_member_use
                        onReorder: (oldIndex, newIndex) {
                          setState(() {
                            if (newIndex > oldIndex) newIndex -= 1;
                            final item = _exercises.removeAt(oldIndex);
                            _exercises.insert(newIndex, item);
                          });
                        },
                        itemBuilder: (context, idx) {
                          final ex = _exercises[idx];
                          final sets = ex['sets'] ?? 3;
                          final reps = ex['reps'] ?? 10;
                          final equip = ex['equipment'] ?? 'Bodyweight';
                          final target = ex['target'] ?? 'Muscle';

                          return Container(
                            key: ValueKey("setup_ex_${ex['id']}_$idx"),
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF0F172A) : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              leading: Container(
                                width: 32,
                                height: 32,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: Colors.teal.shade50,
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  "${idx + 1}",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: Colors.teal.shade700,
                                  ),
                                ),
                              ),
                              title: Text(
                                ex['name'] ?? 'Exercise',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                "$sets sets • $reps • $target • $equip",
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                    tooltip: "Remove exercise",
                                    onPressed: () => _onRemoveExercise(idx),
                                  ),
                                  const Icon(Icons.drag_handle_rounded, color: Colors.grey, size: 20),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),

              // Bottom Start Action Button
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _startWorkout,
                      icon: const Icon(Icons.play_arrow_rounded, size: 24),
                      label: const Text(
                        "Start Workout",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildOverviewStat(IconData icon, String value, String label, Color color) {
    return Column(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
        ),
      ],
    );
  }
}
