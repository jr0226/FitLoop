import 'package:flutter/material.dart';
import 'dart:convert'; // 👈 Needed for json.decode
import 'package:http/http.dart' as http; // 👈 Needed for the API call

// 👇 Import this so it knows where to go when you click a workout
import '../active_workout_page.dart';

// ==========================================
// 6. WORKOUT TAB (Logic-Based Filtering)
// ==========================================
class WorkoutTab extends StatefulWidget {
  const WorkoutTab({super.key});

  @override
  State<WorkoutTab> createState() => _WorkoutTabState();
}

class _WorkoutTabState extends State<WorkoutTab> {
  // Toggle between "Featured" (Local) and "Search" (API)
  bool _showSearch = false;

  // --- API STATE ---
  List<dynamic> _apiExercises = [];
  bool _isLoading = false;
  final TextEditingController _searchController = TextEditingController();

  // --- LOCAL DATA ---
  String _difficulty = "Beginner";
  final List<Map<String, dynamic>> _localExercises = [
    {
      "name": "Push Ups",
      "level": "Beginner",
      "sets": "3 sets x 10 reps",
      "image": "https://images.unsplash.com/photo-1599058945522-28d584b6f0ff?w=400",
      "desc": "Keep body straight, lower chest to floor."
    },
    {
      "name": "Burpees",
      "level": "Advanced",
      "sets": "4 sets x 15 reps",
      "image": "https://images.unsplash.com/photo-1544367563-12123d896889?w=400",
      "desc": "Squat, kick back, push up, jump."
    },
    {
      "name": "Plank",
      "level": "Intermediate",
      "sets": "3 sets x 45 sec",
      "image": "https://images.unsplash.com/photo-1517836357463-d25dfeac3438?w=400",
      "desc": "Hold core tight on elbows."
    },
     {
      "name": "Squats",
      "level": "Beginner",
      "sets": "3 sets x 15 reps",
      "image": "https://images.unsplash.com/photo-1574680096145-d05b474e2155?w=400",
      "desc": "Lower hips back and down."
    },
  ];

  // --- 🔥 EXERCISE DB API INTEGRATION ---
  Future<void> _searchExercises(String query) async {
    if (query.trim().isEmpty) return;
    
    setState(() => _isLoading = true);
    
    // ⚠️ 记得把这里换成你在 RapidAPI 申请到的 Key
    const String apiKey = '249abca3c2msh05e0221ea16d014p145f8ajsnf6508b87260f'; 
    
    try {
      // 通过名字搜索动作，限制返回 20 个结果防止页面卡顿
      final url = Uri.parse('https://exercisedb.p.rapidapi.com/exercises/name/${query.toLowerCase()}?limit=20');
      
      final response = await http.get(url, headers: {
        'X-RapidAPI-Key': apiKey,
        'X-RapidAPI-Host': 'exercisedb.p.rapidapi.com'
      });

      if (response.statusCode == 200) {
        setState(() {
          _apiExercises = json.decode(response.body);
          _isLoading = false;
        });
        
        if (_apiExercises.isEmpty && mounted) {
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No exercises found.")));
        }
      } else {
        throw Exception("API Error: ${response.statusCode}");
      }
    } catch (e) {
      print("Exercise API Error: $e");
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error fetching workouts. Check API Key.")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    List<Map<String, dynamic>> filteredLocal = _localExercises
        .where((ex) => ex["level"] == _difficulty)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Workout Coach"),
        actions: [
          TextButton.icon(
            onPressed: () => setState(() => _showSearch = !_showSearch),
            icon: Icon(_showSearch ? Icons.star : Icons.search, color: Colors.teal),
            label: Text(_showSearch ? "Show Featured" : "Search Library", style: const TextStyle(color: Colors.teal)),
          )
        ],
      ),
      body: _showSearch ? _buildApiSearch() : _buildLocalList(filteredLocal),
    );
  }

  // VIEW 1: API SEARCH UI
  Widget _buildApiSearch() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: "Search Exercise (e.g. curl, squat, deadlift)",
              suffixIcon: IconButton(
                icon: const Icon(Icons.search, color: Colors.teal), 
                onPressed: () => _searchExercises(_searchController.text.trim())
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              filled: true,
              fillColor: Colors.grey.shade100,
            ),
            onSubmitted: (val) => _searchExercises(val.trim()),
          ),
        ),
        
        if (_isLoading) const LinearProgressIndicator(color: Colors.teal),
        
        Expanded(
          child: _apiExercises.isEmpty && !_isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.fitness_center, size: 60, color: Colors.grey.shade300),
                  const SizedBox(height: 10),
                  const Text("Search our database of 1300+ exercises!", style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
          : ListView.builder(
              itemCount: _apiExercises.length,
              itemBuilder: (context, index) {
                final ex = _apiExercises[index];
                
                // 处理从 API 传来的数据
                String name = (ex['name'] ?? 'Unknown').toString().toUpperCase();
                String target = ex['target'] ?? 'Body';
                String equipment = ex['equipment'] ?? 'None';
                String gifUrl = ex['gifUrl'] ?? '';

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(10),
                    // 左侧直接显示 API 传来的动作 GIF 缩略图
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(gifUrl, width: 60, height: 60, fit: BoxFit.cover, errorBuilder: (c,o,s) => const Icon(Icons.fitness_center)),
                    ),
                    title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: Text("Target: $target\nEquip: $equipment", style: const TextStyle(fontSize: 12)),
                    trailing: const Icon(Icons.play_circle_fill, color: Colors.teal, size: 30),
                    onTap: () {
                      // 💡 核心：把 ExerciseDB 的数据格式转换成你的 ActiveWorkoutPage 能读懂的格式
                      List<dynamic> instructionsList = ex['instructions'] ?? [];
                      String fullInstructions = instructionsList.isNotEmpty 
                          ? instructionsList.map((i) => "• $i").join("\n\n") 
                          : "No instructions provided.";

                      Map<String, dynamic> convertedData = {
                        "name": name,
                        "level": "API Database",
                        "sets": "3 sets x 10 reps", // 默认组数
                        "image": gifUrl,            // 把 GIF 传过去
                        "desc": fullInstructions    // 把数组转换成换行字符串
                      };
                      
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ActiveWorkoutPage(
                            exerciseData: convertedData, 
                            totalExercises: 1, 
                            currentExerciseIndex: 0
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

  // VIEW 2: LOCAL FEATURED UI (你的首页推荐卡片，代码保持原样)
  Widget _buildLocalList(List<Map<String, dynamic>> filteredLocal) {
    return Column(
      children: [
         Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: ["Beginner", "Intermediate", "Advanced"].map((level) {
                return ChoiceChip(
                  label: Text(level),
                  selected: _difficulty == level,
                  selectedColor: Colors.teal,
                  labelStyle: TextStyle(color: _difficulty == level ? Colors.white : Colors.black),
                  onSelected: (selected) {
                    if (selected) setState(() => _difficulty = level);
                  },
                );
              }).toList(),
            ),
          ),
        Expanded(
          child: ListView.builder(
            itemCount: filteredLocal.length,
            itemBuilder: (context, index) {
              final ex = filteredLocal[index];
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ActiveWorkoutPage(
                        exerciseData: ex, 
                        totalExercises: filteredLocal.length, 
                        currentExerciseIndex: index
                      ),
                    ),
                  );
                },
                child: Container(
                  margin: const EdgeInsets.all(12),
                  height: 140,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    image: DecorationImage(
                      image: NetworkImage(ex["image"]), 
                      fit: BoxFit.cover,
                      colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.6), BlendMode.darken), 
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(ex["name"], style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            const Icon(Icons.timer, color: Colors.tealAccent, size: 18),
                            const SizedBox(width: 5),
                            Text(ex["sets"], style: const TextStyle(color: Colors.white, fontSize: 16)),
                          ],
                        )
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}