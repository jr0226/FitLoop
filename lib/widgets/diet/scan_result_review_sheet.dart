import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';

class ScanResultReviewSheet extends StatefulWidget {
  final File? imageFile;
  final Uint8List? imageBytes;
  final Map<String, dynamic> initialAnalysis;
  final String? initialMealName;
  final bool isCached;
  final VoidCallback? onReanalyze;
  final Function(Map<String, dynamic> currentEdits)? onEditsChanged;
  final Future<void> Function(Map<String, dynamic> finalMealData) onSave;

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
  });

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

  int _totalCalories = 0;
  int _totalProtein = 0;
  int _totalCarbs = 0;
  int _totalFat = 0;

  @override
  void initState() {
    super.initState();

    final rawFoods = widget.initialAnalysis['foods'] as List? ?? [];
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
      };
    }).toList();

    String initialName = widget.initialMealName ?? widget.initialAnalysis['name']?.toString() ?? '';
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
    final controller = TextEditingController(text: _items[index]['name']);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Rename Item", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: "Enter food name",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
            child: const Text("Update"),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty) {
      setState(() {
        _items[index]['name'] = newName;
      });
    }
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
      };
    }).toList();

    return <String, dynamic>{
      'name': _mealNameController.text.trim().isNotEmpty
          ? _mealNameController.text.trim()
          : _buildMealTitleFromItems(_items),
      'mealType': widget.initialAnalysis['mealType'] ?? 'Meal',
      'foods': finalFoods,
      'calories': _totalCalories,
      'protein': _totalProtein,
      'carbs': _totalCarbs,
      'fat': _totalFat,
      'mealScore': (widget.initialAnalysis['score'] as num?)?.toInt() ?? 0,
      'scoreExplanation': widget.initialAnalysis['explanation'] ?? '',
      'healthierAlternatives': List<String>.from(widget.initialAnalysis['alternatives'] ?? []),
      'source': 'ai_scan',
      'nutritionSource': 'ai_scan',
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
        builder: (context, scrollController) => Column(
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
                            ],
                          ),
                        ),
                      );
                    }),

                  const SizedBox(height: 20),
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
}
