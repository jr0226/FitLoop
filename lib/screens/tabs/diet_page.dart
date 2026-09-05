import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/malaysian_food.dart';
import '../../services/food_service.dart';
import '../../services/daily_workout_summary_service.dart';
import '../../widgets/diet/meal_detail_sheet.dart';
import '../../widgets/diet/food_delete_dialog.dart';
import '../../widgets/diet/food_image_display.dart';

// ==========================================
// 8. DIET PAGE (MAIN LOG & DASHBOARD - SYNCED WITH FIREBASE)
// ==========================================
class DietPage extends StatefulWidget {
  const DietPage({super.key});

  @override
  State<DietPage> createState() => _DietPageState();
}

class _DietPageState extends State<DietPage> {
  DateTime _selectedDate = DateTime.now();
  bool _showPercentage = false;

  void _changeDate(int days) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: days));
    });
  }

  Future<void> _deleteFood(String docId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
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

  // --- NEW: POPUP CALENDAR SELECTOR ---
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2023), // Allow going back
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.teal,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String uid = FirebaseAuth.instance.currentUser!.uid;

    DateTime startOfDay = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    DateTime endOfDay = startOfDay.add(const Duration(days: 1));

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        // Make the calendar icon functional
        leading: IconButton(
          icon: const Icon(Icons.calendar_today, color: Colors.teal),
          onPressed: () => _selectDate(context),
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(
                Icons.arrow_back_ios,
                size: 16,
                color: Colors.black,
              ),
              onPressed: () => _changeDate(-1),
            ),
            Text(
              "${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}",
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            IconButton(
              icon: const Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.black,
              ),
              onPressed: () => _changeDate(1),
            ),
          ],
        ),
        centerTitle: true,
      ),

      // Use StreamBuilder to get Target Calories
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .snapshots(),
        builder: (context, userSnapshot) {
          if (!userSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
          int dailyTarget =
              userData?['calorieTarget'] ??
              userData?['dailyCaloriesTarget'] ??
              2000;
          String goal =
              userData?['fitnessGoal'] ??
              userData?['goal'] ??
              "Maintenance (保持)"; // 获取用户目标

          // --- 科学营养素计算逻辑 (MACROS SCIENCE) ---
          double proPercent = 0.3; // 默认比例
          double carbPercent = 0.4;
          double fatPercent = 0.3;

          if (goal.contains("Weight Loss")) {
            proPercent = 0.4; // 减脂期：提高蛋白质比例，保护肌肉
            carbPercent = 0.3;
            fatPercent = 0.3;
          } else if (goal.contains("Muscle Gain")) {
            proPercent = 0.3;
            carbPercent = 0.5; // 增肌期：高碳水提供训练能量
            fatPercent = 0.2;
          }

          // 计算克数 (Grams) = (总卡路里 * 比例) / 每克卡路里
          double targetPro = (dailyTarget * proPercent) / 4;
          double targetCarbs = (dailyTarget * carbPercent) / 4;
          double targetFat = (dailyTarget * fatPercent) / 9;
          // ------------------------------------------
          // Stream unified workout logs (FitLoop + Health Connect) for the selected day
          return StreamBuilder<int>(
            stream: DailyWorkoutSummaryService.streamDailyUnifiedExerciseCalories(
              uid,
              _selectedDate,
            ),
            builder: (context, workoutSnapshot) {
              final int exerciseBurn = workoutSnapshot.data ?? 0;

              // Use StreamBuilder to get Food Logs for the specific day
              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(uid)
                    .collection('food_logs')
                    .where('timestamp', isGreaterThanOrEqualTo: startOfDay)
                    .where('timestamp', isLessThan: endOfDay)
                    .orderBy('timestamp', descending: true)
                    .snapshots(),
                builder: (context, foodSnapshot) {
                  if (foodSnapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  // Calculate dynamic totals from Firebase
                  int foodEaten = 0;
                  int totalPro = 0;
                  int totalCarbs = 0;
                  int totalFat = 0;
                  List<Map<String, dynamic>> loggedMeals = [];

                  if (foodSnapshot.hasData && foodSnapshot.data!.docs.isNotEmpty) {
                    for (var doc in foodSnapshot.data!.docs) {
                      var data = doc.data() as Map<String, dynamic>;
                      final itemWithId = Map<String, dynamic>.from(data)..['id'] = doc.id;
                      loggedMeals.add(itemWithId);
                      foodEaten += (data['calories'] as num?)?.toInt() ?? 0;
                      totalPro +=
                          ((data['protein'] ?? data['proteins'] ?? 0) as num)
                              .toInt();
                      totalCarbs += ((data['carbs'] ?? 0) as num).toInt();
                      totalFat += ((data['fat'] ?? data['fats'] ?? 0) as num)
                          .toInt();
                    }
                  }

                  int remaining = dailyTarget - foodEaten + exerciseBurn;

                  return SingleChildScrollView(
                    child: Column(
                      children: [
                        // 1. SUMMARY CARD
                        Container(
                          margin: const EdgeInsets.all(16),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(
                                  alpha: Theme.of(context).brightness == Brightness.dark ? 0.25 : 0.04,
                                ),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    _buildMathColumn("Goal", "$dailyTarget"),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 4),
                                      child: Text(
                                        "-",
                                        style: TextStyle(
                                          fontSize: 20,
                                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                    _buildMathColumn("Food", "$foodEaten"),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 4),
                                      child: Text(
                                        "+",
                                        style: TextStyle(
                                          fontSize: 20,
                                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                    _buildMathColumn("Exercise", "$exerciseBurn"),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 4),
                                      child: Text(
                                        "=",
                                        style: TextStyle(
                                          fontSize: 20,
                                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                    _buildMathColumn(
                                      "Remaining",
                                      "$remaining",
                                      isBold: true,
                                      color: remaining < 0
                                          ? Colors.redAccent
                                          : Theme.of(context).colorScheme.primary,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),
                              const Divider(),
                              const SizedBox(height: 10),

                          InkWell(
                            onTap: () => setState(
                              () => _showPercentage = !_showPercentage,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Mock targets for macros based on standard 2000kcal diet (can be made dynamic later)
                                _buildMacroBar(
                                  "Protein",
                                  totalPro.toDouble(),
                                  targetPro,
                                  Colors.purple,
                                ),
                                _buildMacroBar(
                                  "Carbs",
                                  totalCarbs.toDouble(),
                                  targetCarbs,
                                  Colors.orange,
                                ),
                                _buildMacroBar(
                                  "Fat",
                                  totalFat.toDouble(),
                                  targetFat,
                                  Colors.blue,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 5),
                          const Center(
                            child: Text(
                              "Tap bars to toggle %",
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 2. REAL FIREBASE MEALS LIST
                    _buildMealBucket("Logged Meals", loggedMeals),
                    const SizedBox(height: 40),
                  ],
                ),
              );
            },
          );
        },
      );
    },
  ),
);
}

  Widget _buildMathColumn(
    String label,
    String value, {
    bool isBold = false,
    Color? color,
  }) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 5),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: color ?? (isBold ? theme.colorScheme.primary : theme.colorScheme.onSurface),
          ),
        ),
      ],
    );
  }

  Widget _buildMacroBar(
    String label,
    double current,
    double target,
    Color color,
  ) {
    final theme = Theme.of(context);
    double progress = current / target;
    if (progress > 1) progress = 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
        ),
        const SizedBox(height: 5),
        SizedBox(
          width: 90,
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: color.withValues(alpha: 0.15),
            color: color,
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          _showPercentage
              ? "${(progress * 100).toInt()}%"
              : "${(target - current).toInt()}g left",
          style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _buildMealBucket(String title, List<Map<String, dynamic>> items) {
    final theme = Theme.of(context);
    double bucketCals = items.fold(
      0.0,
      (runningTotal, item) =>
          runningTotal + ((item['calories'] as num?)?.toDouble() ?? 0.0),
    );

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                Text(
                  "${bucketCals.toInt()} kcal",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                "No meals logged yet today.",
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),

          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final int itemCals = (item['calories'] as num?)?.toInt() ?? 0;
              final int itemPro =
                  ((item['protein'] ?? item['proteins'] ?? 0) as num).toInt();
              final int score =
                  ((item['mealScore'] ?? item['score'] ?? 0) as num).toInt();
              final Color scoreColor = score >= 80
                  ? Colors.green
                  : (score >= 50 ? Colors.orange : Colors.redAccent);

              final String sourceStr = (item['nutritionSource'] ?? item['source'])
                      ?.toString()
                      .toLowerCase() ??
                  '';
              final bool isAiScan = sourceStr.contains('ai') || score > 0;
              final bool isMalaysian = sourceStr.contains('malaysian') ||
                  sourceStr.contains('myfcd') ||
                  sourceStr == 'manual';

              final String? imageHash = item['imageHash']?.toString();
              final String? imageUrl = item['imageUrl']?.toString();
              final bool hasImage = (imageHash != null && imageHash.isNotEmpty) ||
                  (imageUrl != null && imageUrl.isNotEmpty);

              final defaultAvatar = CircleAvatar(
                radius: 18,
                backgroundColor: isMalaysian
                    ? Colors.green.shade50
                    : (isAiScan
                        ? Colors.teal.shade50
                        : Colors.orange.shade50),
                child: Icon(
                  isMalaysian
                      ? Icons.verified
                      : (isAiScan
                          ? Icons.auto_awesome
                          : Icons.restaurant),
                  color: isMalaysian
                      ? Colors.green.shade700
                      : (isAiScan ? Colors.teal : Colors.orange),
                  size: 18,
                ),
              );

              return ListTile(
                leading: hasImage
                    ? FoodImageDisplay(
                        imageHash: imageHash,
                        imageUrl: imageUrl,
                        width: 36,
                        height: 36,
                        borderRadius: BorderRadius.circular(18),
                        fit: BoxFit.cover,
                        placeholder: defaultAvatar,
                        errorWidget: defaultAvatar,
                      )
                    : defaultAvatar,
                title: Text(
                  item['name'] ?? 'Unknown',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text("$itemCals kcal • Pro: ${itemPro}g"),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (score > 0) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: scoreColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          "$score",
                          style: TextStyle(
                            color: scoreColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                    ],
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        color: Colors.grey,
                        size: 20,
                      ),
                      tooltip: "Delete Meal",
                      onPressed: () async {
                        if (item['id'] != null) {
                          final confirmed = await showFoodDeleteConfirmationDialog(
                            context,
                            foodName: item['name']?.toString() ?? 'Meal',
                          );
                          if (confirmed && mounted) {
                            _deleteFood(item['id'] as String);
                          }
                        }
                      },
                    ),
                  ],
                ),
                onTap: () {
                  MealDetailSheet.show(
                    context,
                    meal: item,
                    onDelete: item['id'] != null
                        ? () => _deleteFood(item['id'] as String)
                        : null,
                  );
                },
              );
            },
          ),

          InkWell(
            // We use standard navigation so it doesn't crash.
            // In a real app, this Add Food page should also save to Firebase.
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AddFoodPage(
                  mealCategory: "Meal",
                  selectedDate: _selectedDate, // 👈 加上这个，告诉它存到哪一天
                ),
              ),
            ),
            child: Container(
              padding: const EdgeInsets.all(16),
              alignment: Alignment.centerLeft,
              child: const Row(
                children: [
                  Icon(Icons.add, color: Colors.teal),
                  SizedBox(width: 8),
                  Text(
                    "MANUAL ADD",
                    style: TextStyle(
                      color: Colors.teal,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// NEW PAGE: ADD FOOD INTERFACE (MALAYSIAN FOOD DATABASE)
// ==========================================
class AddFoodPage extends StatefulWidget {
  final String mealCategory;
  final DateTime selectedDate;

  const AddFoodPage({
    super.key,
    required this.mealCategory,
    required this.selectedDate,
  });

  @override
  State<AddFoodPage> createState() => _AddFoodPageState();
}

class _AddFoodPageState extends State<AddFoodPage> {
  final TextEditingController _searchCtrl = TextEditingController();
  List<MalaysianFood> _allFoods = [];
  List<MalaysianFood> _searchResults = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onSearchChanged);
    _loadFoods();
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_onSearchChanged);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchCtrl.text;
    setState(() {
      _searchResults = FoodService.searchLocalFoods(query, dataset: _allFoods);
    });
  }

  Future<void> _loadFoods({bool forceRefresh = false}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final foods = await FoodService.fetchMalaysianFoods(forceRefresh: forceRefresh);
      if (!mounted) return;
      setState(() {
        _allFoods = foods;
        _searchResults = FoodService.searchLocalFoods(_searchCtrl.text, dataset: foods);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = "Unable to load the food database. Check your connection and try again.";
      });
    }
  }

  void _showConfirmAddSheet(MalaysianFood food) {
    String selectedMeal = widget.mealCategory;
    final validCategories = ['Breakfast', 'Lunch', 'Dinner', 'Snack', 'Meal'];
    if (!validCategories.contains(selectedMeal)) {
      selectedMeal = 'Meal';
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 16,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.outlineVariant,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Food Title & Category
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  food.name,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                  softWrap: true,
                                ),
                                if (food.nameMs.isNotEmpty && food.nameMs != food.name) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    food.nameMs,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontStyle: FontStyle.italic,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
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
                            child: Text(
                              food.category,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Serving Info Banner
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: theme.colorScheme.outlineVariant),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.restaurant_menu, size: 18, color: theme.colorScheme.primary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                "Standard Serving: ${food.servingName} (${food.servingGrams.toInt()} g)",
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Nutritional Breakdown Grid
                      Row(
                        children: [
                          Expanded(
                            child: _buildNutrientTile(
                              "Calories",
                              "${food.servingCalories} kcal",
                              Colors.teal,
                              isPrimary: true,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildNutrientTile(
                              "Protein",
                              "${food.servingProtein} g",
                              Colors.purple,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildNutrientTile(
                              "Carbs",
                              "${food.servingCarbs} g",
                              Colors.orange,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildNutrientTile(
                              "Fat",
                              "${food.servingFat} g",
                              Colors.blue,
                            ),
                          ),
                        ],
                      ),

                      if (food.servingFibre > 0 || food.servingSodium > 0 || food.servingSugar > 0) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 12,
                          runSpacing: 4,
                          children: [
                            if (food.servingFibre > 0)
                              Text("Fibre: ${food.servingFibre}g", style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
                            if (food.servingSugar > 0)
                              Text("Sugar: ${food.servingSugar}g", style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
                            if (food.servingSodium > 0)
                              Text("Sodium: ${food.servingSodium}mg", style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
                          ],
                        ),
                      ],

                      const SizedBox(height: 20),
                      Text(
                        "Meal Category",
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: validCategories.map((cat) {
                          final isSelected = selectedMeal == cat;
                          return ChoiceChip(
                            label: Text(cat),
                            selected: isSelected,
                            onSelected: (selected) {
                              if (selected) {
                                setSheetState(() => selectedMeal = cat);
                              }
                            },
                            selectedColor: theme.colorScheme.primary,
                            labelStyle: TextStyle(
                              color: isSelected
                                  ? (theme.brightness == Brightness.dark ? Colors.black : Colors.white)
                                  : theme.colorScheme.onSurface,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              fontSize: 12,
                            ),
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.check_circle_outline, size: 20),
                          label: const Text("Log Meal to Diary", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: theme.brightness == Brightness.dark ? Colors.black : Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: () => _saveMealToFirebase(food, selectedMeal),
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
  }

  Widget _buildNutrientTile(String label, String value, Color color, {bool isPrimary = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: isPrimary ? 14 : 13,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveMealToFirebase(MalaysianFood food, String mealType) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    Navigator.pop(context); // Close bottom sheet

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => const Center(
        child: CircularProgressIndicator(color: Colors.teal),
      ),
    );

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('food_logs')
          .add({
            'name': food.name,
            'mealType': mealType,
            'foods': [
              {
                'name': food.name,
                'calories': food.servingCalories,
                'protein': food.servingProtein,
                'carbs': food.servingCarbs,
                'fat': food.servingFat,
                'servingGrams': food.servingGrams,
                'servingName': food.servingName,
              },
            ],
            'calories': food.servingCalories,
            'protein': food.servingProtein,
            'carbs': food.servingCarbs,
            'fat': food.servingFat,
            'source': 'malaysian_database',
            'nutritionSource': 'malaysian_database',
            'timestamp': Timestamp.fromDate(widget.selectedDate),
            'createdAt': FieldValue.serverTimestamp(),
          });

      if (!mounted) return;
      Navigator.pop(context); // Dismiss loading dialog
      Navigator.pop(context); // Return to DietPage
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("${food.name} added to diary!"),
          backgroundColor: Colors.teal,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Dismiss loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error saving meal: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          "Malaysian Food Database",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: "Refresh Database",
            onPressed: () => _loadFoods(forceRefresh: true),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Box
          Container(
            color: theme.cardColor,
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: "Search food (e.g. Nasi Lemak, Roti Canai, Laksa)",
                prefixIcon: Icon(Icons.search, color: theme.colorScheme.primary),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => _searchCtrl.clear(),
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),

          // Main Content States
          Expanded(
            child: _buildBodyContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildBodyContent() {
    final theme = Theme.of(context);
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              "Loading Malaysian food database...",
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 14),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cloud_off_rounded, size: 64, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 14),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text("Retry"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.brightness == Brightness.dark ? Colors.black : Colors.white,
                ),
                onPressed: () => _loadFoods(forceRefresh: true),
              ),
            ],
          ),
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, size: 56, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              "No matching Malaysian food found.",
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 15),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final food = _searchResults[index];
        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
          color: theme.cardColor,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => _showConfirmAddSheet(food),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: theme.brightness == Brightness.dark
                          ? theme.colorScheme.surfaceContainerHighest
                          : Colors.teal.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.restaurant, color: theme.colorScheme.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          food.name,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: theme.colorScheme.onSurface,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (food.nameMs.isNotEmpty && food.nameMs != food.name) ...[
                          const SizedBox(height: 1),
                          Text(
                            food.nameMs,
                            style: TextStyle(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 4),
                        Text(
                          "${food.servingName} • ${food.servingGrams.toInt()} g",
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 8,
                          children: [
                            Text(
                              "${food.servingCalories} kcal",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            Text(
                              "P: ${food.servingProtein}g  C: ${food.servingCarbs}g  F: ${food.servingFat}g",
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.add_circle, color: theme.colorScheme.primary, size: 28),
                    tooltip: "Add Food",
                    onPressed: () => _showConfirmAddSheet(food),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
