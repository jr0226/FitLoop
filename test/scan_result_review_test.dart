import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/widgets/diet/scan_result_review_sheet.dart';

void main() {
  testWidgets('ScanResultReviewSheet calculates totals, allows item deletion and portion adjustments', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Map<String, dynamic>? savedMeal;

    final initialAnalysis = {
      'foods': [
        {
          'name': 'Chicken Rice',
          'calories': 500,
          'protein': 30,
          'carbs': 60,
          'fat': 15,
          'servingGrams': 280,
        },
        {
          'name': 'Fried Egg',
          'calories': 90,
          'protein': 6,
          'carbs': 1,
          'fat': 7,
          'servingGrams': 50,
        },
      ],
      'score': 85,
      'explanation': 'Good protein source.',
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
                  initialAnalysis: initialAnalysis,
                  onSave: (finalData) async {
                    savedMeal = finalData;
                  },
                );
              },
              child: const Text("Open Review Sheet"),
            ),
          ),
        ),
      ),
    );

    // Open sheet
    await tester.tap(find.text("Open Review Sheet"));
    await tester.pumpAndSettle();

    // Verify initial display: Total calories = 500 + 90 = 590
    expect(find.text("590"), findsOneWidget);
    expect(find.text("Chicken Rice"), findsWidgets);
    expect(find.text("Fried Egg"), findsOneWidget);
    expect(find.text("Estimated serving: 280 g"), findsOneWidget);
    expect(find.text("Estimated serving: 50 g"), findsOneWidget);

    // Verify portion multiplier controls are completely removed
    expect(find.text("0.5x"), findsNothing);
    expect(find.text("1.0x (Normal)"), findsNothing);
    expect(find.text("1.5x"), findsNothing);
    expect(find.text("2.0x"), findsNothing);

    // Remove Fried Egg (tap its delete icon)
    final deleteIcons = find.byIcon(Icons.delete_outline);
    expect(deleteIcons, findsNWidgets(2));
    await tester.tap(deleteIcons.last);
    await tester.pumpAndSettle();

    // Now only Chicken Rice remains, total calories should be 500
    expect(find.text("500"), findsOneWidget);
    expect(find.text("Fried Egg"), findsNothing);

    // Rename Chicken Rice to Roasted Chicken Rice via food correction dialog
    await tester.tap(find.byIcon(Icons.edit_outlined).first);
    await tester.pumpAndSettle();
    expect(find.text("Correct Food Item"), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, "Roasted Chicken Rice");
    await tester.tap(find.text("Keep Name Only"));
    await tester.pumpAndSettle();

    expect(find.text("Roasted Chicken Rice"), findsWidgets);

    // Save meal to diary
    await tester.tap(find.text("Save Meal to Diary"));
    await tester.pumpAndSettle();

    // Verify callback payload
    expect(savedMeal, isNotNull);
    expect(savedMeal!['source'], equals('ai_scan'));
    expect(savedMeal!['nutritionSource'], equals('ai_scan'));
    expect(savedMeal!['calories'], equals(500));
    expect(savedMeal!['protein'], equals(30));
    expect((savedMeal!['foods'] as List).length, equals(1));
    expect((savedMeal!['foods'] as List)[0]['name'], equals("Roasted Chicken Rice"));
  });

  testWidgets('ScanResultReviewSheet displays Diet Preference Notice and allows save for incompatible meal', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Map<String, dynamic>? savedMeal;

    final initialAnalysis = {
      'foods': [
        {
          'name': 'Chicken Rice',
          'calories': 520,
          'protein': 28,
          'carbs': 65,
          'fat': 14,
          'servingGrams': 280,
        },
      ],
      'score': 80,
      'explanation': 'Balanced meal with high carbohydrates.',
      'alternatives': ['Tofu Rice Bowl', 'Tempeh Salad'],
      'dietCompatibility': 'incompatible',
      'dietNotice': 'This meal does not match your Vegan preference.',
      'allergyNotice': 'This meal may contain ingredients related to your listed allergy (Peanuts). Image analysis cannot verify hidden ingredients or cross-contamination.',
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

    // 1. Verify recognition remains factual (Chicken Rice, not renamed)
    expect(find.text("Chicken Rice"), findsWidgets);

    // 2. Verify Diet Preference Notice is shown
    expect(find.text("Diet Preference Notice"), findsOneWidget);
    expect(find.text("This meal does not match your Vegan preference."), findsOneWidget);

    // 3. Verify Allergy Notice is shown
    expect(find.text("Allergy Notice"), findsOneWidget);
    expect(find.textContaining("related to your listed allergy (Peanuts)"), findsOneWidget);

    // 4. Verify Alternatives follow vegan preference
    expect(find.text("Tofu Rice Bowl"), findsOneWidget);
    expect(find.text("Tempeh Salad"), findsOneWidget);

    // 5. Verify Save is NOT blocked
    await tester.tap(find.text("Save Meal to Diary"));
    await tester.pumpAndSettle();

    expect(savedMeal, isNotNull);
    expect(savedMeal!['dietCompatibility'], equals('incompatible'));
    expect(savedMeal!['dietNotice'], equals('This meal does not match your Vegan preference.'));
    expect(savedMeal!['allergyNotice'], contains('Peanuts'));
  });

  testWidgets('ScanResultReviewSheet does NOT display diet notice when meal is compatible', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final initialAnalysis = {
      'foods': [
        {
          'name': 'Grilled Fish',
          'calories': 300,
          'protein': 35,
          'carbs': 0,
          'fat': 12,
          'servingGrams': 200,
        },
      ],
      'score': 90,
      'explanation': 'Excellent lean protein meal.',
      'alternatives': ['Steamed Salmon'],
      'dietCompatibility': 'compatible',
      'dietNotice': null,
      'allergyNotice': null,
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
                  onSave: (finalData) async {},
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

    expect(find.text("Grilled Fish"), findsWidgets);
    expect(find.text("Diet Preference Notice"), findsNothing);
    expect(find.text("Allergy Notice"), findsNothing);
  });
}
