import 'package:flutter/material.dart';
import 'dart:convert'; // 👈 Needed for json.decode
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart'; // 👈 Needed for camera
import 'package:google_generative_ai/google_generative_ai.dart';

// ==========================================
// 7. UPGRADED AI CAMERA TAB & HISTORY
// ==========================================
class CameraTab extends StatefulWidget {
  final Function(int) onFoodDetected;

  const CameraTab({super.key, required this.onFoodDetected});

  @override
  State<CameraTab> createState() => _CameraTabState();
}

class _CameraTabState extends State<CameraTab> {
  bool _scanning = false;
  final ImagePicker _picker = ImagePicker();
  DateTime _selectedDate = DateTime.now();

  final _model = GenerativeModel(
    model: 'gemini-3-flash-preview',
    apiKey: 'AIzaSyCXeklnWb_wLOVXPb-Ph3eA5Iu4sPEOU8Q', 
  );

  String _getDateString(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  void _changeDate(int days) {
    setState(() { _selectedDate = _selectedDate.add(Duration(days: days)); });
  }

  // --- 彻底精简的 DELETE FOOD ---
  Future<void> _deleteFood(String docId) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).collection('food_logs').doc(docId).delete();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Food deleted.")));
    } catch (e) {
      print("Delete error: $e");
    }
  }

  // --- 彻底精简的 EDIT FOOD ---
  Future<void> _editFoodDialog(String docId, Map<String, dynamic> currentData) async {
    final nameCtrl = TextEditingController(text: currentData['name']);
    final calCtrl = TextEditingController(text: currentData['calories'].toString());
    final proCtrl = TextEditingController(text: currentData['proteins'].toString());
    final carbCtrl = TextEditingController(text: currentData['carbs'].toString());
    final fatCtrl = TextEditingController(text: currentData['fats'].toString());

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Edit Food"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Name")),
              TextField(controller: calCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Calories")),
              TextField(controller: proCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Proteins (g)")),
              TextField(controller: carbCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Carbs (g)")),
              TextField(controller: fatCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Fats (g)")),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
            onPressed: () async {
              final uid = FirebaseAuth.instance.currentUser!.uid;
              await FirebaseFirestore.instance.collection('users').doc(uid).collection('food_logs').doc(docId).update({
                'name': nameCtrl.text,
                'calories': int.tryParse(calCtrl.text) ?? currentData['calories'],
                'proteins': int.tryParse(proCtrl.text) ?? currentData['proteins'],
                'carbs': int.tryParse(carbCtrl.text) ?? currentData['carbs'],
                'fats': int.tryParse(fatCtrl.text) ?? currentData['fats'],
              });

              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Food updated!")));
              }
            },
            child: const Text("Save"),
          )
        ],
      )
    );
  }

  Future<void> _takePhotoAndScan() async {
    final XFile? photo = await _picker.pickImage(source: ImageSource.camera, maxWidth: 1024, maxHeight: 1024, imageQuality: 85); 
    if (photo == null) return;
    setState(() { _scanning = true; });

    try {
      // 1. Fetch the user's actual goal from Firebase to personalize the AI's advice!
      final user = FirebaseAuth.instance.currentUser!;
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      String userGoal = userDoc.data()?['goal'] ?? 'Maintenance';

      final bytes = await photo.readAsBytes();
      
      // 2. The Upgraded Super-Prompt
      final prompt = '''
      You are an expert fitness nutritionist. Analyze the food in this image. 
      The user's current fitness goal is "$userGoal".
      Return ONLY a valid JSON object with the exact following structure. Do NOT wrap it in markdown block quotes (no ```json).
      {
        "foods": [
          {"name": "string", "calories": int, "proteins": int, "carbs": int, "fats": int}
        ],
        "totalCalories": int,
        "totalProteins": int,
        "totalCarbs": int,
        "totalFats": int,
        "score": int, // 0 to 100 representing how well this fits their "$userGoal" goal.
        "explanation": "string", // Explain why you gave this score based on their goal.
        "alternatives": ["string", "string"] // Suggest 2 healthier alternatives if the score is low, or variations if high.
      }
      ''';

      final content = [
        Content.multi([
          TextPart(prompt),
          DataPart('image/jpeg', bytes),
        ])
      ];

      final response = await _model.generateContent(content);
      if (response.text == null || response.text!.isEmpty) throw Exception("Gemini returned an empty response.");

      String rawText = response.text!;
      int startIndex = rawText.indexOf('{');
      int endIndex = rawText.lastIndexOf('}');

      if (startIndex != -1 && endIndex != -1) {
        String cleanJson = rawText.substring(startIndex, endIndex + 1);
        Map<String, dynamic> analysisData = json.decode(cleanJson);
        
        if (mounted) {
          setState(() => _scanning = false);
          // 3. Show the UI popup instead of saving immediately
          _showAnalysisResult(analysisData);
        }
      } else {
        throw Exception("No JSON object found in response");
      }
    } catch (e) {
      setState(() => _scanning = false);
      print("Gemini/JSON Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to analyze food. Please try again.")));
    }
  }

  // --- NEW: AI ANALYSIS POPUP ---
  void _showAnalysisResult(Map<String, dynamic> data) {
    int score = data['score'] ?? 0;
    Color scoreColor = score >= 80 ? Colors.green : (score >= 50 ? Colors.orange : Colors.red);
    List<dynamic> foods = data['foods'] ?? [];
    List<dynamic> alternatives = data['alternatives'] ?? [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)))),
              const SizedBox(height: 20),
              
              // SCORE HEADER
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("AI Nutrition Analysis", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(color: scoreColor.withOpacity(0.1), borderRadius: BorderRadius.circular(15)),
                    child: Row(
                      children: [
                        Icon(Icons.star, color: scoreColor, size: 20),
                        const SizedBox(width: 5),
                        Text("$score/100", style: TextStyle(color: scoreColor, fontWeight: FontWeight.bold, fontSize: 18)),
                      ],
                    ),
                  )
                ],
              ),
              const SizedBox(height: 15),

              // EXPLANATION
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey.shade200)),
                child: Text(data['explanation'] ?? "No explanation provided.", style: const TextStyle(fontSize: 14, height: 1.5)),
              ),
              const SizedBox(height: 20),

              // DETECTED FOODS LIST
              const Text("Detected Foods", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 10),
              ...foods.map((f) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(backgroundColor: Colors.teal, child: Icon(Icons.fastfood, color: Colors.white, size: 18)),
                title: Text(f['name']),
                subtitle: Text("Pro: ${f['proteins']}g • Carbs: ${f['carbs']}g • Fat: ${f['fats']}g"),
                trailing: Text("${f['calories']} kcal", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              )),
              
              const Divider(),
              
              // TOTALS
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Total Meal Macros", style: TextStyle(fontWeight: FontWeight.bold)),
                    Text("${data['totalCalories']} kcal", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.teal)),
                  ],
                ),
              ),
              const SizedBox(height: 15),

              // ALTERNATIVES
              if (alternatives.isNotEmpty) ...[
                const Text("💡 Healthier Alternatives", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.orange)),
                const SizedBox(height: 10),
                ...alternatives.map((alt) => Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.check_circle_outline, color: Colors.orange, size: 20),
                      const SizedBox(width: 10),
                      Expanded(child: Text(alt.toString(), style: TextStyle(color: Colors.grey.shade700))),
                    ],
                  ),
                )),
              ],
              const SizedBox(height: 30),

              // SAVE BUTTON
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    // Save to Firebase
                    final user = FirebaseAuth.instance.currentUser!;
                    await FirebaseFirestore.instance.collection('users').doc(user.uid).collection('food_logs').add({
                      'name': foods.length > 1 ? "Mixed Meal (${foods.length} items)" : foods[0]['name'],
                      'calories': data['totalCalories'],
                      'proteins': data['totalProteins'],
                      'carbs': data['totalCarbs'],
                      'fats': data['totalFats'],
                      'score': score,
                      'timestamp': _selectedDate, 
                    });

                    if (context.mounted) {
                      Navigator.pop(context); // Close BottomSheet
                      widget.onFoodDetected(data['totalCalories'] as int); 
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Meal saved to diary!")));
                    }
                  },
                  icon: const Icon(Icons.save),
                  label: const Text("Save to Food Diary", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String uid = FirebaseAuth.instance.currentUser!.uid;
    String selectedDateStr = _getDateString(_selectedDate);

    DateTime startOfDay = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    DateTime endOfDay = startOfDay.add(const Duration(days: 1));

    return Scaffold(
      appBar: AppBar(title: const Text("Food Scanner & History")),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
        builder: (context, userSnapshot) {
          if (!userSnapshot.hasData) return const Center(child: CircularProgressIndicator());
          int target = (userSnapshot.data!.data() as Map<String, dynamic>?)?['dailyCaloriesTarget'] ?? 2000;

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('users').doc(uid).collection('food_logs')
                .where('timestamp', isGreaterThanOrEqualTo: startOfDay)
                .where('timestamp', isLessThan: endOfDay)
                .orderBy('timestamp', descending: true)
                .snapshots(),
            builder: (context, foodSnapshot) {
              
              int consumed = 0;
              if (foodSnapshot.hasData) {
                for (var doc in foodSnapshot.data!.docs) {
                  consumed += ((doc.data() as Map<String, dynamic>)['calories'] as num?)?.toInt() ?? 0;
                }
              }
              int remaining = target - consumed;

              return Column(
                children: [
                  // 1. DATE PICKER
                  Container(
                    color: Colors.white, padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        IconButton(icon: const Icon(Icons.arrow_back_ios, size: 18), onPressed: () => _changeDate(-1)),
                        Text(selectedDateStr == _getDateString(DateTime.now()) ? "Today, $selectedDateStr" : selectedDateStr, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        IconButton(icon: const Icon(Icons.arrow_forward_ios, size: 18), onPressed: () => _changeDate(1)),
                      ],
                    ),
                  ),

                  // 2. CALORIES LEFT
                  Container(
                    margin: const EdgeInsets.all(16), padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.teal.shade50, borderRadius: BorderRadius.circular(15)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(children: [const Text("Target", style: TextStyle(color: Colors.grey)), Text("$target", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))]),
                        const Text("-", style: TextStyle(fontSize: 24, color: Colors.grey)),
                        Column(children: [const Text("Eaten", style: TextStyle(color: Colors.grey)), Text("$consumed", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.orange))]),
                        const Text("=", style: TextStyle(fontSize: 24, color: Colors.grey)),
                        Column(children: [const Text("Left", style: TextStyle(color: Colors.grey)), Text("$remaining", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: remaining < 0 ? Colors.red : Colors.teal))]),
                      ],
                    ),
                  ),

                  // 3. CAMERA BUTTON
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: ElevatedButton.icon(
                      onPressed: _scanning ? null : _takePhotoAndScan,
                      icon: _scanning ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.camera_alt),
                      label: Text(_scanning ? "Analyzing Food..." : "Scan Food for $selectedDateStr"),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 50)),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // 4. HISTORY (With Edit/Delete)
                  Expanded(
                    child: foodSnapshot.connectionState == ConnectionState.waiting
                        ? const Center(child: CircularProgressIndicator())
                        : (!foodSnapshot.hasData || foodSnapshot.data!.docs.isEmpty)
                            ? const Center(child: Text("No food logged on this date.", style: TextStyle(color: Colors.grey)))
                            : ListView.builder(
                                itemCount: foodSnapshot.data!.docs.length,
                                itemBuilder: (context, index) {
                                  final doc = foodSnapshot.data!.docs[index];
                                  final meal = doc.data() as Map<String, dynamic>;
                                  
                                  return Card(
                                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                                    child: ExpansionTile(
                                      leading: const CircleAvatar(backgroundColor: Colors.orange, child: Icon(Icons.restaurant, color: Colors.white, size: 18)),
                                      title: Text(meal['name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold)),
                                      subtitle: Text("${meal['calories']} kcal"),
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.all(16.0),
                                          child: Column(
                                            children: [
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                                children: [
                                                  _buildMacroText("Protein", meal['proteins'], Colors.purple),
                                                  _buildMacroText("Carbs", meal['carbs'], Colors.orange),
                                                  _buildMacroText("Fats", meal['fats'], Colors.red),
                                                ],
                                              ),
                                              const Divider(),
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.end,
                                                children: [
                                                  TextButton.icon(onPressed: () => _editFoodDialog(doc.id, meal), icon: const Icon(Icons.edit, size: 16, color: Colors.teal), label: const Text("Edit", style: TextStyle(color: Colors.teal))),
                                                  TextButton.icon(
                                                    onPressed: () {
                                                      showDialog(context: context, builder: (c) => AlertDialog(
                                                        title: const Text("Delete Food?"),
                                                        content: const Text("This will permanently remove this item."),
                                                        actions: [
                                                          TextButton(onPressed: ()=>Navigator.pop(c), child: const Text("Cancel")),
                                                          TextButton(onPressed: (){ Navigator.pop(c); _deleteFood(doc.id); }, child: const Text("Delete", style: TextStyle(color: Colors.red))),
                                                        ],
                                                      ));
                                                    },
                                                    icon: const Icon(Icons.delete, size: 16, color: Colors.red), label: const Text("Delete", style: TextStyle(color: Colors.red)),
                                                  ),
                                                ],
                                              )
                                            ],
                                          ),
                                        )
                                      ],
                                    ),
                                  );
                                },
                              ),
                  ),
                ],
              );
            }
          );
        }
      ),
    );
  }

  Widget _buildMacroText(String label, dynamic value, Color color) {
    return Column(children: [Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)), Text("${value ?? 0}g", style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16))]);
  }
}