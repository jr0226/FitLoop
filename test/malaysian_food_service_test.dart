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
  });

  group('FoodService Local Search & Caching Tests', () {
    final sampleDataset = [
      MalaysianFood(
        id: 1,
        sourceId: 'MY001',
        name: 'Nasi Lemak',
        nameMs: 'Nasi Lemak',
        category: 'Rice & Dishes',
        caloriesKcal: 180.0,
        proteinG: 4.0,
        fatG: 8.0,
        carbsG: 25.0,
        servingName: '1 plate',
        servingGrams: 250.0,
      ),
      MalaysianFood(
        id: 2,
        sourceId: 'MY002',
        name: 'Nasi Lemak Ayam Goreng',
        nameMs: 'Nasi Lemak Ayam Goreng',
        category: 'Rice & Dishes',
        caloriesKcal: 210.0,
        proteinG: 8.5,
        fatG: 9.5,
        carbsG: 23.0,
        servingName: '1 plate',
        servingGrams: 350.0,
      ),
      MalaysianFood(
        id: 3,
        sourceId: 'MY003',
        name: 'Chicken Rice',
        nameMs: 'Nasi Ayam',
        category: 'Rice & Dishes',
        caloriesKcal: 190.0,
        proteinG: 10.0,
        fatG: 6.0,
        carbsG: 24.0,
        servingName: '1 plate',
        servingGrams: 280.0,
      ),
      MalaysianFood(
        id: 29,
        sourceId: 'MY029',
        name: 'Roti Canai',
        nameMs: 'Roti Canai',
        category: 'Breads & Flour Foods',
        caloriesKcal: 300.0,
        proteinG: 7.0,
        fatG: 15.0,
        carbsG: 35.0,
        servingName: '1 piece',
        servingGrams: 95.0,
      ),
      MalaysianFood(
        id: 15,
        sourceId: 'MY015',
        name: 'Mee Goreng Mamak',
        nameMs: 'Mee Goreng Mamak',
        category: 'Noodles & Rice Noodles',
        caloriesKcal: 210.0,
        proteinG: 7.0,
        fatG: 8.0,
        carbsG: 30.0,
        servingName: '1 plate',
        servingGrams: 300.0,
      ),
    ];

    setUp(() {
      FoodService.setCachedFoodsForTesting(null);
    });

    test('searchLocalFoods ranks exact match first', () {
      final results = FoodService.searchLocalFoods(
        'Nasi Lemak',
        dataset: sampleDataset,
      );
      expect(results.isNotEmpty, isTrue);
      expect(results.first.name, equals('Nasi Lemak'));
      expect(results.length, greaterThanOrEqualTo(2));
    });

    test('searchLocalFoods matches Malay name (name_ms) cross-lingually', () {
      // Searching "nasi ayam" should find "Chicken Rice" (nameMs: "Nasi Ayam")
      final results = FoodService.searchLocalFoods(
        'nasi ayam',
        dataset: sampleDataset,
      );
      expect(results.any((f) => f.name == 'Chicken Rice'), isTrue);
    });

    test('searchLocalFoods matches category', () {
      final results = FoodService.searchLocalFoods(
        'Noodles',
        dataset: sampleDataset,
      );
      expect(results.any((f) => f.name == 'Mee Goreng Mamak'), isTrue);
    });

    test('searchLocalFoods returns empty list for completely unmatched query', () {
      final results = FoodService.searchLocalFoods(
        'pizzaquichexyz',
        dataset: sampleDataset,
      );
      expect(results, isEmpty);
    });

    test('fetchMalaysianFoods caches in memory and reuses without second HTTP call', () async {
      int httpCallsCount = 0;
      final mockClient = MockClient((request) async {
        httpCallsCount++;
        return http.Response(
          json.encode([
            {
              "id": 1,
              "source_id": "MY001",
              "name": "Nasi Lemak",
              "name_ms": "Nasi Lemak",
              "category": "Rice & Dishes",
              "calories_kcal": 180.0,
              "protein_g": 4.0,
              "fat_g": 8.0,
              "carbs_g": 25.0,
              "serving_name": "1 plate",
              "serving_grams": 250.0,
            }
          ]),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final firstLoad = await FoodService.fetchMalaysianFoods(client: mockClient);
      expect(firstLoad.length, equals(1));
      expect(httpCallsCount, equals(1));

      // Second call should return from memory cache without invoking mockClient
      final secondLoad = await FoodService.fetchMalaysianFoods(client: mockClient);
      expect(secondLoad.length, equals(1));
      expect(httpCallsCount, equals(1)); // Still 1!
    });
  });
}
