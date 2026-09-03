import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/widgets/diet/meal_detail_sheet.dart';

void main() {
  final List<double> screenWidths = [320.0, 360.0, 390.0, 412.0];
  const longName1 = "McDonald's French Fries (Large)";
  const longName2 = "Grilled Chicken Breast with Black Pepper Sauce";
  const longName3 = "Mixed Roasted Duck, Char Siew and Roasted Chicken Rice";

  for (final width in screenWidths) {
    testWidgets('Renders long food names at ${width}px width with 1.2 text scale without overflow', (WidgetTester tester) async {
      tester.view.physicalSize = Size(width * 2, 1200 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final meal = {
        'id': 'test_meal_1',
        'name': longName3,
        'mealType': 'Dinner',
        'calories': 780,
        'protein': 45,
        'carbs': 85,
        'fat': 24,
        'fibre': 4.5,
        'sugar': 2.1,
        'sodium': 450.0,
        'mealScore': 82,
        'scoreExplanation': 'Hearty post-workout dinner rich in high-quality protein.',
        'foods': [
          {
            'name': longName1,
            'calories': 365,
            'protein': 4,
            'carbs': 48,
            'fat': 17,
            'servingGrams': 117,
            'nutritionSource': 'malaysian_db',
          },
          {
            'name': longName2,
            'calories': 415,
            'protein': 41,
            'carbs': 37,
            'fat': 7,
            'servingGrams': 250,
          },
        ],
      };

      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(1.2),
            ),
            child: child!,
          ),
          home: Scaffold(
            body: MealDetailSheet(meal: meal),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify meal name and first food item are present and properly rendered
      expect(find.text(longName3), findsOneWidget);
      await tester.scrollUntilVisible(find.text(longName1), 100);
      expect(find.text(longName1), findsOneWidget);

      // Verify no RenderFlex overflow exceptions occurred at this width
      expect(tester.takeException(), isNull);
    });
  }
}
