import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/utils/routine_category_classifier.dart';
import 'package:flutter_application_1/models/workout_models.dart';

void main() {
  group('RoutineCategoryClassifier Tests', () {
    test('All tab matches any routine category', () {
      expect(RoutineCategoryClassifier.matchesCategory('Chest', 'All'), isTrue);
      expect(RoutineCategoryClassifier.matchesCategory('Legs', 'All'), isTrue);
      expect(RoutineCategoryClassifier.matchesCategory('Core', 'All'), isTrue);
      expect(RoutineCategoryClassifier.matchesCategory('Cardio', 'All'), isTrue);
      expect(RoutineCategoryClassifier.matchesCategory('Full Body', 'All'), isTrue);
      expect(RoutineCategoryClassifier.matchesCategory('Unknown Category', 'All'), isTrue);
    });

    test('Upper Body category test matrix includes Chest, Back, Arms, Shoulders', () {
      expect(RoutineCategoryClassifier.matchesCategory('Upper Body', 'Upper Body'), isTrue);
      expect(RoutineCategoryClassifier.matchesCategory('Chest', 'Upper Body'), isTrue);
      expect(RoutineCategoryClassifier.matchesCategory('Back', 'Upper Body'), isTrue);
      expect(RoutineCategoryClassifier.matchesCategory('Arms', 'Upper Body'), isTrue);
      expect(RoutineCategoryClassifier.matchesCategory('Shoulders', 'Upper Body'), isTrue);
      expect(RoutineCategoryClassifier.matchesCategory('Biceps Focus', 'Upper Body'), isTrue);
      expect(RoutineCategoryClassifier.matchesCategory('Triceps Blast', 'Upper Body'), isTrue);

      // Non-upper body should not match
      expect(RoutineCategoryClassifier.matchesCategory('Legs', 'Upper Body'), isFalse);
      expect(RoutineCategoryClassifier.matchesCategory('Core', 'Upper Body'), isFalse);
      expect(RoutineCategoryClassifier.matchesCategory('Cardio', 'Upper Body'), isFalse);
    });

    test('Lower Body category test matrix includes Legs, Glutes, Quads, Hamstrings', () {
      expect(RoutineCategoryClassifier.matchesCategory('Lower Body', 'Lower Body'), isTrue);
      expect(RoutineCategoryClassifier.matchesCategory('Legs', 'Lower Body'), isTrue);
      expect(RoutineCategoryClassifier.matchesCategory('Glutes', 'Lower Body'), isTrue);
      expect(RoutineCategoryClassifier.matchesCategory('Quads', 'Lower Body'), isTrue);
      expect(RoutineCategoryClassifier.matchesCategory('Hamstrings', 'Lower Body'), isTrue);
      expect(RoutineCategoryClassifier.matchesCategory('Calves', 'Lower Body'), isTrue);

      // Non-lower body should not match
      expect(RoutineCategoryClassifier.matchesCategory('Chest', 'Lower Body'), isFalse);
      expect(RoutineCategoryClassifier.matchesCategory('Core', 'Lower Body'), isFalse);
      expect(RoutineCategoryClassifier.matchesCategory('Cardio', 'Lower Body'), isFalse);
    });

    test('Core category test matrix includes Core, Waist, Abs, Abdominals', () {
      expect(RoutineCategoryClassifier.matchesCategory('Core', 'Core'), isTrue);
      expect(RoutineCategoryClassifier.matchesCategory('Waist', 'Core'), isTrue);
      expect(RoutineCategoryClassifier.matchesCategory('Abs', 'Core'), isTrue);
      expect(RoutineCategoryClassifier.matchesCategory('Abdominals', 'Core'), isTrue);
      expect(RoutineCategoryClassifier.matchesCategory('Lower Abs Shred', 'Core'), isTrue);

      // Non-core should not match
      expect(RoutineCategoryClassifier.matchesCategory('Chest', 'Core'), isFalse);
      expect(RoutineCategoryClassifier.matchesCategory('Legs', 'Core'), isFalse);
    });

    test('Cardio category test matrix includes Cardio, Conditioning, Running, Cycling, HIIT', () {
      expect(RoutineCategoryClassifier.matchesCategory('Cardio', 'Cardio'), isTrue);
      expect(RoutineCategoryClassifier.matchesCategory('Conditioning', 'Cardio'), isTrue);
      expect(RoutineCategoryClassifier.matchesCategory('Running', 'Cardio'), isTrue);
      expect(RoutineCategoryClassifier.matchesCategory('Cycling', 'Cardio'), isTrue);
      expect(RoutineCategoryClassifier.matchesCategory('HIIT Burn', 'Cardio'), isTrue);
      expect(RoutineCategoryClassifier.matchesCategory('Aerobic', 'Cardio'), isTrue);

      // Non-cardio should not match
      expect(RoutineCategoryClassifier.matchesCategory('Chest', 'Cardio'), isFalse);
      expect(RoutineCategoryClassifier.matchesCategory('Legs', 'Cardio'), isFalse);
    });

    test('Full Body matches true Full Body routines', () {
      expect(RoutineCategoryClassifier.matchesCategory('Full Body', 'Full Body'), isTrue);
      expect(RoutineCategoryClassifier.matchesCategory('Full Body Conditioning', 'Full Body'), isTrue);

      expect(RoutineCategoryClassifier.matchesCategory('Chest', 'Full Body'), isFalse);
      expect(RoutineCategoryClassifier.matchesCategory('Legs', 'Full Body'), isFalse);
    });

    test('formatRoutineMetadata formats concise metadata line', () {
      final routineDumbbells = WorkoutRoutine(
        id: 'r1',
        title: 'Upper Hypertrophy',
        subtitle: '3 exercises',
        level: FitnessLevel.beginner,
        goal: UserGoalTag.muscleGain,
        durationMinutes: 30,
        estimatedCalories: 200,
        category: 'Upper Body',
        exercises: [
          ExerciseModel(id: 'e1', name: 'Dumbbell Bench Press', targetMuscle: 'Chest', equipment: 'Dumbbells'),
          ExerciseModel(id: 'e2', name: 'Dumbbell Row', targetMuscle: 'Back', equipment: 'Dumbbells'),
        ],
      );

      final meta = RoutineCategoryClassifier.formatRoutineMetadata(routineDumbbells);
      expect(meta, equals('Beginner • Upper Body • Dumbbells'));

      final routineBodyweight = WorkoutRoutine(
        id: 'r2',
        title: 'Full Body Calisthenics',
        subtitle: '3 exercises',
        level: FitnessLevel.intermediate,
        goal: UserGoalTag.weightLoss,
        durationMinutes: 25,
        estimatedCalories: 180,
        category: 'Full Body',
        exercises: [
          ExerciseModel(id: 'e3', name: 'Push-Ups', targetMuscle: 'Chest', equipment: 'Bodyweight'),
          ExerciseModel(id: 'e4', name: 'Squats', targetMuscle: 'Legs', equipment: 'Bodyweight'),
        ],
      );

      final metaBw = RoutineCategoryClassifier.formatRoutineMetadata(routineBodyweight);
      expect(metaBw, equals('Intermediate • Full Body • Bodyweight'));
    });
  });

  group('Centralized Multi-Tier Routine Category Membership Tests', () {
    test('Lower Body Foundation (category=Strength, exercises=Squat, Lunge, RDL) matches Lower Body and All, not Upper Body', () {
      final routine = WorkoutRoutine(
        id: 'lbf_1',
        title: 'Lower Body Foundation',
        subtitle: 'Foundation routine for legs',
        level: FitnessLevel.beginner,
        goal: UserGoalTag.maintenance,
        durationMinutes: 35,
        estimatedCalories: 240,
        category: 'Strength',
        exercises: [
          ExerciseModel(id: 'sq_1', name: 'Squat', targetMuscle: 'Quads', equipment: 'Barbell'),
          ExerciseModel(id: 'lg_1', name: 'Lunge', targetMuscle: 'Legs', equipment: 'Dumbbells'),
          ExerciseModel(id: 'rdl_1', name: 'Romanian Deadlift', targetMuscle: 'Hamstrings', equipment: 'Barbell'),
        ],
      );

      expect(RoutineCategoryClassifier.matchesRoutine(routine, 'All'), isTrue);
      expect(RoutineCategoryClassifier.matchesRoutine(routine, 'Lower Body'), isTrue);
      expect(RoutineCategoryClassifier.matchesRoutine(routine, 'Upper Body'), isFalse);
      expect(RoutineCategoryClassifier.matchesRoutine(routine, 'Core'), isFalse);
      expect(RoutineCategoryClassifier.matchesRoutine(routine, 'Cardio'), isFalse);
    });

    test('Upper Body Strength (category=Strength, exercises=Bench Press, Lat Pulldown, Shoulder Press) matches Upper Body and All', () {
      final routine = WorkoutRoutine(
        id: 'ubs_1',
        title: 'Upper Body Strength',
        subtitle: 'Upper compound strength',
        level: FitnessLevel.intermediate,
        goal: UserGoalTag.muscleGain,
        durationMinutes: 40,
        estimatedCalories: 280,
        category: 'Strength',
        exercises: [
          ExerciseModel(id: 'bp_1', name: 'Bench Press', targetMuscle: 'Chest', equipment: 'Barbell'),
          ExerciseModel(id: 'lp_1', name: 'Lat Pulldown', targetMuscle: 'Back', equipment: 'Cable'),
          ExerciseModel(id: 'sp_1', name: 'Shoulder Press', targetMuscle: 'Shoulders', equipment: 'Dumbbell'),
        ],
      );

      expect(RoutineCategoryClassifier.matchesRoutine(routine, 'All'), isTrue);
      expect(RoutineCategoryClassifier.matchesRoutine(routine, 'Upper Body'), isTrue);
      expect(RoutineCategoryClassifier.matchesRoutine(routine, 'Lower Body'), isFalse);
      expect(RoutineCategoryClassifier.matchesRoutine(routine, 'Core'), isFalse);
      expect(RoutineCategoryClassifier.matchesRoutine(routine, 'Cardio'), isFalse);
    });

    test('Core Stability (category=Strength, exercises=Plank, Crunch, Dead Bug) matches Core and All', () {
      final routine = WorkoutRoutine(
        id: 'cs_1',
        title: 'Core Stability',
        subtitle: 'Midsection foundation',
        level: FitnessLevel.beginner,
        goal: UserGoalTag.maintenance,
        durationMinutes: 20,
        estimatedCalories: 120,
        category: 'Strength',
        exercises: [
          ExerciseModel(id: 'pl_1', name: 'Plank', targetMuscle: 'Core', equipment: 'Bodyweight'),
          ExerciseModel(id: 'cr_1', name: 'Crunch', targetMuscle: 'Abs', equipment: 'Bodyweight'),
          ExerciseModel(id: 'db_1', name: 'Dead Bug', targetMuscle: 'Core', equipment: 'Bodyweight'),
        ],
      );

      expect(RoutineCategoryClassifier.matchesRoutine(routine, 'All'), isTrue);
      expect(RoutineCategoryClassifier.matchesRoutine(routine, 'Core'), isTrue);
      expect(RoutineCategoryClassifier.matchesRoutine(routine, 'Upper Body'), isFalse);
      expect(RoutineCategoryClassifier.matchesRoutine(routine, 'Lower Body'), isFalse);
      expect(RoutineCategoryClassifier.matchesRoutine(routine, 'Cardio'), isFalse);
    });

    test('Cardio Burner (category=Conditioning, exercises=Air Bike, Running) matches Cardio and All', () {
      final routine = WorkoutRoutine(
        id: 'cb_1',
        title: 'Cardio Burner',
        subtitle: 'High energy conditioning',
        level: FitnessLevel.intermediate,
        goal: UserGoalTag.endurance,
        durationMinutes: 30,
        estimatedCalories: 300,
        category: 'Conditioning',
        exercises: [
          ExerciseModel(id: 'ab_1', name: 'Air Bike', targetMuscle: 'Cardio', equipment: 'Air Bike', trackingType: ExerciseTrackingType.cardio),
          ExerciseModel(id: 'rn_1', name: 'Running', targetMuscle: 'Cardio', equipment: 'Treadmill', trackingType: ExerciseTrackingType.cardio),
        ],
      );

      expect(RoutineCategoryClassifier.matchesRoutine(routine, 'All'), isTrue);
      expect(RoutineCategoryClassifier.matchesRoutine(routine, 'Cardio'), isTrue);
      expect(RoutineCategoryClassifier.matchesRoutine(routine, 'Upper Body'), isFalse);
      expect(RoutineCategoryClassifier.matchesRoutine(routine, 'Lower Body'), isFalse);
      expect(RoutineCategoryClassifier.matchesRoutine(routine, 'Core'), isFalse);
    });

    test('Exercise composition fallback infers category when routine category is generic (General / Workout)', () {
      final routineGenericName = WorkoutRoutine(
        id: 'gn_1',
        title: 'Daily Session A',
        subtitle: '3 sets each',
        level: FitnessLevel.beginner,
        goal: UserGoalTag.maintenance,
        durationMinutes: 30,
        estimatedCalories: 200,
        category: 'Workout',
        exercises: [
          ExerciseModel(id: 'sq_2', name: 'Goblet Squat', targetMuscle: 'Quads', equipment: 'Dumbbell'),
          ExerciseModel(id: 'lg_2', name: 'Walking Lunge', targetMuscle: 'Legs', equipment: 'Bodyweight'),
          ExerciseModel(id: 'cr_2', name: 'Calf Raise', targetMuscle: 'Calves', equipment: 'Bodyweight'),
        ],
      );

      expect(RoutineCategoryClassifier.matchesRoutine(routineGenericName, 'Lower Body'), isTrue);
      expect(RoutineCategoryClassifier.matchesRoutine(routineGenericName, 'Upper Body'), isFalse);
    });

    test('Mixed upper and lower exercises without explicit focus infers Full Body', () {
      final mixedRoutine = WorkoutRoutine(
        id: 'mx_1',
        title: 'Circuit Training',
        subtitle: 'Whole body',
        level: FitnessLevel.intermediate,
        goal: UserGoalTag.weightLoss,
        durationMinutes: 35,
        estimatedCalories: 260,
        category: 'General',
        exercises: [
          ExerciseModel(id: 'e1', name: 'Push-Up', targetMuscle: 'Chest', equipment: 'Bodyweight'),
          ExerciseModel(id: 'e2', name: 'Pull-Up', targetMuscle: 'Back', equipment: 'Bodyweight'),
          ExerciseModel(id: 'e3', name: 'Squat', targetMuscle: 'Quads', equipment: 'Bodyweight'),
          ExerciseModel(id: 'e4', name: 'Lunge', targetMuscle: 'Legs', equipment: 'Bodyweight'),
        ],
      );

      expect(RoutineCategoryClassifier.matchesRoutine(mixedRoutine, 'Full Body'), isTrue);
      expect(RoutineCategoryClassifier.matchesRoutine(mixedRoutine, 'Lower Body'), isFalse);
      expect(RoutineCategoryClassifier.matchesRoutine(mixedRoutine, 'Upper Body'), isFalse);
    });
  });
}
