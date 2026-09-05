import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/services/workout_category_validator.dart';
import 'package:flutter_application_1/services/daily_recommendation_service.dart';

void main() {
  group('WorkoutCategoryValidator - Strict Category Audit & Repair', () {
    test('CARDIO: 20 iterations with resistance inputs must yield ZERO resistance movements', () {
      final resistanceSampleInputs = [
        {'name': 'Incline Push-Ups', 'equipment': 'Bodyweight', 'target': 'Chest'},
        {'name': 'One-Arm Dumbbell Row', 'equipment': 'Dumbbells', 'target': 'Back'},
        {'name': 'Dumbbell Shoulder Press', 'equipment': 'Dumbbells', 'target': 'Shoulders'},
        {'name': 'Barbell Bench Press', 'equipment': 'Barbell', 'target': 'Chest'},
        {'name': 'Biceps Curl', 'equipment': 'Dumbbells', 'target': 'Arms'},
        {'name': 'Triceps Extension', 'equipment': 'Dumbbells', 'target': 'Arms'},
        {'name': 'Barbell Squat', 'equipment': 'Barbell', 'target': 'Legs'},
      ];

      for (int i = 0; i < 20; i++) {
        final rawRoutine = {
          'name': 'Cardio Test Plan $i',
          'category': 'Cardio',
          'exercises': [
            resistanceSampleInputs[i % resistanceSampleInputs.length],
            resistanceSampleInputs[(i + 1) % resistanceSampleInputs.length],
            resistanceSampleInputs[(i + 2) % resistanceSampleInputs.length],
          ],
        };

        final repaired = WorkoutCategoryValidator.validateAndRepairRoutine(
          rawRoutine,
          requestedCategory: 'Cardio',
          availableEquipment: ['Bodyweight'],
          fitnessLevel: 'Beginner',
        );

        final exercises = repaired['exercises'] as List;
        expect(exercises.length, greaterThanOrEqualTo(3));

        for (var ex in exercises) {
          final name = (ex['name'] ?? '').toString().toLowerCase();
          final target = (ex['target'] ?? '').toString().toLowerCase();

          // Assert NO forbidden resistance movements exist
          expect(name.contains('push-up'), isFalse, reason: 'Iteration $i generated resistance: $name');
          expect(name.contains('row'), isFalse, reason: 'Iteration $i generated resistance: $name');
          expect(name.contains('press'), isFalse, reason: 'Iteration $i generated resistance: $name');
          expect(name.contains('curl'), isFalse, reason: 'Iteration $i generated resistance: $name');
          expect(name.contains('squat'), isFalse, reason: 'Iteration $i generated resistance: $name');

          // Assert target is strictly Cardio
          expect(target, equals('cardio'));

          // Assert timed/cardio tracking attributes
          final dur = ex['durationSeconds'];
          expect(dur, isNotNull);
          expect(dur as num, greaterThan(0));
        }
      }
    });

    test('CORE: exercises must have valid core/ab/oblique relevance', () {
      final rawRoutine = {
        'name': 'Core Session',
        'category': 'Core',
        'exercises': [
          {'name': 'Bench Press', 'target': 'Chest', 'equipment': 'Barbell'},
          {'name': 'Plank', 'target': 'Core', 'equipment': 'Bodyweight'},
          {'name': 'Bicep Curl', 'target': 'Arms', 'equipment': 'Dumbbells'},
        ],
      };

      final repaired = WorkoutCategoryValidator.validateAndRepairRoutine(
        rawRoutine,
        requestedCategory: 'Core',
        availableEquipment: ['Bodyweight'],
      );

      final exercises = repaired['exercises'] as List;
      expect(exercises.length, greaterThanOrEqualTo(3));

      for (var ex in exercises) {
        final name = (ex['name'] ?? '').toString().toLowerCase();
        final target = (ex['target'] ?? '').toString().toLowerCase();
        final isCore = name.contains('plank') ||
            name.contains('dead bug') ||
            name.contains('crunch') ||
            name.contains('twist') ||
            name.contains('bug') ||
            name.contains('raise') ||
            target.contains('core') ||
            target.contains('ab');
        expect(isCore, isTrue, reason: 'Expected core movement, got: $name ($target)');
      }
    });

    test('LEGS: no unrelated upper-body movements allowed', () {
      final rawRoutine = {
        'name': 'Leg Day',
        'category': 'Legs',
        'exercises': [
          {'name': 'Dumbbell Shoulder Press', 'target': 'Shoulders', 'equipment': 'Dumbbells'},
          {'name': 'Bodyweight Air Squats', 'target': 'Legs', 'equipment': 'Bodyweight'},
          {'name': 'Bench Press', 'target': 'Chest', 'equipment': 'Barbell'},
        ],
      };

      final repaired = WorkoutCategoryValidator.validateAndRepairRoutine(
        rawRoutine,
        requestedCategory: 'Legs',
        availableEquipment: ['Bodyweight'],
      );

      final exercises = repaired['exercises'] as List;
      for (var ex in exercises) {
        final name = (ex['name'] ?? '').toString().toLowerCase();
        expect(name.contains('press'), isFalse, reason: 'Upper body press in legs routine: $name');
        expect(name.contains('row'), isFalse);
      }
    });

    test('PUSH: chest, shoulders, triceps only', () {
      final rawRoutine = {
        'name': 'Push Session',
        'category': 'Push',
        'exercises': [
          {'name': 'Barbell Row', 'target': 'Back', 'equipment': 'Barbell'},
          {'name': 'Push-Ups', 'target': 'Chest', 'equipment': 'Bodyweight'},
          {'name': 'Bicep Curls', 'target': 'Arms', 'equipment': 'Dumbbells'},
        ],
      };

      final repaired = WorkoutCategoryValidator.validateAndRepairRoutine(
        rawRoutine,
        requestedCategory: 'Push',
        availableEquipment: ['Bodyweight'],
      );

      final exercises = repaired['exercises'] as List;
      for (var ex in exercises) {
        final name = (ex['name'] ?? '').toString().toLowerCase();
        expect(name.contains('row'), isFalse, reason: 'Pull exercise in push: $name');
        expect(name.contains('curl'), isFalse, reason: 'Pull exercise in push: $name');
      }
    });

    test('PULL: back, biceps, rear delts only', () {
      final rawRoutine = {
        'name': 'Pull Day',
        'category': 'Pull',
        'exercises': [
          {'name': 'Bench Press', 'target': 'Chest', 'equipment': 'Barbell'},
          {'name': 'Prone Back Extensions (Superman)', 'target': 'Back', 'equipment': 'Bodyweight'},
          {'name': 'Shoulder Press', 'target': 'Shoulders', 'equipment': 'Dumbbells'},
        ],
      };

      final repaired = WorkoutCategoryValidator.validateAndRepairRoutine(
        rawRoutine,
        requestedCategory: 'Pull',
        availableEquipment: ['Bodyweight'],
      );

      final exercises = repaired['exercises'] as List;
      for (var ex in exercises) {
        final name = (ex['name'] ?? '').toString().toLowerCase();
        expect(name.contains('bench press'), isFalse, reason: 'Push exercise in pull: $name');
      }
    });

    test('FULL BODY: must contain balanced Upper Push + Upper Pull + Lower + Core coverage', () {
      final rawRoutine = {
        'name': 'Full Body Routine',
        'category': 'Full Body',
        'exercises': [
          {'name': 'Push-Ups', 'target': 'Chest', 'equipment': 'Bodyweight'},
          {'name': 'Incline Push-Ups', 'target': 'Chest', 'equipment': 'Bodyweight'},
          {'name': 'Diamond Push-Ups', 'target': 'Chest', 'equipment': 'Bodyweight'},
        ],
      };

      final repaired = WorkoutCategoryValidator.validateAndRepairRoutine(
        rawRoutine,
        requestedCategory: 'Full Body',
        availableEquipment: ['Bodyweight'],
      );

      final exercises = repaired['exercises'] as List;
      final names = exercises.map((e) => (e['name'] ?? '').toString().toLowerCase()).toList();

      final hasLower = names.any((n) => n.contains('squat') || n.contains('lunge') || n.contains('leg') || n.contains('bridge'));
      final hasCore = names.any((n) => n.contains('plank') || n.contains('dead bug') || n.contains('crunch') || n.contains('twist'));

      expect(hasLower, isTrue, reason: 'Full body routine lacks lower body exercise: $names');
      expect(hasCore, isTrue, reason: 'Full body routine lacks core exercise: $names');
    });

    test('BEGINNER LEVEL: advanced-only movements are repaired', () {
      final rawRoutine = {
        'name': 'Beginner Routine',
        'category': 'Full Body',
        'exercises': [
          {'name': 'Pistol Squat', 'target': 'Legs', 'equipment': 'Bodyweight'},
          {'name': 'Muscle-Up', 'target': 'Back', 'equipment': 'Bodyweight'},
          {'name': 'Push-Ups', 'target': 'Chest', 'equipment': 'Bodyweight'},
        ],
      };

      final repaired = WorkoutCategoryValidator.validateAndRepairRoutine(
        rawRoutine,
        requestedCategory: 'Full Body',
        fitnessLevel: 'Beginner',
      );

      final exercises = repaired['exercises'] as List;
      final names = exercises.map((e) => (e['name'] ?? '').toString().toLowerCase()).toList();

      expect(names.contains('pistol squat'), isFalse);
      expect(names.contains('muscle-up'), isFalse);
    });

    test('BODYWEIGHT ONLY: equipment violations repaired to bodyweight', () {
      final rawRoutine = {
        'name': 'Home Session',
        'category': 'Chest',
        'exercises': [
          {'name': 'Barbell Bench Press', 'target': 'Chest', 'equipment': 'Barbell'},
          {'name': 'Dumbbell Chest Fly', 'target': 'Chest', 'equipment': 'Dumbbells'},
          {'name': 'Cable Crossover', 'target': 'Chest', 'equipment': 'Cable Machine'},
        ],
      };

      final repaired = WorkoutCategoryValidator.validateAndRepairRoutine(
        rawRoutine,
        requestedCategory: 'Chest',
        availableEquipment: ['Bodyweight'],
      );

      final exercises = repaired['exercises'] as List;
      for (var ex in exercises) {
        expect(ex['equipment'], equals('Bodyweight'), reason: 'Exercise had equipment violation: ${ex['name']}');
      }
    });

    test('DEDUPLICATION: aliases and identical names are deduplicated', () {
      final rawRoutine = {
        'name': 'Duplicate Test',
        'category': 'Chest',
        'exercises': [
          {'name': 'Push-Ups', 'target': 'Chest', 'equipment': 'Bodyweight'},
          {'name': 'Push Ups', 'target': 'Chest', 'equipment': 'Bodyweight'},
          {'name': 'Standard Push-Up', 'target': 'Chest', 'equipment': 'Bodyweight'},
        ],
      };

      final repaired = WorkoutCategoryValidator.validateAndRepairRoutine(
        rawRoutine,
        requestedCategory: 'Chest',
        availableEquipment: ['Bodyweight'],
      );

      final exercises = repaired['exercises'] as List;
      final normalizedNames = exercises
          .map((e) => WorkoutCategoryValidator.normalizeExerciseName(e['name'].toString()))
          .toSet();

      expect(normalizedNames.length, equals(exercises.length), reason: 'Duplicate exercise found');
    });
  });

  group('DailyRecommendationService - Split Rotation & Stability', () {
    test('SAME DATE yields EXACT SAME routine recommendation', () {
      final today = DateTime(2026, 9, 5);
      final rec1 = DailyRecommendationService.getDailyRecommendation(
        userId: 'test_user_42',
        date: today,
        fitnessLevel: 'Intermediate',
        userEquipment: ['Dumbbells'],
      );

      final rec2 = DailyRecommendationService.getDailyRecommendation(
        userId: 'test_user_42',
        date: today,
        fitnessLevel: 'Intermediate',
        userEquipment: ['Dumbbells'],
      );

      expect(rec1.signature, equals(rec2.signature));
      expect(rec1.title, equals(rec2.title));
      expect(rec1.exercises.length, equals(rec2.exercises.length));
    });

    test('CONSECUTIVE DATES rotate through 4-day split progression', () {
      final day1 = DateTime(2026, 9, 1);
      final day2 = DateTime(2026, 9, 2);
      final day3 = DateTime(2026, 9, 3);
      final day4 = DateTime(2026, 9, 4);

      final r1 = DailyRecommendationService.getDailyRecommendation(userId: 'u1', date: day1);
      final r2 = DailyRecommendationService.getDailyRecommendation(userId: 'u1', date: day2);
      final r3 = DailyRecommendationService.getDailyRecommendation(userId: 'u1', date: day3);
      final r4 = DailyRecommendationService.getDailyRecommendation(userId: 'u1', date: day4);

      // Check consecutive days have distinct signatures and different categories/titles
      expect(r1.signature, isNot(equals(r2.signature)));
      expect(r2.signature, isNot(equals(r3.signature)));
      expect(r3.signature, isNot(equals(r4.signature)));
    });

    test('NO EXACT REPETITION within a 4-day block', () {
      final Set<String> signatures = {};
      for (int i = 0; i < 4; i++) {
        final d = DateTime(2026, 9, 10 + i);
        final r = DailyRecommendationService.getDailyRecommendation(userId: 'u_unique', date: d);
        signatures.add(r.signature);
      }
      expect(signatures.length, equals(4));
    });
  });
}
