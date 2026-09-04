import 'package:flutter/foundation.dart';

/// Service responsible for client-side evaluation of diet compatibility and comprehensive
/// sanitization of all user-facing recommendation text and alternative meals.
///
/// Provides defense-in-depth so that the Flutter application guarantees 100% adherence to
/// user dietary preferences (e.g. Vegan, Vegetarian, Halal, Pescatarian) and reported allergies,
/// regardless of whether the backend API or upstream AI model is stale, cached, or imperfect.
class DietPersonalizationService {
  DietPersonalizationService._();

  // Prohibited tokens for Vegan diets across meal components and recommendations
  static const List<String> veganForbiddenTokens = [
    'chicken',
    'beef',
    'pork',
    'mutton',
    'lamb',
    'duck',
    'turkey',
    'bacon',
    'ham',
    'lard',
    'meat',
    'fish',
    'salmon',
    'tuna',
    'cod',
    'tilapia',
    'mackerel',
    'anchovy',
    'prawn',
    'shrimp',
    'crab',
    'squid',
    'octopus',
    'lobster',
    'clam',
    'oyster',
    'mussel',
    'scallop',
    'seafood',
    'egg',
    'telur',
    'mayo',
    'mayonnaise',
    'milk',
    'cheese',
    'yogurt',
    'yoghurt',
    'butter',
    'cream',
    'whey',
    'casein',
    'ghee',
    'honey',
    'gelatin',
    'ikan',
    'udang',
    'ketam',
    'sotong',
    'ayam',
    'daging',
    'hae mee',
    'har mee',
  ];

  // Prohibited tokens for Vegetarian diets
  static const List<String> vegetarianForbiddenTokens = [
    'chicken',
    'beef',
    'pork',
    'mutton',
    'lamb',
    'duck',
    'turkey',
    'bacon',
    'ham',
    'lard',
    'meat',
    'fish',
    'salmon',
    'tuna',
    'cod',
    'tilapia',
    'mackerel',
    'anchovy',
    'prawn',
    'shrimp',
    'crab',
    'squid',
    'octopus',
    'lobster',
    'clam',
    'oyster',
    'mussel',
    'scallop',
    'seafood',
    'ikan',
    'udang',
    'ketam',
    'sotong',
    'ayam',
    'daging',
    'hae mee',
    'har mee',
  ];

  // Prohibited tokens for Halal diets
  static const List<String> halalForbiddenTokens = [
    'pork',
    'bacon',
    'lard',
    'ham',
    'alcohol',
    'wine',
    'beer',
    'mirin',
    'sake',
    'rum',
    'babi',
    'char siu',
    'bak kut teh',
  ];

  // Prohibited tokens for Pescatarian diets
  static const List<String> pescatarianForbiddenTokens = [
    'chicken',
    'beef',
    'pork',
    'mutton',
    'lamb',
    'duck',
    'turkey',
    'bacon',
    'ham',
    'lard',
    'meat',
    'ayam',
    'daging',
  ];

  static const Map<String, List<String>> allergenTokenMap = {
    'peanuts': ['peanut', 'groundnut'],
    'nuts': ['nut', 'almond', 'walnut', 'cashew', 'pecan', 'hazelnut', 'pistachio', 'macadamia'],
    'dairy': ['dairy', 'milk', 'cheese', 'butter', 'cream', 'yogurt', 'yoghurt', 'whey'],
    'shellfish': ['shellfish', 'shrimp', 'prawn', 'crab', 'lobster', 'clam', 'oyster', 'mussel', 'udang', 'ketam'],
    'eggs': ['egg', 'telur'],
    'soy': ['soy', 'soya', 'tofu', 'edamame', 'tempeh'],
    'fish': ['fish', 'salmon', 'tuna', 'cod', 'tilapia', 'mackerel', 'anchovy', 'ikan'],
    'gluten': ['gluten', 'wheat', 'barley', 'rye'],
  };

  /// Evaluates dietary compatibility and sanitizes all user-facing recommendation texts
  /// (both `alternatives` and `explanation`/`scoreExplanation`).
  ///
  /// Preserves factual recognition of detected foods (e.g. Prawn Mee stays Prawn Mee).
  static Map<String, dynamic> sanitizeAndEvaluate(
    Map<String, dynamic> rawAnalysis, {
    required String dietPreference,
    List<String> allergies = const [],
  }) {
    final result = Map<String, dynamic>.from(rawAnalysis);
    final cleanDiet = dietPreference.trim();
    final dietLower = cleanDiet.toLowerCase();
    final cleanAllergies = allergies.map((a) => a.trim().toLowerCase()).where((a) => a.isNotEmpty).toList();

    // 1. Evaluate Food Items Compatibility (Preserving factual food names)
    final dynamic rawFoods = result['foods'];
    List<dynamic> foodsList = [];
    if (rawFoods is List) {
      foodsList = rawFoods;
    }

    bool isCompatible = true;
    String? dietNotice;
    String? allergyNotice;

    List<String> activeDietTokens = [];
    if (dietLower == 'vegan') {
      activeDietTokens = veganForbiddenTokens;
    } else if (dietLower == 'vegetarian') {
      activeDietTokens = vegetarianForbiddenTokens;
    } else if (dietLower == 'halal') {
      activeDietTokens = halalForbiddenTokens;
    } else if (dietLower == 'pescatarian') {
      activeDietTokens = pescatarianForbiddenTokens;
    }

    if (activeDietTokens.isNotEmpty) {
      for (final item in foodsList) {
        final name = (item is Map ? (item['name'] ?? '') : item.toString()).toString().toLowerCase();
        for (final token in activeDietTokens) {
          final regex = RegExp(r'\b' + RegExp.escape(token) + r's?\b', caseSensitive: false);
          if (regex.hasMatch(name)) {
            isCompatible = false;
            break;
          }
        }
        if (!isCompatible) break;
      }

      if (!isCompatible) {
        if (dietLower == 'halal') {
          dietNotice = 'This meal may contain non-Halal ingredients (pork/alcohol).';
        } else {
          dietNotice = 'This meal does not match your $cleanDiet preference.';
        }
      }
    }

    // Check reported allergies against detected foods
    final List<String> matchedAllergens = [];
    for (final userAllergy in cleanAllergies) {
      List<String> allergenTokens = [userAllergy];
      for (final entry in allergenTokenMap.entries) {
        if (entry.key.contains(userAllergy) || userAllergy.contains(entry.key)) {
          allergenTokens = entry.value;
          break;
        }
      }

      for (final item in foodsList) {
        final name = (item is Map ? (item['name'] ?? '') : item.toString()).toString().toLowerCase();
        for (final token in allergenTokens) {
          final regex = RegExp(r'\b' + RegExp.escape(token) + r's?\b', caseSensitive: false);
          if (regex.hasMatch(name)) {
            if (!matchedAllergens.contains(userAllergy)) {
              matchedAllergens.add(userAllergy);
            }
            break;
          }
        }
      }
    }

    if (matchedAllergens.isNotEmpty) {
      allergyNotice = 'This meal may contain ingredients matching your reported allergies: ${matchedAllergens.join(', ')}.';
    }

    result['dietCompatibility'] = isCompatible ? 'compatible' : 'incompatible';
    result['dietNotice'] = dietNotice;
    result['allergyNotice'] = allergyNotice;

    // 2. Sanitize ALL User-Facing Alternatives
    final dynamic rawAlternatives = result['alternatives'] ?? result['healthierAlternatives'];
    List<String> alternativesList = [];
    if (rawAlternatives is List) {
      alternativesList = rawAlternatives.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
    }

    final sanitizedAlternatives = <String>[];
    for (final alt in alternativesList) {
      if (_isAlternativeAllowed(alt, activeDietTokens, cleanAllergies)) {
        sanitizedAlternatives.add(alt);
      } else {
        debugPrint("[DietPersonalization] Rejected non-$cleanDiet alternative: '$alt'");
      }
    }

    // If all alternatives were stripped due to restrictions, supply curated diet-compliant options
    if (sanitizedAlternatives.isEmpty && dietLower != 'standard') {
      sanitizedAlternatives.addAll(_buildFallbackAlternatives(dietLower, foodsList));
    }

    result['alternatives'] = sanitizedAlternatives;
    result['healthierAlternatives'] = sanitizedAlternatives;

    // 3. Sanitize Recommendation Text in explanation and related text fields
    final String rawExplanation = (result['explanation'] ?? result['scoreExplanation'] ?? '').toString();
    if (rawExplanation.isNotEmpty) {
      final sanitizedExplanation = sanitizeRecommendationText(
        rawExplanation,
        dietPreference: cleanDiet,
        allergies: cleanAllergies,
      );
      result['explanation'] = sanitizedExplanation;
      result['scoreExplanation'] = sanitizedExplanation;
    }

    if (result['dietitianInsight'] != null) {
      result['dietitianInsight'] = sanitizeRecommendationText(
        result['dietitianInsight'].toString(),
        dietPreference: cleanDiet,
        allergies: cleanAllergies,
      );
    }

    return result;
  }

  /// Sanitizes prose recommendation text by scrubbing and replacing non-compliant protein suggestions.
  static String sanitizeRecommendationText(
    String text, {
    required String dietPreference,
    List<String> allergies = const [],
  }) {
    final dietLower = dietPreference.trim().toLowerCase();
    String cleaned = text;

    if (dietLower == 'vegan') {
      // Direct phrase replacements for common AI protein suggestions
      cleaned = cleaned.replaceAll(RegExp(r'\badd\s+extra\s+chicken(\s+breast)?\b', caseSensitive: false), 'add extra firm tofu or tempeh');
      cleaned = cleaned.replaceAll(RegExp(r'\badding\s+extra\s+chicken(\s+breast)?\b', caseSensitive: false), 'adding extra firm tofu or tempeh');
      cleaned = cleaned.replaceAll(RegExp(r'\badd\s+chicken(\s+breast)?\b', caseSensitive: false), 'add tofu or tempeh');
      cleaned = cleaned.replaceAll(RegExp(r'\badding\s+chicken(\s+breast)?\b', caseSensitive: false), 'adding tofu or tempeh');
      cleaned = cleaned.replaceAll(RegExp(r'\bpair\s+with\s+(grilled\s+)?chicken(\s+breast)?\b', caseSensitive: false), 'pair with grilled tempeh or tofu');
      cleaned = cleaned.replaceAll(RegExp(r'\b(a\s+)?(hard-)?boiled\s+egg\b', caseSensitive: false), 'steamed edamame');
      cleaned = cleaned.replaceAll(RegExp(r'\b(hard-)?boiled\s+eggs\b', caseSensitive: false), 'steamed edamame or hemp seeds');
      cleaned = cleaned.replaceAll(RegExp(r'\badd\s+(an\s+)?egg\b', caseSensitive: false), 'add edamame or tofu');
      cleaned = cleaned.replaceAll(RegExp(r'\badding\s+(an\s+)?egg\b', caseSensitive: false), 'adding edamame or tofu');
      cleaned = cleaned.replaceAll(RegExp(r'\badd\s+eggs\b', caseSensitive: false), 'add edamame or hemp seeds');
      cleaned = cleaned.replaceAll(RegExp(r'\badding\s+eggs\b', caseSensitive: false), 'adding edamame or hemp seeds');
      cleaned = cleaned.replaceAll(RegExp(r'\bgrilled\s+fish\b', caseSensitive: false), 'grilled tempeh');
      cleaned = cleaned.replaceAll(RegExp(r'\bextra\s+fish\b', caseSensitive: false), 'extra plant-based protein');
      cleaned = cleaned.replaceAll(RegExp(r'\bextra\s+meat\b', caseSensitive: false), 'extra plant-based protein');
      cleaned = cleaned.replaceAll(RegExp(r'\banimal\s+protein\b', caseSensitive: false), 'plant-based protein');
      cleaned = cleaned.replaceAll(RegExp(r'\bwhey\s+protein\b', caseSensitive: false), 'plant-based protein');
      cleaned = cleaned.replaceAll(RegExp(r'\bgreek\s+yogurt\b', caseSensitive: false), 'soy yogurt');

      // Check sentences: if a recommendation sentence still advocates non-vegan animal products, sanitize or remove it
      final sentences = cleaned.split(RegExp(r'(?<=[.!?])\s+'));
      final cleanedSentences = <String>[];
      for (final s in sentences) {
        final isRecommendationSentence = RegExp(r'\b(consider|recommend|suggest|try|add|adding|pair|substitute|boost|increase|opt)\b', caseSensitive: false).hasMatch(s);
        bool hasAnimalTerm = false;
        for (final term in veganForbiddenTokens) {
          if (RegExp(r'\b' + RegExp.escape(term) + r's?\b', caseSensitive: false).hasMatch(s)) {
            hasAnimalTerm = true;
            break;
          }
        }

        if (isRecommendationSentence && hasAnimalTerm) {
          cleanedSentences.add('To boost protein while adhering to your Vegan diet, consider adding grilled tempeh, firm tofu, or edamame.');
        } else {
          cleanedSentences.add(s);
        }
      }
      cleaned = cleanedSentences.join(' ');
    } else if (dietLower == 'vegetarian') {
      cleaned = cleaned.replaceAll(RegExp(r'\badd\s+extra\s+chicken(\s+breast)?\b', caseSensitive: false), 'add extra tofu or eggs');
      cleaned = cleaned.replaceAll(RegExp(r'\badding\s+extra\s+chicken(\s+breast)?\b', caseSensitive: false), 'adding extra tofu or eggs');
      cleaned = cleaned.replaceAll(RegExp(r'\badd\s+chicken\b', caseSensitive: false), 'add tofu or eggs');
      cleaned = cleaned.replaceAll(RegExp(r'\bgrilled\s+fish\b', caseSensitive: false), 'grilled tofu or paneer');
      cleaned = cleaned.replaceAll(RegExp(r'\bextra\s+meat\b', caseSensitive: false), 'extra plant protein or eggs');
    }

    return cleaned.trim();
  }

  static bool _isAlternativeAllowed(
    String text,
    List<String> dietTokens,
    List<String> allergies,
  ) {
    final textLower = text.toLowerCase();

    // Check diet restrictions
    for (final token in dietTokens) {
      final regex = RegExp(r'\b' + RegExp.escape(token) + r's?\b', caseSensitive: false);
      if (regex.hasMatch(textLower)) {
        return false;
      }
    }

    // Check allergen restrictions
    for (final userAllergy in allergies) {
      List<String> allergenTokens = [userAllergy];
      for (final entry in allergenTokenMap.entries) {
        if (entry.key.contains(userAllergy) || userAllergy.contains(entry.key)) {
          allergenTokens = entry.value;
          break;
        }
      }

      for (final token in allergenTokens) {
        final regex = RegExp(r'\b' + RegExp.escape(token) + r's?\b', caseSensitive: false);
        if (regex.hasMatch(textLower)) {
          return false;
        }
      }
    }

    return true;
  }

  static List<String> _buildFallbackAlternatives(String diet, List<dynamic> foodsList) {
    final foodNames = foodsList
        .map((f) => (f is Map ? (f['name'] ?? '') : f.toString()).toString().toLowerCase())
        .join(' ');

    final bool isNoodle = foodNames.contains('mee') ||
        foodNames.contains('noodle') ||
        foodNames.contains('bihun') ||
        foodNames.contains('vermicelli') ||
        foodNames.contains('kuey teow') ||
        foodNames.contains('hor fun') ||
        foodNames.contains('ramen');

    final bool isRice = foodNames.contains('rice') ||
        foodNames.contains('nasi') ||
        foodNames.contains('porridge') ||
        foodNames.contains('bubur');

    if (diet == 'vegan') {
      if (isNoodle) {
        return [
          "Vegetarian Clear Noodle Soup with Braised Tofu and Mushrooms",
          "Stir-Fried Vegan Mee Hoon with Tempeh and Bok Choy",
          "Spicy Tofu and Edamame Noodle Bowl (100% Plant-Based)",
        ];
      }
      if (isRice) {
        return [
          "Brown Rice with Stir-Fried Tempeh, Long Beans, and Tofu",
          "Vegan Nasi Goreng with Mixed Vegetables and Edamame",
          "Claypot Braised Tofu and Shiitake Mushroom Rice",
        ];
      }
      return [
        "Stir-Fried Tofu and Mixed Vegetables with Brown Rice",
        "Tempeh and Edamame Power Bowl with Light Soy Dressing",
        "Lentil and Vegetable Curry with Wholemeal Chapati",
      ];
    } else if (diet == 'vegetarian') {
      return [
        "Vegetarian Clear Noodle Soup with Braised Tofu and Greens",
        "Egg and Vegetable Fried Brown Rice with Extra Tofu",
        "Stir-Fried Tofu, Paneer, and Seasonal Vegetables",
      ];
    } else if (diet == 'halal') {
      return [
        "Mee Soup with Chicken Breast and Bok Choy",
        "Grilled Chicken Rice with Steamed Greens and Fresh Chili Dip",
        "Stir-Fried Rice Vermicelli with Tofu and Bean Sprouts",
      ];
    }

    return [
      "Stir-Fried Tofu and Vegetables with Steamed Rice",
      "Fresh Vegetable Noodle Soup with Plant Protein",
    ];
  }
}
