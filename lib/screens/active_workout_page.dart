import 'package:flutter/material.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ==========================================
// 10. ACTIVE WORKOUT SESSION PAGE (ROUTINE ENGINE)
// ==========================================
class ActiveWorkoutPage extends StatefulWidget {
  final String workoutName; // e.g., "Chest Day", "Full Body Blast"
  final List<Map<String, dynamic>> routine; // Array of exercises

  const ActiveWorkoutPage({
    super.key,
    required this.workoutName,
    required this.routine,
  });

  @override
  State<ActiveWorkoutPage> createState() => _ActiveWorkoutPageState();
}

class _ActiveWorkoutPageState extends State<ActiveWorkoutPage> {
  // --- WORKOUT STATE ---
  int _currentIndex = 0;
  List<Map<String, dynamic>> _allCompletedExercises = []; // Stores the final data to push to Firebase

  // --- TIMERS ---
  Timer? _sessionTimer;
  int _sessionSeconds = 0;
  
  Timer? _restTimer;
  int _restSeconds = 0;
  bool _isResting = false;
  final int _defaultRestTime = 60;

  // Current sets for the currently active exercise
  List<Map<String, dynamic>> _currentSets = [];
  final TextEditingController _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _startSessionTimer();
    _initializeSetsForCurrentExercise();
  }

  @override
  void dispose() {
    _sessionTimer?.cancel();
    _restTimer?.cancel();
    _noteController.dispose();
    super.dispose();
  }

  void _initializeSetsForCurrentExercise() {
    // Reset the sets when we move to a new exercise
    _currentSets = [
      {"set": 1, "prev": "-", "weight": "", "reps": "", "done": false},
    ];
    _noteController.clear();
  }

  // --- TIMER LOGIC ---
  void _startSessionTimer() {
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() => _sessionSeconds++);
    });
  }

  void _triggerRestTimer() {
    setState(() {
      _isResting = true;
      _restSeconds = _defaultRestTime;
    });
    _restTimer?.cancel();
    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_restSeconds > 0) {
        setState(() => _restSeconds--);
      } else {
        _skipRest();
      }
    });
  }

  void _adjustRestTime(int seconds) {
    setState(() {
      _restSeconds += seconds;
      if (_restSeconds < 0) _restSeconds = 0;
    });
  }

  void _skipRest() {
    _restTimer?.cancel();
    setState(() => _isResting = false);
  }

  String _formatTime(int seconds) {
    int m = seconds ~/ 60;
    int s = seconds % 60;
    return "${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}";
  }

  // --- NAVIGATION & SAVING ---
  void _minimize() {
    Navigator.pop(context); 
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Workout minimized"))
    );
  }

  void _saveCurrentExerciseData() {
    // Save the current exercise's sets into our master list
    final completedSets = _currentSets.where((s) => s['done'] == true).toList();
    if (completedSets.isNotEmpty) {
      _allCompletedExercises.add({
        'exerciseName': widget.routine[_currentIndex]['name'],
        'category': widget.routine[_currentIndex]['category'] ?? 'General',
        'notes': _noteController.text,
        'sets': completedSets.map((s) => {
          'set': s['set'],
          'weight': double.tryParse(s['weight'].toString()) ?? 0.0,
          'reps': int.tryParse(s['reps'].toString()) ?? 0,
        }).toList()
      });
    }
  }

  void _nextExercise() {
    _saveCurrentExerciseData();
    setState(() {
      _currentIndex++;
      _initializeSetsForCurrentExercise();
      _skipRest(); // Cancel any active rest timer
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Loaded: ${widget.routine[_currentIndex]['name']}"))
    );
  }

  Future<void> _finishWorkout() async {
    _saveCurrentExerciseData(); // Save the final exercise
    
    if (_allCompletedExercises.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No sets completed. Workout discarded."))
      );
      Navigator.pop(context);
      return;
    }

    showDialog(
      context: context, 
      barrierDismissible: false, 
      builder: (c) => const Center(child: CircularProgressIndicator(color: Colors.teal))
    );

    try {
      final user = FirebaseAuth.instance.currentUser!;
      final int caloriesBurned = (_sessionSeconds / 60.0 * 5.0).round();

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('workout_logs')
          .add({
            'routineName': widget.workoutName,
            'durationSeconds': _sessionSeconds,
            'caloriesBurned': caloriesBurned,
            'exercises': _allCompletedExercises, // Array of all exercises done!
            'timestamp': FieldValue.serverTimestamp(),
          });

      if (mounted) {
        Navigator.pop(context); // Close dialog
        Navigator.pop(context); // Close page
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Workout Complete! Burned ~$caloriesBurned kcal 🔥"))
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error saving workout: $e"))
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Current exercise data
    final currentExercise = widget.routine[_currentIndex];
    double progress = (_currentIndex + 1) / widget.routine.length;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.keyboard_arrow_down), onPressed: _minimize),
        title: Column(
          children: [
            Text(widget.workoutName, style: const TextStyle(fontSize: 14, color: Colors.grey)),
            Text(_formatTime(_sessionSeconds), style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              showDialog(context: context, builder: (c) => AlertDialog(
                title: const Text("End Workout?"),
                content: const Text("All unsaved progress will be lost."),
                actions: [
                  TextButton(onPressed: ()=>Navigator.pop(c), child: const Text("Cancel")),
                  TextButton(onPressed: (){ Navigator.pop(c); Navigator.pop(context); }, child: const Text("End", style: TextStyle(color: Colors.red))),
                ],
              ));
            },
            child: const Text("End", style: TextStyle(color: Colors.red)),
          )
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(value: progress, backgroundColor: Colors.grey[300], color: Colors.teal),
        ),
      ),
      
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Visual Header
                  Container(
                    height: 200,
                    width: double.infinity,
                    color: Colors.black,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(currentExercise['image'], fit: BoxFit.cover, errorBuilder: (c,o,s)=>const Icon(Icons.image_not_supported, color: Colors.white)),
                        Container(decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.transparent, Colors.black.withOpacity(0.8)], begin: Alignment.topCenter, end: Alignment.bottomCenter))),
                        Positioned(
                          bottom: 10, left: 15,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(currentExercise['name'], style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                              Text("Exercise ${_currentIndex + 1} of ${widget.routine.length}", style: const TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  ExpansionTile(
                    title: const Text("Instructions & Form Cues"),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(currentExercise['desc'] ?? "Focus on the mind-muscle connection and maintain slow, controlled movements."),
                      )
                    ],
                  ),
                  const Divider(),

                  // The Set Logger
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Column(
                      children: [
                        Row(
                          children: const [
                            SizedBox(width: 30, child: Text("Set", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
                            Expanded(child: Center(child: Text("Previous", style: TextStyle(color: Colors.grey, fontSize: 12)))),
                            Expanded(child: Center(child: Text("kg", style: TextStyle(fontWeight: FontWeight.bold)))),
                            Expanded(child: Center(child: Text("Reps", style: TextStyle(fontWeight: FontWeight.bold)))),
                            SizedBox(width: 40, child: Icon(Icons.check, color: Colors.grey)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        
                        ..._currentSets.map((set) {
                          bool isDone = set['done'];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: isDone ? Colors.teal.withOpacity(0.1) : Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade300)
                            ),
                            child: Row(
                              children: [
                                SizedBox(width: 30, child: Center(child: Text("${set['set']}", style: const TextStyle(fontWeight: FontWeight.bold)))),
                                
                                Expanded(child: Center(child: Text(set['prev'], style: const TextStyle(color: Colors.grey, fontSize: 12)))),
                                
                                Expanded(
                                  child: Container(
                                    margin: const EdgeInsets.symmetric(horizontal: 4),
                                    height: 40,
                                    child: TextFormField(
                                      initialValue: set['weight'].toString(),
                                      textAlign: TextAlign.center,
                                      keyboardType: TextInputType.number,
                                      onChanged: (val) => set['weight'] = val,
                                      decoration: InputDecoration(
                                        contentPadding: const EdgeInsets.only(bottom: 10),
                                        filled: true,
                                        fillColor: Colors.grey[100],
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(5), borderSide: BorderSide.none),
                                      ),
                                    ),
                                  ),
                                ),
                                
                                Expanded(
                                  child: Container(
                                    margin: const EdgeInsets.symmetric(horizontal: 4),
                                    height: 40,
                                    child: TextFormField(
                                      initialValue: set['reps'].toString(),
                                      textAlign: TextAlign.center,
                                      keyboardType: TextInputType.number,
                                      onChanged: (val) => set['reps'] = val,
                                      decoration: InputDecoration(
                                        contentPadding: const EdgeInsets.only(bottom: 10),
                                        filled: true,
                                        fillColor: Colors.grey[100],
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(5), borderSide: BorderSide.none),
                                      ),
                                    ),
                                  ),
                                ),
                                
                                SizedBox(
                                  width: 40,
                                  child: Checkbox(
                                    activeColor: Colors.teal,
                                    value: isDone,
                                    onChanged: (val) {
                                      FocusScope.of(context).unfocus();
                                      setState(() {
                                        set['done'] = val;
                                        if (val == true) _triggerRestTimer(); 
                                      });
                                    },
                                  ),
                                )
                              ],
                            ),
                          );
                        }).toList(),

                        TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _currentSets.add({
                                "set": _currentSets.length + 1, 
                                "prev": "-", 
                                "weight": _currentSets.last['weight'], 
                                "reps": _currentSets.last['reps'], 
                                "done": false
                              });
                            });
                          }, 
                          icon: const Icon(Icons.add), 
                          label: const Text("Add Set")
                        ),
                      ],
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: TextField(
                      controller: _noteController,
                      decoration: const InputDecoration(
                        labelText: "Exercise Notes",
                        hintText: "e.g., Seat height 4, felt good...",
                        prefixIcon: Icon(Icons.edit_note),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 100), 
                ],
              ),
            ),
          ),

          // Bottom Navigation
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -5))]
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (_currentIndex > 0)
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _currentIndex--;
                        _initializeSetsForCurrentExercise(); // In a full app, you'd reload the saved sets here instead of resetting
                      });
                    }, 
                    icon: const Icon(Icons.arrow_back_ios, size: 16), 
                    label: const Text("Prev")
                  )
                else 
                  const SizedBox(width: 80), 

                if (_currentIndex < widget.routine.length - 1)
                  ElevatedButton.icon(
                    onPressed: _nextExercise, // Loads the next exercise!
                    icon: const Icon(Icons.arrow_forward_ios, size: 16),
                    label: const Text("Next Exercise"),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
                  )
                else
                  ElevatedButton.icon(
                    onPressed: _finishWorkout, // Saves the whole routine!
                    icon: const Icon(Icons.check_circle),
                    label: const Text("Finish Workout"),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
                  )
              ],
            ),
          )
        ],
      ),

      bottomSheet: _isResting ? Container(
        color: Colors.teal,
        padding: const EdgeInsets.all(16),
        height: 120,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Rest Timer", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                Text(_formatTime(_restSeconds), style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                ElevatedButton(
                  onPressed: _skipRest, 
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.teal),
                  child: const Text("Skip")
                )
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton(onPressed: () => _adjustRestTime(-10), style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white)), child: const Text("-10s")),
                const SizedBox(width: 20),
                OutlinedButton(onPressed: () => _adjustRestTime(30), style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white)), child: const Text("+30s")),
              ],
            )
          ],
        ),
      ) : null,
    );
  }
}