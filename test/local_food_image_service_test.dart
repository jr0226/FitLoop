import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/services/local_food_image_service.dart';
import 'package:flutter_application_1/widgets/diet/food_image_display.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('fitloop_food_images_test_');
    LocalFoodImageService.instance.setBaseDirForTesting(tempDir);
  });

  tearDown(() async {
    LocalFoodImageService.instance.setBaseDirForTesting(null);
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('LocalFoodImageService Tests', () {
    test('saveImage saves file and deduplicates duplicate writes', () async {
      final bytes = Uint8List.fromList([1, 2, 3, 4, 5]);
      const hash = 'sample_hash_dedup_1';

      // 1. First save
      final file1 = await LocalFoodImageService.instance.saveImage(
        imageHash: hash,
        imageBytes: bytes,
      );
      expect(await file1.exists(), isTrue);
      expect(file1.path.endsWith('$hash.jpg'), isTrue);
      expect(await file1.readAsBytes(), equals(bytes));

      // 2. Duplicate save with same hash
      final file2 = await LocalFoodImageService.instance.saveImage(
        imageHash: hash,
        imageBytes: bytes,
      );
      expect(file2.path, equals(file1.path));

      // Check directory contents: exactly ONE file exists
      final foodDir = await LocalFoodImageService.instance.getFoodImagesDirectory();
      final files = foodDir.listSync();
      expect(files, hasLength(1));
    });

    test('getImageFile and getImageBytes retrieve correct file and bytes', () async {
      final bytes = Uint8List.fromList([10, 20, 30, 40, 50]);
      const hash = 'retrieve_hash_test';

      expect(await LocalFoodImageService.instance.hasImage(hash), isFalse);

      await LocalFoodImageService.instance.saveImage(imageHash: hash, imageBytes: bytes);

      expect(await LocalFoodImageService.instance.hasImage(hash), isTrue);
      final file = await LocalFoodImageService.instance.getImageFile(hash);
      expect(file, isNotNull);

      final retrievedBytes = await LocalFoodImageService.instance.getImageBytes(hash);
      expect(retrievedBytes, equals(bytes));
    });

    test('cleanupOrphanImages preserves referenced and recent images', () async {
      final bytes = Uint8List.fromList([9, 9, 9]);

      // Image A: Referenced by an active log
      const hashA = 'hash_active_referenced';
      await LocalFoodImageService.instance.saveImage(imageHash: hashA, imageBytes: bytes);

      // Image B: Unreferenced but recent (created today)
      const hashB = 'hash_unreferenced_recent';
      await LocalFoodImageService.instance.saveImage(imageHash: hashB, imageBytes: bytes);

      // Image C: Unreferenced AND older than 30 days
      const hashC = 'hash_unreferenced_old';
      final fileC = await LocalFoodImageService.instance.saveImage(imageHash: hashC, imageBytes: bytes);
      // Artificially modify file timestamp to 40 days ago
      final oldDate = DateTime.now().subtract(const Duration(days: 40));
      await fileC.setLastModified(oldDate);

      // Run cleanup
      final deletedCount = await LocalFoodImageService.instance.cleanupOrphanImages(
        activeReferencedHashes: {hashA},
        maxAge: const Duration(days: 30),
      );

      expect(deletedCount, equals(1)); // Only hashC should be deleted
      expect(await LocalFoodImageService.instance.hasImage(hashA), isTrue); // kept because referenced
      expect(await LocalFoodImageService.instance.hasImage(hashB), isTrue); // kept because recent (<30 days)
      expect(await LocalFoodImageService.instance.hasImage(hashC), isFalse); // deleted
    });
  });

  group('FoodImageDisplay Widget Tests', () {
    testWidgets('FoodImageDisplay renders custom placeholder when image is absent', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FoodImageDisplay(
              placeholder: Text('Custom Food Placeholder'),
            ),
          ),
        ),
      );
      expect(find.text('Custom Food Placeholder'), findsOneWidget);
    });

    testWidgets('FoodImageDisplay renders default restaurant icon when image is empty', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FoodImageDisplay(),
          ),
        ),
      );
      expect(find.byIcon(Icons.restaurant), findsOneWidget);
    });
  });
}
