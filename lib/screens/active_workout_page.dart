import 'package:flutter/material.dart';
import 'dart:async';
// ==========================================
// 10. ACTIVE WORKOUT SESSION PAGE
// ==========================================
class ActiveWorkoutPage extends StatefulWidget {
  final Map<String, dynamic> exerciseData; // The exercise we are doing
  final int totalExercises;
  final int currentExerciseIndex;

  const ActiveWorkoutPage({
    super.key,
    required this.exerciseData,
    required this.totalExercises,
    required this.currentExerciseIndex,
  });

  @override
  State<ActiveWorkoutPage> createState() => _ActiveWorkoutPageState();
}

class _ActiveWorkoutPageState extends State<ActiveWorkoutPage> {
  // --- TIMERS ---
  Timer? _sessionTimer;
  int _sessionSeconds = 0;
  
  Timer? _restTimer;
  int _restSeconds = 0;
  bool _isResting = false;
  final int _defaultRestTime = 60; // Default 60s rest

  // --- LOGGING DATA ---
  // Mocking "Previous Session" data for "Progressive Overload"
  final List<Map<String, dynamic>> _sets = [
    {"set": 1, "prev": "20kg x 10", "weight": "20", "reps": "10", "done": false},
    {"set": 2, "prev": "20kg x 10", "weight": "20", "reps": "10", "done": false},
    {"set": 3, "prev": "20kg x 8",  "weight": "20", "reps": "8",  "done": false},
  ];

  final TextEditingController _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _startSessionTimer();
  }

  @override
  void dispose() {
    _sessionTimer?.cancel();
    _restTimer?.cancel();
    super.dispose();
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
        _skipRest(); // Timer finished
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

  // --- FORMATTERS ---
  String _formatTime(int seconds) {
    int m = seconds ~/ 60;
    int s = seconds % 60;
    return "${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}";
  }

  // --- NAVIGATION LOGIC ---
  void _minimize() {
    // In a real app, this would minimize to a floating bubble.
    // For FYP, we pop but show a message.
    Navigator.pop(context); 
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Workout minimized (Session continues in background)")));
  }

  void _finishWorkout() {
    // TODO: Save all logs to Firestore here
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Workout Complete! Great Job! 🎉")));
  }

  @override
  Widget build(BuildContext context) {
    double progress = (widget.currentExerciseIndex + 1) / widget.totalExercises;

    return Scaffold(
      // === APP BAR (Minimize / Cancel) ===
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.keyboard_arrow_down), onPressed: _minimize),
        title: Text("Active Session  ${_formatTime(_sessionSeconds)}"),
        actions: [
          TextButton(
            onPressed: () {
              // Confirm Exit Dialog
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
          // === SCROLLABLE CONTENT ===
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // 1. VISUAL GUIDANCE & INFO
                  Container(
                    height: 200,
                    width: double.infinity,
                    color: Colors.black,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(widget.exerciseData['image'], fit: BoxFit.cover, errorBuilder: (c,o,s)=>const Icon(Icons.image_not_supported, color: Colors.white)),
                        Container(decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.transparent, Colors.black.withOpacity(0.8)], begin: Alignment.topCenter, end: Alignment.bottomCenter))),
                        Positioned(
                          bottom: 10, left: 15,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(widget.exerciseData['name'], style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                              const Text("Target: Chest, Triceps, Shoulders", style: TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.bold)), // Muscle Highlight
                            ],
                          ),
                        ),
                        // SUBSTITUTE BUTTON
                        Positioned(
                          top: 10, right: 10,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Substitute: Machine Press selected")));
                            }, 
                            icon: const Icon(Icons.swap_horiz, size: 16), 
                            label: const Text("Swap"),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.black54, foregroundColor: Colors.white),
                          ),
                        )
                      ],
                    ),
                  ),

                  // 2. TEXT INSTRUCTIONS (Expandable)
                  const ExpansionTile(
                    title: Text("Instructions & Form Cues"),
                    children: [
                      Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text("Keep your back flat against the bench. Lower the weight slowly to your chest, pause, and explode up. Do not lock your elbows at the top."),
                      )
                    ],
                  ),

                  const Divider(),

                  // 3. THE LOGGING GRID (THE MEAT)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Column(
                      children: [
                        // Header
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
                        
                        // Dynamic Set Rows
                        ..._sets.map((set) {
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
                                // Set Number
                                SizedBox(width: 30, child: Center(child: Text("${set['set']}", style: const TextStyle(fontWeight: FontWeight.bold)))),
                                
                                // Previous Data
                                Expanded(child: Center(child: Text(set['prev'], style: const TextStyle(color: Colors.grey, fontSize: 12)))),
                                
                                // Weight Input
                                Expanded(
                                  child: Container(
                                    margin: const EdgeInsets.symmetric(horizontal: 4),
                                    height: 40,
                                    child: TextFormField(
                                      initialValue: set['weight'],
                                      textAlign: TextAlign.center,
                                      keyboardType: TextInputType.number,
                                      decoration: InputDecoration(
                                        contentPadding: const EdgeInsets.only(bottom: 10),
                                        filled: true,
                                        fillColor: Colors.grey[100],
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(5), borderSide: BorderSide.none),
                                      ),
                                    ),
                                  ),
                                ),
                                
                                // Reps Input
                                Expanded(
                                  child: Container(
                                    margin: const EdgeInsets.symmetric(horizontal: 4),
                                    height: 40,
                                    child: TextFormField(
                                      initialValue: set['reps'],
                                      textAlign: TextAlign.center,
                                      keyboardType: TextInputType.number,
                                      decoration: InputDecoration(
                                        contentPadding: const EdgeInsets.only(bottom: 10),
                                        filled: true,
                                        fillColor: Colors.grey[100],
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(5), borderSide: BorderSide.none),
                                      ),
                                    ),
                                  ),
                                ),
                                
                                // Check Button
                                SizedBox(
                                  width: 40,
                                  child: Checkbox(
                                    activeColor: Colors.teal,
                                    value: isDone,
                                    onChanged: (val) {
                                      setState(() {
                                        set['done'] = val;
                                        if (val == true) _triggerRestTimer(); // AUTO TRIGGER REST
                                      });
                                    },
                                  ),
                                )
                              ],
                            ),
                          );
                        }).toList(),

                        // Add Set Button
                        TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _sets.add({"set": _sets.length + 1, "prev": "-", "weight": "-", "reps": "-", "done": false});
                            });
                          }, 
                          icon: const Icon(Icons.add), 
                          label: const Text("Add Set")
                        ),
                      ],
                    ),
                  ),

                  // 4. NOTES
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: TextField(
                      controller: _noteController,
                      decoration: const InputDecoration(
                        labelText: "Exercise Notes",
                        hintText: "e.g., Seat height 4, shoulder pain...",
                        prefixIcon: Icon(Icons.edit_note),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  
                  // Spacer for the Rest Timer Panel
                  const SizedBox(height: 100), 
                ],
              ),
            ),
          ),

          // === BOTTOM NAVIGATION ===
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: const Offset(0, -5))]
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (widget.currentExerciseIndex > 0)
                  TextButton.icon(
                    onPressed: () => Navigator.pop(context), 
                    icon: const Icon(Icons.arrow_back_ios, size: 16), 
                    label: const Text("Prev")
                  )
                else 
                  const SizedBox(width: 80), // Spacer

                // Finish or Next Button
                if (widget.currentExerciseIndex < widget.totalExercises - 1)
                  ElevatedButton.icon(
                    onPressed: () {
                      // Navigate to Next Exercise Logic (Demo: just pops for now)
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Next Exercise Loaded...")));
                    },
                    icon: const Icon(Icons.arrow_forward_ios, size: 16),
                    label: const Text("Next Exercise"),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
                  )
                else
                  ElevatedButton.icon(
                    onPressed: _finishWorkout,
                    icon: const Icon(Icons.check_circle),
                    label: const Text("Finish Workout"),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
                  )
              ],
            ),
          )
        ],
      ),

      // === REST TIMER OVERLAY (Appears when Resting) ===
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