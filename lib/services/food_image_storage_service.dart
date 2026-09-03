import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

class FoodImageUploadResult {
  final String imageUrl;
  final String imageStoragePath;
  final String? imageHash;

  const FoodImageUploadResult({
    required this.imageUrl,
    required this.imageStoragePath,
    this.imageHash,
  });
}

class FoodImageStorageService {
  FoodImageStorageService._();
  static final FoodImageStorageService instance = FoodImageStorageService._();

  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Uploads a food image to Firebase Storage at `users/{uid}/food_images/{imageHash}.jpg` (or `{mealId}.jpg`).
  ///
  /// Automatically deduplicates: if an image with the same imageHash was previously uploaded,
  /// returns the existing download URL without re-uploading bytes.
  ///
  /// Returns a [FoodImageUploadResult] with the download URL and storage path on success,
  /// or `null` if the upload fails (allowing food logs to still save safely).
  Future<FoodImageUploadResult?> uploadFoodImage({
    required String uid,
    required String mealId,
    String? imageHash,
    File? imageFile,
    Uint8List? imageBytes,
  }) async {
    if (uid.isEmpty || (mealId.isEmpty && (imageHash == null || imageHash.isEmpty))) {
      debugPrint("[FoodImageStorage] Cannot upload: empty uid or mealId/imageHash.");
      return null;
    }

    if (imageFile == null && imageBytes == null) {
      debugPrint("[FoodImageStorage] No image data provided to upload.");
      return null;
    }

    // Using imageHash in the filename allows exact duplicate-image deduplication across multiple meal logs
    final String filename = (imageHash != null && imageHash.isNotEmpty) ? "$imageHash.jpg" : "$mealId.jpg";
    final String storagePath = "users/$uid/food_images/$filename";
    final Reference ref = _storage.ref().child(storagePath);

    // 1. Deduplication Check: if image with this hash already exists, reuse it immediately
    if (imageHash != null && imageHash.isNotEmpty) {
      try {
        final String existingUrl = await ref.getDownloadURL();
        debugPrint("[FoodImageStorage] Deduplication hit: image $filename already exists in Storage. Reusing URL.");
        return FoodImageUploadResult(
          imageUrl: existingUrl,
          imageStoragePath: storagePath,
          imageHash: imageHash,
        );
      } catch (_) {
        // Not yet uploaded in Storage; proceed with normal upload
      }
    }

    final SettableMetadata metadata = SettableMetadata(
      contentType: 'image/jpeg',
      customMetadata: {
        'uploadedAt': DateTime.now().toIso8601String(),
        'mealId': mealId,
        'userId': uid,
        'imageHash': ?imageHash,
      },
    );

    try {
      UploadTask uploadTask;
      if (imageBytes != null) {
        uploadTask = ref.putData(imageBytes, metadata);
      } else {
        uploadTask = ref.putFile(imageFile!, metadata);
      }

      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      debugPrint("[FoodImageStorage] Image successfully uploaded to $storagePath");
      return FoodImageUploadResult(
        imageUrl: downloadUrl,
        imageStoragePath: storagePath,
        imageHash: imageHash,
      );
    } catch (e) {
      debugPrint("[FoodImageStorage] Image upload failed: $e. Meal log will proceed without image.");
      return null;
    }
  }

  /// Deletes a food image from Firebase Storage if it exists.
  Future<void> deleteFoodImage(String storagePath) async {
    if (storagePath.isEmpty) return;
    try {
      await _storage.ref().child(storagePath).delete();
      debugPrint("[FoodImageStorage] Image successfully deleted: $storagePath");
    } catch (e) {
      debugPrint("[FoodImageStorage] Could not delete image at $storagePath: $e");
    }
  }
}
