import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/ai_service.dart';
import '../../services/local_food_image_service.dart';
import '../../services/scan_food_cache_service.dart';
import '../../services/scan_draft_service.dart';
import '../../services/diet_personalization_service.dart';
import '../../widgets/diet/meal_detail_sheet.dart';
import '../../widgets/diet/food_delete_dialog.dart';
import '../../widgets/diet/scan_result_review_sheet.dart';
import '../../widgets/diet/food_image_display.dart';

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
  ScanDraft? _activeDraft;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    _loadActiveDraft();
  }

  Future<void> _loadActiveDraft() async {
    final draft = await ScanDraftService.instance.getDraft();
    if (mounted) {
      setState(() => _activeDraft = draft);
    }
  }

  Future<void> _discardActiveDraft() async {
    await ScanDraftService.instance.clearDraft();
    if (mounted) {
      setState(() => _activeDraft = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Draft scan discarded.")),
      );
    }
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

  String _deriveDefaultMealName(Map<String, dynamic> analysisData) {
    final rawFoods = analysisData['foods'] as List? ?? [];
    if (rawFoods.isEmpty) return 'Scanned Meal';
    if (rawFoods.length == 1) {
      final f = rawFoods[0];
      return (f is Map ? f['name'] : f.toString()) ?? 'Meal';
    }
    final names = rawFoods.map((f) => (f is Map ? f['name'] : f.toString()) ?? 'Food').toList();
    if (names.length <= 2) {
      return names.join(', ');
    }
    return "${names[0]}, ${names[1]} + ${names.length - 2} more";
  }

  Future<void> _saveMealToFirestore({
    required Map<String, dynamic> finalMealData,
    required Uint8List imageBytes,
    required String imageHash,
  }) async {
    final user = FirebaseAuth.instance.currentUser!;
    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('food_logs')
        .doc();

    bool hasLocalImage = false;
    try {
      // 1. Save compressed image to local on-device storage (food_images/$imageHash.jpg)
      // Automatically deduplicates: if image was already saved, reuses file with 0 extra disk writes.
      await LocalFoodImageService.instance.saveImage(
        imageHash: imageHash,
        imageBytes: imageBytes,
      );
      hasLocalImage = true;
    } catch (localSaveErr) {
      debugPrint("[ScanFood] Local image save error: $localSaveErr");
    }

    // 2. Persist to Firestore: store imageHash and hasLocalImage (no paid Firebase Storage URL required)
    final Map<String, dynamic> dataToSave = {
      ...finalMealData,
      'imageHash': imageHash,
      'hasLocalImage': hasLocalImage,
      'timestamp': Timestamp.fromDate(_selectedDate),
      'createdAt': FieldValue.serverTimestamp(),
    };

    await docRef.set(dataToSave);

    // 3. Clear corresponding draft after confirmed save
    await ScanDraftService.instance.clearDraft();
    await _loadActiveDraft();

    if (mounted) {
      widget.onFoodDetected((dataToSave['calories'] as num?)?.toInt() ?? 0);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Meal successfully logged to diary!"),
        ),
      );
    }
  }

  Future<void> _resumeActiveDraft() async {
    if (_activeDraft == null) return;
    final draft = _activeDraft!;

    String dietPreference = 'Standard';
    List<String> allergies = [];
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        final userData = userDoc.data() ?? {};
        dietPreference = userData['dietPreference'] ?? 'Standard';
        if (userData['allergies'] is List) {
          allergies = List<String>.from((userData['allergies'] as List).map((e) => e.toString()));
        }
      }
    } catch (_) {}

    final sanitizedAnalysis = DietPersonalizationService.sanitizeAndEvaluate(
      draft.analysisData,
      dietPreference: dietPreference,
      allergies: allergies,
    );

    if (!mounted) return;

    ScanResultReviewSheet.show(
      context,
      imageBytes: draft.imageBytes,
      initialAnalysis: sanitizedAnalysis,
      initialMealName: draft.mealName,
      isCached: true,
      onEditsChanged: (edits) {
        ScanDraftService.instance.saveDraft(
          imageHash: draft.imageHash,
          imageBytes: draft.imageBytes,
          analysisData: sanitizedAnalysis,
          mealName: edits['name']?.toString() ?? draft.mealName,
          userEdits: edits,
        );
      },
      onReanalyze: () => _reanalyze(draft.imageBytes, draft.imageHash),
      onSave: (finalMealData) => _saveMealToFirestore(
        finalMealData: finalMealData,
        imageBytes: draft.imageBytes,
        imageHash: draft.imageHash,
      ),
    );
  }

  Future<void> _reanalyze(Uint8List bytes, String imageHash) async {
    setState(() => _scanning = true);

    try {
      final user = FirebaseAuth.instance.currentUser!;
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final userData = userDoc.data() ?? {};
      final String userGoal = userData['fitnessGoal'] ?? userData['goal'] ?? 'Maintenance';
      final int? calorieTarget = (userData['calorieTarget'] ?? userData['dailyCaloriesTarget'] as num?)?.toInt();
      final String dietPreference = userData['dietPreference'] ?? 'Standard';
      List<String> allergies = [];
      if (userData['allergies'] is List) {
        allergies = List<String>.from((userData['allergies'] as List).map((e) => e.toString()));
      }

      await ScanFoodCacheService.instance.removeCachedAnalysis(
        imageHash,
        dietPreference: dietPreference,
        allergies: allergies,
      );

      var freshAnalysis = await AiService.analyzeFoodImage(
        imageBytes: bytes,
        userGoal: userGoal,
        calorieTarget: calorieTarget,
        dietPreference: dietPreference,
        allergies: allergies,
      );

      // Defense-in-depth: client-side personalized evaluation & recommendation sanitization
      freshAnalysis = DietPersonalizationService.sanitizeAndEvaluate(
        freshAnalysis,
        dietPreference: dietPreference,
        allergies: allergies,
      );

      await ScanFoodCacheService.instance.saveAnalysis(
        imageHash,
        freshAnalysis,
        dietPreference: dietPreference,
        allergies: allergies,
      );
      final defaultMealName = _deriveDefaultMealName(freshAnalysis);
      await ScanDraftService.instance.saveDraft(
        imageHash: imageHash,
        imageBytes: bytes,
        analysisData: freshAnalysis,
        mealName: defaultMealName,
      );
      await _loadActiveDraft();

      if (mounted) {
        setState(() => _scanning = false);
        ScanResultReviewSheet.show(
          context,
          imageBytes: bytes,
          initialAnalysis: freshAnalysis,
          initialMealName: defaultMealName,
          isCached: false,
          onEditsChanged: (edits) {
            ScanDraftService.instance.saveDraft(
              imageHash: imageHash,
              imageBytes: bytes,
              analysisData: freshAnalysis,
              mealName: edits['name']?.toString() ?? defaultMealName,
              userEdits: edits,
            );
          },
          onReanalyze: () => _reanalyze(bytes, imageHash),
          onSave: (finalMealData) => _saveMealToFirestore(
            finalMealData: finalMealData,
            imageBytes: bytes,
            imageHash: imageHash,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _scanning = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Re-analysis failed: $e")),
        );
      }
    }
  }

  Future<void> _takePhotoAndScan(ImageSource source) async {
    final XFile? photo = await _picker.pickImage(
      source: source,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 75,
    );
    if (photo == null) return;

    setState(() => _scanning = true);

    try {
      final bytes = await photo.readAsBytes();
      final imageHash = ScanFoodCacheService.instance.computeImageHash(bytes);
      debugPrint("[ScanFood] Selected photo hash: $imageHash (${bytes.length} bytes)");

      // 1. Fetch current User Profile FIRST to establish dietary context before cache check
      final user = FirebaseAuth.instance.currentUser!;
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final userData = userDoc.data() ?? {};
      final String userGoal = userData['fitnessGoal'] ?? userData['goal'] ?? 'Maintenance';
      final int? calorieTarget = (userData['calorieTarget'] ?? userData['dailyCaloriesTarget'] as num?)?.toInt();
      final String dietPreference = userData['dietPreference'] ?? 'Standard';
      List<String> allergies = [];
      if (userData['allergies'] is List) {
        allergies = List<String>.from((userData['allergies'] as List).map((e) => e.toString()));
      }

      // 2. Check Exact-Image + Personalization Persistent Cache
      Map<String, dynamic>? analysisData = await ScanFoodCacheService.instance.getCachedAnalysis(
        imageHash,
        dietPreference: dietPreference,
        allergies: allergies,
      );
      final bool isCached = analysisData != null;

      if (!isCached) {
        analysisData = await AiService.analyzeFoodImage(
          imageBytes: bytes,
          userGoal: userGoal,
          calorieTarget: calorieTarget,
          dietPreference: dietPreference,
          allergies: allergies,
        );
      }

      // 3. Defense-in-depth: client-side personalized evaluation & recommendation sanitization
      analysisData = DietPersonalizationService.sanitizeAndEvaluate(
        analysisData,
        dietPreference: dietPreference,
        allergies: allergies,
      );

      // Store into persistent exact-image + personalized cache
      await ScanFoodCacheService.instance.saveAnalysis(
        imageHash,
        analysisData,
        dietPreference: dietPreference,
        allergies: allergies,
      );

      // 4. Auto-save local draft BEFORE user confirms Save Meal
      final String defaultMealName = _deriveDefaultMealName(analysisData);
      await ScanDraftService.instance.saveDraft(
        imageHash: imageHash,
        imageBytes: bytes,
        analysisData: analysisData,
        mealName: defaultMealName,
      );
      await _loadActiveDraft();

      if (mounted) {
        setState(() => _scanning = false);

        await ScanResultReviewSheet.show(
          context,
          imageBytes: bytes,
          initialAnalysis: analysisData,
          initialMealName: defaultMealName,
          isCached: isCached,
          onEditsChanged: (edits) {
            ScanDraftService.instance.saveDraft(
              imageHash: imageHash,
              imageBytes: bytes,
              analysisData: analysisData!,
              mealName: edits['name']?.toString() ?? defaultMealName,
              userEdits: edits,
            );
          },
          onReanalyze: () => _reanalyze(bytes, imageHash),
          onSave: (finalMealData) => _saveMealToFirestore(
            finalMealData: finalMealData,
            imageBytes: bytes,
            imageHash: imageHash,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _scanning = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Could not recognize food: $e"),
          ),
        );
      }
    }
  }

  void _showMealDetails(Map<String, dynamic> data) {
    MealDetailSheet.show(
      context,
      meal: data,
      onDelete: data['id'] != null ? () => _deleteFood(data['id'] as String) : null,
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
                    color: Colors.teal.withValues(alpha: 0.3),
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

            // Resume Previous Scan Draft Card (Auto-saved)
            if (_activeDraft != null) _buildResumeDraftCard(),

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
                    final meal = Map<String, dynamic>.from(doc.data() as Map<String, dynamic>)..['id'] = doc.id;
                    final int score = (meal['mealScore'] ?? meal['score'] as num?)?.toInt() ?? 0;
                    final int calories = (meal['calories'] as num?)?.toInt() ?? 0;
                    final int protein = (meal['protein'] ?? meal['proteins'] as num?)?.toInt() ?? 0;
                    
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
                        onLongPress: () async {
                          final confirmed = await showFoodDeleteConfirmationDialog(
                            context,
                            foodName: meal['name']?.toString() ?? 'Meal',
                          );
                          if (confirmed && mounted) {
                            _deleteFood(doc.id);
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              FoodImageDisplay(
                                imageHash: meal['imageHash']?.toString(),
                                imageUrl: meal['imageUrl']?.toString(),
                                width: 48,
                                height: 48,
                                borderRadius: BorderRadius.circular(24),
                                fit: BoxFit.cover,
                                placeholder: CircleAvatar(
                                  radius: 24,
                                  backgroundColor: Colors.teal.shade50,
                                  child: const Icon(Icons.fastfood, color: Colors.teal),
                                ),
                                errorWidget: CircleAvatar(
                                  radius: 24,
                                  backgroundColor: Colors.teal.shade50,
                                  child: const Icon(Icons.fastfood, color: Colors.teal),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      meal['name'] ?? 'Meal',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "$calories kcal • P: ${protein}g",
                                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                              if (score > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(color: scoreColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
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

  Widget _buildResumeDraftCard() {
    final draft = _activeDraft!;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.amber.shade300, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade200,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit_note, size: 14, color: Colors.amber.shade900),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          "PREVIOUS SCAN",
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Colors.amber.shade900,
                            letterSpacing: 0.5,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                draft.timeAgo,
                style: TextStyle(fontSize: 11, color: Colors.amber.shade900, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(
                  draft.imageBytes,
                  width: 54,
                  height: 54,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => CircleAvatar(
                    radius: 27,
                    backgroundColor: Colors.amber.shade100,
                    child: const Icon(Icons.fastfood, color: Colors.amber),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      draft.mealName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${draft.calories} kcal • P: ${draft.protein}g",
                      style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                flex: 1,
                child: OutlinedButton(
                  onPressed: _discardActiveDraft,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red.shade700,
                    side: BorderSide(color: Colors.red.shade300),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                  ),
                  child: const FittedBox(fit: BoxFit.scaleDown, child: Text("Discard")),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 1,
                child: ElevatedButton(
                  onPressed: _resumeActiveDraft,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                  ),
                  child: const FittedBox(fit: BoxFit.scaleDown, child: Text("Resume")),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}