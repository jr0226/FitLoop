import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_1/services/scan_food_cache_service.dart';
import 'package:flutter_application_1/services/scan_draft_service.dart';
import 'package:flutter_application_1/services/local_food_image_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('fitloop_draft_test_');
    LocalFoodImageService.instance.setBaseDirForTesting(tempDir);
  });

  tearDown(() async {
    LocalFoodImageService.instance.setBaseDirForTesting(null);
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('ScanFoodCacheService Tests', () {
    test('computeImageHash produces deterministic SHA-256 string for identical bytes', () {
      final bytes1 = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
      final bytes2 = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
      final bytesDiff = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8, 9, 11]);

      final hash1 = ScanFoodCacheService.instance.computeImageHash(bytes1);
      final hash2 = ScanFoodCacheService.instance.computeImageHash(bytes2);
      final hashDiff = ScanFoodCacheService.instance.computeImageHash(bytesDiff);

      expect(hash1, equals(hash2));
      expect(hash1.length, equals(64)); // SHA-256 hex string is 64 characters
      expect(hash1, isNot(equals(hashDiff)));
    });

    test('getCachedAnalysis returns null on cache miss', () async {
      final result = await ScanFoodCacheService.instance.getCachedAnalysis('non_existent_hash');
      expect(result, isNull);
    });

    test('saveAnalysis stores and getCachedAnalysis retrieves full payload', () async {
      const hash = 'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2';
      final sampleAnalysis = {
        'foods': [
          {'name': 'Nasi Lemak', 'calories': 450, 'protein': 12, 'carbs': 55, 'fat': 18}
        ],
        'totalCalories': 450,
        'totalProteins': 12,
        'totalCarbs': 55,
        'totalFats': 18,
        'score': 78,
        'explanation': 'Balanced Malaysian meal.',
        'alternatives': ['Less sambal for lower sodium'],
      };

      await ScanFoodCacheService.instance.saveAnalysis(hash, sampleAnalysis);
      final cached = await ScanFoodCacheService.instance.getCachedAnalysis(hash);

      expect(cached, isNotNull);
      expect(cached!['totalCalories'], equals(450));
      expect(cached['foods'], hasLength(1));
      expect(cached['foods'][0]['name'], equals('Nasi Lemak'));
      expect(cached['score'], equals(78));
    });

    test('removeCachedAnalysis removes entry enabling clean re-analysis', () async {
      const hash = 'sample_hash_for_invalidation';
      await ScanFoodCacheService.instance.saveAnalysis(hash, {'totalCalories': 300});

      var cached = await ScanFoodCacheService.instance.getCachedAnalysis(hash);
      expect(cached, isNotNull);

      await ScanFoodCacheService.instance.removeCachedAnalysis(hash);
      cached = await ScanFoodCacheService.instance.getCachedAnalysis(hash);
      expect(cached, isNull);
    });

    test('5-run repeatability simulation demonstrates 1st miss and 2nd-5th cache hits', () async {
      final testImageBytes = Uint8List.fromList(List.generate(100, (i) => (i * 7) % 256));

      int backendCallCount = 0;

      Future<Map<String, dynamic>> scanPipeline(Uint8List bytes) async {
        final hash = ScanFoodCacheService.instance.computeImageHash(bytes);
        final cached = await ScanFoodCacheService.instance.getCachedAnalysis(hash);
        if (cached != null) {
          return cached;
        }

        // Simulate backend call
        backendCallCount++;
        final freshResult = {
          'foods': [
            {'name': 'Roti Canai', 'calories': 300, 'protein': 7, 'carbs': 38, 'fat': 13}
          ],
          'totalCalories': 300,
          'totalProteins': 7,
          'totalCarbs': 38,
          'totalFats': 13,
          'score': 70,
        };
        await ScanFoodCacheService.instance.saveAnalysis(hash, freshResult);
        return freshResult;
      }

      // Run 1: First scan -> cache miss -> backend called
      final run1 = await scanPipeline(testImageBytes);
      expect(backendCallCount, equals(1));
      expect(run1['totalCalories'], equals(300));

      // Run 2: Exact same image -> cache HIT -> backend NOT called
      final run2 = await scanPipeline(testImageBytes);
      expect(backendCallCount, equals(1));
      expect(run2, equals(run1));

      // Run 3: Exact same image -> cache HIT -> backend NOT called
      final run3 = await scanPipeline(testImageBytes);
      expect(backendCallCount, equals(1));
      expect(run3, equals(run1));

      // Run 4: Exact same image -> cache HIT -> backend NOT called
      final run4 = await scanPipeline(testImageBytes);
      expect(backendCallCount, equals(1));
      expect(run4, equals(run1));

      // Run 5: Exact same image -> cache HIT -> backend NOT called
      final run5 = await scanPipeline(testImageBytes);
      expect(backendCallCount, equals(1));
      expect(run5, equals(run1));
    });
  });

  group('ScanDraftService Tests', () {
    test('saveDraft stores draft and getDraft restores it faithfully', () async {
      final bytes = Uint8List.fromList([10, 20, 30, 40]);
      const hash = 'draft_hash_123';
      final analysis = {
        'foods': [
          {'name': 'Chicken Rice', 'calories': 600}
        ],
        'totalCalories': 600,
        'totalProteins': 32,
      };

      await ScanDraftService.instance.saveDraft(
        imageHash: hash,
        imageBytes: bytes,
        analysisData: analysis,
        mealName: 'Chicken Rice with Chili',
      );

      final draft = await ScanDraftService.instance.getDraft();
      expect(draft, isNotNull);
      expect(draft!.imageHash, equals(hash));
      expect(draft.mealName, equals('Chicken Rice with Chili'));
      expect(draft.calories, equals(600));
      expect(draft.imageBytes, equals(bytes));
      expect(draft.isExpired, isFalse);
    });

    test('clearDraft wipes active draft', () async {
      final bytes = Uint8List.fromList([1, 2, 3]);
      await ScanDraftService.instance.saveDraft(
        imageHash: 'temp_hash',
        imageBytes: bytes,
        analysisData: {'totalCalories': 200},
        mealName: 'Salad',
      );

      expect(await ScanDraftService.instance.hasActiveDraft(), isTrue);

      await ScanDraftService.instance.clearDraft();
      expect(await ScanDraftService.instance.hasActiveDraft(), isFalse);
      expect(await ScanDraftService.instance.getDraft(), isNull);
    });

    test('user edits in draft override base analysis totals', () async {
      final bytes = Uint8List.fromList([1, 2, 3]);
      final analysis = {'totalCalories': 400, 'totalProteins': 20};

      await ScanDraftService.instance.saveDraft(
        imageHash: 'edit_hash',
        imageBytes: bytes,
        analysisData: analysis,
        mealName: 'Original Rice',
        userEdits: {'calories': 600, 'protein': 35},
      );

      final draft = await ScanDraftService.instance.getDraft();
      expect(draft, isNotNull);
      expect(draft!.calories, equals(600)); // user edited
      expect(draft.protein, equals(35));
    });

    test('draft older than 24 hours is automatically expired', () {
      final oldDraft = ScanDraft(
        imageHash: 'old_hash',
        imageBytes: Uint8List.fromList([0]),
        analysisData: {},
        mealName: 'Old Food',
        timestamp: DateTime.now().subtract(const Duration(hours: 25)),
      );

      expect(oldDraft.isExpired, isTrue);
    });
  });
}
