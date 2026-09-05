import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_application_1/models/malaysian_food.dart';
import 'package:flutter_application_1/services/food_service.dart';

void main() {
  group('MalaysianFood Model Tests', () {
    test('Nasi Lemak correctly scales from per-100g to 250g standard serving', () {
      final json = {
        "id": 1,
        "source_id": "MY001",
        "name": "Nasi Lemak",
        "name_ms": "Nasi Lemak",
        "category": "Rice & Dishes",
        "calories_kcal": 180.0, // per 100g
        "protein_g": 4.0,       // per 100g
        "fat_g": 8.0,           // per 100g
        "carbs_g": 25.0,        // per 100g
        "fibre_g": 1.5,
        "sugar_g": 2.0,
        "sodium_mg": 300.0,
        "serving_name": "1 plate",
        "serving_grams": 250.0,
      };

      final food = MalaysianFood.fromJson(json);
      expect(food.servingMultiplier, equals(2.5));
      expect(food.servingCalories, equals(450)); // 180 * 2.5
      expect(food.servingProtein, equals(10));   // 4 * 2.5
      expect(food.servingFat, equals(20));       // 8 * 2.5
      expect(food.servingCarbs, equals(63));     // 25 * 2.5 = 62.5 -> 63
      expect(food.servingSodium, equals(750));   // 300 * 2.5
    });

    test('Roti Canai correctly scales from per-100g to 95g standard serving', () {
      final json = {
        "id": 29,
        "source_id": "MY029",
        "name": "Roti Canai",
        "name_ms": "Roti Canai",
        "category": "Breads & Flour Foods",
        "calories_kcal": 300.0, // per 100g
        "protein_g": 7.0,
        "fat_g": 15.0,
        "carbs_g": 35.0,
        "fibre_g": 2.0,
        "sugar_g": 3.0,
        "sodium_mg": 450.0,
        "serving_name": "1 piece",
        "serving_grams": 95.0,
      };

      final food = MalaysianFood.fromJson(json);
      expect(food.servingMultiplier, closeTo(0.95, 0.001));
      expect(food.servingCalories, equals(285)); // 300 * 0.95
      expect(food.servingProtein, equals(7));    // 7 * 0.95 = 6.65 -> 7
      expect(food.servingFat, equals(14));       // 15 * 0.95 = 14.25 -> 14
      expect(food.servingCarbs, equals(33));     // 35 * 0.95 = 33.25 -> 33
    });

    test('Fresh Orange Juice correctly handles per-100ml basis and 250ml serving', () {
      final json = {
        "ndb_no": "R113064",
        "official_name": "FRUIT JUICE, FRESH, ORANGE",
        "category": "Fruit Juices",
        "basis_type": "per_100ml",
        "basis_amount": 100.0,
        "basis_unit": "ml",
        "energy_kcal": 51.0,
        "protein_g": 0.6,
        "fat_g": 0.1,
        "carbohydrate_g": 11.9,
        "total_dietary_fibre_g": 0.2,
        "total_sugars_g": 9.4,
        "sodium_mg": 1.0,
        "serving_label": "1 glass",
        "serving_amount": 250.0,
        "serving_unit": "ml",
        "source": "Institute for Medical Research, Malaysia",
        "source_url": "https://myfcd.moh.gov.my/myfcdcurrent/index.php/site/detail_product/R113064/0/10/-1/0/0",
        "published_date": "2020-01-01",
      };

      final food = MalaysianFood.fromJson(json);
      expect(food.isPer100ml, isTrue);
      expect(food.isPer100g, isFalse);
      expect(food.basisUnit, equals("ml"));
      expect(food.servingUnit, equals("ml"));
      expect(food.servingAmount, equals(250.0));
      expect(food.servingMultiplier, equals(2.5));
      expect(food.servingCalories, equals(128)); // 51 * 2.5 = 127.5 -> 128
      expect(food.servingCarbs, equals(30));     // 11.9 * 2.5 = 29.75 -> 30
      expect(food.servingSummary, equals("1 glass (250 ml)"));
      expect(food.sourceId, equals("R113064"));
      expect(food.sourceUrl, contains("R113064"));
    });

    test('Official MyFCD 1997 Nasi Lemak correctly scales from per-100g to 230g standard plate', () {
      final json = {
        "identifier": "221019",
        "official_name": "RICE, COCONUT MILK (NASI LEMAK)",
        "display_name": "Nasi Lemak",
        "name_ms": "Nasi Lemak",
        "category": "Cereal based",
        "basis_type": "per_100g",
        "basis_amount": 100.0,
        "basis_unit": "g",
        "energy_kcal": 169.0,
        "protein_g": 4.2,
        "fat_g": 5.7,
        "carbohydrate_g": 25.3,
        "serving_label": "1 plate",
        "serving_amount": 230.0,
        "serving_unit": "g",
        "source": "Institute for Medical Research, Malaysia",
        "source_database": "MyFCD 1997",
      };

      final food = MalaysianFood.fromJson(json);
      expect(food.isOfficialMyFCD, isTrue);
      expect(food.servingMultiplier, closeTo(2.3, 0.001));
      expect(food.servingCalories, equals(389)); // 169 * 2.3 = 388.7 -> 389
      expect(food.servingProtein, equals(10));   // 4.2 * 2.3 = 9.66 -> 10
      expect(food.servingFat, equals(13));       // 5.7 * 2.3 = 13.11 -> 13
      expect(food.servingCarbs, equals(58));     // 25.3 * 2.3 = 58.19 -> 58
      expect(food.displayCalories, equals("389 kcal"));
      expect(food.hasEnergy, isTrue);
    });

    test('Food with unanalyzed nutrients preserves NULL and displays Not available instead of fake zeros', () {
      final json = {
        "identifier": "R237013",
        "official_name": "PEARL MILK TEA",
        "display_name": "Pearl Milk Tea",
        "category": "Beverages",
        "basis_type": "per_100ml",
        "basis_amount": 100.0,
        "basis_unit": "ml",
        "energy_kcal": null,
        "protein_g": null,
        "fat_g": null,
        "carbohydrate_g": null,
        "total_sugars_g": 9.55,
        "source_database": "MyFCD Current",
      };

      final food = MalaysianFood.fromJson(json);
      expect(food.isOfficialMyFCD, isTrue);
      expect(food.hasEnergy, isFalse);
      expect(food.hasProtein, isFalse);
      expect(food.hasFat, isFalse);
      expect(food.hasCarbs, isFalse);
      expect(food.displayCalories, equals("Not available"));
      expect(food.displayProtein, equals("Not available"));
      expect(food.displayFat, equals("Not available"));
      expect(food.displayCarbs, equals("Not available"));
    });
  });

  group('FoodService Local Search & Caching Tests', () {
    final sampleDataset = [
      MalaysianFood(
        id: 1,
        sourceId: '221019',
        name: 'Nasi Lemak',
        officialName: 'RICE, COCONUT MILK (NASI LEMAK)',
        nameMs: 'Nasi Lemak',
        category: 'Cereal based',
        normalizedCategory: 'Rice / Cereal dishes',
        caloriesKcal: 169.0,
        proteinG: 4.2,
        fatG: 5.7,
        carbsG: 25.3,
        rawCaloriesKcal: 169.0,
        rawProteinG: 4.2,
        rawFatG: 5.7,
        rawCarbsG: 25.3,
        servingName: '1 plate',
        servingAmount: 230.0,
        sourceDatabase: 'MyFCD 1997',
        isSearchableForLogging: true,
      ),
      MalaysianFood(
        id: 2,
        sourceId: '221023',
        name: 'Roti Canai',
        officialName: '(ROTI CANAI)',
        nameMs: 'Roti Canai',
        category: 'Cereal based',
        normalizedCategory: 'Kuih / Snacks',
        caloriesKcal: 317.0,
        proteinG: 7.0,
        fatG: 10.8,
        carbsG: 47.9,
        rawCaloriesKcal: 317.0,
        rawProteinG: 7.0,
        rawFatG: 10.8,
        rawCarbsG: 47.9,
        servingName: '1 piece',
        servingAmount: 95.0,
        sourceDatabase: 'MyFCD 1997',
        isSearchableForLogging: true,
      ),
      MalaysianFood(
        id: 3,
        sourceId: '221018',
        name: 'Chicken Rice',
        officialName: 'RICE, CHICKEN (NASI AYAM)',
        nameMs: 'Nasi Ayam',
        category: 'Cereal based',
        normalizedCategory: 'Rice / Cereal dishes',
        caloriesKcal: 121.0,
        proteinG: 4.4,
        fatG: 2.7,
        carbsG: 19.8,
        rawCaloriesKcal: 121.0,
        rawProteinG: 4.4,
        rawFatG: 2.7,
        rawCarbsG: 19.8,
        servingName: '1 plate',
        servingAmount: 250.0,
        sourceDatabase: 'MyFCD 1997',
        isSearchableForLogging: true,
      ),
      MalaysianFood(
        id: 4,
        sourceId: '221010',
        name: 'Curry Laksa',
        officialName: 'CURRY LAKSA (KARI LAKSA)',
        nameMs: 'Kari Laksa',
        category: 'Cereal based',
        normalizedCategory: 'Noodles',
        caloriesKcal: 117.0,
        proteinG: 3.5,
        fatG: 6.4,
        carbsG: 11.3,
        rawCaloriesKcal: 117.0,
        rawProteinG: 3.5,
        rawFatG: 6.4,
        rawCarbsG: 11.3,
        servingName: '1 bowl',
        servingAmount: 650.0,
        sourceDatabase: 'MyFCD 1997',
        isSearchableForLogging: true,
      ),
      // Analytical duplicate of Nasi Lemak (should be filtered out)
      MalaysianFood(
        id: 5,
        sourceId: '403019',
        name: 'Nasi Lemak',
        officialName: 'NASI LEMAK',
        nameMs: 'Nasi Lemak',
        category: 'Cholesterol in ready-to-eat meals',
        normalizedCategory: 'Rice / Cereal dishes',
        caloriesKcal: 165.0,
        proteinG: 4.8,
        fatG: 3.6,
        carbsG: 28.3,
        rawCaloriesKcal: 165.0,
        rawProteinG: 4.8,
        rawFatG: 3.6,
        rawCarbsG: 28.3,
        sourceDatabase: 'MyFCD 1997',
        isSearchableForLogging: false,
      ),
      // Incomplete nutrient assay record with null energy (should be filtered out)
      MalaysianFood(
        id: 6,
        sourceId: '404019',
        name: 'Nasi Lemak',
        officialName: 'NASI LEMAK',
        category: 'Fatty acids in ready-to-eat meals',
        caloriesKcal: 0.0,
        proteinG: 0.0,
        fatG: 0.0,
        carbsG: 0.0,
        rawCaloriesKcal: null,
        rawProteinG: null,
        rawFatG: null,
        rawCarbsG: null,
        sourceDatabase: 'MyFCD 1997',
        isSearchableForLogging: false,
      ),
    ];

    setUp(() {
      FoodService.setCachedFoodsForTesting(null);
    });

    test('searchLocalFoods returns exactly 1 canonical Nasi Lemak and hides analytical duplicates', () {
      final results = FoodService.searchLocalFoods(
        'Nasi Lemak',
        dataset: sampleDataset,
      );
      expect(results.length, equals(1));
      expect(results.first.sourceId, equals('221019'));
      expect(results.first.isSearchableForLogging, isTrue);
    });

    test('searchLocalFoods filters by normalizedCategory correctly', () {
      final noodleResults = FoodService.searchLocalFoods(
        '',
        dataset: sampleDataset,
        category: 'Noodles',
      );
      expect(noodleResults.length, equals(1));
      expect(noodleResults.first.name, equals('Curry Laksa'));

      final riceResults = FoodService.searchLocalFoods(
        '',
        dataset: sampleDataset,
        category: 'Rice / Cereal dishes',
      );
      expect(riceResults.length, equals(2)); // Nasi Lemak + Chicken Rice
      expect(riceResults.any((f) => f.sourceId == '403019'), isFalse);
    });

    test('searchLocalFoods matches Malay name cross-lingually (nasi ayam -> Chicken Rice)', () {
      final results = FoodService.searchLocalFoods(
        'nasi ayam',
        dataset: sampleDataset,
      );
      expect(results.any((f) => f.name == 'Chicken Rice'), isTrue);
    });

    test('searchLocalFoods returns empty list for query not in MyFCD (no legacy fallback)', () {
      final results = FoodService.searchLocalFoods(
        'teh tarik xyz',
        dataset: sampleDataset,
      );
      expect(results, isEmpty);
    });

    test('fetchMalaysianFoods calls v3 endpoint and NEVER v1', () async {
      Uri? requestedUri;
      final mockClient = MockClient((request) async {
        requestedUri = request.url;
        return http.Response(
          json.encode([
            {
              "identifier": "221019",
              "official_name": "RICE, COCONUT MILK (NASI LEMAK)",
              "display_name": "Nasi Lemak",
              "category": "Cereal based",
              "energy_kcal": 169.0,
              "protein_g": 4.2,
              "fat_g": 5.7,
              "carbohydrate_g": 25.3,
              "serving_label": "1 plate",
              "serving_amount": 230.0,
              "serving_unit": "g",
              "source_database": "MyFCD 1997"
            }
          ]),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final foods = await FoodService.fetchMalaysianFoods(client: mockClient);
      expect(foods.length, equals(1));
      expect(requestedUri != null, isTrue);
      expect(requestedUri.toString(), contains('/api/v3/foods'));
      expect(requestedUri.toString(), contains('only_primary=true'));
      expect(requestedUri.toString(), contains('only_searchable=true'));
      expect(requestedUri.toString(), isNot(contains('/api/v1/foods')));
    });

    test('fetchMalaysianFoods uses cache namespace myfcd_food_catalog_v3 on repeated calls', () async {
      int httpCallsCount = 0;
      final mockClient = MockClient((request) async {
        httpCallsCount++;
        return http.Response(
          json.encode([
            {
              "identifier": "221019",
              "official_name": "RICE, COCONUT MILK (NASI LEMAK)",
              "display_name": "Nasi Lemak",
              "category": "Cereal based",
              "energy_kcal": 169.0,
              "protein_g": 4.2,
              "fat_g": 5.7,
              "carbohydrate_g": 25.3,
              "source_database": "MyFCD 1997"
            }
          ]),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final firstLoad = await FoodService.fetchMalaysianFoods(client: mockClient);
      expect(firstLoad.length, equals(1));
      expect(httpCallsCount, equals(1));

      // Second load must use memory cache without network call
      final secondLoad = await FoodService.fetchMalaysianFoods(client: mockClient);
      expect(secondLoad.length, equals(1));
      expect(httpCallsCount, equals(1));
    });
  });
}
