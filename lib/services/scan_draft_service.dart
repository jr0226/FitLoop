import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'local_food_image_service.dart';

class ScanDraft {
  final String imageHash;
  final Uint8List? _inMemoryBytes;
  final Map<String, dynamic> analysisData;
  final String mealName;
  final Map<String, dynamic>? userEdits;
  final DateTime timestamp;

  const ScanDraft({
    required this.imageHash,
    Uint8List? imageBytes,
    Uint8List? inMemoryBytes,
    required this.analysisData,
    required this.mealName,
    this.userEdits,
    required this.timestamp,
  }) : _inMemoryBytes = inMemoryBytes ?? imageBytes;

  /// Returns available image bytes, resolving synchronously from local disk if available.
  Uint8List get imageBytes {
    final bytes = _inMemoryBytes;
    if (bytes != null && bytes.isNotEmpty) {
      return bytes;
    }
    final file = LocalFoodImageService.instance.getImageFileImmediate(imageHash);
    if (file != null && file.existsSync()) {
      try {
        return file.readAsBytesSync();
      } catch (_) {}
    }
    return Uint8List(0);
  }

  int get calories {
    if (userEdits != null && userEdits!['calories'] is num) {
      return (userEdits!['calories'] as num).toInt();
    }
    return (analysisData['totalCalories'] as num?)?.toInt() ?? 0;
  }

  int get protein {
    if (userEdits != null && userEdits!['protein'] is num) {
      return (userEdits!['protein'] as num).toInt();
    }
    return (analysisData['totalProteins'] as num?)?.toInt() ?? 0;
  }

  /// Drafts older than 24 hours are automatically marked expired.
  bool get isExpired {
    final difference = DateTime.now().difference(timestamp);
    return difference.inHours >= 24;
  }

  String get timeAgo {
    final difference = DateTime.now().difference(timestamp);
    if (difference.inMinutes < 1) {
      return "Just now";
    } else if (difference.inMinutes < 60) {
      return "${difference.inMinutes}m ago";
    } else if (difference.inHours < 24) {
      return "${difference.inHours}h ago";
    } else {
      return "${difference.inDays}d ago";
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'imageHash': imageHash,
      // No large base64 image bytes stored in SharedPreferences.
      // Replaced by lightweight imageHash referencing local on-device file.
      'analysisData': analysisData,
      'mealName': mealName,
      'userEdits': userEdits,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory ScanDraft.fromJson(Map<String, dynamic> json, {Uint8List? resolvedBytes}) {
    Uint8List? bytes = resolvedBytes;
    if (bytes == null && json['imageBytesBase64'] != null && (json['imageBytesBase64'] as String).isNotEmpty) {
      try {
        bytes = base64.decode(json['imageBytesBase64'] as String);
      } catch (_) {}
    }

    return ScanDraft(
      imageHash: json['imageHash'] as String? ?? '',
      inMemoryBytes: bytes,
      analysisData: Map<String, dynamic>.from(json['analysisData'] as Map? ?? {}),
      mealName: json['mealName'] as String? ?? 'Meal',
      userEdits: json['userEdits'] != null ? Map<String, dynamic>.from(json['userEdits'] as Map) : null,
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

class ScanDraftService {
  ScanDraftService._();
  static final ScanDraftService instance = ScanDraftService._();

  static const String _draftKey = 'fitloop_active_scan_draft';

  /// Saves or updates the currently active scan draft.
  ///
  /// Guarantees the compressed image is stored on-device in `food_images/{imageHash}.jpg`,
  /// avoiding large base64 strings in SharedPreferences.
  Future<void> saveDraft({
    required String imageHash,
    required Uint8List imageBytes,
    required Map<String, dynamic> analysisData,
    required String mealName,
    Map<String, dynamic>? userEdits,
  }) async {
    try {
      // 1. Persist image bytes to local filesystem
      if (imageBytes.isNotEmpty) {
        await LocalFoodImageService.instance.saveImage(
          imageHash: imageHash,
          imageBytes: imageBytes,
        );
      }

      // 2. Store lightweight draft metadata in SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final draft = ScanDraft(
        imageHash: imageHash,
        inMemoryBytes: imageBytes,
        analysisData: analysisData,
        mealName: mealName,
        userEdits: userEdits,
        timestamp: DateTime.now(),
      );

      await prefs.setString(_draftKey, json.encode(draft.toJson()));
      debugPrint("[ScanDraft] Draft saved: ${draft.mealName} (hash: $imageHash, no base64 in prefs)");
    } catch (e) {
      debugPrint("[ScanDraft] Error saving draft: $e");
    }
  }

  /// Retrieves the active unsaved draft if one exists and has not expired.
  /// Resolves the actual image bytes from local on-device storage.
  Future<ScanDraft?> getDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_draftKey);
      if (raw == null || raw.isEmpty) return null;

      final decoded = json.decode(raw);
      if (decoded is! Map<String, dynamic>) return null;

      final imageHash = decoded['imageHash'] as String? ?? '';
      final resolvedBytes = await LocalFoodImageService.instance.getImageBytes(imageHash);

      final draft = ScanDraft.fromJson(decoded, resolvedBytes: resolvedBytes);
      if (draft.isExpired) {
        debugPrint("[ScanDraft] Stored draft expired (>24h). Discarding automatically.");
        await prefs.remove(_draftKey);
        return null;
      }

      return draft;
    } catch (e) {
      debugPrint("[ScanDraft] Error reading draft: $e");
      return null;
    }
  }

  /// Clears the active scan draft upon user save or explicit discard.
  /// Note: Does NOT delete the local image file to prevent accidental loss if referenced by logs/cache.
  Future<void> clearDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_draftKey);
      debugPrint("[ScanDraft] Active draft cleared (local image preserved).");
    } catch (e) {
      debugPrint("[ScanDraft] Error clearing draft: $e");
    }
  }

  /// Quickly checks if an active draft exists.
  Future<bool> hasActiveDraft() async {
    final draft = await getDraft();
    return draft != null;
  }
}
