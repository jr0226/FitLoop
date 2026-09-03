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

    // Rename Chicken Rice to Roasted Chicken Rice
    await tester.tap(find.byIcon(Icons.edit_outlined).first);
    await tester.pumpAndSettle();
    expect(find.text("Rename Item"), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, "Roasted Chicken Rice");
    await tester.tap(find.text("Update"));
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
}
