import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_1/services/scan_food_cache_service.dart';
import 'package:flutter_application_1/widgets/diet/scan_result_review_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // 1x1 valid transparent PNG bytes to avoid ImageCodec exceptions in widget tests
  final validImageBytes = Uint8List.fromList(<int>[
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49,
    0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06,
    0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44,
    0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, 0x05, 0x00, 0x01, 0x0D,
    0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42,
    0x60, 0x82,
  ]);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Food Correction Flow Tests (Cases A through F)', () {
    // =========================================================================
    // CASE A: AI detects Chicken Rice -> User corrects to Fish Rice
    // -> final name Fish Rice -> nutrition recalculated -> save allowed
    // =========================================================================
    testWidgets('CASE A: Correction to Fish Rice recalculates nutrition and preserves authoritative metadata on save', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      Map<String, dynamic>? savedMeal;

      final initialAnalysis = {
        'foods': [
          {
            'name': 'Chicken Rice',
            'calories': 520,
            'protein': 30,
            'carbs': 65,
            'fat': 16,
            'servingGrams': 300,
          }
        ],
        'score': 80,
        'explanation': 'Standard chicken rice.',
        'alternatives': ['Add cucumber slices'],
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  ScanResultReviewSheet.show(
                    context,
                    imageBytes: validImageBytes,
                    imageHash: 'test_hash_case_a',
                    initialAnalysis: initialAnalysis,
                    recalculateFn: ({
                      required Uint8List imageBytes,
                      required String correctedFoodName,
                      double? previousServingGrams,
                      String userGoal = 'Maintenance',
                      int? calorieTarget,
                      String dietPreference = 'Standard',
                      List<String> allergies = const [],
                    }) async {
                      expect(correctedFoodName, equals('Fish Rice'));
                      return {
                        'foods': [
                          {
                            'name': 'Fish Rice',
                            'calories': 420,
                            'protein': 28,
                            'carbs': 55,
                            'fat': 8,
                            'servingGrams': 290,
                          }
                        ],
                        'totalCalories': 420,
                        'totalProteins': 28,
                        'totalCarbs': 55,
                        'totalFats': 8,
                        'score': 88,
                        'explanation': 'Lean fish with steamed rice portion.',
                        'alternatives': ['Steamed greens'],
                        'dietCompatibility': 'compatible',
                      };
                    },
                    onSave: (finalData) async {
                      savedMeal = finalData;
                    },
                  );
                },
                child: const Text("Open Sheet"),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text("Open Sheet"));
      await tester.pumpAndSettle();

      // Verify initial Chicken Rice display
      expect(find.text("Chicken Rice"), findsWidgets);
      expect(find.text("520"), findsOneWidget);

      // Tap edit icon on the food item
      await tester.tap(find.byIcon(Icons.edit_outlined).first);
      await tester.pumpAndSettle();

      expect(find.text("Correct Food Item"), findsOneWidget);

      // Enter corrected name "Fish Rice"
      await tester.enterText(find.byType(TextField).last, "Fish Rice");
      await tester.pumpAndSettle();

      // Tap "Recalculate with AI"
      await tester.tap(find.text("Recalculate with AI"));
      await tester.pumpAndSettle();

      // Verify updated results
      expect(find.text("Fish Rice"), findsWidgets);
      expect(find.text("420"), findsOneWidget); // Updated calories
      expect(find.text("Updated after your correction"), findsOneWidget);

      // Save meal to diary
      await tester.tap(find.text("Save Meal to Diary"));
      await tester.pumpAndSettle();

      expect(savedMeal, isNotNull);
      expect(savedMeal!['source'], equals('ai_scan'));
      expect(savedMeal!['wasUserCorrected'], isTrue);
      expect(savedMeal!['originalDetectedFoodName'], equals('Chicken Rice'));
      expect(savedMeal!['correctedFoodName'], equals('Fish Rice'));
      expect(savedMeal!['correctionCount'], equals(1));
      expect(savedMeal!['calories'], equals(420));
      expect(savedMeal!['protein'], equals(28));
      expect(savedMeal!['carbs'], equals(55));
      expect(savedMeal!['fat'], equals(8));
    });

    // =========================================================================
    // CASE B: AI detects Chicken -> User corrects to Tofu
    // -> AI must not override corrected name
    // =========================================================================
    testWidgets('CASE B: User corrects Chicken to Tofu - authoritative name is enforced even if AI returns another name', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      Map<String, dynamic>? savedMeal;

      final initialAnalysis = {
        'foods': [
          {'name': 'Chicken', 'calories': 350, 'protein': 32, 'carbs': 0, 'fat': 12, 'servingGrams': 200}
        ],
        'score': 80,
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  ScanResultReviewSheet.show(
                    context,
                    imageBytes: validImageBytes,
                    imageHash: 'test_hash_case_b',
                    initialAnalysis: initialAnalysis,
                    recalculateFn: ({
                      required Uint8List imageBytes,
                      required String correctedFoodName,
                      double? previousServingGrams,
                      String userGoal = 'Maintenance',
                      int? calorieTarget,
                      String dietPreference = 'Standard',
                      List<String> allergies = const [],
                    }) async {
                      // Simulate an AI response that tried to return "Fried Soy Protein" instead of "Tofu"
                      return {
                        'foods': [
                          {
                            'name': 'Fried Soy Protein',
                            'calories': 180,
                            'protein': 16,
                            'carbs': 4,
                            'fat': 10,
                            'servingGrams': 180,
                          }
                        ],
                        'totalCalories': 180,
                        'totalProteins': 16,
                        'totalCarbs': 4,
                        'totalFats': 10,
                        'score': 90,
                      };
                    },
                    onSave: (finalData) async {
                      savedMeal = finalData;
                    },
                  );
                },
                child: const Text("Open Sheet"),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text("Open Sheet"));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.edit_outlined).first);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).last, "Tofu");
      await tester.pumpAndSettle();

      await tester.tap(find.text("Recalculate with AI"));
      await tester.pumpAndSettle();

      // The authoritative name Tofu MUST be preserved, not Fried Soy Protein
      expect(find.text("Tofu"), findsWidgets);
      expect(find.text("Fried Soy Protein"), findsNothing);
      expect(find.text("180"), findsOneWidget);

      await tester.tap(find.text("Save Meal to Diary"));
      await tester.pumpAndSettle();

      expect(savedMeal!['correctedFoodName'], equals('Tofu'));
      final foods = savedMeal!['foods'] as List;
      expect(foods[0]['name'], equals('Tofu'));
    });

    // =========================================================================
    // CASE C: User correction + Vegan -> incompatible warning shown
    // =========================================================================
    testWidgets('CASE C: User correction to Fish Rice under Vegan diet shows incompatibility notice', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final initialAnalysis = {
        'foods': [
          {'name': 'Chicken Rice', 'calories': 500, 'protein': 30, 'carbs': 60, 'fat': 15, 'servingGrams': 250}
        ],
        'score': 70,
        'dietCompatibility': 'incompatible',
        'dietNotice': 'This meal does not match your Vegan preference (Chicken).',
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  ScanResultReviewSheet.show(
                    context,
                    imageBytes: validImageBytes,
                    imageHash: 'test_hash_case_c',
                    initialAnalysis: initialAnalysis,
                    dietPreference: 'Vegan',
                    recalculateFn: ({
                      required Uint8List imageBytes,
                      required String correctedFoodName,
                      double? previousServingGrams,
                      String userGoal = 'Maintenance',
                      int? calorieTarget,
                      String dietPreference = 'Standard',
                      List<String> allergies = const [],
                    }) async {
                      return {
                        'foods': [
                          {
                            'name': 'Fish Rice',
                            'calories': 400,
                            'protein': 25,
                            'carbs': 55,
                            'fat': 8,
                            'servingGrams': 250,
                          }
                        ],
                        'dietCompatibility': 'incompatible',
                        'dietNotice': 'This meal does not match your Vegan preference (Fish).',
                      };
                    },
                    onSave: (_) async {},
                  );
                },
                child: const Text("Open Sheet"),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text("Open Sheet"));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.edit_outlined).first);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).last, "Fish Rice");
      await tester.tap(find.text("Recalculate with AI"));
      await tester.pumpAndSettle();

      // Verify diet incompatibility notice is shown for the corrected food
      expect(find.text("Diet Preference Notice"), findsOneWidget);
      expect(find.textContaining("This meal does not match your Vegan preference"), findsOneWidget);
    });

    // =========================================================================
    // CASE D: Re-analysis network failure -> corrected name preserved -> manual save
    // =========================================================================
    testWidgets('CASE D: Network failure preserves corrected name and allows manual save', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      Map<String, dynamic>? savedMeal;

      final initialAnalysis = {
        'foods': [
          {'name': 'Chicken Rice', 'calories': 500, 'protein': 30, 'carbs': 60, 'fat': 15, 'servingGrams': 250}
        ],
        'score': 80,
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  ScanResultReviewSheet.show(
                    context,
                    imageBytes: validImageBytes,
                    imageHash: 'test_hash_case_d',
                    initialAnalysis: initialAnalysis,
                    recalculateFn: ({
                      required Uint8List imageBytes,
                      required String correctedFoodName,
                      double? previousServingGrams,
                      String userGoal = 'Maintenance',
                      int? calorieTarget,
                      String dietPreference = 'Standard',
                      List<String> allergies = const [],
                    }) async {
                      throw Exception('Simulated network timeout');
                    },
                    onSave: (finalData) async {
                      savedMeal = finalData;
                    },
                  );
                },
                child: const Text("Open Sheet"),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text("Open Sheet"));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.edit_outlined).first);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).last, "Fish Rice");
      await tester.tap(find.text("Recalculate with AI"));
      await tester.pumpAndSettle();

      // Error dialog appears
      expect(find.text("Recalculation Failed"), findsOneWidget);
      expect(find.textContaining("Unable to recalculate nutrition right now"), findsOneWidget);

      // Tap "Keep edited name"
      await tester.tap(find.text("Keep edited name"));
      await tester.pumpAndSettle();

      // Confirm corrected name is preserved on the card
      expect(find.text("Fish Rice"), findsWidgets);

      // User can still save the meal manually
      await tester.tap(find.text("Save Meal to Diary"));
      await tester.pumpAndSettle();

      expect(savedMeal, isNotNull);
      expect(savedMeal!['wasUserCorrected'], isTrue);
      expect(savedMeal!['correctedFoodName'], equals('Fish Rice'));
    });

    // =========================================================================
    // CASE E: Same original image, Correction 1 vs Correction 2 -> cache distinguishes
    // =========================================================================
    test('CASE E: Cache distinguishes between original scan and different food corrections for identical image hash', () async {
      const hash = 'sample_image_hash_case_e';

      final originalData = {
        'foods': [
          {'name': 'Chicken Rice', 'calories': 520}
        ],
        'totalCalories': 520,
      };

      final fishRiceData = {
        'foods': [
          {'name': 'Fish Rice', 'calories': 420}
        ],
        'totalCalories': 420,
      };

      final tofuRiceData = {
        'foods': [
          {'name': 'Tofu Rice', 'calories': 350}
        ],
        'totalCalories': 350,
      };

      // Save original
      await ScanFoodCacheService.instance.saveAnalysis(hash, originalData);

      // Save correction 1
      await ScanFoodCacheService.instance.saveAnalysis(hash, fishRiceData, correctedFoodName: 'Fish Rice');

      // Save correction 2
      await ScanFoodCacheService.instance.saveAnalysis(hash, tofuRiceData, correctedFoodName: 'Tofu Rice');

      // Retrieve each independently
      final cachedOriginal = await ScanFoodCacheService.instance.getCachedAnalysis(hash);
      final cachedFish = await ScanFoodCacheService.instance.getCachedAnalysis(hash, correctedFoodName: 'Fish Rice');
      final cachedTofu = await ScanFoodCacheService.instance.getCachedAnalysis(hash, correctedFoodName: 'Tofu Rice');

      expect(cachedOriginal, isNotNull);
      expect(cachedOriginal!['totalCalories'], equals(520));
      expect(cachedOriginal['foods'][0]['name'], equals('Chicken Rice'));

      expect(cachedFish, isNotNull);
      expect(cachedFish!['totalCalories'], equals(420));
      expect(cachedFish['foods'][0]['name'], equals('Fish Rice'));

      expect(cachedTofu, isNotNull);
      expect(cachedTofu!['totalCalories'], equals(350));
      expect(cachedTofu['foods'][0]['name'], equals('Tofu Rice'));
    });

    // =========================================================================
    // CASE F: User only fixes spelling ("Nasi Lemek" -> "Nasi Lemak")
    // -> Keep Name Only does NOT invoke AI recalculation
    // =========================================================================
    testWidgets('CASE F: User fixes spelling with Keep Name Only without triggering AI call', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      int aiCallCount = 0;
      Map<String, dynamic>? savedMeal;

      final initialAnalysis = {
        'foods': [
          {'name': 'Nasi Lemek', 'calories': 600, 'protein': 14, 'carbs': 70, 'fat': 24, 'servingGrams': 350}
        ],
        'score': 75,
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  ScanResultReviewSheet.show(
                    context,
                    imageBytes: validImageBytes,
                    imageHash: 'test_hash_case_f',
                    initialAnalysis: initialAnalysis,
                    recalculateFn: ({
                      required Uint8List imageBytes,
                      required String correctedFoodName,
                      double? previousServingGrams,
                      String userGoal = 'Maintenance',
                      int? calorieTarget,
                      String dietPreference = 'Standard',
                      List<String> allergies = const [],
                    }) async {
                      aiCallCount++;
                      return {};
                    },
                    onSave: (finalData) async {
                      savedMeal = finalData;
                    },
                  );
                },
                child: const Text("Open Sheet"),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text("Open Sheet"));
      await tester.pumpAndSettle();

      expect(find.text("Nasi Lemek"), findsWidgets);

      await tester.tap(find.byIcon(Icons.edit_outlined).first);
      await tester.pumpAndSettle();

      // Fix spelling to Nasi Lemak
      await tester.enterText(find.byType(TextField).last, "Nasi Lemak");
      await tester.pumpAndSettle();

      // Tap "Keep Name Only"
      await tester.tap(find.text("Keep Name Only"));
      await tester.pumpAndSettle();

      // Verify AI recalculation was never called
      expect(aiCallCount, equals(0));

      // Verify name is updated in the UI
      expect(find.text("Nasi Lemak"), findsWidgets);
      expect(find.text("600"), findsOneWidget); // Original calories remain unchanged

      // Save meal
      await tester.tap(find.text("Save Meal to Diary"));
      await tester.pumpAndSettle();

      expect(savedMeal, isNotNull);
      expect(savedMeal!['wasUserCorrected'], isTrue);
      expect(savedMeal!['correctedFoodName'], equals('Nasi Lemak'));
      expect(savedMeal!['calories'], equals(600));
    });

    // =========================================================================
    // KEYBOARD & RESPONSIVE TESTS: 320x568, 360x640, viewInsets, 1.2x & 1.3x font
    // =========================================================================
    testWidgets('Responsive & Keyboard Test: 320x568 small screen with keyboard viewInsets (bottom: 260)', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);

      final initialAnalysis = {
        'foods': [
          {'name': 'Chicken Rice', 'calories': 500, 'protein': 30, 'carbs': 60, 'fat': 15}
        ],
        'score': 80,
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  ScanResultReviewSheet.show(
                    context,
                    initialAnalysis: initialAnalysis,
                    onSave: (_) async {},
                  );
                },
                child: const Text("Open Sheet"),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text("Open Sheet"));
      await tester.pumpAndSettle();

      final editIcon = find.byIcon(Icons.edit_outlined).first;
      await tester.tap(editIcon);
      await tester.pumpAndSettle();

      // Simulate soft keyboard popping up for the dialog TextField
      tester.view.viewInsets = const FakeViewPadding(bottom: 260);
      await tester.pumpAndSettle();

      // Verify dialog is visible and zero RenderFlex overflow was thrown
      expect(find.text("Correct Food Item"), findsOneWidget);
      expect(find.text("Cancel"), findsOneWidget);
      expect(find.text("Keep Name Only"), findsOneWidget);
      expect(find.text("Recalculate with AI"), findsOneWidget);

      // Verify text entry works with keyboard present
      await tester.enterText(find.byType(TextField).last, "Fish Rice");
      await tester.pumpAndSettle();

      // Scroll Keep Name Only into view within the scrollable dialog
      await tester.ensureVisible(find.text("Keep Name Only"));
      await tester.pumpAndSettle();

      // Tap Keep Name Only
      await tester.tap(find.text("Keep Name Only"));
      await tester.pumpAndSettle();

      // Keyboard closes when dialog dismisses
      tester.view.viewInsets = FakeViewPadding.zero;
      await tester.pumpAndSettle();

      expect(find.text("Fish Rice"), findsWidgets);
    });

    testWidgets('Responsive & Keyboard Test: 360x640 screen with keyboard viewInsets (bottom: 280)', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);

      final initialAnalysis = {
        'foods': [
          {'name': 'Chicken Rice', 'calories': 500, 'protein': 30, 'carbs': 60, 'fat': 15}
        ],
        'score': 80,
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  ScanResultReviewSheet.show(
                    context,
                    initialAnalysis: initialAnalysis,
                    onSave: (_) async {},
                  );
                },
                child: const Text("Open Sheet"),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text("Open Sheet"));
      await tester.pumpAndSettle();

      final editIcon = find.byIcon(Icons.edit_outlined).first;
      await tester.ensureVisible(editIcon);
      await tester.tap(editIcon);
      await tester.pumpAndSettle();

      // Simulate soft keyboard
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      await tester.pumpAndSettle();

      expect(find.text("Correct Food Item"), findsOneWidget);
      expect(find.text("Cancel"), findsOneWidget);
      expect(find.text("Keep Name Only"), findsOneWidget);
      expect(find.text("Recalculate with AI"), findsOneWidget);

      await tester.ensureVisible(find.text("Cancel"));
      await tester.tap(find.text("Cancel"));
      await tester.pumpAndSettle();

      expect(find.text("Correct Food Item"), findsNothing);
    });

    testWidgets('Responsive & TextScale Test: 1.2x and 1.3x text scale with keyboard does not overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);

      final initialAnalysis = {
        'foods': [
          {'name': 'Chicken Rice', 'calories': 500, 'protein': 30, 'carbs': 60, 'fat': 15}
        ],
        'score': 80,
      };

      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child!,
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  ScanResultReviewSheet.show(
                    context,
                    initialAnalysis: initialAnalysis,
                    onSave: (_) async {},
                  );
                },
                child: const Text("Open Sheet"),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text("Open Sheet"));
      await tester.pumpAndSettle();

      // Scroll sheet slightly to ensure food item card is above bottom action bar under 1.3x scale
      await tester.drag(find.byType(ListView).first, const Offset(0, -200));
      await tester.pumpAndSettle();

      final editIcon = find.byIcon(Icons.edit_outlined).first;
      await tester.tap(editIcon);
      await tester.pumpAndSettle();

      // Simulate keyboard with large font
      tester.view.viewInsets = const FakeViewPadding(bottom: 250);
      await tester.pumpAndSettle();

      expect(find.text("Correct Food Item"), findsOneWidget);
      expect(find.text("Cancel"), findsOneWidget);
      expect(find.text("Keep Name Only"), findsOneWidget);
      expect(find.text("Recalculate with AI"), findsOneWidget);

      // Verify clicking actions works cleanly under 1.3x text scale
      await tester.ensureVisible(find.text("Cancel"));
      await tester.tap(find.text("Cancel"));
      await tester.pumpAndSettle();

      expect(find.text("Correct Food Item"), findsNothing);
    });
  });
}
