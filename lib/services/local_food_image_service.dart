import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Service for persisting, deduplicating, and retrieving food images locally on-device.
///
/// Images are stored under the app documents directory:
/// `food_images/{imageHash}.jpg`
///
/// Deduplication guarantee: An exact image (identified by its SHA-256 hash)
/// is stored only once regardless of how many meal logs reference it.
class LocalFoodImageService {
  LocalFoodImageService._();
  static final LocalFoodImageService instance = LocalFoodImageService._();

  Directory? _imagesDir;
  Directory? _customBaseDir;

  /// Allows injecting a custom directory for unit and widget tests.
  @visibleForTesting
  void setBaseDirForTesting(Directory? dir) {
    _customBaseDir = dir;
    _imagesDir = dir;
  }

  /// Returns the persistent `food_images` directory on device.
  Future<Directory> getFoodImagesDirectory() async {
    if (_imagesDir != null) {
      if (!await _imagesDir!.exists()) {
        await _imagesDir!.create(recursive: true);
      }
      return _imagesDir!;
    }

    Directory foodImagesDir;
    try {
      final baseDir = _customBaseDir ?? await getApplicationDocumentsDirectory();
      foodImagesDir = Directory('${baseDir.path}/food_images');
    } catch (_) {
      // Fallback for flutter_test environments when path_provider channel is unmocked
      foodImagesDir = Directory('${Directory.systemTemp.path}/fitloop_food_images');
    }

    if (!await foodImagesDir.exists()) {
      await foodImagesDir.create(recursive: true);
    }
    _imagesDir = foodImagesDir;
    return foodImagesDir;
  }

  /// Fast synchronous lookup for an image file if the directory has already been initialized.
  File? getImageFileImmediate(String imageHash) {
    if (_imagesDir == null || imageHash.isEmpty) return null;
    final file = File('${_imagesDir!.path}/$imageHash.jpg');
    return file.existsSync() ? file : null;
  }

  /// Saves compressed image bytes locally using `{imageHash}.jpg`.
  ///
  /// If the image file already exists, it is reused without re-writing (deduplication).
  Future<File> saveImage({
    required String imageHash,
    required Uint8List imageBytes,
  }) async {
    final dir = await getFoodImagesDirectory();
    final file = File('${dir.path}/$imageHash.jpg');

    if (await file.exists()) {
      debugPrint("[LocalFoodImage] Deduplication hit: image $imageHash.jpg already exists locally.");
      return file;
    }

    await file.writeAsBytes(imageBytes, flush: true);
    debugPrint("[LocalFoodImage] Saved compressed food image: ${file.path} (${imageBytes.length} bytes)");
    return file;
  }

  /// Resolves the local image file for a given imageHash.
  /// Returns `null` if the file does not exist on this device.
  Future<File?> getImageFile(String imageHash) async {
    if (imageHash.isEmpty) return null;
    try {
      final dir = await getFoodImagesDirectory();
      final file = File('${dir.path}/$imageHash.jpg');
      if (await file.exists()) {
        return file;
      }
    } catch (e) {
      debugPrint("[LocalFoodImage] Error resolving image for $imageHash: $e");
    }
    return null;
  }

  /// Reads the raw bytes of a locally stored food image.
  Future<Uint8List?> getImageBytes(String imageHash) async {
    final file = await getImageFile(imageHash);
    if (file != null) {
      try {
        return await file.readAsBytes();
      } catch (e) {
        debugPrint("[LocalFoodImage] Error reading bytes for $imageHash: $e");
      }
    }
    return null;
  }

  /// Checks whether an image exists locally.
  Future<bool> hasImage(String imageHash) async {
    final file = await getImageFile(imageHash);
    return file != null;
  }

  /// Deletes a specific food image file if requested.
  Future<bool> deleteImage(String imageHash) async {
    if (imageHash.isEmpty) return false;
    try {
      final dir = await getFoodImagesDirectory();
      final file = File('${dir.path}/$imageHash.jpg');
      if (await file.exists()) {
        await file.delete();
        debugPrint("[LocalFoodImage] Deleted image $imageHash.jpg");
        return true;
      }
    } catch (e) {
      debugPrint("[LocalFoodImage] Error deleting image $imageHash: $e");
    }
    return false;
  }

  /// Optional cleanup strategy:
  /// Deletes local food images that are no longer referenced by active drafts
  /// or saved meal logs, AND are older than [maxAge] (default 30 days).
  ///
  /// Never deletes recent files to prevent accidental data loss.
  Future<int> cleanupOrphanImages({
    required Set<String> activeReferencedHashes,
    Duration maxAge = const Duration(days: 30),
  }) async {
    int deletedCount = 0;
    try {
      final dir = await getFoodImagesDirectory();
      final entities = dir.listSync();
      final now = DateTime.now();

      for (final entity in entities) {
        if (entity is File && entity.path.endsWith('.jpg')) {
          final fileName = entity.uri.pathSegments.last;
          final hash = fileName.replaceAll('.jpg', '');

          // If referenced by active draft or saved log, keep it!
          if (activeReferencedHashes.contains(hash)) {
            continue;
          }

          // Check file age
          final stat = await entity.stat();
          final age = now.difference(stat.modified);
          if (age > maxAge) {
            await entity.delete();
            deletedCount++;
            debugPrint("[LocalFoodImage] Cleaned up orphaned food image: $fileName (age: ${age.inDays} days)");
          }
        }
      }
    } catch (e) {
      debugPrint("[LocalFoodImage] Cleanup error: $e");
    }
    return deletedCount;
  }
}
