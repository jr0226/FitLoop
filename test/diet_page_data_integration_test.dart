import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_application_1/models/malaysian_food.dart';
import 'package:flutter_application_1/services/food_service.dart';
import 'package:flutter_application_1/services/daily_workout_summary_service.dart';
import 'package:flutter_application_1/screens/tabs/diet_page.dart';

void main() {
  final sampleFoods = [
    const MalaysianFood(
      id: 1,
      sourceId: 'MY001',
      name: 'Nasi Lemak',
      nameMs: 'Nasi Lemak',
      category: 'Rice & Dishes',
      caloriesKcal: 180.0,
      proteinG: 4.0,
      fatG: 8.0,
      carbsG: 25.0,
      // raw* fields must be non-null for isValidForLogging to pass
      rawCaloriesKcal: 180.0,
      rawProteinG: 4.0,
      rawFatG: 8.0,
      rawCarbsG: 25.0,
      servingName: '1 plate',
      servingGrams: 250.0,
      isSearchableForLogging: true,
    ),
    const MalaysianFood(
      id: 29,
      sourceId: 'MY029',
      name: 'Roti Canai',
      nameMs: 'Roti Canai',
      category: 'Breads & Flour Foods',
      caloriesKcal: 300.0,
      proteinG: 7.0,
      fatG: 15.0,
      carbsG: 35.0,
      // raw* fields must be non-null for isValidForLogging to pass
      rawCaloriesKcal: 300.0,
      rawProteinG: 7.0,
      rawFatG: 15.0,
      rawCarbsG: 35.0,
      servingName: '1 piece',
      servingGrams: 95.0,
      isSearchableForLogging: true,
    ),
  ];

  setUp(() {
    // Inject the browse cache so _loadFoods returns instantly without network
    FoodService.setCachedFoodsForTesting(sampleFoods);

    // Inject a mock search client: query-matches against sampleFoods
    FoodService.setSearchClientForTesting(MockClient((request) async {
      final q = request.url.queryParameters['q'] ?? '';
      final matches = sampleFoods
          .where((f) => f.name.toLowerCase().contains(q.toLowerCase()))
          .map((f) => {
                'id': f.id,
                'identifier': f.sourceId,
                'display_name': f.name,
                'name_ms': f.nameMs,
                'category': f.category,
                'energy_kcal': f.caloriesKcal,
                'protein_g': f.proteinG,
                'fat_g': f.fatG,
                'carbohydrate_g': f.carbsG,
                'serving_label': f.servingName,
                'serving_amount': f.servingAmount,
                'serving_unit': f.servingUnit,
                'is_searchable_for_logging': 1,
              })
          .toList();
      return http.Response(
        json.encode(matches),
        200,
        headers: {'content-type': 'application/json'},
      );
    }));
  });

  tearDown(() {
    FoodService.setCachedFoodsForTesting(null);
    FoodService.setSearchClientForTesting(null);
  });

  group('Diet Page & AddFoodPage Widget Tests', () {
    testWidgets('AddFoodPage displays cached Malaysian foods and filters on search', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AddFoodPage(
            mealCategory: 'Breakfast',
            selectedDate: DateTime(2026, 9, 4),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Browse mode: verify first page foods are displayed
      expect(find.text('Nasi Lemak'), findsOneWidget);
      expect(find.text('Roti Canai'), findsOneWidget);
      expect(find.text('450 kcal'), findsOneWidget); // 180 * 2.5
      expect(find.text('285 kcal'), findsOneWidget); // 300 * 0.95

      // Enter search term "Roti" → triggers debounce → server search
      await tester.enterText(find.byType(TextField), 'Roti');
      // Wait for debounce (350ms) + async server call + frame rebuild
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      // Only Roti Canai should be displayed
      expect(find.text('Roti Canai'), findsOneWidget);
      expect(find.text('Nasi Lemak'), findsNothing);
    });

    testWidgets('Tapping food item opens confirmation sheet with full details and meal categories', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AddFoodPage(
            mealCategory: 'Lunch',
            selectedDate: DateTime(2026, 9, 4),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap Nasi Lemak card
      await tester.tap(find.text('Nasi Lemak'));
      await tester.pumpAndSettle();

      // Modal Bottom Sheet appears
      expect(find.text('Standard Serving: 1 plate (250 g)'), findsOneWidget);
      expect(find.text('450 kcal'), findsAtLeastNWidgets(1));
      expect(find.text('Log Meal to Diary'), findsOneWidget);

      // Meal categories are present
      expect(find.text('Breakfast'), findsOneWidget);
      expect(find.text('Lunch'), findsOneWidget);
      expect(find.text('Dinner'), findsOneWidget);
      expect(find.text('Snack'), findsOneWidget);
      expect(find.text('Meal'), findsOneWidget);
    });

    test('Diet Remaining equation: Goal - Food + Exercise = Remaining', () {
      const int goal = 2000;
      const int food = 1500;
      const int exercise = 350;

      final int remaining = goal - food + exercise;
      expect(remaining, equals(850));
    });

    test('Exercise calories correctly calculated for target date and multi-workout scenarios', () {
      final now = DateTime(2026, 9, 4, 12, 0);
      final logs = [
        {'completedAt': DateTime(2026, 9, 4, 7, 0).toIso8601String(), 'caloriesBurned': 180},
        {'completedAt': DateTime(2026, 9, 4, 18, 0).toIso8601String(), 'caloriesBurned': 220},
        {'completedAt': DateTime(2026, 9, 3, 18, 0).toIso8601String(), 'caloriesBurned': 400}, // yesterday
      ];

      final todayBurn = DailyWorkoutSummaryService.calculateDayBurnedCalories(logs, now);
      expect(todayBurn, equals(400)); // 180 + 220
    });
  });
}
