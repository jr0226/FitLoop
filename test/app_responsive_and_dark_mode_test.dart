import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/theme/app_theme.dart';
import 'package:flutter_application_1/widgets/diet/meal_detail_sheet.dart';
import 'package:flutter_application_1/widgets/diet/food_delete_dialog.dart';
import 'package:flutter_application_1/widgets/workout/daily_routine_card.dart';
import 'package:flutter_application_1/models/workout_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildTestHost({
    required Widget child,
    required Size screenSize,
    required double textScale,
    required ThemeData theme,
  }) {
    return MediaQuery(
      data: MediaQueryData(
        size: screenSize,
        textScaler: TextScaler.linear(textScale),
      ),
      child: MaterialApp(
        theme: theme,
        home: Scaffold(body: child),
      ),
    );
  }

  group('Responsive UI & Dark Mode Hardening Tests', () {
    final screenSizes = [
      const Size(320, 640), // Small Android (320px)
      const Size(360, 780), // Standard Android
      const Size(390, 844), // iPhone 12/13/14
      const Size(412, 915), // Pixel / Large phone
    ];

    final textScales = [1.0, 1.2, 1.3];

    for (final size in screenSizes) {
      for (final scale in textScales) {
        testWidgets('DailyRoutineCard renders without overflow at ${size.width}x${size.height} (scale: $scale)', (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);

          final routine = WorkoutRoutine(
            id: 'test_routine_1',
            title: 'Full Body High Intensity Hypertrophy Training Routine',
            subtitle: 'Build muscle and accelerate metabolic rate through progressive overload',
            category: 'Full Body',
            level: FitnessLevel.intermediate,
            goal: UserGoalTag.muscleGain,
            durationMinutes: 45,
            estimatedCalories: 380,
            exercises: const [
              ExerciseModel(id: 'ex1', name: 'Barbell Squats', targetMuscle: 'Quads', equipment: 'Barbell'),
              ExerciseModel(id: 'ex2', name: 'Dumbbell Bench Press', targetMuscle: 'Chest', equipment: 'Dumbbell'),
            ],
          );

          await tester.pumpWidget(
            buildTestHost(
              screenSize: size,
              textScale: scale,
              theme: AppTheme.darkTheme,
              child: SingleChildScrollView(
                child: DailyRoutineCard(
                  routine: routine,
                  onStart: () {},
                ),
              ),
            ),
          );

          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.text('Full Body High Intensity Hypertrophy Training Routine'), findsOneWidget);
        });
      }
    }

    testWidgets('MealDetailSheet renders properly in Dark Mode without hardcoded black text on dark background', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final mealData = {
        'foodName': 'Nasi Lemak Special with Sambal Sotong and Fried Chicken',
        'calories': 680,
        'protein': 25,
        'carbs': 82,
        'fat': 28,
        'serving': '1 plate (350g)',
        'source': 'Malaysian Food Database',
        'dietitianInsight': 'Rich in energy and protein, but consider reducing coconut milk intake for lower saturated fat.',
      };

      await tester.pumpWidget(
        buildTestHost(
          screenSize: const Size(360, 800),
          textScale: 1.0,
          theme: AppTheme.darkTheme,
          child: MealDetailSheet(
            meal: mealData,
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Nasi Lemak Special with Sambal Sotong and Fried Chicken'), findsOneWidget);
      expect(find.text('MALAYSIAN DB'), findsWidgets);
      expect(find.text('Nutrition Source: Malaysian Food Database'), findsOneWidget);
      expect(find.text('Informational nutrition estimate. Not intended as medical or clinical dietary advice.'), findsOneWidget);
    });

    testWidgets('MealDetailSheet renders AI Image Estimate source card correctly', (tester) async {
      final mealData = {
        'name': 'Chicken Rice',
        'calories': 500,
        'protein': 30,
        'carbs': 60,
        'fat': 15,
        'source': 'ai_scan',
        'nutritionSource': 'ai_scan',
      };

      await tester.pumpWidget(
        buildTestHost(
          screenSize: const Size(360, 800),
          textScale: 1.0,
          theme: AppTheme.lightTheme,
          child: MealDetailSheet(
            meal: mealData,
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Chicken Rice'), findsOneWidget);
      expect(find.text('AI SCAN'), findsWidgets);
      expect(find.text('Nutrition Source: AI Image Estimate'), findsOneWidget);
      expect(find.text('Informational nutrition estimate. Not intended as medical or clinical dietary advice.'), findsOneWidget);
    });

    testWidgets('Food delete dialog responds to Dark Mode surfaces', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => showFoodDeleteConfirmationDialog(ctx, foodName: 'Chicken Rice'),
                child: const Text('Delete Food'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Delete Food'));
      await tester.pumpAndSettle();

      expect(find.text('Delete meal?'), findsOneWidget);
      expect(find.text('Chicken Rice'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Delete meal?'), findsNothing);
    });
  });
}
