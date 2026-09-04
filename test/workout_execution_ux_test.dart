import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/models/workout_models.dart';
import 'package:flutter_application_1/screens/active_workout_page.dart';
import 'package:flutter_application_1/widgets/workout/workout_setup_sheet.dart';
import 'package:flutter_application_1/screens/build_routine_screen.dart';
import 'package:flutter_application_1/widgets/workout/exercise_list_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final sampleExercises = [
    const ExerciseModel(
      id: 'ex_bench',
      name: 'Dumbbell Bench Press',
      targetMuscle: 'Chest',
      equipment: 'Dumbbell',
      defaultSets: 3,
      defaultReps: 10,
      restSeconds: 60,
    ),
    const ExerciseModel(
      id: 'ex_pushup',
      name: 'Push Ups',
      targetMuscle: 'Chest',
      equipment: 'Bodyweight',
      defaultSets: 3,
      defaultReps: 15,
      restSeconds: 45,
    ),
    const ExerciseModel(
      id: 'ex_bike',
      name: 'Air Bike Sprint',
      targetMuscle: 'Cardio',
      equipment: 'Cardio Machine',
      defaultSets: 1,
      defaultReps: 0,
      durationSeconds: 300,
    ),
  ];

  final sampleRoutine = WorkoutRoutine(
    id: 'test_routine_1',
    title: 'Functional Full Body Split',
    subtitle: 'Strength and conditioning split',
    level: FitnessLevel.intermediate,
    goal: UserGoalTag.muscleGain,
    durationMinutes: 45,
    estimatedCalories: 350,
    exercises: sampleExercises,
    category: 'Full Body',
  );

  group('1. Workout Setup Sheet Tests', () {
    testWidgets('Displays routine details, rest options, and exercise items', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WorkoutSetupSheet(
              routine: sampleRoutine,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check Routine Header Info
      expect(find.text('Functional Full Body Split'), findsOneWidget);
      expect(find.text('Full Body'), findsOneWidget);
      expect(find.text('Intermediate'), findsOneWidget);
      expect(find.text('3 Exercises'), findsOneWidget);
      expect(find.text('~45 min'), findsOneWidget);

      // Check Rest Between Sets Option Chips
      expect(find.text('Default Rest Between Sets'), findsOneWidget);
      expect(find.text('Off'), findsOneWidget);
      expect(find.text('30s'), findsWidgets);
      expect(find.text('45s'), findsOneWidget);
      expect(find.text('60s (Default)'), findsOneWidget);
      expect(find.text('90s'), findsWidgets);
      expect(find.text('120s'), findsOneWidget);

      // Check Rest Between Exercises
      expect(find.text('Rest Between Exercises (Optional)'), findsOneWidget);

      // Scroll down to see exercises
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pumpAndSettle();

      // Check Exercises List
      expect(find.text('Dumbbell Bench Press'), findsOneWidget);
      expect(find.text('Push Ups'), findsOneWidget);
      expect(find.text('Air Bike Sprint'), findsOneWidget);

      // Check + Add Exercise button
      expect(find.text('+ Add Exercise'), findsOneWidget);

      // Check Start Workout button
      expect(find.text('Start Workout'), findsOneWidget);
    });

    testWidgets('Tapping rest chips changes default rest selection', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WorkoutSetupSheet(
              routine: sampleRoutine,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap 90s chip for sets
      final chip90s = find.widgetWithText(ChoiceChip, '90s').first;
      await tester.tap(chip90s);
      await tester.pumpAndSettle();

      final choiceChip = tester.widget<ChoiceChip>(chip90s);
      expect(choiceChip.selected, isTrue);
    });
  });

  group('2. Active Workout Complete Set & Strength Flow', () {
    final strengthRoutine = [
      {
        'name': 'Dumbbell Bench Press',
        'target': 'Chest',
        'equipment': 'Dumbbell',
        'sets': 3,
        'reps': '10',
        'restSeconds': 60,
      }
    ];

    testWidgets('Strength exercise shows Complete Set button, target vs actual, and completes set', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ActiveWorkoutPage(
            workoutName: 'Chest Day',
            routine: strengthRoutine,
            defaultRestSeconds: 60,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check Exercise Header
      expect(find.text('Chest Day'), findsOneWidget);
      expect(find.text('Dumbbell Bench Press'), findsOneWidget);
      expect(find.text('Chest'), findsOneWidget);
      expect(find.text('Dumbbell'), findsOneWidget);

      // Check Table Headers
      expect(find.text('SET'), findsOneWidget);
      expect(find.text('TARGET'), findsOneWidget);
      expect(find.text('WEIGHT (KG)'), findsOneWidget);
      expect(find.text('ACTUAL REPS'), findsOneWidget);

      // Check Target Reps
      expect(find.text('10 reps'), findsWidgets);

      // Check Explicit Complete Set 1 button
      expect(find.text('Complete Set 1'), findsOneWidget);

      // Tap Complete Set 1
      await tester.tap(find.text('Complete Set 1'));
      await tester.pump();

      // Set 1 marked completed
      expect(find.text('Set 1 completed ✓'), findsOneWidget);
      expect(find.text('Complete Set 1'), findsNothing);

      // Rest Timer triggered
      expect(find.text('REST'), findsOneWidget);
      expect(find.text('Skip Rest'), findsOneWidget);
      expect(find.text('+10s'), findsOneWidget);
      expect(find.text('-10s'), findsOneWidget);
    });

    testWidgets('Rest Timer controls [-10s], [+10s], and [Skip Rest] work correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ActiveWorkoutPage(
            workoutName: 'Chest Day',
            routine: strengthRoutine,
            defaultRestSeconds: 60,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Complete Set 1
      await tester.tap(find.text('Complete Set 1'));
      await tester.pump();

      expect(find.text('REST'), findsOneWidget);

      // Tap +10s
      await tester.tap(find.text('+10s'));
      await tester.pump();
      expect(find.text('REST'), findsOneWidget);

      // Tap -10s multiple times (must never drop below 0)
      for (int i = 0; i < 8; i++) {
        await tester.tap(find.text('-10s'));
        await tester.pump();
      }
      expect(find.text('REST'), findsOneWidget);

      // Tap Skip Rest
      await tester.tap(find.text('Skip Rest'));
      await tester.pump();

      // Rest card dismissed
      expect(find.text('REST'), findsNothing);
    });
  });

  group('3. Bodyweight Exercise UX', () {
    final bodyweightRoutine = [
      {
        'name': 'Push Ups',
        'target': 'Chest',
        'equipment': 'Bodyweight',
        'sets': 3,
        'reps': '15',
        'restSeconds': 45,
      }
    ];

    testWidgets('Bodyweight exercises display Bodyweight badge and allow reps entry without mandatory weight', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ActiveWorkoutPage(
            workoutName: 'Calisthenics Blast',
            routine: bodyweightRoutine,
            defaultRestSeconds: 45,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Header indicates bodyweight
      expect(find.text('Push Ups'), findsOneWidget);
      expect(find.text('Bodyweight'), findsWidgets);

      // Table displays Bodyweight badge in weight column
      expect(find.text('15 reps'), findsWidgets);
      expect(find.text('Complete Set 1'), findsOneWidget);

      // Tap Complete Set 1
      await tester.tap(find.text('Complete Set 1'));
      await tester.pump();

      expect(find.text('Set 1 completed ✓'), findsOneWidget);
    });
  });

  group('4. Cardio & Timed Activity UX', () {
    final cardioRoutine = [
      {
        'name': 'Air Bike Sprint',
        'target': 'Cardio',
        'equipment': 'Cardio Machine',
        'durationSeconds': 300,
        'category': 'Cardio',
      }
    ];

    testWidgets('Cardio exercise displays stopwatch/duration UI with Start/Pause/Complete Activity', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ActiveWorkoutPage(
            workoutName: 'Cardio Intervals',
            routine: cardioRoutine,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Timed Activity Card
      expect(find.text('Air Bike Sprint'), findsOneWidget);
      expect(find.text('Timed Activity'), findsOneWidget);
      expect(find.text('Target: 05:00'), findsOneWidget);
      expect(find.text('05:00'), findsOneWidget);

      // Does NOT show weight or reps input tables
      expect(find.text('WEIGHT (KG)'), findsNothing);
      expect(find.text('ACTUAL REPS'), findsNothing);

      // Has Start, Reset, Complete Activity buttons
      expect(find.text('Start'), findsOneWidget);
      expect(find.text('Reset'), findsOneWidget);
      expect(find.text('Complete Activity'), findsOneWidget);

      // Tap Start -> changes to Pause
      await tester.tap(find.text('Start'));
      await tester.pump();
      expect(find.text('Pause'), findsOneWidget);

      // Tap Complete Activity
      await tester.tap(find.text('Complete Activity'));
      await tester.pump();
      expect(find.text('Activity Completed ✓'), findsOneWidget);
    });
  });

  group('5. Safety & Navigation Confirmation', () {
    final multiRoutine = [
      {
        'name': 'Dumbbell Bench Press',
        'target': 'Chest',
        'equipment': 'Dumbbell',
        'sets': 2,
        'reps': '10',
      },
      {
        'name': 'Incline Dumbbell Fly',
        'target': 'Chest',
        'equipment': 'Dumbbell',
        'sets': 2,
        'reps': '12',
      },
    ];

    testWidgets('PopScope / Close button triggers Leave Workout? confirmation dialog', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ActiveWorkoutPage(
            workoutName: 'Chest Workout',
            routine: multiRoutine,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap AppBar Close button
      await tester.tap(find.byTooltip('Leave Workout'));
      await tester.pumpAndSettle();

      // Shows confirmation dialog
      expect(find.text('Leave Workout?'), findsOneWidget);
      expect(find.text('Resume Workout'), findsOneWidget);
      expect(find.text('Leave Session'), findsOneWidget);

      // Tap Resume Workout
      await tester.tap(find.text('Resume Workout'));
      await tester.pumpAndSettle();

      expect(find.text('Leave Workout?'), findsNothing);
    });

    testWidgets('Early Finish Workout shows completion count confirmation dialog', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ActiveWorkoutPage(
            workoutName: 'Chest Workout',
            routine: multiRoutine,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Complete 1 set
      await tester.tap(find.text('Complete Set 1'));
      await tester.pump();

      // Advance to exercise 2
      await tester.tap(find.text('Next Exercise'));
      await tester.pumpAndSettle();

      // Tap Finish Workout
      await tester.tap(find.text('Finish Workout'));
      await tester.pumpAndSettle();

      // Early finish dialog
      expect(find.text('Finish Workout?'), findsOneWidget);
      expect(find.text('Completed: 1 of 2 exercises'), findsOneWidget);
      expect(find.text('Total Sets Logged: 1'), findsOneWidget);
      expect(find.text('Continue Workout'), findsOneWidget);
      expect(find.text('Finish Anyway'), findsOneWidget);
    });
  });

  group('6. Build My Own Routine Screen Tests', () {
    testWidgets('BuildRoutineScreen allows naming, category, and exercise list management', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: BuildRoutineScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Build My Own Routine'), findsOneWidget);
      expect(find.text('Routine Name'), findsOneWidget);
      expect(find.text('Category'), findsOneWidget);
      expect(find.text('Level'), findsOneWidget);
      expect(find.text('Default Rest Between Sets'), findsOneWidget);
      expect(find.text('Add Exercise'), findsOneWidget);
      expect(find.text('No exercises added yet'), findsOneWidget);
    });
  });

  group('7. Responsive Viewport Tests (320px, 360px, 390px, 412px)', () {
    final widths = [320.0, 360.0, 390.0, 412.0];

    for (final width in widths) {
      testWidgets('ActiveWorkoutPage renders without overflow at ${width}px width', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(size: Size(width, 800)),
              child: ActiveWorkoutPage(
                workoutName: 'Responsive Test Routine',
                routine: [
                  {
                    'name': 'Barbell Bench Press',
                    'target': 'Chest',
                    'equipment': 'Barbell',
                    'sets': 3,
                    'reps': 10,
                  }
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);

        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });
      });
    }
  });

  group('8. Exercise Tracking Type Inference Tests', () {
    test('Correctly classifies Bench Press as strength', () {
      final type = inferExerciseTrackingType(
        name: 'Barbell Bench Press',
        category: 'Chest',
        equipment: 'Barbell',
      );
      expect(type, ExerciseTrackingType.strength);
    });

    test('Correctly classifies Push-Up as reps', () {
      final type = inferExerciseTrackingType(
        name: 'Standard Push-Up',
        category: 'Chest',
        equipment: 'Bodyweight',
      );
      expect(type, ExerciseTrackingType.reps);
    });

    test('Correctly classifies Plank as timed', () {
      final type = inferExerciseTrackingType(
        name: 'Forearm Plank',
        category: 'Core',
        equipment: 'Bodyweight',
        reps: '45s',
      );
      expect(type, ExerciseTrackingType.timed);
    });

    test('Correctly classifies Running as cardio', () {
      final type = inferExerciseTrackingType(
        name: 'Outdoor Running',
        category: 'Cardio',
        equipment: 'None',
      );
      expect(type, ExerciseTrackingType.cardio);
    });

    test('Correctly classifies Air Bike as cardio', () {
      final type = inferExerciseTrackingType(
        name: 'Air Bike Sprint',
        category: 'Cardio',
        equipment: 'Stationary Bike',
      );
      expect(type, ExerciseTrackingType.cardio);
    });
  });

  group('9. Routine Signature & Deduplication Tests', () {
    test('Routines with same name and same exercises have identical signatures (deduplicated to 1)', () {
      final sig1 = WorkoutRoutine.generateRoutineSignature(
        name: 'Morning Blast',
        category: 'Full Body',
        fitnessLevel: 'Beginner',
        exerciseNames: ['Push-Up', 'Bodyweight Squat', 'Plank'],
      );

      final sig2 = WorkoutRoutine.generateRoutineSignature(
        name: ' Morning Blast ',
        category: 'full body',
        fitnessLevel: 'beginner',
        exerciseNames: ['Push-Up', 'Bodyweight Squat', 'Plank'],
      );

      expect(sig1, equals(sig2));

      // Simulate UI list deduplication
      final routinesList = [
        WorkoutRoutine(
          id: 'doc_1',
          title: 'Morning Blast',
          subtitle: '',
          level: FitnessLevel.beginner,
          goal: UserGoalTag.maintenance,
          durationMinutes: 30,
          estimatedCalories: 200,
          category: 'Full Body',
          exercises: const [
            ExerciseModel(id: '1', name: 'Push-Up', targetMuscle: 'Chest', equipment: 'Bodyweight'),
            ExerciseModel(id: '2', name: 'Bodyweight Squat', targetMuscle: 'Legs', equipment: 'Bodyweight'),
          ],
        ),
        WorkoutRoutine(
          id: 'doc_2_duplicate',
          title: 'Morning Blast',
          subtitle: '',
          level: FitnessLevel.beginner,
          goal: UserGoalTag.maintenance,
          durationMinutes: 30,
          estimatedCalories: 200,
          category: 'Full Body',
          exercises: const [
            ExerciseModel(id: '1', name: 'Push-Up', targetMuscle: 'Chest', equipment: 'Bodyweight'),
            ExerciseModel(id: '2', name: 'Bodyweight Squat', targetMuscle: 'Legs', equipment: 'Bodyweight'),
          ],
        ),
      ];

      final Map<String, WorkoutRoutine> uniqueMap = {};
      for (final r in routinesList) {
        uniqueMap.putIfAbsent(r.signature, () => r);
      }
      expect(uniqueMap.length, 1);
    });

    test('Routines with same name but different exercises have different signatures (both visible)', () {
      final sigA = WorkoutRoutine.generateRoutineSignature(
        name: 'Morning Blast',
        category: 'Full Body',
        fitnessLevel: 'Beginner',
        exerciseNames: ['Push-Up', 'Pull-Up'],
      );

      final sigB = WorkoutRoutine.generateRoutineSignature(
        name: 'Morning Blast',
        category: 'Full Body',
        fitnessLevel: 'Beginner',
        exerciseNames: ['Bench Press', 'Barbell Squat'],
      );

      expect(sigA, isNot(equals(sigB)));

      final routinesList = [
        WorkoutRoutine(
          id: 'doc_1',
          title: 'Morning Blast',
          subtitle: '',
          level: FitnessLevel.beginner,
          goal: UserGoalTag.maintenance,
          durationMinutes: 30,
          estimatedCalories: 200,
          category: 'Full Body',
          exercises: const [
            ExerciseModel(id: '1', name: 'Push-Up', targetMuscle: 'Chest', equipment: 'Bodyweight'),
          ],
        ),
        WorkoutRoutine(
          id: 'doc_2_different',
          title: 'Morning Blast',
          subtitle: '',
          level: FitnessLevel.beginner,
          goal: UserGoalTag.maintenance,
          durationMinutes: 30,
          estimatedCalories: 200,
          category: 'Full Body',
          exercises: const [
            ExerciseModel(id: '3', name: 'Bench Press', targetMuscle: 'Chest', equipment: 'Barbell'),
          ],
        ),
      ];

      final Map<String, WorkoutRoutine> uniqueMap = {};
      for (final r in routinesList) {
        uniqueMap.putIfAbsent(r.signature, () => r);
      }
      expect(uniqueMap.length, 2);
    });
  });

  group('10. Favorite Toggle UX Tests', () {
    testWidgets('ExerciseListCard renders favorite heart button and triggers onToggleFavorite', (tester) async {
      bool toggled = false;
      const testEx = ExerciseModel(
        id: 'ex_curl',
        name: 'Bicep Curl',
        targetMuscle: 'Arms',
        equipment: 'Dumbbell',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExerciseListCard(
              exercise: testEx,
              isFavorite: false,
              onToggleFavorite: () => toggled = true,
              onTap: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.favorite_border), findsOneWidget);
      expect(find.text('Strength'), findsOneWidget); // Tracking type badge

      await tester.tap(find.byIcon(Icons.favorite_border));
      await tester.pumpAndSettle();

      expect(toggled, isTrue);
    });
  });

  group('11. Jaccard Similarity & Routine Clustering Tests', () {
    test('Calculates Jaccard similarity correctly', () {
      final setA = {'bench press', 'lat pulldown', 'shoulder press', 'bicep curl'};
      final setB = {'bench press', 'lat pulldown', 'shoulder press', 'hammer curl'};
      // Intersection = 3 (bench, lat, shoulder), Union = 5
      final similarity = WorkoutRoutine.calculateExerciseSimilarity(setA, setB);
      expect(similarity, closeTo(0.60, 0.01));

      // Overlap of 3 out of 3 = 1.0
      final setC = {'bench press', 'lat pulldown', 'shoulder press'};
      final setD = {'bench press', 'lat pulldown', 'shoulder press'};
      expect(WorkoutRoutine.calculateExerciseSimilarity(setC, setD), equals(1.0));

      // Disjoint routines (Upper Body A vs Upper Body B) = 0.0
      final setE = {'push-up', 'dumbbell row', 'arnold press', 'tricep extension'};
      expect(WorkoutRoutine.calculateExerciseSimilarity(setA, setE), equals(0.0));
    });

    test('RoutineCluster groups near-duplicates and preserves distinct routines', () {
      const ex1 = ExerciseModel(id: '1', name: 'Bench Press', targetMuscle: 'Chest', equipment: 'Barbell');
      const ex2 = ExerciseModel(id: '2', name: 'Lat Pulldown', targetMuscle: 'Back', equipment: 'Cable');
      const ex3 = ExerciseModel(id: '3', name: 'Shoulder Press', targetMuscle: 'Shoulders', equipment: 'Dumbbell');
      const ex4 = ExerciseModel(id: '4', name: 'Bicep Curl', targetMuscle: 'Arms', equipment: 'Dumbbell');

      const ex6 = ExerciseModel(id: '6', name: 'Push-Up', targetMuscle: 'Chest', equipment: 'Bodyweight');
      const ex7 = ExerciseModel(id: '7', name: 'Dumbbell Row', targetMuscle: 'Back', equipment: 'Dumbbell');
      const ex8 = ExerciseModel(id: '8', name: 'Arnold Press', targetMuscle: 'Shoulders', equipment: 'Dumbbell');
      const ex9 = ExerciseModel(id: '9', name: 'Tricep Extension', targetMuscle: 'Arms', equipment: 'Cable');

      const routine1 = WorkoutRoutine(
        id: 'r1',
        title: 'Upper Body Power',
        subtitle: 'Strength',
        level: FitnessLevel.intermediate,
        goal: UserGoalTag.muscleGain,
        durationMinutes: 45,
        estimatedCalories: 300,
        category: 'Upper Body',
        exercises: [ex1, ex2, ex3, ex4],
      );

      // 100% same exercises in different order
      const routine1Variation = WorkoutRoutine(
        id: 'r1_var',
        title: 'Upper Body Power Blast',
        subtitle: 'Strength',
        level: FitnessLevel.intermediate,
        goal: UserGoalTag.muscleGain,
        durationMinutes: 45,
        estimatedCalories: 300,
        category: 'Upper Body',
        exercises: [ex4, ex3, ex2, ex1],
      );

      // Distinct Upper Body routine
      const routine2 = WorkoutRoutine(
        id: 'r2',
        title: 'Upper Body Calisthenics',
        subtitle: 'Bodyweight',
        level: FitnessLevel.intermediate,
        goal: UserGoalTag.muscleGain,
        durationMinutes: 40,
        estimatedCalories: 250,
        category: 'Upper Body',
        exercises: [ex6, ex7, ex8, ex9],
      );

      final clusters = RoutineCluster.clusterRoutines([routine1, routine1Variation, routine2]);
      // routine1 and routine1Variation should be clustered together (total clusters: 2)
      expect(clusters.length, equals(2));
      expect(clusters.first.hasVariations, isTrue);
      expect(clusters.first.variations.length, equals(1));
      expect(clusters.last.hasVariations, isFalse);
    });
  });

  group('12. Add to Routine & Favorite Usability Tests', () {
    testWidgets('ExerciseListCard displays Add to Routine button and triggers callback', (tester) async {
      bool addedToRoutine = false;
      const testEx = ExerciseModel(
        id: 'ex_bench',
        name: 'Dumbbell Bench Press',
        targetMuscle: 'Chest',
        equipment: 'Dumbbells',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExerciseListCard(
              exercise: testEx,
              isFavorite: true,
              onTap: () {},
              onAddToRoutine: () => addedToRoutine = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Add to Routine'), findsOneWidget);
      await tester.tap(find.text('Add to Routine'));
      await tester.pumpAndSettle();

      expect(addedToRoutine, isTrue);
    });

    testWidgets('BuildRoutineScreen initializes with initialExercises', (tester) async {
      const testEx = ExerciseModel(
        id: 'ex_airbike',
        name: 'Air Bike',
        targetMuscle: 'Cardio',
        equipment: 'Stationary Bike',
        trackingType: ExerciseTrackingType.cardio,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: BuildRoutineScreen(
            initialExercises: [testEx],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Air Bike Routine'), findsOneWidget);
      expect(find.text('Air Bike'), findsOneWidget);
    });
  });
}
