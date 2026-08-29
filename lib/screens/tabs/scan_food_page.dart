import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class CameraTab extends StatefulWidget {
  final Function(int) onFoodDetected;

  const CameraTab({super.key, required this.onFoodDetected});

  @override
  State<CameraTab> createState() => _CameraTabState();
}

class _CameraTabState extends State<CameraTab>
    with SingleTickerProviderStateMixin {
  bool _scanning = false;
  final ImagePicker _picker = ImagePicker();
  DateTime _selectedDate = DateTime.now();
  late AnimationController _pulseController;

  // Replace with your actual Gemini API key
  final _model = GenerativeModel(
    model: 'gemini-3-flash-preview',
    apiKey: 'AQ.Ab8RN6K6De9MX3EdbrjPrjVPuqN3FSs8qa3_r4cKONfS2c31OA',
  );

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  String _getDateString(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  void _changeDate(int days) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: days));
    });
  }

  Future<void> _deleteFood(String docId) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('food_logs')
          .doc(docId)
          .delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Meal removed from diary.")),
        );
      }
    } catch (e) {
      debugPrint("Delete error: $e");
    }
  }

  // === FIX 2: INSTANT SAVE UPON SCAN ===
  Future<void> _takePhotoAndScan(ImageSource source) async {
    final XFile? photo = await _picker.pickImage(
      source: source,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (photo == null) return;

    setState(() => _scanning = true);

    try {
      final user = FirebaseAuth.instance.currentUser!;
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final String userGoal = userDoc.data()?['goal'] ?? 'Maintenance';

      final bytes = await photo.readAsBytes();

      final prompt = '''
      You are an elite AI sports nutritionist. Analyze the food in this image.
      The user's fitness goal is "$userGoal".
      Return ONLY a valid JSON object matching this exact structure (no markdown backticks):
      {
        "foods": [
          {"name": "string", "calories": int, "proteins": int, "carbs": int, "fats": int}
        ],
        "totalCalories": int,
        "totalProteins": int,
        "totalCarbs": int,
        "totalFats": int,
        "score": int,
        "explanation": "string",
        "alternatives": ["string", "string"]
      }
      ''';

      final content = [
        Content.multi([TextPart(prompt), DataPart('image/jpeg', bytes)]),
      ];

      final response = await _model.generateContent(content);
      if (response.text == null || response.text!.isEmpty) {
        throw Exception("Empty AI response.");
      }

      String rawText = response.text!;
      int startIndex = rawText.indexOf('{');
      int endIndex = rawText.lastIndexOf('}');

      if (startIndex != -1 && endIndex != -1) {
        String cleanJson = rawText.substring(startIndex, endIndex + 1);
        Map<String, dynamic> analysisData = json.decode(cleanJson);

        // DIRECTLY SAVE TO FIREBASE
        final List<dynamic> foods = analysisData['foods'] ?? [];
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('food_logs')
            .add({
          'name': foods.length > 1
              ? "Mixed Meal (${foods.length} items)"
              : (foods.isNotEmpty ? foods[0]['name'] : 'Meal'),
          'calories': analysisData['totalCalories'] ?? 0,
          'proteins': analysisData['totalProteins'] ?? 0,
          'carbs': analysisData['totalCarbs'] ?? 0,
          'fats': analysisData['totalFats'] ?? 0,
          'score': analysisData['score'] ?? 0,
          'explanation': analysisData['explanation'] ?? '',
          'alternatives': analysisData['alternatives'] ?? [],
          'foods': foods, // Save the itemized array for the bottom sheet!
          'timestamp': _selectedDate,
        });

        if (mounted) {
          setState(() => _scanning = false);
          widget.onFoodDetected((analysisData['totalCalories'] ?? 0) as int);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Meal instantly logged to diary!")),
          );
        }
      } else {
        throw Exception("Invalid JSON formatting.");
      }
    } catch (e) {
      if (mounted) {
        setState(() => _scanning = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Could not recognize food. Please try again."),
          ),
        );
      }
    }
  }

  // === FIX 3: READ-ONLY BOTTOM SHEET ===
  void _showMealDetails(Map<String, dynamic> data) {
    final int score = data['score'] ?? 0;
    final Color scoreColor = score >= 80
        ? Colors.green
        : (score >= 50 ? Colors.orange : Colors.redAccent);
    final List<dynamic> foods = data['foods'] ?? [];
    final List<dynamic> alternatives = data['alternatives'] ?? [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 48,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // === FIX 4: OVERFLOW ERROR ===
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Expanded( // Wraps text if it gets too long
                          child: Text(
                            "AI Nutrition Analysis",
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: scoreColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: scoreColor.withOpacity(0.4),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.auto_awesome, color: scoreColor, size: 18),
                              const SizedBox(width: 6),
                              Text(
                                "$score / 100",
                                style: TextStyle(
                                  color: scoreColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (data['explanation'] != null && data['explanation'].toString().isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Text(
                          data['explanation'],
                          style: TextStyle(color: Colors.grey.shade800, height: 1.4),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                    
                    if (foods.isNotEmpty) ...[
                      const Text(
                        "Detected Items",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 10),
                      ...foods.map(
                        (f) => Card(
                          elevation: 0,
                          color: Colors.teal.withOpacity(0.04),
                          margin: const EdgeInsets.only(bottom: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: Colors.teal,
                              child: Icon(Icons.restaurant, color: Colors.white, size: 18),
                            ),
                            title: Text(
                              f['name'] ?? 'Unknown',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              "P: ${f['proteins'] ?? 0}g • C: ${f['carbs'] ?? 0}g • F: ${f['fats'] ?? 0}g",
                            ),
                            trailing: Text(
                              "${f['calories'] ?? 0} kcal",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: Colors.teal,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    if (alternatives.isNotEmpty) ...[
                      const Text(
                        "💡 Healthier Alternatives",
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ...alternatives.map(
                        (alt) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.check_circle, color: Colors.orange, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  alt.toString(),
                                  style: TextStyle(color: Colors.grey.shade700),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final startOfDay = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          "AI Food Scanner",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      // === FIX 1: FLEXIBLE SCROLLING LAYOUT ===
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Date Selector Banner
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () => _changeDate(-1),
                  ),
                  Text(
                    _getDateString(_selectedDate) ==
                            _getDateString(DateTime.now())
                        ? "Today, ${_getDateString(_selectedDate)}"
                        : _getDateString(_selectedDate),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: () => _changeDate(1),
                  ),
                ],
              ),
            ),

            // Creative Hero Scanner Section
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.teal.shade800, Colors.teal.shade500],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.teal.withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _scanning
                      ? ScaleTransition(
                          scale: Tween<double>(begin: 0.95, end: 1.05).animate(
                            CurvedAnimation(
                              parent: _pulseController,
                              curve: Curves.easeInOut,
                            ),
                          ),
                          child: const CircleAvatar(
                            radius: 36,
                            backgroundColor: Colors.white24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 3,
                            ),
                          ),
                        )
                      : const CircleAvatar(
                          radius: 36,
                          backgroundColor: Colors.white24,
                          child: Icon(
                            Icons.camera_alt_outlined,
                            size: 36,
                            color: Colors.white,
                          ),
                        ),
                  const SizedBox(height: 16),
                  Text(
                    _scanning
                        ? "AI is analyzing nutrients..."
                        : "Snap or Upload Your Meal",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    "Instant calories, macros & goal score",
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _scanning
                              ? null
                              : () => _takePhotoAndScan(ImageSource.camera),
                          icon: const Icon(Icons.camera_alt, size: 18),
                          label: const Text("Camera"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.teal.shade800,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _scanning
                              ? null
                              : () => _takePhotoAndScan(ImageSource.gallery),
                          icon: const Icon(Icons.photo_library, size: 18),
                          label: const Text("Gallery"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white24,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Food History Section Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Logged Today",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Icon(Icons.history, color: Colors.grey.shade600, size: 20),
                ],
              ),
            ),

            // History Log Stream
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(uid)
                  .collection('food_logs')
                  .where('timestamp', isGreaterThanOrEqualTo: startOfDay)
                  .where('timestamp', isLessThan: endOfDay)
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(40.0),
                    child: Center(
                      child: CircularProgressIndicator(color: Colors.teal),
                    ),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(40.0),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.no_meals_outlined,
                            size: 54,
                            color: Colors.grey.shade300,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            "No meals logged for this date.",
                            style: TextStyle(color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                // shrinkWrap allows the ListView to exist inside the SingleChildScrollView
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final doc = snapshot.data!.docs[index];
                    final meal = doc.data() as Map<String, dynamic>;
                    final int score = meal['score'] ?? 0;
                    
                    final Color scoreColor = score >= 80 ? Colors.green : (score >= 50 ? Colors.orange : Colors.redAccent);

                    return Card(
                      elevation: 0,
                      color: Colors.white,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () => _showMealDetails(meal), // Tap to view details
                        onLongPress: () => _deleteFood(doc.id), // Long press to delete
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: Colors.teal.shade50,
                                child: const Icon(Icons.fastfood, color: Colors.teal),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      meal['name'] ?? 'Meal',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "${meal['calories']} kcal • P: ${meal['proteins']}g",
                                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                              if (score > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(color: scoreColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                                  child: Text("$score", style: TextStyle(color: scoreColor, fontWeight: FontWeight.bold, fontSize: 14)),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 30), // Bottom padding
          ],
        ),
      ),
    );
  }
}