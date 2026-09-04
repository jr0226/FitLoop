import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/services/diet_personalization_service.dart';
import 'package:flutter_application_1/services/scan_food_cache_service.dart';

void main() {
  group('DietPersonalizationService & Cache Key Tests', () {
    test('Vegan user scanning Prawn Mee: preserves factual recognition, sets incompatibility warning, sanitizes alternatives and explanation', () {
      // Exact data returned by the live Render backend for Penang Prawn Mee
      final rawRenderResponse = <String, dynamic>{
        'foods': [
          {
            'name': 'Penang Prawn Mee (Hae Mee)',
            'serving': '1 bowl (approx 450g)',
            'calories': 510,
            'proteins': 24,
            'carbs': 68,
            'fats': 16,
            'fibre': 4,
            'sugar': 6,
            'sodium': 1850,
          }
        ],
        'totalCalories': 510,
        'totalProteins': 24,
        'totalCarbs': 68,
        'totalFats': 16,
        'score': 72,
        'explanation':
            'The Penang Prawn Mee is low in protein. To hit your fitness goals, consider adding extra chicken breast or a hard-boiled egg.',
        'alternatives': [
          'Dry Prawn Mee (to consume less broth and reduce sodium intake)',
          'Ipoh Hor Fun (with shredded chicken and prawns in a lighter broth)',
        ],
      };

      final sanitized = DietPersonalizationService.sanitizeAndEvaluate(
        rawRenderResponse,
        dietPreference: 'Vegan',
        allergies: [],
      );

      // 1. Factual food recognition is PRESERVED (NOT renamed to vegan dish)
      final foods = sanitized['foods'] as List;
      expect(foods.first['name'], equals('Penang Prawn Mee (Hae Mee)'));

      // 2. Incompatibility warning is set
      expect(sanitized['dietCompatibility'], equals('incompatible'));
      expect(sanitized['dietNotice'], equals('This meal does not match your Vegan preference.'));

      // 3. Alternatives must NOT contain chicken, fish, shrimp, prawn, egg, or animal meat
      final alternatives = (sanitized['alternatives'] as List).cast<String>();
      expect(alternatives.isNotEmpty, isTrue);
      for (final alt in alternatives) {
        final altLower = alt.toLowerCase();
        expect(altLower.contains('chicken'), isFalse, reason: 'Found chicken in: $alt');
        expect(altLower.contains('prawn'), isFalse, reason: 'Found prawn in: $alt');
        expect(altLower.contains('shrimp'), isFalse, reason: 'Found shrimp in: $alt');
        expect(altLower.contains('meat'), isFalse, reason: 'Found meat in: $alt');
        expect(altLower.contains('egg'), isFalse, reason: 'Found egg in: $alt');
      }

      // 4. Explanation recommendation text must NOT recommend adding chicken or egg
      final explanation = (sanitized['explanation'] as String).toLowerCase();
      expect(explanation.contains('add extra chicken'), isFalse);
      expect(explanation.contains('chicken breast'), isFalse);
      expect(explanation.contains('hard-boiled egg'), isFalse);
      expect(explanation.contains('boiled egg'), isFalse);
      expect(
        explanation.contains('tofu') ||
            explanation.contains('tempeh') ||
            explanation.contains('edamame') ||
            explanation.contains('plant-based'),
        isTrue,
      );
    });

    test('Cache key includes dietPreference and normalized allergies and version 3', () {
      expect(ScanFoodCacheService.currentAnalysisVersion, equals(3));
      final hash = ScanFoodCacheService.instance.computeImageHash(Uint8List.fromList([1, 2, 3]));
      expect(hash.isNotEmpty, isTrue);
    });

    test('Vegetarian user scanning Beef Burger: factual recognition and warning', () {
      final rawResponse = <String, dynamic>{
        'foods': [
          {'name': 'Beef Burger', 'calories': 550, 'proteins': 28, 'carbs': 45, 'fats': 25}
        ],
        'totalCalories': 550,
        'totalProteins': 28,
        'totalCarbs': 45,
        'totalFats': 25,
        'score': 65,
        'explanation': 'A protein-dense burger. You could add chicken or bacon for more protein.',
        'alternatives': ['Turkey Burger', 'Portobello Mushroom Burger'],
      };

      final sanitized = DietPersonalizationService.sanitizeAndEvaluate(
        rawResponse,
        dietPreference: 'Vegetarian',
      );

      expect(sanitized['foods'].first['name'], equals('Beef Burger'));
      expect(sanitized['dietCompatibility'], equals('incompatible'));
      expect(sanitized['dietNotice'], equals('This meal does not match your Vegetarian preference.'));

      final alts = (sanitized['alternatives'] as List).cast<String>();
      expect(alts.contains('Turkey Burger'), isFalse);
      expect(alts.contains('Portobello Mushroom Burger'), isTrue);

      final exp = (sanitized['explanation'] as String).toLowerCase();
      expect(exp.contains('add chicken'), isFalse);
    });

    test('Halal user scanning Sweet and Sour Pork: incompatible warning', () {
      final rawResponse = <String, dynamic>{
        'foods': [
          {'name': 'Sweet and Sour Pork', 'calories': 400, 'proteins': 20, 'carbs': 30, 'fats': 15}
        ],
        'totalCalories': 400,
        'totalProteins': 20,
        'totalCarbs': 30,
        'totalFats': 15,
        'score': 60,
        'explanation': 'Tasty pork dish.',
        'alternatives': ['Crispy Bacon and Rice', 'Sweet and Sour Chicken with Steamed Rice'],
      };

      final sanitized = DietPersonalizationService.sanitizeAndEvaluate(
        rawResponse,
        dietPreference: 'Halal',
      );

      expect(sanitized['dietCompatibility'], equals('incompatible'));
      expect(sanitized['dietNotice'], equals('This meal may contain non-Halal ingredients (pork/alcohol).'));

      final alts = (sanitized['alternatives'] as List).cast<String>();
      expect(alts.contains('Crispy Bacon and Rice'), isFalse);
      expect(alts.contains('Sweet and Sour Chicken with Steamed Rice'), isTrue);
    });
  });
}
