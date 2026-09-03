/// Model representing a standardized Malaysian food entry from the Malaysian Food Database.
///
/// Note on Nutritional Values:
/// [caloriesKcal], [proteinG], [fatG], [carbsG], etc. represent density **per 100 grams**.
/// The computed getters ([servingCalories], [servingProtein], [servingFat], [servingCarbs])
/// calculate total nutrients for the standard [servingGrams] and [servingName].
class MalaysianFood {
  final int id;
  final String sourceId;
  final String name;
  final String nameMs;
  final String category;
  final double caloriesKcal; // per 100g
  final double proteinG;     // per 100g
  final double fatG;         // per 100g
  final double carbsG;       // per 100g
  final double fibreG;       // per 100g
  final double sugarG;       // per 100g
  final double sodiumMg;     // per 100g
  final String servingName;  // e.g. "1 plate", "1 piece", "1 bowl"
  final double servingGrams; // e.g. 250.0
  final String? sourceName;
  final String? sourceUrl;
  final String? sourcePublishedDate;

  const MalaysianFood({
    required this.id,
    required this.sourceId,
    required this.name,
    this.nameMs = '',
    this.category = 'General',
    required this.caloriesKcal,
    required this.proteinG,
    required this.fatG,
    required this.carbsG,
    this.fibreG = 0.0,
    this.sugarG = 0.0,
    this.sodiumMg = 0.0,
    this.servingName = '1 serving',
    this.servingGrams = 100.0,
    this.sourceName,
    this.sourceUrl,
    this.sourcePublishedDate,
  });

  /// Multiplier to convert 100g density to the listed standard serving size.
  double get servingMultiplier => (servingGrams > 0 ? servingGrams : 100.0) / 100.0;

  /// Total calories in the standard serving (kcal).
  int get servingCalories => (caloriesKcal * servingMultiplier).round();

  /// Total protein in the standard serving (g).
  int get servingProtein => (proteinG * servingMultiplier).round();

  /// Total fat in the standard serving (g).
  int get servingFat => (fatG * servingMultiplier).round();

  /// Total carbohydrates in the standard serving (g).
  int get servingCarbs => (carbsG * servingMultiplier).round();

  /// Total dietary fibre in the standard serving (g).
  double get servingFibre => double.parse((fibreG * servingMultiplier).toStringAsFixed(1));

  /// Total sugar in the standard serving (g).
  double get servingSugar => double.parse((sugarG * servingMultiplier).toStringAsFixed(1));

  /// Total sodium in the standard serving (mg).
  int get servingSodium => (sodiumMg * servingMultiplier).round();

  factory MalaysianFood.fromJson(Map<String, dynamic> json) {
    return MalaysianFood(
      id: (json['id'] as num?)?.toInt() ?? 0,
      sourceId: json['source_id']?.toString() ?? json['sourceId']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unknown Food',
      nameMs: json['name_ms']?.toString() ?? json['nameMs']?.toString() ?? '',
      category: json['category']?.toString() ?? 'General',
      caloriesKcal: (json['calories_kcal'] as num?)?.toDouble() ??
          (json['caloriesPer100g'] as num?)?.toDouble() ??
          (json['calories'] as num?)?.toDouble() ??
          0.0,
      proteinG: (json['protein_g'] as num?)?.toDouble() ??
          (json['proteinPer100g'] as num?)?.toDouble() ??
          (json['protein'] as num?)?.toDouble() ??
          0.0,
      fatG: (json['fat_g'] as num?)?.toDouble() ??
          (json['fatPer100g'] as num?)?.toDouble() ??
          (json['fat'] as num?)?.toDouble() ??
          0.0,
      carbsG: (json['carbs_g'] as num?)?.toDouble() ??
          (json['carbsPer100g'] as num?)?.toDouble() ??
          (json['carbs'] as num?)?.toDouble() ??
          0.0,
      fibreG: (json['fibre_g'] as num?)?.toDouble() ??
          (json['fibrePer100g'] as num?)?.toDouble() ??
          0.0,
      sugarG: (json['sugar_g'] as num?)?.toDouble() ??
          (json['sugarPer100g'] as num?)?.toDouble() ??
          0.0,
      sodiumMg: (json['sodium_mg'] as num?)?.toDouble() ??
          (json['sodiumPer100g'] as num?)?.toDouble() ??
          0.0,
      servingName: json['serving_name']?.toString() ??
          json['servingName']?.toString() ??
          '1 serving',
      servingGrams: (json['serving_grams'] as num?)?.toDouble() ??
          (json['servingGrams'] as num?)?.toDouble() ??
          100.0,
      sourceName: json['source_name']?.toString() ?? json['sourceName']?.toString(),
      sourceUrl: json['source_url']?.toString() ?? json['sourceUrl']?.toString(),
      sourcePublishedDate: json['source_published_date']?.toString() ??
          json['sourcePublishedDate']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'source_id': sourceId,
      'name': name,
      'name_ms': nameMs,
      'category': category,
      'calories_kcal': caloriesKcal,
      'protein_g': proteinG,
      'fat_g': fatG,
      'carbs_g': carbsG,
      'fibre_g': fibreG,
      'sugar_g': sugarG,
      'sodium_mg': sodiumMg,
      'serving_name': servingName,
      'serving_grams': servingGrams,
      'source_name': sourceName,
      'source_url': sourceUrl,
      'source_published_date': sourcePublishedDate,
    };
  }
}
