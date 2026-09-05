import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../services/ai_service.dart';
import '../../services/diet_personalization_service.dart';
import '../../services/scan_food_cache_service.dart';
import '../../services/local_food_image_service.dart';

class ScanResultReviewSheet extends StatefulWidget {
  final File? imageFile;
  final Uint8List? imageBytes;
  final Map<String, dynamic> initialAnalysis;
  final String? initialMealName;
  final bool isCached;
  final VoidCallback? onReanalyze;
  final Function(Map<String, dynamic> currentEdits)? onEditsChanged;
  final Future<void> Function(Map<String, dynamic> finalMealData) onSave;
  final String? imageHash;
  final String userGoal;
  final int? calorieTarget;
  final String dietPreference;
  final List<String> allergies;

  const ScanResultReviewSheet({
    super.key,
    this.imageFile,
    this.imageBytes,
    required this.initialAnalysis,
    this.initialMealName,
    this.isCached = false,
    this.onReanalyze,
    this.onEditsChanged,
    required this.onSave,
    this.imageHash,
    this.userGoal = 'Maintenance',
    this.calorieTarget,
    this.dietPreference = 'Standard',
    this.allergies = const [],
    this.recalculateFn,
  });

  final Future<Map<String, dynamic>> Function({
    required Uint8List imageBytes,
    required String correctedFoodName,
    double? previousServingGrams,
    String userGoal,
    int? calorieTarget,
    String dietPreference,
    List<String> allergies,
  })? recalculateFn;

  static Future<void> show(
    BuildContext context, {
    File? imageFile,
    Uint8List? imageBytes,
    required Map<String, dynamic> initialAnalysis,
    String? initialMealName,
    bool isCached = false,
    VoidCallback? onReanalyze,
    Function(Map<String, dynamic> currentEdits)? onEditsChanged,
    required Future<void> Function(Map<String, dynamic> finalMealData) onSave,
    String? imageHash,
    String userGoal = 'Maintenance',
    int? calorieTarget,
    String dietPreference = 'Standard',
    List<String> allergies = const [],
    Future<Map<String, dynamic>> Function({
      required Uint8List imageBytes,
      required String correctedFoodName,
      double? previousServingGrams,
      String userGoal,
      int? calorieTarget,
      String dietPreference,
      List<String> allergies,
    })? recalculateFn,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ScanResultReviewSheet(
        imageFile: imageFile,
        imageBytes: imageBytes,
        initialAnalysis: initialAnalysis,
        initialMealName: initialMealName,
        isCached: isCached,
        onReanalyze: onReanalyze,
        onEditsChanged: onEditsChanged,
        onSave: onSave,
        imageHash: imageHash,
        userGoal: userGoal,
        calorieTarget: calorieTarget,
        dietPreference: dietPreference,
        allergies: allergies,
        recalculateFn: recalculateFn,
      ),
    );
  }

  @override
  State<ScanResultReviewSheet> createState() => _ScanResultReviewSheetState();
}

class _ScanResultReviewSheetState extends State<ScanResultReviewSheet> {
  late TextEditingController _mealNameController;
  late List<Map<String, dynamic>> _items;
  bool _isSaving = false;

  // Human-in-the-loop correction state
  bool _isRecalculating = false;
  int _recalculationCount = 0;
  static const int _maxRecalculations = 2;
  bool _wasUserCorrected = false;
  String? _originalDetectedFoodName;
  String? _correctedFoodName;
  late Map<String, dynamic> _currentAnalysis;

  int _totalCalories = 0;
  int _totalProtein = 0;
  int _totalCarbs = 0;
  int _totalFat = 0;

  @override
  void initState() {
    super.initState();
    _currentAnalysis = Map<String, dynamic>.from(widget.initialAnalysis);

    final rawFoods = _currentAnalysis['foods'] as List? ?? [];
    _items = rawFoods.map((f) {
      if (f is Map) {
        final cals = (f['calories'] as num?)?.toInt() ?? 0;
        final pro = ((f['protein'] ?? f['proteins'] ?? 0) as num).toInt();
        final carbs = ((f['carbs'] ?? 0) as num).toInt();
        final fat = ((f['fat'] ?? f['fats'] ?? 0) as num).toInt();
        final grams = (f['servingGrams'] ?? f['serving_grams'] as num?)?.toDouble() ?? 100.0;

        return <String, dynamic>{
          'name': (f['name'] ?? 'Food').toString(),
          'baseCalories': cals,
          'baseProtein': pro,
          'baseCarbs': carbs,
          'baseFat': fat,
          'baseGrams': grams,
          'multiplier': 1.0,
          'calories': cals,
          'protein': pro,
          'carbs': carbs,
          'fat': fat,
          'servingGrams': grams,
          'nutritionSource': f['nutritionSource'] ?? f['nutrition_source'],
          'matchedFoodName': f['matchedFoodName'] ?? f['matched_food_name'],
          'isCorrected': false,
        };
      }
      return <String, dynamic>{
        'name': f.toString(),
        'baseCalories': 0,
        'baseProtein': 0,
        'baseCarbs': 0,
        'baseFat': 0,
        'baseGrams': 100.0,
        'multiplier': 1.0,
        'calories': 0,
        'protein': 0,
        'carbs': 0,
        'fat': 0,
        'servingGrams': 100.0,
        'isCorrected': false,
      };
    }).toList();

    String initialName = widget.initialMealName ?? _currentAnalysis['name']?.toString() ?? '';
    if (initialName.isEmpty) {
      if (_items.length == 1) {
        initialName = _items[0]['name'];
      } else if (_items.length > 1) {
        initialName = _buildMealTitleFromItems(_items);
      } else {
        initialName = 'Scanned Meal';
      }
    }
    _mealNameController = TextEditingController(text: initialName);
    _mealNameController.addListener(_notifyEdits);

    _recalculateTotals();
  }

  void _notifyEdits() {
    widget.onEditsChanged?.call(_buildCurrentPayload());
  }

  String _buildMealTitleFromItems(List<Map<String, dynamic>> items) {
    if (items.isEmpty) return 'Meal';
    if (items.length == 1) return items[0]['name'];
    final names = items.map((e) => e['name'].toString()).toList();
    if (names.length <= 2) {
      return names.join(', ');
    }
    return "${names[0]}, ${names[1]} + ${names.length - 2} more";
  }

  void _recalculateTotals() {
    int cals = 0;
    int pro = 0;
    int carbs = 0;
    int fat = 0;

    for (final item in _items) {
      cals += (item['calories'] as int? ?? 0);
      pro += (item['protein'] as int? ?? 0);
      carbs += (item['carbs'] as int? ?? 0);
      fat += (item['fat'] as int? ?? 0);
    }

    setState(() {
      _totalCalories = cals;
      _totalProtein = pro;
      _totalCarbs = carbs;
      _totalFat = fat;
    });

    _notifyEdits();
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
      if (_items.isNotEmpty) {
        _mealNameController.text = _buildMealTitleFromItems(_items);
      }
    });
    _recalculateTotals();
  }

  Future<void> _editItemName(int index) async {
    final currentItem = _items[index];
    final originalName = currentItem['name'].toString();
    final controller = TextEditingController(text: originalName);

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) {
        final remainingRecalculations = _maxRecalculations - _recalculationCount;
        final canRecalculateWithAi = remainingRecalculations > 0;

        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            final theme = Theme.of(dialogCtx);
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.edit_note_rounded, color: Colors.teal),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "Correct Food Item",
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        "Enter the actual food name. You can recalculate nutrition with AI using the original scan image, or keep the name edit only.",
                        style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant, height: 1.35),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: controller,
                        autofocus: true,
                        decoration: InputDecoration(
                          labelText: "Food Name",
                          hintText: "e.g. Fish Rice, Tofu Rice",
                          filled: true,
                          fillColor: theme.brightness == Brightness.dark
                              ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)
                              : Colors.grey.shade50,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        onChanged: (_) => setDialogState(() {}),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            canRecalculateWithAi ? Icons.auto_awesome : Icons.info_outline,
                            size: 14,
                            color: canRecalculateWithAi ? Colors.teal : Colors.grey,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              canRecalculateWithAi
                                  ? "AI Recalculations remaining: $remainingRecalculations/$_maxRecalculations"
                                  : "AI limit reached ($remainingRecalculations/$_maxRecalculations). Manual edit allowed.",
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: canRecalculateWithAi ? Colors.teal.shade800 : Colors.grey.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Wrap(
                          alignment: WrapAlignment.end,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text("Cancel"),
                            ),
                            OutlinedButton(
                              onPressed: () {
                                final trimmed = controller.text.trim();
                                if (trimmed.isNotEmpty) {
                                  Navigator.pop(ctx, {'action': 'keep_only', 'name': trimmed});
                                }
                              },
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              child: const Text("Keep Name Only"),
                            ),
                            ElevatedButton.icon(
                              onPressed: canRecalculateWithAi
                                  ? () {
                                      final trimmed = controller.text.trim();
                                      if (trimmed.isNotEmpty) {
                                        Navigator.pop(ctx, {'action': 'recalculate', 'name': trimmed});
                                      }
                                    }
                                  : null,
                              icon: const Icon(Icons.auto_awesome, size: 16),
                              label: const Text("Recalculate with AI"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.teal,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (result == null) return;

    final action = result['action'] as String;
    final newName = result['name'] as String;

    if (action == 'keep_only') {
      setState(() {
        _items[index]['name'] = newName;
        _items[index]['isCorrected'] = true;
        _wasUserCorrected = true;
        _originalDetectedFoodName ??= originalName;
        _correctedFoodName = newName;
        if (_items.length == 1) {
          _mealNameController.text = newName;
        } else {
          _mealNameController.text = _buildMealTitleFromItems(_items);
        }
      });
      _notifyEdits();
      return;
    }

    if (action == 'recalculate') {
      await _performRecalculation(index: index, originalName: originalName, correctedName: newName);
    }
  }

  Future<Uint8List?> _resolveImageBytes() async {
    if (widget.imageBytes != null && widget.imageBytes!.isNotEmpty) {
      return widget.imageBytes;
    }
    if (widget.imageFile != null && widget.imageFile!.existsSync()) {
      try {
        final bytes = await widget.imageFile!.readAsBytes();
        if (bytes.isNotEmpty) return bytes;
      } catch (e) {
        debugPrint("[ScanResultReview] Error reading imageFile bytes: $e");
      }
    }
    if (widget.imageHash != null && widget.imageHash!.isNotEmpty) {
      final bytes = await LocalFoodImageService.instance.getImageBytes(widget.imageHash!);
      if (bytes != null && bytes.isNotEmpty) {
        return bytes;
      }
    }
    return null;
  }

  Future<void> _performRecalculation({
    required int index,
    required String originalName,
    required String correctedName,
  }) async {
    final imageBytes = await _resolveImageBytes();
    if (imageBytes == null || imageBytes.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Original scan image is no longer available.")),
        );
      }
      return;
    }

    final String imageHash = widget.imageHash ?? ScanFoodCacheService.instance.computeImageHash(imageBytes);
    final previousServingGrams = (_items[index]['servingGrams'] as num?)?.toDouble() ??
        (_items[index]['baseGrams'] as num?)?.toDouble();

    setState(() {
      _isRecalculating = true;
    });

    try {
      // 1. Check local cache with distinct corrected key
      Map<String, dynamic>? analysisData = await ScanFoodCacheService.instance.getCachedAnalysis(
        imageHash,
        dietPreference: widget.dietPreference,
        allergies: widget.allergies,
        correctedFoodName: correctedName,
      );

      // 2. If not cached, call backend recalculate-food endpoint (or mock callback in tests)
      if (analysisData == null) {
        if (widget.recalculateFn != null) {
          analysisData = await widget.recalculateFn!(
            imageBytes: imageBytes,
            correctedFoodName: correctedName,
            previousServingGrams: previousServingGrams,
            userGoal: widget.userGoal,
            calorieTarget: widget.calorieTarget,
            dietPreference: widget.dietPreference,
            allergies: widget.allergies,
          );
        } else {
          analysisData = await AiService.recalculateFoodNutrition(
            imageBytes: imageBytes,
            correctedFoodName: correctedName,
            previousServingGrams: previousServingGrams,
            userGoal: widget.userGoal,
            calorieTarget: widget.calorieTarget,
            dietPreference: widget.dietPreference,
            allergies: widget.allergies,
          );
        }
      }

      // 3. Defense-in-depth: client-side dietary & allergy evaluation
      analysisData = DietPersonalizationService.sanitizeAndEvaluate(
        analysisData,
        dietPreference: widget.dietPreference,
        allergies: widget.allergies,
      );

      // 4. Save to persistent cache under corrected key
      await ScanFoodCacheService.instance.saveAnalysis(
        imageHash,
        analysisData,
        dietPreference: widget.dietPreference,
        allergies: widget.allergies,
        correctedFoodName: correctedName,
      );

      if (!mounted) return;

      // 5. Update items and state while strictly preserving user's authoritative corrected name
      final rawFoods = analysisData['foods'] as List? ?? [];
      Map<String, dynamic>? recalculatedPrimary;
      if (rawFoods.isNotEmpty && rawFoods[0] is Map) {
        recalculatedPrimary = Map<String, dynamic>.from(rawFoods[0] as Map);
      }

      final cals = (recalculatedPrimary?['calories'] as num?)?.toInt() ??
          (analysisData['totalCalories'] as num?)?.toInt() ??
          _items[index]['calories'] as int;
      final pro = ((recalculatedPrimary?['protein'] ?? recalculatedPrimary?['proteins'] ?? analysisData['totalProteins'] ?? 0) as num).toInt();
      final carbs = ((recalculatedPrimary?['carbs'] ?? analysisData['totalCarbs'] ?? 0) as num).toInt();
      final fat = ((recalculatedPrimary?['fat'] ?? recalculatedPrimary?['fats'] ?? analysisData['totalFats'] ?? 0) as num).toInt();
      final grams = (recalculatedPrimary?['servingGrams'] ?? recalculatedPrimary?['serving_grams'] as num?)?.toDouble() ??
          previousServingGrams ?? 100.0;

      setState(() {
        _isRecalculating = false;
        _recalculationCount += 1;
        _wasUserCorrected = true;
        _originalDetectedFoodName ??= originalName;
        _correctedFoodName = correctedName;

        _items[index] = {
          'name': correctedName,
          'baseCalories': cals,
          'baseProtein': pro,
          'baseCarbs': carbs,
          'baseFat': fat,
          'baseGrams': grams,
          'multiplier': 1.0,
          'calories': cals,
          'protein': pro,
          'carbs': carbs,
          'fat': fat,
          'servingGrams': grams,
          'nutritionSource': recalculatedPrimary?['nutritionSource'] ?? 'ai_recalculation',
          'matchedFoodName': recalculatedPrimary?['matchedFoodName'],
          'isCorrected': true,
        };

        _currentAnalysis = {
          ..._currentAnalysis,
          ...analysisData!,
        };

        if (_items.length == 1) {
          _mealNameController.text = correctedName;
        } else {
          _mealNameController.text = _buildMealTitleFromItems(_items);
        }
      });

      _recalculateTotals();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text("Updated nutrition for '$correctedName'")),
              ],
            ),
            backgroundColor: Colors.teal.shade800,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isRecalculating = false;
      });

      // Preserve user corrected name on failure without losing it!
      _showRecalculationFailureDialog(
        index: index,
        originalName: originalName,
        correctedName: correctedName,
        errorMessage: e.toString(),
      );
    }
  }

  void _showRecalculationFailureDialog({
    required int index,
    required String originalName,
    required String correctedName,
    required String errorMessage,
  }) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: Colors.redAccent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Recalculation Failed",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  "Unable to recalculate nutrition right now. Your corrected food name will not be lost.",
                  style: TextStyle(fontSize: 13, height: 1.35, color: theme.colorScheme.onSurface),
                ),
                const SizedBox(height: 8),
                Text(
                  "Food: $correctedName",
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.teal),
                ),
                if (errorMessage.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50.withValues(alpha: theme.brightness == Brightness.dark ? 0.15 : 0.6),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade300.withValues(alpha: 0.5)),
                    ),
                    child: Text(
                      "Details: $errorMessage",
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.brightness == Brightness.dark ? Colors.red.shade200 : Colors.red.shade900,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerRight,
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text("Cancel"),
                      ),
                      OutlinedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          setState(() {
                            _items[index]['name'] = correctedName;
                            _items[index]['isCorrected'] = true;
                            _wasUserCorrected = true;
                            _originalDetectedFoodName ??= originalName;
                            _correctedFoodName = correctedName;
                            if (_items.length == 1) {
                              _mealNameController.text = correctedName;
                            } else {
                              _mealNameController.text = _buildMealTitleFromItems(_items);
                            }
                          });
                          _notifyEdits();
                        },
                        child: const Text("Keep edited name"),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _performRecalculation(
                            index: index,
                            originalName: originalName,
                            correctedName: correctedName,
                          );
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                        child: const Text("Retry"),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Map<String, dynamic> _buildCurrentPayload() {
    final finalFoods = _items.map((item) {
      return {
        'name': item['name'],
        'calories': item['calories'],
        'protein': item['protein'],
        'carbs': item['carbs'],
        'fat': item['fat'],
        'servingGrams': item['servingGrams'],
        if (item['nutritionSource'] != null) 'nutritionSource': item['nutritionSource'],
        if (item['matchedFoodName'] != null) 'matchedFoodName': item['matchedFoodName'],
        if (item['isCorrected'] == true) 'isCorrected': true,
      };
    }).toList();

    return <String, dynamic>{
      'name': _mealNameController.text.trim().isNotEmpty
          ? _mealNameController.text.trim()
          : _buildMealTitleFromItems(_items),
      'mealType': _currentAnalysis['mealType'] ?? 'Meal',
      'foods': finalFoods,
      'calories': _totalCalories,
      'protein': _totalProtein,
      'carbs': _totalCarbs,
      'fat': _totalFat,
      'mealScore': (_currentAnalysis['score'] as num?)?.toInt() ?? 0,
      'scoreExplanation': _currentAnalysis['explanation'] ?? '',
      'healthierAlternatives': List<String>.from(_currentAnalysis['alternatives'] ?? []),
      'dietCompatibility': _currentAnalysis['dietCompatibility'] ?? 'compatible',
      if (_currentAnalysis['dietNotice'] != null) 'dietNotice': _currentAnalysis['dietNotice'],
      if (_currentAnalysis['allergyNotice'] != null) 'allergyNotice': _currentAnalysis['allergyNotice'],
      'source': 'ai_scan',
      'nutritionSource': 'ai_scan',
      // Human-in-the-loop FYP evaluation metadata
      'wasUserCorrected': _wasUserCorrected,
      if (_wasUserCorrected && _originalDetectedFoodName != null)
        'originalDetectedFoodName': _originalDetectedFoodName,
      if (_wasUserCorrected && _correctedFoodName != null)
        'correctedFoodName': _correctedFoodName,
      if (_wasUserCorrected)
        'correctionCount': _recalculationCount,
    };
  }

  Future<void> _handleSave() async {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please keep at least one food item.")),
      );
      return;
    }

    setState(() => _isSaving = true);

    final mealData = _buildCurrentPayload();

    try {
      await widget.onSave(mealData);
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to save meal: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.88,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => Stack(
          children: [
            Column(
              children: [
            // Drag handle
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(10),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.brightness == Brightness.dark
                          ? theme.colorScheme.surfaceContainerHighest
                          : Colors.teal.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: theme.brightness == Brightness.dark
                            ? theme.colorScheme.outlineVariant
                            : Colors.teal.shade200,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.auto_awesome, size: 12, color: theme.colorScheme.primary),
                        const SizedBox(width: 4),
                        Text(
                          "SCAN REVIEW",
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: theme.colorScheme.primary,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.close, color: theme.colorScheme.onSurfaceVariant),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            const Divider(height: 8),

            // Scrollable Content
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                children: [
                  // Photo preview (Preserves entire photo without crop or zoom)
                  if (widget.imageFile != null || widget.imageBytes != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        constraints: const BoxConstraints(maxHeight: 240),
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: widget.imageFile != null
                            ? Image.file(widget.imageFile!, fit: BoxFit.contain)
                            : Image.memory(widget.imageBytes!, fit: BoxFit.contain),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // Instant Cache notice if served from cache
                  if (widget.isCached) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.bolt, color: Colors.blue.shade700, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "Instant match from local scan cache.",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue.shade900,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          if (widget.onReanalyze != null)
                            TextButton(
                              onPressed: () {
                                Navigator.pop(context);
                                widget.onReanalyze!();
                              },
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                "Re-run AI",
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.teal.shade800,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // Editable Meal Name
                  Text(
                    "MEAL NAME",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _mealNameController,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: theme.colorScheme.onSurface),
                    decoration: InputDecoration(
                      hintText: "Meal name",
                      suffixIcon: Icon(Icons.edit, size: 18, color: theme.colorScheme.primary),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerHighest,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Nutrition Summary Banner
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: theme.brightness == Brightness.dark
                          ? theme.colorScheme.surfaceContainerHighest
                          : Colors.teal.shade50,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: theme.brightness == Brightness.dark
                            ? theme.colorScheme.outlineVariant
                            : Colors.teal.shade100,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildMacroColumn("Calories", "$_totalCalories", "kcal", theme.colorScheme.primary),
                        _buildMacroColumn("Protein", "${_totalProtein}g", "", Colors.blueAccent),
                        _buildMacroColumn("Carbs", "${_totalCarbs}g", "", Colors.orangeAccent),
                        _buildMacroColumn("Fat", "${_totalFat}g", "", Colors.redAccent),
                      ],
                    ),
                  ),

                  // Diet Compatibility Notice Card
                  if (_currentAnalysis['dietNotice'] != null &&
                      _currentAnalysis['dietNotice'].toString().trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildDietNoticeCard(
                      theme: theme,
                      notice: _currentAnalysis['dietNotice'].toString(),
                      isCaution: _currentAnalysis['dietCompatibility'] == 'caution',
                    ),
                  ],

                  // Allergy Notice Card
                  if (_currentAnalysis['allergyNotice'] != null &&
                      _currentAnalysis['allergyNotice'].toString().trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildAllergyNoticeCard(
                      theme: theme,
                      notice: _currentAnalysis['allergyNotice'].toString(),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // Detected Items Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "DETECTED FOODS (${_items.length})",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        "Tap item to edit",
                        style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  if (_items.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      alignment: Alignment.center,
                      child: Text(
                        "No foods detected. Tap 'Discard' to scan again.",
                        style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    )
                  else
                    ..._items.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final item = entry.value;
                      final cals = item['calories'] as int;
                      final pro = item['protein'] as int;
                      final carbs = item['carbs'] as int;
                      final fat = item['fat'] as int;
                      final servingGrams = (item['servingGrams'] ?? item['serving_grams'] as num?)?.toDouble() ??
                          (item['baseGrams'] as num?)?.toDouble();
                      final name = item['name'].toString();

                      return Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 10),
                        color: theme.brightness == Brightness.dark
                            ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45)
                            : Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(color: theme.colorScheme.outlineVariant),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: InkWell(
                                      onTap: () => _editItemName(idx),
                                      borderRadius: BorderRadius.circular(6),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              name,
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                                color: theme.colorScheme.onSurface,
                                              ),
                                              maxLines: 3,
                                              softWrap: true,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Icon(Icons.edit_outlined, size: 16, color: theme.colorScheme.onSurfaceVariant),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    "$cals kcal",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                    visualDensity: VisualDensity.compact,
                                    tooltip: "Remove item",
                                    onPressed: () => _removeItem(idx),
                                  ),
                                ],
                              ),
                              if (servingGrams != null && servingGrams > 0) ...[
                                const SizedBox(height: 2),
                                Text(
                                  "Estimated serving: ${servingGrams.toInt()} g",
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 4),
                              Text(
                                "Protein: $pro g • Carbs: $carbs g • Fat: $fat g",
                                style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                              ),
                              if (item['matchedFoodName'] != null &&
                                  item['matchedFoodName'].toString().isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade50.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: Colors.green.shade400.withValues(alpha: 0.4)),
                                  ),
                                  child: Text(
                                    "DB Match: ${item['matchedFoodName']}",
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.greenAccent,
                                    ),
                                  ),
                                ),
                              ],
                              if (item['isCorrected'] == true) ...[
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.teal.shade50.withValues(alpha: theme.brightness == Brightness.dark ? 0.2 : 0.9),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: Colors.teal.shade300),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.auto_awesome, size: 11, color: Colors.teal.shade700),
                                      const SizedBox(width: 4),
                                      Text(
                                        "Updated after your correction",
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.teal.shade800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    }),

                  // Personalization & Dietitian Insight Preview
                  if (_currentAnalysis['explanation'] != null &&
                      _currentAnalysis['explanation'].toString().trim().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.brightness == Brightness.dark
                            ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)
                            : Colors.teal.shade50.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: theme.brightness == Brightness.dark
                              ? theme.colorScheme.outlineVariant
                              : Colors.teal.shade100,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.tips_and_updates_outlined, color: theme.colorScheme.primary, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "AI Nutrition Insight",
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  _currentAnalysis['explanation'].toString(),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: theme.colorScheme.onSurface,
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Healthier Alternatives Preview
                  if (_currentAnalysis['alternatives'] is List &&
                      (_currentAnalysis['alternatives'] as List).isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text(
                      "💡 HEALTHIER ALTERNATIVES",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                        color: Colors.orangeAccent.shade700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ...(_currentAnalysis['alternatives'] as List).map(
                      (alt) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.check_circle_outline, color: Colors.orange, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                alt.toString(),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: theme.colorScheme.onSurface,
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  // Safety disclaimer
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 4),
                    child: Text(
                      "⚠️ AI suggestions may not identify hidden ingredients or cross-contamination.",
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                ],
              ),
            ),

            // Bottom Actions
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: theme.cardColor,
                border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: theme.brightness == Brightness.dark ? 0.2 : 0.05),
                    blurRadius: 6,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: OutlinedButton(
                      onPressed: _isSaving ? null : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: theme.colorScheme.onSurface,
                        side: BorderSide(color: theme.colorScheme.outlineVariant),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text("Discard"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : _handleSave,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.brightness == Brightness.dark ? Colors.black : Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      icon: _isSaving
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                color: theme.brightness == Brightness.dark ? Colors.black : Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.check),
                      label: Text(
                        _isSaving ? "Saving Meal..." : "Save Meal to Diary",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (_isRecalculating)
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: 0.5),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: Colors.teal),
                      const SizedBox(height: 16),
                      Text(
                        "Recalculating with AI...",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Estimating portion & nutrition from image",
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
    );
  }

  Widget _buildMacroColumn(String label, String value, String unit, Color color) {
    return Column(
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
            ),
            if (unit.isNotEmpty)
              Text(
                " $unit",
                style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.8)),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildDietNoticeCard({
    required ThemeData theme,
    required String notice,
    required bool isCaution,
  }) {
    final Color cardBg = isCaution
        ? Colors.amber.shade50.withValues(alpha: theme.brightness == Brightness.dark ? 0.2 : 0.8)
        : Colors.orange.shade50.withValues(alpha: theme.brightness == Brightness.dark ? 0.2 : 0.8);
    final Color borderCol = isCaution ? Colors.amber.shade300 : Colors.orange.shade300;
    final Color iconCol = isCaution ? Colors.amber.shade800 : Colors.orange.shade800;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderCol),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isCaution ? Icons.help_outline_rounded : Icons.info_outline_rounded,
            color: iconCol,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Diet Preference Notice",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isCaution ? Colors.amber.shade900 : Colors.orange.shade900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  notice,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAllergyNoticeCard({
    required ThemeData theme,
    required String notice,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.amber.shade50.withValues(alpha: theme.brightness == Brightness.dark ? 0.2 : 0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade300),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: Colors.amber.shade800,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Allergy Notice",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber.shade900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  notice,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
