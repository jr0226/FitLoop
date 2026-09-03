import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'food_delete_dialog.dart';
import 'food_image_display.dart';

class MealDetailSheet extends StatelessWidget {
  final Map<String, dynamic> meal;
  final VoidCallback? onDelete;

  const MealDetailSheet({
    super.key,
    required this.meal,
    this.onDelete,
  });

  static Future<void> show(
    BuildContext context, {
    required Map<String, dynamic> meal,
    VoidCallback? onDelete,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => MealDetailSheet(
        meal: meal,
        onDelete: onDelete,
      ),
    );
  }

  String _formatTimestamp(dynamic ts) {
    if (ts == null) return '';
    if (ts is Timestamp) {
      return DateFormat('MMM d, yyyy • h:mm a').format(ts.toDate());
    } else if (ts is DateTime) {
      return DateFormat('MMM d, yyyy • h:mm a').format(ts);
    } else if (ts is String) {
      try {
        final dt = DateTime.parse(ts);
        return DateFormat('MMM d, yyyy • h:mm a').format(dt);
      } catch (_) {
        return ts;
      }
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final String name = (meal['name'] ?? meal['foodName'])?.toString() ?? 'Meal';
    final String mealType = meal['mealType']?.toString() ?? 'Meal';
    final String timeStr = _formatTimestamp(meal['timestamp'] ?? meal['createdAt']);
    final String source = (meal['nutritionSource'] ?? meal['source'])?.toString().toLowerCase() ?? '';

    final int calories = (meal['calories'] as num?)?.toInt() ?? 0;
    final int protein = ((meal['protein'] ?? meal['proteins'] ?? 0) as num).toInt();
    final int carbs = ((meal['carbs'] ?? 0) as num).toInt();
    final int fat = ((meal['fat'] ?? meal['fats'] ?? 0) as num).toInt();

    final num? fibre = meal['fibre'] ?? meal['fiber'] as num?;
    final num? sugar = meal['sugar'] as num?;
    final num? sodium = meal['sodium'] as num?;

    final int score = ((meal['mealScore'] ?? meal['score'] ?? 0) as num).toInt();
    final String explanation = (meal['scoreExplanation'] ?? meal['explanation'] ?? meal['personalizedAdvice'] ?? meal['advice'] ?? '').toString().trim();
    final List<dynamic> alternatives = (meal['healthierAlternatives'] ?? meal['alternatives'] as List?) ?? [];
    final List<dynamic> foods = (meal['foods'] as List?) ?? [];

    final bool isMalaysianSource = source.contains('malaysian') || source.contains('myfcd') || source == 'manual';
    final bool isAiScan = !isMalaysianSource && (source.contains('ai') || source.contains('scan') || score > 0 || explanation.isNotEmpty || alternatives.isNotEmpty);

    final Color scoreColor = score >= 80
        ? Colors.green
        : (score >= 50 ? Colors.orange : Colors.redAccent);

    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.45,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            // Drag Handle
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(10),
              ),
            ),

            // Sheet Header with Title & Action Buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _buildSourceBadge(isAiScan: isAiScan, isMalaysian: isMalaysianSource, source: source),
                            if (mealType.isNotEmpty && mealType.toLowerCase() != 'meal')
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: theme.colorScheme.outlineVariant),
                                ),
                                child: Text(
                                  mealType.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: theme.colorScheme.onSurfaceVariant,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          name,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                          maxLines: 4,
                          softWrap: true,
                        ),
                        if (timeStr.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            timeStr,
                            style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (score > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: scoreColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: scoreColor.withValues(alpha: 0.35)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.auto_awesome, color: scoreColor, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            "$score/100",
                            style: TextStyle(
                              color: scoreColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  IconButton(
                    icon: Icon(Icons.close, color: theme.colorScheme.onSurfaceVariant),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 16),

            // Scrollable Content
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                children: [
                  // 0. SCANNED FOOD IMAGE BANNER (When available via local hash or legacy url)
                  if ((meal['imageHash'] != null && meal['imageHash'].toString().isNotEmpty) ||
                      (meal['imageUrl'] != null && meal['imageUrl'].toString().isNotEmpty)) ...[
                    _buildMealImageBanner(
                      imageHash: meal['imageHash']?.toString(),
                      imageUrl: meal['imageUrl']?.toString(),
                    ),
                  ],

                  // 1. PRIMARY NUTRITION HERO CARD
                  _buildNutritionHeroCard(
                    calories: calories,
                    protein: protein,
                    carbs: carbs,
                    fat: fat,
                    fibre: fibre,
                    sugar: sugar,
                    sodium: sodium,
                  ),

                  const SizedBox(height: 14),

                  // NUTRITION SOURCE & TRANSPARENCY CARD
                  _buildNutritionSourceCard(
                    isMalaysian: isMalaysianSource,
                    isAiScan: isAiScan,
                    source: source,
                    theme: theme,
                  ),

                  const SizedBox(height: 18),

                  // 2. AI INSIGHTS & EXPLANATION (Only when available)
                  if (explanation.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.brightness == Brightness.dark
                            ? theme.colorScheme.surfaceContainerHighest
                            : Colors.teal.shade50.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: theme.brightness == Brightness.dark
                              ? theme.colorScheme.outlineVariant
                              : Colors.teal.shade100,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.tips_and_updates_outlined, color: theme.colorScheme.primary, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Dietitian Insight",
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  explanation,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: theme.colorScheme.onSurface,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],

                  // 3. INDIVIDUAL FOOD ITEMS BREAKDOWN
                  if (foods.isNotEmpty) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          foods.length > 1
                              ? "DETECTED ITEMS (${foods.length})"
                              : "NUTRITION BREAKDOWN",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ...foods.map((item) => _buildFoodItemCard(context, item)),
                    const SizedBox(height: 18),
                  ],

                  // 4. HEALTHIER ALTERNATIVES (If present)
                  if (alternatives.isNotEmpty) ...[
                    const Text(
                      "💡 HEALTHIER ALTERNATIVES",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                        color: Colors.orangeAccent,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ...alternatives.map(
                      (alt) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.check_circle, color: Colors.orange, size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                alt.toString(),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: theme.colorScheme.onSurface,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],

                  // 5. DELETE MEAL ACTION (If callback supplied)
                  if (onDelete != null) ...[
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final confirmed = await showFoodDeleteConfirmationDialog(
                          context,
                          foodName: name,
                        );
                        if (confirmed && context.mounted) {
                          Navigator.pop(context);
                          onDelete!();
                        }
                      },
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                      label: const Text(
                        "Delete Meal from Diary",
                        style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.redAccent.shade100),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceBadge({
    required bool isAiScan,
    required bool isMalaysian,
    required String source,
  }) {
    if (isMalaysian) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.green.shade200),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.verified, size: 10, color: Colors.green.shade700),
              const SizedBox(width: 4),
              Text(
                "MALAYSIAN DB",
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.green.shade800),
              ),
            ],
          ),
        ),
      );
    }

    if (isAiScan) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.teal.shade50,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.teal.shade200),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_awesome, size: 10, color: Colors.teal.shade700),
              const SizedBox(width: 4),
              Text(
                "AI SCAN",
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.teal.shade800),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Text(
        "MANUAL ENTRY",
        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.grey.shade700),
      ),
    );
  }

  Widget _buildNutritionSourceCard({
    required bool isMalaysian,
    required bool isAiScan,
    required String source,
    required ThemeData theme,
  }) {
    final bool isDark = theme.brightness == Brightness.dark;

    final String title = isMalaysian
        ? "Nutrition Source: Malaysian Food Database"
        : (isAiScan ? "Nutrition Source: AI Image Estimate" : "Nutrition Source: Manual Entry");

    final String badgeText = isMalaysian
        ? "MALAYSIAN DB"
        : (isAiScan ? "AI SCAN" : "MANUAL");

    final Color badgeBg = isMalaysian
        ? (isDark ? Colors.green.shade900.withValues(alpha: 0.5) : Colors.green.shade50)
        : (isAiScan
            ? (isDark ? Colors.teal.shade900.withValues(alpha: 0.5) : Colors.teal.shade50)
            : (isDark ? Colors.grey.shade900 : Colors.grey.shade100));

    final Color badgeBorder = isMalaysian
        ? (isDark ? Colors.green.shade700 : Colors.green.shade200)
        : (isAiScan
            ? (isDark ? Colors.teal.shade700 : Colors.teal.shade200)
            : (isDark ? Colors.grey.shade700 : Colors.grey.shade300));

    final Color badgeColor = isMalaysian
        ? (isDark ? Colors.green.shade300 : Colors.green.shade800)
        : (isAiScan
            ? (isDark ? Colors.teal.shade300 : Colors.teal.shade800)
            : (isDark ? Colors.grey.shade300 : Colors.grey.shade700));

    final IconData icon = isMalaysian
        ? Icons.verified_rounded
        : (isAiScan ? Icons.auto_awesome_rounded : Icons.edit_note_rounded);

    final String description = isMalaysian
        ? "Nutritional reference calculated from the Malaysian Food Database per-100g composition. Values reflect a standardized reference serving and may differ from visual portion estimates."
        : (isAiScan
            ? "Nutritional values estimated from meal photo using Gemini 3.8 visual recognition and portion analysis. Values reflect the detected portion size on the plate and may differ from standardized database reference portions."
            : "User-entered nutritional reference values.");

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4)
            : (isMalaysian
                ? Colors.green.shade50.withValues(alpha: 0.35)
                : (isAiScan
                    ? Colors.teal.shade50.withValues(alpha: 0.35)
                    : Colors.grey.shade50)),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? theme.colorScheme.outlineVariant
              : (isMalaysian
                  ? Colors.green.shade100
                  : (isAiScan ? Colors.teal.shade100 : Colors.grey.shade200)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: badgeColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: badgeBorder),
                ),
                child: Text(
                  badgeText,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: badgeColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            description,
            style: TextStyle(
              fontSize: 11.5,
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Icon(
                  Icons.info_outline_rounded,
                  size: 11,
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  "Informational nutrition estimate. Not intended as medical or clinical dietary advice.",
                  style: TextStyle(
                    fontSize: 10,
                    fontStyle: FontStyle.italic,
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNutritionHeroCard({
    required int calories,
    required int protein,
    required int carbs,
    required int fat,
    num? fibre,
    num? sugar,
    num? sodium,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.teal.shade800, Colors.teal.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.teal.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "TOTAL ENERGY",
                      style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "$calories",
                      style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  "KILOCALORIES",
                  style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                _buildHeroMacroPill("Protein", "${protein}g", Colors.purpleAccent),
                _buildHeroMacroPill("Carbs", "${carbs}g", Colors.orangeAccent),
                _buildHeroMacroPill("Fat", "${fat}g", Colors.lightBlueAccent),
              ],
            ),
          ),
          if ((fibre != null && fibre > 0) || (sugar != null && sugar > 0) || (sodium != null && sodium > 0)) ...[
            const SizedBox(height: 10),
            Wrap(
              alignment: WrapAlignment.spaceAround,
              spacing: 8,
              runSpacing: 4,
              children: [
                if (fibre != null && fibre > 0)
                  _buildMicroLabel("Fibre", "${fibre.toStringAsFixed(1)}g"),
                if (sugar != null && sugar > 0)
                  _buildMicroLabel("Sugar", "${sugar.toStringAsFixed(1)}g"),
                if (sodium != null && sodium > 0)
                  _buildMicroLabel("Sodium", "${sodium.toInt()}mg"),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeroMacroPill(String title, String value, Color accentColor) {
    return Expanded(
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(color: accentColor, shape: BoxShape.circle),
                ),
                const SizedBox(width: 4),
                Text(
                  title,
                  style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMicroLabel(String title, String value) {
    return Text(
      "$title: $value",
      style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500),
    );
  }

  Widget _buildFoodItemCard(BuildContext context, dynamic item) {
    final theme = Theme.of(context);
    if (item is! Map) {
      return Card(
        elevation: 0,
        color: theme.colorScheme.surfaceContainerHighest,
        margin: const EdgeInsets.only(bottom: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ListTile(
          title: Text(
            item.toString(),
            style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
          ),
        ),
      );
    }

    final String itemName = (item['name'] ?? 'Item').toString();
    final int itemCals = (item['calories'] as num?)?.toInt() ?? 0;
    final int itemPro = ((item['protein'] ?? item['proteins'] ?? 0) as num).toInt();
    final int itemCarbs = ((item['carbs'] ?? 0) as num).toInt();
    final int itemFat = ((item['fat'] ?? item['fats'] ?? 0) as num).toInt();

    final String? matchedName = item['matchedFoodName'] ?? item['matched_food_name'];
    final num? matchScore = item['matchScore'] ?? item['match_score'];
    final String? nutritionSource = item['nutritionSource'] ?? item['nutrition_source'];
    final num? servingGrams = item['servingGrams'] ?? item['serving_grams'];

    final bool isMyFCD = (nutritionSource ?? '').toLowerCase().contains('malaysian') ||
        (nutritionSource ?? '').toLowerCase().contains('myfcd');

    return Card(
      elevation: 0,
      color: theme.cardColor,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: theme.brightness == Brightness.dark
                      ? theme.colorScheme.surfaceContainerHighest
                      : (isMyFCD ? Colors.green.shade50 : Colors.teal.shade50),
                  child: Icon(
                    isMyFCD ? Icons.verified : Icons.restaurant,
                    color: isMyFCD ? (theme.brightness == Brightness.dark ? Colors.greenAccent : Colors.green.shade700) : theme.colorScheme.primary,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        itemName,
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: theme.colorScheme.onSurface),
                        maxLines: 3,
                        softWrap: true,
                      ),
                      if (servingGrams != null && servingGrams > 0) ...[
                        const SizedBox(height: 2),
                        Text(
                          "Serving size: ${servingGrams.toInt()}g",
                          style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  "$itemCals kcal",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Nutrition breakdown pills
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                _buildMacroChip("Pro", "${itemPro}g", Colors.purple),
                _buildMacroChip("Carb", "${itemCarbs}g", Colors.orange),
                _buildMacroChip("Fat", "${itemFat}g", Colors.blue),
                if (nutritionSource != null && nutritionSource.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isMyFCD ? Colors.green.shade50 : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: isMyFCD ? Colors.green.shade200 : Colors.grey.shade300),
                    ),
                    child: Text(
                      isMyFCD ? "Malaysian DB" : nutritionSource,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isMyFCD ? Colors.green.shade800 : Colors.grey.shade700,
                      ),
                    ),
                  ),
              ],
            ),
            if (matchedName != null && matchedName.isNotEmpty && matchedName.toLowerCase() != itemName.toLowerCase()) ...[
              const SizedBox(height: 6),
              Text(
                "Matched: $matchedName ${matchScore != null ? '(${(matchScore * 100).toInt()}%)' : ''}",
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMacroChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        "$label: $value",
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }

  Widget _buildMealImageBanner({String? imageHash, String? imageUrl}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      constraints: const BoxConstraints(maxHeight: 250),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: FoodImageDisplay(
        imageHash: imageHash,
        imageUrl: imageUrl,
        borderRadius: BorderRadius.circular(18),
        fit: BoxFit.contain,
        errorWidget: Container(
          color: Colors.grey.shade100,
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.broken_image_outlined, color: Colors.grey.shade400, size: 24),
              const SizedBox(width: 8),
              Text(
                "Image unavailable",
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

