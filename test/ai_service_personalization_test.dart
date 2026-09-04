import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_application_1/services/ai_service.dart';
import 'package:flutter_application_1/models/workout_models.dart';

void main() {
  group('AiService Personalization Tests', () {
    test('analyzeFoodImage passes user preferences and parses valid response', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, contains('/api/ai/analyze-food'));
        expect(request.method, equals('POST'));

        return http.Response(
          json.encode({
            'foods': [
              {'name': 'Grilled Tofu', 'calories': 180, 'proteins': 18, 'carbs': 5, 'fats': 7}
            ],
            'totalCalories': 180,
            'totalProteins': 18,
            'totalCarbs': 5,
            'totalFats': 7,
            'score': 92,
            'explanation': 'Great high-protein vegetarian meal.',
            'alternatives': ['Steamed Edamame'],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final result = await AiService.analyzeFoodImage(
        imageBytes: Uint8List.fromList([1, 2, 3, 4]),
        userGoal: 'Muscle Gain',
        calorieTarget: 2200,
        dietPreference: 'Vegetarian',
        allergies: ['Peanuts'],
        httpClient: mockClient,
      );

      expect(result['totalCalories'], equals(180));
      expect(result['score'], equals(92));
      expect(result['foods'], isNotEmpty);
    });

    test('analyzeFoodImage safe defaults when preferences are omitted', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, contains('/api/ai/analyze-food'));
        return http.Response(
          json.encode({
            'foods': [],
            'totalCalories': 0,
            'totalProteins': 0,
            'totalCarbs': 0,
            'totalFats': 0,
            'score': 70,
            'explanation': 'Balanced meal.',
            'alternatives': [],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final result = await AiService.analyzeFoodImage(
        imageBytes: Uint8List.fromList([1, 2, 3]),
        httpClient: mockClient,
      );

      expect(result['score'], equals(70));
    });

    test('generateWorkoutPlan passes equipment, preferences, and recent summary', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, contains('/api/ai/generate-workout'));
        expect(request.method, equals('POST'));

        final body = json.decode(request.body) as Map<String, dynamic>;
        expect(body['userGoal'], equals('Muscle Gain'));
        expect(body['difficulty'], equals('Intermediate'));
        expect(body['equipment'], equals(['Dumbbells', 'Bench']));
        expect(body['preferredWorkoutTypes'], equals(['Strength', 'Upper Body']));
        expect(body['recentWorkoutsSummary'], equals('Recent 7 days: Chest: 1 session, Legs: 2 sessions'));

        return http.Response(
          json.encode([
            {
              'routineName': 'Dumbbell Upper Hypertrophy',
              'level': 'Intermediate',
              'category': 'Upper Body',
              'image': 'https://example.com/image.jpg',
              'exercises': [
                {
                  'name': 'Dumbbell Incline Bench Press',
                  'category': 'Chest',
                  'sets': '3 sets x 10 reps',
                  'image': 'https://example.com/ex.jpg',
                  'desc': 'Controlled eccentric tempo.',
                }
              ]
            }
          ]),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final routines = await AiService.generateWorkoutPlan(
        userGoal: 'Muscle Gain',
        difficulty: 'Intermediate',
        equipment: ['Dumbbells', 'Bench'],
        preferredWorkoutTypes: ['Strength', 'Upper Body'],
        recentWorkoutsSummary: 'Recent 7 days: Chest: 1 session, Legs: 2 sessions',
        httpClient: mockClient,
      );

      expect(routines, isNotEmpty);
      expect(routines.first['routineName'], equals('Dumbbell Upper Hypertrophy'));
      expect(routines.first['exercises'], isNotEmpty);
    });

    test('generateWorkoutPlan safe defaults for legacy calls', () async {
      final mockClient = MockClient((request) async {
        final body = json.decode(request.body) as Map<String, dynamic>;
        expect(body['userGoal'], equals('Maintenance'));
        expect(body['difficulty'], equals('Intermediate'));
        expect(body['equipment'], isEmpty);
        expect(body['preferredWorkoutTypes'], isEmpty);
        expect(body.containsKey('recentWorkoutsSummary'), isFalse);

        return http.Response(
          json.encode([
            {
              'routineName': 'Full Body Beginner',
              'level': 'Beginner',
              'category': 'Full Body',
              'exercises': []
            }
          ]),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final routines = await AiService.generateWorkoutPlan(
        httpClient: mockClient,
      );

      expect(routines.length, equals(1));
      expect(routines.first['routineName'], equals('Full Body Beginner'));
    });

    test('generateWorkoutPlan passes targetCategory when provided', () async {
      final mockClient = MockClient((request) async {
        final body = json.decode(request.body) as Map<String, dynamic>;
        expect(body['targetCategory'], equals('Cardio'));
        expect(body['category'], equals('Cardio'));

        return http.Response(
          json.encode([
            {
              'routineName': 'Cardio Burn Engine',
              'level': 'Beginner',
              'category': 'Cardio',
              'exercises': [
                {
                  'name': 'Air Bike Sprint',
                  'target': 'Cardio',
                  'equipment': 'Air Bike',
                  'sets': '5 sets x 30s',
                  'durationSeconds': 30,
                }
              ]
            }
          ]),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final routines = await AiService.generateWorkoutPlan(
        targetCategory: 'Cardio',
        httpClient: mockClient,
      );

      expect(routines.length, equals(1));
      expect(routines.first['category'], equals('Cardio'));
    });

    test('ExerciseModel parses Cardio timed intervals correctly', () {
      final ex = ExerciseModel.fromJson({
        'name': 'Jump Rope',
        'target': 'Cardio',
        'equipment': 'Jump Rope',
        'sets': '4 sets x 60s',
        'durationSeconds': 60,
      });

      expect(ex.name, equals('Jump Rope'));
      expect(ex.isTimed, isTrue);
      expect(ex.durationSeconds, equals(60));
      expect(ex.defaultSets, equals(4));
      expect(ex.defaultReps, equals(0));
    });

    test('ExerciseModel parses duration from sets string when durationSeconds omitted', () {
      final ex = ExerciseModel.fromJson({
        'name': 'Plank Hold',
        'target': 'Abs',
        'equipment': 'Bodyweight',
        'sets': '3 sets x 45 seconds',
      });

      expect(ex.targetMuscle, equals('Core'));
      expect(ex.isTimed, isTrue);
      expect(ex.durationSeconds, equals(45));
      expect(ex.defaultSets, equals(3));
      expect(ex.defaultReps, equals(0));
    });

    test('WorkoutRoutine normalizes Abs/Waist categories to Core', () {
      final routine = WorkoutRoutine.fromFirestore('routine_1', {
        'name': 'Abs Shred',
        'category': 'waist',
        'fitnessGoal': 'Muscle Gain',
        'level': 'Beginner',
        'exercises': [
          {
            'name': 'Crunches',
            'target': 'abdominals',
            'sets': '3 sets x 15 reps',
          }
        ],
      });

      expect(routine.category, equals('Core'));
      expect(routine.exercises.first.targetMuscle, equals('Core'));
    });
  });
}
