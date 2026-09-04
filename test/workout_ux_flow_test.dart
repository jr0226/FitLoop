import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/models/workout_models.dart';
import 'package:flutter_application_1/widgets/workout/daily_routine_card.dart';
import 'package:flutter_application_1/widgets/workout/routine_detail_modal.dart';
import 'package:flutter_application_1/widgets/workout/workout_streak_header.dart';
import 'package:flutter_application_1/widgets/workout/workout_history_list_card.dart';
import 'package:flutter_application_1/widgets/workout/visual_strength_charts.dart';
import 'package:flutter_application_1/widgets/workout/exercise_list_card.dart';
import 'package:flutter_application_1/screens/active_workout_page.dart';

void main() {
  group('Workout Hub & Routine UX Tests', () {
    final sampleExercises = [
      const ExerciseModel(
        id: 'ex1',
        name: 'Barbell Bench Press (Heavy)',
        targetMuscle: 'Chest',
        equipment: 'Barbell',
        defaultSets: 3,
        defaultReps: 10,
        instructions: ['Lie back on bench', 'Lower bar to chest and push'],
      ),
      const ExerciseModel(
        id: 'ex2',
        name: 'Incline Dumbbell Fly',
        targetMuscle: 'Chest',
        equipment: 'Dumbbell',
        defaultSets: 3,
        defaultReps: 12,
      ),
      const ExerciseModel(
        id: 'ex3',
        name: 'Push Ups (Bodyweight)',
        targetMuscle: 'Chest',
        equipment: 'Bodyweight',
        defaultSets: 3,
        defaultReps: 15,
      ),
      const ExerciseModel(
        id: 'ex4',
        name: 'Cable Crossover Triceps Pushdown Extension',
        targetMuscle: 'Arms',
        equipment: 'Cable',
        defaultSets: 3,
        defaultReps: 12,
      ),
    ];

    final sampleRoutine = WorkoutRoutine(
      id: 'r1',
      title: 'Hypertrophy Upper Body Power Split Routine',
      subtitle: 'Build upper body mass and strength',
      level: FitnessLevel.intermediate,
      goal: UserGoalTag.muscleGain,
      durationMinutes: 45,
      estimatedCalories: 320,
      exercises: sampleExercises,
      category: 'Upper Body',
      isAiGenerated: true,
    );

    testWidgets('DailyRoutineCard displays routine information and primary Start CTA', (tester) async {
      bool started = false;
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DailyRoutineCard(
              routine: sampleRoutine,
              onStart: () => started = true,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      // Verify Routine Title and Tag
      expect(find.text('RECOMMENDED FOR YOU'), findsOneWidget);
      expect(find.text('Hypertrophy Upper Body Power Split Routine'), findsOneWidget);
      expect(find.text('Upper Body'), findsOneWidget);
      expect(find.text('45 min'), findsOneWidget);
      expect(find.text('320 kcal'), findsOneWidget);

      // Verify Exercise preview
      expect(find.text('Barbell Bench Press (Heavy)'), findsOneWidget);
      expect(find.text('+ 1 more exercises (Tap to view all)'), findsOneWidget);

      // Verify Primary CTA
      final startBtn = find.text('Start Workout');
      expect(startBtn, findsOneWidget);

      await tester.tap(startBtn);
      await tester.pump();
      expect(started, isTrue);

      // Tap card body
      await tester.tap(find.text('Hypertrophy Upper Body Power Split Routine'));
      await tester.pump();
      expect(tapped, isTrue);
    });

    testWidgets('RoutineDetailModal displays all exercises and triggers onStart', (tester) async {
      bool started = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  RoutineDetailModal.show(
                    context,
                    routine: sampleRoutine,
                    onStart: () => started = true,
                  );
                },
                child: const Text('Open Modal'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      // Modal content
      expect(find.text('Workout Movements'), findsOneWidget);
      expect(find.text('Barbell Bench Press (Heavy)'), findsOneWidget);
      expect(find.text('Incline Dumbbell Fly'), findsOneWidget);

      // Scroll to remaining exercises
      await tester.scrollUntilVisible(
        find.text('Push Ups (Bodyweight)'),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Push Ups (Bodyweight)'), findsOneWidget);

      // Tap Start Workout inside sticky bottom bar
      final modalStartBtn = find.widgetWithText(ElevatedButton, 'Start Workout');
      expect(modalStartBtn, findsOneWidget);

      await tester.tap(modalStartBtn);
      await tester.pumpAndSettle();
      expect(started, isTrue);
    });

    testWidgets('WorkoutStreakHeader displays compact consistency stats without overflow', (tester) async {
      const summary = StreakSummary(
        currentStreakDays: 5,
        bestStreakDays: 14,
        weeklyCompletedDays: 3,
        weeklyGoalDays: 4,
        pastWeekActiveDays: [true, true, true, false, false, false, false],
        badges: [],
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: WorkoutStreakHeader(streakSummary: summary),
          ),
        ),
      );

      expect(find.text('5 Day Streak'), findsOneWidget);
      expect(find.text('Best: 14 days'), findsOneWidget);
      expect(find.text('3/4 Days'), findsOneWidget);
    });
  });

  group('Active Workout & Set Logging UX Tests', () {
    final activeRoutine = [
      {
        'name': 'Push Ups',
        'target': 'Chest',
        'equipment': 'Bodyweight',
        'sets': 2,
        'reps': 15,
      },
      {
        'name': 'Barbell Squat',
        'target': 'Legs',
        'equipment': 'Barbell',
        'sets': 2,
        'reps': 8,
      }
    ];

    testWidgets('ActiveWorkoutPage displays clean header, bodyweight indicators, and advances', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ActiveWorkoutPage(
            workoutName: 'Upper Body Blast',
            routine: activeRoutine,
          ),
        ),
      );

      // Verify clean header
      expect(find.text('Upper Body Blast'), findsOneWidget);
      expect(find.text('Ex 1 of 2'), findsOneWidget);

      // Verify Bodyweight exercise does not force 60kg
      expect(find.text('Bodyweight'), findsWidgets);

      // Verify table headers
      expect(find.text('SET'), findsOneWidget);
      expect(find.text('TARGET'), findsOneWidget);
      expect(find.text('ACTUAL REPS'), findsOneWidget);

      // Verify Next Exercise action
      expect(find.text('Next Exercise'), findsOneWidget);

      // Advance to exercise 2
      await tester.tap(find.text('Next Exercise'));
      await tester.pumpAndSettle();

      expect(find.text('Ex 2 of 2'), findsOneWidget);
      expect(find.text('Barbell Squat'), findsOneWidget);
      // On last exercise, action becomes Finish Workout
      expect(find.text('Finish Workout'), findsOneWidget);
    });

    testWidgets('ActiveWorkoutPage early finish confirmation and discard session', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ActiveWorkoutPage(
            workoutName: 'Upper Body Blast',
            routine: activeRoutine,
          ),
        ),
      );

      // Advance to last exercise without completing any sets
      await tester.tap(find.text('Next Exercise'));
      await tester.pumpAndSettle();

      // Tap Finish Workout with 0 completed sets -> shows Discard dialog
      await tester.tap(find.text('Finish Workout'));
      await tester.pumpAndSettle();

      expect(find.text('Discard Session?'), findsOneWidget);
      expect(find.text('Discard'), findsOneWidget);

      // Tap continue workout
      await tester.tap(find.text('Continue Workout'));
      await tester.pumpAndSettle();
      expect(find.text('Discard Session?'), findsNothing);
    });
  });

  group('Exercise Library & Cards UX Tests', () {
    testWidgets('ExerciseListCard renders movement details and equipment', (tester) async {
      const exercise = ExerciseModel(
        id: 'ex_curl',
        name: 'Dumbbell Bicep Curl (Standing)',
        targetMuscle: 'Arms',
        equipment: 'Dumbbell',
        difficulty: FitnessLevel.beginner,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExerciseListCard(
              exercise: exercise,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('Dumbbell Bicep Curl (Standing)'), findsOneWidget);
      expect(find.text('Target: Arms'), findsOneWidget);
      expect(find.text('Dumbbell'), findsOneWidget);
      expect(find.text('Beginner'), findsOneWidget);
    });
  });

  group('Workout Analytics & Progression Charts Tests', () {
    testWidgets('VisualStrengthCharts renders empty state when no sessions', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: VisualStrengthCharts(sessions: []),
          ),
        ),
      );

      expect(find.text('No Progression Data Yet'), findsOneWidget);
    });

    testWidgets('VisualStrengthCharts displays correct unit and exercise progression with sessions', (tester) async {
      final sessions = [
        WorkoutHistorySession(
          id: 's1',
          routineName: 'Full Body A',
          date: DateTime.now().subtract(const Duration(days: 3)),
          durationMinutes: 30,
          caloriesBurned: 200,
          exercises: const [
            CompletedExerciseLog(
              exerciseName: 'Bench Press',
              targetMuscle: 'Chest',
              sets: [
                CompletedSetLog(setNumber: 1, weightKg: 60, reps: 10),
                CompletedSetLog(setNumber: 2, weightKg: 65, reps: 8),
              ],
            ),
          ],
        ),
        WorkoutHistorySession(
          id: 's2',
          routineName: 'Full Body B',
          date: DateTime.now(),
          durationMinutes: 35,
          caloriesBurned: 240,
          exercises: const [
            CompletedExerciseLog(
              exerciseName: 'Bench Press',
              targetMuscle: 'Chest',
              sets: [
                CompletedSetLog(setNumber: 1, weightKg: 70, reps: 8),
              ],
            ),
          ],
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: VisualStrengthCharts(sessions: sessions),
            ),
          ),
        ),
      );

      expect(find.text('Strength Progression'), findsOneWidget);
      expect(find.text('Peak Weight per Session'), findsOneWidget);
      expect(find.text('Workout Frequency'), findsOneWidget);
    });

    testWidgets('WorkoutHistoryListCard toggles expansion on tap', (tester) async {
      final session = WorkoutHistorySession(
        id: 's1',
        routineName: 'Leg Day Volume',
        date: DateTime.now(),
        durationMinutes: 40,
        caloriesBurned: 280,
        exercises: const [
          CompletedExerciseLog(
            exerciseName: 'Barbell Back Squats',
            targetMuscle: 'Legs',
            sets: [
              CompletedSetLog(setNumber: 1, weightKg: 80, reps: 10),
              CompletedSetLog(setNumber: 2, weightKg: 90, reps: 8),
            ],
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WorkoutHistoryListCard(session: session),
          ),
        ),
      );

      expect(find.text('Leg Day Volume'), findsOneWidget);
      expect(find.text('40 mins'), findsOneWidget);
      expect(find.text('Volume: 1520 kg'), findsOneWidget);

      // Before tap, details are collapsed
      expect(find.text('Barbell Back Squats'), findsNothing);

      // Tap card to expand
      await tester.tap(find.text('Leg Day Volume'));
      await tester.pumpAndSettle();

      expect(find.text('Barbell Back Squats'), findsOneWidget);
      expect(find.text('80kg × 10'), findsOneWidget);
    });
  });

  group('Responsive Layout Tests (320px, 360px, 390px, 412px @ 1.0x & 1.2x scale)', () {
    final widths = [320.0, 360.0, 390.0, 412.0];
    final scales = [1.0, 1.2];

    for (final width in widths) {
      for (final scale in scales) {
        testWidgets('DailyRoutineCard & WorkoutStreakHeader render without overflow at ${width}px @ ${scale}x scale', (tester) async {
          tester.view.physicalSize = Size(width * 2, 800 * 2);
          tester.view.devicePixelRatio = 2.0;

          const streak = StreakSummary(
            currentStreakDays: 3,
            bestStreakDays: 7,
            weeklyCompletedDays: 2,
            weeklyGoalDays: 4,
            pastWeekActiveDays: [true, true, false, false, false, false, false],
            badges: [],
          );

          final routine = WorkoutRoutine(
            id: 'r_resp',
            title: 'Extremely Long High Intensity Interval Conditioning Routine Name That Should Wrap Gracefully',
            subtitle: 'Subheading that explains metabolic conditioning and hypertrophy in full detail',
            level: FitnessLevel.advanced,
            goal: UserGoalTag.endurance,
            durationMinutes: 50,
            estimatedCalories: 450,
            exercises: [
              const ExerciseModel(
                id: 'e1',
                name: 'Kettlebell Romanian Deadlift to High Pull Movement',
                targetMuscle: 'Full Body',
                equipment: 'Kettlebell',
                defaultSets: 4,
                defaultReps: 12,
              ),
            ],
            category: 'Full Body Conditioning',
          );

          await tester.pumpWidget(
            MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(
                  size: Size(width, 800),
                  textScaler: TextScaler.linear(scale),
                ),
                child: Scaffold(
                  body: SingleChildScrollView(
                    child: Column(
                      children: [
                        const WorkoutStreakHeader(streakSummary: streak),
                        DailyRoutineCard(
                          routine: routine,
                          onStart: () {},
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );

          expect(tester.takeException(), isNull);

          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });
        });
      }
    }
  });
}
