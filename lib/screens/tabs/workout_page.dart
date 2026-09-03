import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/ai_service.dart';
import '../../services/exercise_service.dart';

import '../active_workout_page.dart';

class WorkoutTab extends StatefulWidget {
  const WorkoutTab({super.key});

  @override
  State<WorkoutTab> createState() => _WorkoutTabState();
}

class _WorkoutTabState extends State<WorkoutTab> {
  bool _showSearch = false;
  String _userGoal = "Maintenance"; 
  String _selectedCategory = "All"; 
  String _difficulty = "Beginner";

  // --- API STATE ---
  List<dynamic> _apiExercises = [];
  bool _isLoading = false;
  final TextEditingController _searchController = TextEditingController();

  final List<String> _categories = ["All", "Full Body", "Upper Body", "Lower Body", "Core"];

  @override
  void initState() {
    super.initState();
    _fetchUserGoal();
  }

  Future<void> _fetchUserGoal() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (mounted && doc.exists) {
        final data = doc.data() ?? {};
        setState(() {
          _userGoal = data['fitnessGoal'] ?? data['goal'] ?? "Maintenance";
        });
      }
    }
  }

  // --- 🔥 EXERCISE DB API INTEGRATION ---
  Future<void> _searchExercises(String query) async {
    if (query.trim().isEmpty) return;
    setState(() => _isLoading = true);
    
    try {
      final results = await ExerciseService.searchExercises(query);
      if (mounted) {
        setState(() {
          _apiExercises = results;
          _isLoading = false;
        });
        if (_apiExercises.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("No exercises found.")),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error fetching workouts: $e")),
        );
      }
    }
  }

  // --- 🤖 AI ROUTINE GENERATOR (Builds & Saves Full Plans!) ---
  Future<void> _generateFullAIPlan() async {
    bool isDialogOpen = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.teal),
            SizedBox(height: 16),
            Text("AI is building your custom plan...", style: TextStyle(color: Colors.white, decoration: TextDecoration.none, fontSize: 14)),
          ],
        )
      ),
    ).then((_) => isDialogOpen = false); 

    try {
      final user = FirebaseAuth.instance.currentUser;
      final uid = user?.uid;
      if (uid == null) throw Exception("User not authenticated.");

      final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final userData = userDoc.data() ?? {};
      final String effectiveGoal = userData['fitnessGoal'] ?? userData['goal'] ?? _userGoal;
      final String effectiveDifficulty = userData['fitnessLevel'] ?? userData['level'] ?? _difficulty;
      List<String> equipment = [];
      if (userData['equipment'] is List) {
        equipment = List<String>.from((userData['equipment'] as List).map((e) => e.toString()));
      }
      List<String> preferredWorkoutTypes = [];
      if (userData['preferredWorkoutTypes'] is List) {
        preferredWorkoutTypes = List<String>.from((userData['preferredWorkoutTypes'] as List).map((e) => e.toString()));
      }

      // Compact 7-day workout history summary
      String? recentSummary;
      try {
        final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
        final recentLogsSnap = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
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
        final docRef = FirebaseFirestore.instance.collection('users').doc(uid).collection('routines').doc();
        final String routineName = routine['name'] ?? routine['routineName'] ?? 'Workout Routine';
        final String routineLevel = routine['fitnessLevel'] ?? routine['level'] ?? _difficulty;
        final String routineCategory = routine['category'] ?? 'Full Body';
        final String routineImage = routine['imageUrl'] ?? routine['image'] ?? 'https://images.unsplash.com/photo-1517836357463-d25dfeac3438?w=400';
        final List<dynamic> rawExercises = routine['exercises'] ?? [];

        final List<Map<String, dynamic>> normalizedExercises = rawExercises.map((e) {
          if (e is Map) {
            final String exName = e['name'] ?? e['exerciseName'] ?? 'Exercise';
            final String target = e['target'] ?? e['category'] ?? 'Full Body';
            final String equipment = e['equipment'] ?? 'General';
            final String setsReps = e['sets']?.toString() ?? '3 sets x 10 reps';
            final String instructions = e['instructions'] ?? e['desc'] ?? '';
            final String exImage = e['imageUrl'] ?? e['image'] ?? '';

            return {
              'name': exName,
              'exerciseName': exName, // Legacy compatibility
              'target': target,
              'category': target, // Legacy compatibility
              'equipment': equipment,
              'sets': setsReps,
              'instructions': instructions,
              'desc': instructions, // Legacy compatibility
              if (exImage.isNotEmpty) 'imageUrl': exImage,
              if (exImage.isNotEmpty) 'image': exImage, // Legacy compatibility
            };
          }
          return {'name': e.toString(), 'exerciseName': e.toString()};
        }).toList();

        batch.set(docRef, {
          'name': routineName,
          'routineName': routineName, // Legacy compatibility dual-write
          'category': routineCategory,
          'fitnessGoal': _userGoal,
          'fitnessLevel': routineLevel,
          'level': routineLevel, // Legacy compatibility dual-write
          'source': 'ai_generated',
          'imageUrl': routineImage,
          'image': routineImage, // Legacy compatibility dual-write
          'exercises': normalizedExercises,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();

      if (isDialogOpen && mounted) {
        Navigator.pop(context);
        isDialogOpen = false;
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("AI Plan generated and saved to your routines! 🎉")),
        );
      }
    } catch (e) {
      debugPrint("==== AI GENERATION ERROR ====");
      debugPrint(e.toString());
      debugPrint("=============================");
      
      if (isDialogOpen && mounted) {
        Navigator.pop(context);
        isDialogOpen = false;
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("AI Error: Check VS Code Console!")));
      }
    }
  }

  // --- DELETE ROUTINE ---
  Future<void> _deleteRoutine(String docId) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    await FirebaseFirestore.instance.collection('users').doc(uid).collection('routines').doc(docId).delete();
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text("Training Hub", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () => setState(() => _showSearch = !_showSearch),
            icon: Icon(_showSearch ? Icons.close : Icons.search, color: Colors.teal),
          )
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.black12)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Your Current Goal", style: TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 4),
                Text(_userGoal, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.teal)),
              ],
            ),
          ),
          
          Expanded(
            child: _showSearch ? _buildApiSearch() : _buildMyRoutines(uid),
          ),
        ],
      ),
    );
  }

  Widget _buildApiSearch() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: "Search 1300+ exercises...",
              prefixIcon: const Icon(Icons.fitness_center, color: Colors.teal),
              suffixIcon: IconButton(
                icon: const Icon(Icons.search, color: Colors.teal), 
                onPressed: () => _searchExercises(_searchController.text.trim())
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
              filled: true,
              fillColor: Colors.grey.shade200,
            ),
            onSubmitted: (val) => _searchExercises(val.trim()),
          ),
        ),
        
        if (_isLoading) const LinearProgressIndicator(color: Colors.teal),
        
        Expanded(
          child: _apiExercises.isEmpty && !_isLoading
          ? const Center(child: Text("Search for specific movements.", style: TextStyle(color: Colors.grey)))
          : ListView.builder(
              itemCount: _apiExercises.length,
              itemBuilder: (context, index) {
                final ex = _apiExercises[index];
                String name = (ex['name'] ?? 'Unknown').toString().toUpperCase();
                String target = ex['target'] ?? 'Body';
                String gifUrl = ex['gifUrl'] ?? '';

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: Colors.grey.shade200)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(10),
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(gifUrl, width: 60, height: 60, fit: BoxFit.cover, errorBuilder: (c,o,s) => const Icon(Icons.fitness_center)),
                    ),
                    title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: Text("Target: $target", style: const TextStyle(fontSize: 12)),
                    trailing: const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
                    onTap: () {
                      List<dynamic> instructionsList = ex['instructions'] ?? [];
                      String fullInstructions = instructionsList.isNotEmpty 
                          ? instructionsList.map((i) => "• $i").join("\n\n") 
                          : "No instructions provided.";

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ActiveWorkoutPage(
                            workoutName: "Quick Session: $name",
                            routine: [{
                              "name": name,
                              "category": target,
                              "sets": "3 sets x 10 reps", 
                              "image": gifUrl,
                              "desc": fullInstructions
                            }],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
        )
      ],
    );
  }

  Widget _buildMyRoutines(String uid) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 60,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            itemCount: _categories.length,
            itemBuilder: (context, index) {
              final cat = _categories[index];
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: ChoiceChip(
                  label: Text(cat),
                  selected: _selectedCategory == cat,
                  selectedColor: Colors.teal,
                  backgroundColor: Colors.white,
                  labelStyle: TextStyle(color: _selectedCategory == cat ? Colors.white : Colors.black, fontWeight: FontWeight.bold),
                  onSelected: (selected) {
                    if (selected) setState(() => _selectedCategory = cat);
                  },
                ),
              );
            },
          ),
        ),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: ["Beginner", "Intermediate", "Advanced"].map((level) {
              bool isSelected = _difficulty == level;
              return InkWell(
                onTap: () => setState(() => _difficulty = level),
                child: Text(
                  level,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? Colors.teal : Colors.grey,
                    decoration: isSelected ? TextDecoration.underline : TextDecoration.none,
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 10),

        // Live Stream of User's Routines
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('users').doc(uid).collection('routines').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Colors.teal));
              }

              final docs = snapshot.data?.docs ?? [];
              
              // Filter for difficulty level (supporting both fitnessLevel and legacy level)
              final difficultyDocs = docs.where((d) {
                final data = d.data() as Map<String, dynamic>;
                final String level = data['fitnessLevel'] ?? data['level'] ?? 'Beginner';
                return level.toLowerCase() == _difficulty.toLowerCase();
              }).toList();

              // Local filtering for category
              final filteredDocs = _selectedCategory == "All" 
                ? difficultyDocs 
                : difficultyDocs.where((d) => (d.data() as Map<String, dynamic>)['category'] == _selectedCategory).toList();

              if (filteredDocs.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(30.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.assignment_add, size: 60, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text("No $_difficulty routines found.", style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _generateFullAIPlan,
                          icon: const Icon(Icons.auto_awesome),
                          label: const Text("Let AI Build My Plan", style: TextStyle(fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal, 
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.only(bottom: 80),
                itemCount: filteredDocs.length,
                itemBuilder: (context, index) {
                  final routineId = filteredDocs[index].id;
                  final routine = filteredDocs[index].data() as Map<String, dynamic>;
                  final String routineName = routine["name"] ?? routine["routineName"] ?? "Routine";
                  final String routineCategory = routine["category"] ?? "Workout";
                  final String routineImage = routine["imageUrl"] ?? routine["image"] ?? "https://images.unsplash.com/photo-1517836357463-d25dfeac3438?w=400";
                  final String routineLevel = routine["fitnessLevel"] ?? routine["level"] ?? _difficulty;
                  final String routineGoal = routine["fitnessGoal"] ?? _userGoal;
                  final List<dynamic> exercises = routine["exercises"] ?? [];
                  
                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ActiveWorkoutPage(
                            workoutName: routineName,
                            routine: List<Map<String, dynamic>>.from(exercises),
                            routineId: routineId,
                            workoutType: routineCategory,
                            fitnessGoal: routineGoal,
                            fitnessLevel: routineLevel,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      height: 140,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        image: DecorationImage(
                          image: NetworkImage(routineImage), 
                          fit: BoxFit.cover,
                          colorFilter: ColorFilter.mode(Colors.black.withValues(alpha: 0.5), BlendMode.darken), 
                        ),
                        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4))],
                      ),
                      child: Stack(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(8)),
                                  child: Text(routineCategory, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                ),
                                const SizedBox(height: 8),
                                Text(routineName, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.fitness_center, color: Colors.tealAccent, size: 16),
                                    const SizedBox(width: 5),
                                    Text("${exercises.length} Exercises", style: const TextStyle(color: Colors.white, fontSize: 14)),
                                  ],
                                )
                              ],
                            ),
                          ),
                          Positioned(
                            top: 10,
                            right: 10,
                            child: IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.white70),
                              onPressed: () => _deleteRoutine(routineId),
                            ),
                          )
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}