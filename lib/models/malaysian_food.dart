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
  final String? officialName;
  final String nameMs;
  final String category;
  final double caloriesKcal; // per basisAmount (100g or 100ml)
  final double proteinG;     // per basisAmount
  final double fatG;         // per basisAmount
  final double carbsG;       // per basisAmount
  final double fibreG;       // per basisAmount
  final double sugarG;       // per basisAmount
  final double sodiumMg;     // per basisAmount
  final double? rawCaloriesKcal;
  final double? rawProteinG;
  final double? rawFatG;
  final double? rawCarbsG;
  final String servingName;  // e.g. "1 plate", "1 piece", "1 glass"
  final double servingAmount; // e.g. 250.0 (grams or ml)
  final String servingUnit;   // 'g' or 'ml'
  final String basisType;     // 'per_100g' or 'per_100ml'
  final double basisAmount;   // 100.0
  final String basisUnit;     // 'g' or 'ml'
  final String? sourceName;
  final String? sourceUrl;
  final String? sourcePublishedDate;
  final String? sourceDatabase;

  /// Returns true if this record is verified from official MyFCD sources
  bool get isOfficialMyFCD =>
      sourceDatabase != null ||
      sourceName?.toLowerCase().contains('myfcd') == true ||
      (sourceId.isNotEmpty && (sourceId.startsWith('R') || int.tryParse(sourceId) != null));

  /// Whether energy/calories was analyzed and officially provided
  bool get hasEnergy => rawCaloriesKcal != null;

  /// Whether protein was analyzed and officially provided
  bool get hasProtein => rawProteinG != null;

  /// Whether fat was analyzed and officially provided
  bool get hasFat => rawFatG != null;

  /// Whether carbohydrates was analyzed and officially provided
  bool get hasCarbs => rawCarbsG != null;

  /// Safe display of calories without fabricating zeros for unanalyzed nutrients
  String get displayCalories => hasEnergy ? '$servingCalories kcal' : 'Not available';

  /// Safe display of protein without fabricating zeros
  String get displayProtein => hasProtein ? '${servingProtein}g' : 'Not available';

  /// Safe display of carbs without fabricating zeros
  String get displayCarbs => hasCarbs ? '${servingCarbs}g' : 'Not available';

  /// Safe display of fat without fabricating zeros
  String get displayFat => hasFat ? '${servingFat}g' : 'Not available';

  /// Backward-compatible alias for servingAmount (in grams or ml)
  double get servingGrams => servingAmount;

  /// Returns true if this food's nutritional basis is measured per 100ml
  bool get isPer100ml => basisType == 'per_100ml' || basisUnit.toLowerCase() == 'ml';

  /// Returns true if this food's nutritional basis is measured per 100g
  bool get isPer100g => !isPer100ml;

  /// Formatted serving summary string e.g. "1 glass (250 ml)" or "1 plate (250 g)"
  String get servingSummary {
    final amtStr = servingAmount.truncateToDouble() == servingAmount
        ? servingAmount.toInt().toString()
        : servingAmount.toStringAsFixed(1);
    return servingAmount > 0 ? '$servingName ($amtStr $servingUnit)' : servingName;
  }

  const MalaysianFood({
    required this.id,
    required this.sourceId,
    required this.name,
    this.officialName,
    this.nameMs = '',
    this.category = 'General',
    required this.caloriesKcal,
    required this.proteinG,
    required this.fatG,
    required this.carbsG,
    this.fibreG = 0.0,
    this.sugarG = 0.0,
    this.sodiumMg = 0.0,
    this.rawCaloriesKcal,
    this.rawProteinG,
    this.rawFatG,
    this.rawCarbsG,
    this.servingName = '1 serving',
    double? servingGrams,
    double? servingAmount,
    this.servingUnit = 'g',
    this.basisType = 'per_100g',
    this.basisAmount = 100.0,
    this.basisUnit = 'g',
    this.sourceName,
    this.sourceUrl,
    this.sourcePublishedDate,
    this.sourceDatabase,
  }) : servingAmount = servingAmount ?? servingGrams ?? 100.0;

  /// Multiplier to convert base density (100g or 100ml) to standard serving size.
  double get servingMultiplier {
    final effectiveBasis = basisAmount > 0 ? basisAmount : 100.0;
    final effectiveServing = servingAmount > 0 ? servingAmount : effectiveBasis;
    return effectiveServing / effectiveBasis;
  }

  /// Total calories in standard serving (kcal).
  int get servingCalories => (caloriesKcal * servingMultiplier).round();

  /// Total protein in standard serving (g).
  int get servingProtein => (proteinG * servingMultiplier).round();

  /// Total fat in standard serving (g).
  int get servingFat => (fatG * servingMultiplier).round();

  /// Total carbohydrates in standard serving (g).
  int get servingCarbs => (carbsG * servingMultiplier).round();

  /// Total dietary fibre in standard serving (g).
  double get servingFibre => double.parse((fibreG * servingMultiplier).toStringAsFixed(1));

  /// Total sugar in standard serving (g).
  double get servingSugar => double.parse((sugarG * servingMultiplier).toStringAsFixed(1));

  /// Total sodium in standard serving (mg).
  int get servingSodium => (sodiumMg * servingMultiplier).round();

  factory MalaysianFood.fromJson(Map<String, dynamic> json) {
    final bType = json['basis_type']?.toString() ?? 'per_100g';
    final bUnit = json['basis_unit']?.toString() ?? (bType == 'per_100ml' ? 'ml' : 'g');
    final bAmount = (json['basis_amount'] as num?)?.toDouble() ?? 100.0;

    final sAmount = (json['serving_amount'] as num?)?.toDouble() ??
        (json['serving_weight_or_volume'] as num?)?.toDouble() ??
        (json['serving_grams'] as num?)?.toDouble() ??
        (json['servingGrams'] as num?)?.toDouble() ??
        100.0;

    final sUnit = json['serving_unit']?.toString() ??
        json['servingUnit']?.toString() ??
        bUnit;

    final displayName = json['display_name']?.toString() ?? json['name']?.toString();
    final officialName = json['official_name']?.toString();
    final effectiveName = displayName ?? officialName ?? 'Unknown Food';

    final rawCals = (json['calories_kcal'] as num?)?.toDouble() ??
        (json['energy_kcal'] as num?)?.toDouble() ??
        (json['caloriesPer100g'] as num?)?.toDouble() ??
        (json['calories'] as num?)?.toDouble();

    final rawProt = (json['protein_g'] as num?)?.toDouble() ??
        (json['proteinPer100g'] as num?)?.toDouble() ??
        (json['protein'] as num?)?.toDouble();

    final rawFat = (json['fat_g'] as num?)?.toDouble() ??
        (json['fatPer100g'] as num?)?.toDouble() ??
        (json['fat'] as num?)?.toDouble();

    final rawCarbs = (json['carbohydrate_g'] as num?)?.toDouble() ??
        (json['carbs_g'] as num?)?.toDouble() ??
        (json['carbsPer100g'] as num?)?.toDouble() ??
        (json['carbs'] as num?)?.toDouble();

    return MalaysianFood(
      id: (json['id'] as num?)?.toInt() ?? 0,
      sourceId: json['identifier']?.toString() ?? json['source_id']?.toString() ?? json['ndb_no']?.toString() ?? json['sourceId']?.toString() ?? '',
      name: effectiveName,
      officialName: officialName,
      nameMs: json['name_ms']?.toString() ?? json['nameMs']?.toString() ?? '',
      category: json['category']?.toString() ?? 'General',
      caloriesKcal: rawCals ?? 0.0,
      proteinG: rawProt ?? 0.0,
      fatG: rawFat ?? 0.0,
      carbsG: rawCarbs ?? 0.0,
      fibreG: (json['total_dietary_fibre_g'] as num?)?.toDouble() ??
          (json['fibre_g'] as num?)?.toDouble() ??
          (json['fibrePer100g'] as num?)?.toDouble() ??
          0.0,
      sugarG: (json['total_sugars_g'] as num?)?.toDouble() ??
          (json['sugar_g'] as num?)?.toDouble() ??
          (json['sugarPer100g'] as num?)?.toDouble() ??
          0.0,
      sodiumMg: (json['sodium_mg'] as num?)?.toDouble() ??
          (json['sodium'] as num?)?.toDouble() ??
          (json['sodiumPer100g'] as num?)?.toDouble() ??
          0.0,
      rawCaloriesKcal: rawCals,
      rawProteinG: rawProt,
      rawFatG: rawFat,
      rawCarbsG: rawCarbs,
      servingName: json['serving_label']?.toString() ??
          json['serving_name']?.toString() ??
          json['servingName']?.toString() ??
          '1 serving',
      servingAmount: sAmount,
      servingUnit: sUnit,
      basisType: bType,
      basisAmount: bAmount,
      basisUnit: bUnit,
      sourceName: json['source']?.toString() ?? json['source_name']?.toString() ?? json['sourceName']?.toString(),
      sourceUrl: json['source_url']?.toString() ?? json['sourceUrl']?.toString(),
      sourcePublishedDate: json['published_date']?.toString() ??
          json['source_published_date']?.toString() ??
          json['sourcePublishedDate']?.toString(),
      sourceDatabase: json['source_database']?.toString() ?? json['sourceDatabase']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'source_id': sourceId,
      'name': name,
      'official_name': officialName,
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
      'serving_amount': servingAmount,
      'serving_grams': servingAmount,
      'serving_unit': servingUnit,
      'basis_type': basisType,
      'basis_amount': basisAmount,
      'basis_unit': basisUnit,
      'source_name': sourceName,
      'source_url': sourceUrl,
      'source_published_date': sourcePublishedDate,
      'source_database': sourceDatabase,
    };
  }
}
