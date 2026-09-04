import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/workout_models.dart';
import 'exercise_library_screen.dart';
import 'active_workout_page.dart';

class BuildRoutineScreen extends StatefulWidget {
  final WorkoutRoutine? initialRoutine; // If editing or copying an existing routine
  final List<ExerciseModel>? initialExercises; // If pre-populating with exercises

  const BuildRoutineScreen({
    super.key,
    this.initialRoutine,
    this.initialExercises,
  });

  @override
  State<BuildRoutineScreen> createState() => _BuildRoutineScreenState();
}

class _BuildRoutineScreenState extends State<BuildRoutineScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  
  String _selectedCategory = 'Strength';
  FitnessLevel _selectedLevel = FitnessLevel.beginner;
  UserGoalTag _selectedGoal = UserGoalTag.muscleGain;
  int _defaultRestSeconds = 60;

  final List<Map<String, dynamic>> _exercises = [];
  bool _isSaving = false;

  final List<String> _categories = [
    'Strength',
    'Upper Body',
    'Lower Body',
    'Core',
    'Cardio',
    'Full Body',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialRoutine != null) {
      final r = widget.initialRoutine!;
      _nameController.text = r.title.contains('(Custom)') ? r.title : "${r.title} (Custom)";
      _selectedCategory = r.category;
      _selectedLevel = r.level;
      _selectedGoal = r.goal;
      for (final e in r.exercises) {
        _exercises.add({
          'id': e.id,
          'name': e.name,
          'target': e.targetMuscle,
          'equipment': e.equipment,
          'sets': e.defaultSets,
          'reps': e.isTimed ? '${e.durationSeconds}s' : e.defaultReps,
          'durationSeconds': e.durationSeconds,
          'restSeconds': e.restSeconds,
        });
      }
    } else if (widget.initialExercises != null && widget.initialExercises!.isNotEmpty) {
      final first = widget.initialExercises!.first;
      _nameController.text = "${first.name} Routine";
      if (first.trackingType == ExerciseTrackingType.cardio) {
        _selectedCategory = 'Cardio';
      } else if (first.targetMuscle.toLowerCase() == 'core' || first.targetMuscle.toLowerCase() == 'waist') {
        _selectedCategory = 'Core';
      } else {
        _selectedCategory = 'Strength';
      }
      for (final e in widget.initialExercises!) {
        _exercises.add({
          'id': e.id,
          'name': e.name,
          'target': e.targetMuscle,
          'equipment': e.equipment,
          'sets': e.defaultSets,
          'reps': e.isTimed ? '${e.durationSeconds}s' : e.defaultReps,
          'durationSeconds': e.durationSeconds,
          'restSeconds': e.restSeconds,
          'trackingType': e.trackingType.name,
        });
      }
    } else {
      _nameController.text = "My Custom Routine";
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
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
          },
        ),
      ),
    );
  }

  void _onRemoveExercise(int index) {
    final removed = _exercises.removeAt(index);
    setState(() {});
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

  void _editExerciseDetails(int index) {
    final ex = _exercises[index];
    final setsCtrl = TextEditingController(text: ex['sets']?.toString() ?? '3');
    final repsCtrl = TextEditingController(text: ex['reps']?.toString() ?? '10');
    final restCtrl = TextEditingController(text: ex['restSeconds']?.toString() ?? '60');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ex['name'] ?? 'Exercise Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: setsCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Target Sets"),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: repsCtrl,
              decoration: const InputDecoration(
                labelText: "Target Reps or Duration",
                hintText: "e.g. 10 or 45s",
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: restCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Rest Time (seconds)"),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              final sets = int.tryParse(setsCtrl.text.trim()) ?? 3;
              final reps = repsCtrl.text.trim().isEmpty ? '10' : repsCtrl.text.trim();
              final rest = int.tryParse(restCtrl.text.trim()) ?? 60;
              setState(() {
                ex['sets'] = sets;
                ex['reps'] = reps;
                ex['restSeconds'] = rest;
              });
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
            child: const Text("Apply"),
          ),
        ],
      ),
    );
  }

  Future<void> _saveRoutine({bool andStart = false}) async {
    if (!_formKey.currentState!.validate()) return;
    if (_exercises.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please add at least 1 exercise to the routine."),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      final routineTitle = _nameController.text.trim();
      final estimatedMinutes = (_exercises.length * 4.5).round().clamp(10, 90);
      final estimatedCalories = (_exercises.length * 35).round().clamp(80, 600);

      final routineData = {
        'name': routineTitle,
        'title': routineTitle,
        'subtitle': '${_exercises.length} exercises • $_selectedCategory',
        'category': _selectedCategory,
        'fitnessLevel': _selectedLevel.displayName,
        'fitnessGoal': _selectedGoal.displayName,
        'durationMinutes': estimatedMinutes,
        'estimatedCalories': estimatedCalories,
        'defaultRestSeconds': _defaultRestSeconds,
        'source': 'custom',
        'isAiGenerated': false,
        'exercises': _exercises.map((e) {
          final isTimed = (e['reps']?.toString().contains('s') ?? false) || (e['durationSeconds'] ?? 0) > 0;
          return {
            'id': e['id'] ?? '',
            'name': e['name'] ?? 'Exercise',
            'target': e['target'] ?? 'Muscle',
            'targetMuscle': e['target'] ?? 'Muscle',
            'equipment': e['equipment'] ?? 'Bodyweight',
            'sets': e['sets'] ?? 3,
            'reps': e['reps'] ?? '10',
            'defaultSets': e['sets'] ?? 3,
            'defaultReps': isTimed ? 0 : (int.tryParse(e['reps'].toString()) ?? 10),
            'durationSeconds': e['durationSeconds'],
            'restSeconds': e['restSeconds'] ?? _defaultRestSeconds,
          };
        }).toList(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      String routineId = '';
      if (user != null) {
        final docRef = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('routines')
            .add(routineData);
        routineId = docRef.id;
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Routine '$routineTitle' saved!"),
          backgroundColor: Colors.teal,
        ),
      );

      if (andStart) {
        Navigator.pop(context); // Close builder
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ActiveWorkoutPage(
              workoutName: routineTitle,
              routine: _exercises,
              routineId: routineId,
              workoutType: _selectedCategory,
              fitnessGoal: _selectedGoal.displayName,
              fitnessLevel: _selectedLevel.displayName,
              defaultRestSeconds: _defaultRestSeconds,
            ),
          ),
        );
      } else {
        Navigator.pop(context, true); // Return success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error saving routine: $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Build My Own Routine", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          if (_isSaving)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            )
          else
            TextButton(
              onPressed: () => _saveRoutine(andStart: false),
              child: const Text("Save", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Routine Name Field
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: "Routine Name",
                hintText: "e.g. Upper Body Hypertrophy",
                prefixIcon: const Icon(Icons.edit_note_rounded, color: Colors.teal),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? "Please enter a routine name" : null,
            ),

            const SizedBox(height: 16),

            // Category & Level Selectors
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedCategory,
                    decoration: InputDecoration(
                      labelText: "Category",
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 13)))).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedCategory = val);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<FitnessLevel>(
                    initialValue: _selectedLevel,
                    decoration: InputDecoration(
                      labelText: "Level",
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: FitnessLevel.values.map((l) => DropdownMenuItem(value: l, child: Text(l.displayName, style: const TextStyle(fontSize: 13)))).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedLevel = val);
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Default Rest Setting
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Default Rest Between Sets", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                DropdownButton<int>(
                  value: _defaultRestSeconds,
                  underline: const SizedBox.shrink(),
                  items: const [
                    DropdownMenuItem(value: 0, child: Text("Off")),
                    DropdownMenuItem(value: 30, child: Text("30 sec")),
                    DropdownMenuItem(value: 45, child: Text("45 sec")),
                    DropdownMenuItem(value: 60, child: Text("60 sec")),
                    DropdownMenuItem(value: 90, child: Text("90 sec")),
                    DropdownMenuItem(value: 120, child: Text("120 sec")),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _defaultRestSeconds = val);
                  },
                ),
              ],
            ),

            const Divider(height: 32),

            // Exercises Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Exercises (${_exercises.length})", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text("Drag to reorder • Tap to edit sets/reps", style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: _onAddExercise,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text("Add Exercise", style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            if (_exercises.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    Icon(Icons.fitness_center_rounded, size: 40, color: Colors.grey.shade400),
                    const SizedBox(height: 10),
                    const Text("No exercises added yet", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 4),
                    Text("Tap '+ Add Exercise' to browse the Exercise Library", style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                  ],
                ),
              )
            else
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
                  itemBuilder: (ctx, idx) {
                    final ex = _exercises[idx];
                    return Container(
                      key: ValueKey("custom_ex_${ex['id']}_$idx"),
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Material(
                        color: isDark ? const Color(0xFF0F172A) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: ListTile(
                            onTap: () => _editExerciseDetails(idx),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        leading: Container(
                          width: 28,
                          height: 28,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: Colors.teal.shade50, shape: BoxShape.circle),
                          child: Text("${idx + 1}", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.teal.shade700)),
                        ),
                        title: Text(ex['name'] ?? 'Exercise', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: Text(
                          "${ex['sets']} sets • ${ex['reps']} reps • ${ex['restSeconds'] ?? _defaultRestSeconds}s rest",
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                              onPressed: () => _onRemoveExercise(idx),
                            ),
                            const Icon(Icons.drag_handle_rounded, color: Colors.grey, size: 20),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
                ),
              ),

            const SizedBox(height: 32),

            // Start Immediately Action Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _exercises.isEmpty ? null : () => _saveRoutine(andStart: true),
                icon: const Icon(Icons.play_arrow_rounded, size: 22),
                label: const Text("Save & Start Workout", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
