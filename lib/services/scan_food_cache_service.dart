import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ScanFoodCacheService {
  ScanFoodCacheService._();
  static final ScanFoodCacheService instance = ScanFoodCacheService._();

  /// Increment this version whenever the analysis prompt, backend schema,
  /// or AI model (e.g. Gemini 3.8 Flash) changes meaningfully.
  static const int currentAnalysisVersion = 2;

  static const String _cachePrefix = 'scan_cache_';

  /// Computes a canonical, deterministic SHA-256 hash string from normalized image bytes.
  String computeImageHash(Uint8List bytes) {
    final digest = sha256.convert(bytes);
    return digest.toString().toLowerCase();
  }

  String _buildCacheKey(String imageHash) {
    return '$_cachePrefix${imageHash}_v$currentAnalysisVersion';
  }

  /// Retrieves a previously cached analysis result for this exact image hash and schema version.
  /// Returns null if not cached, expired, or corrupted.
  Future<Map<String, dynamic>?> getCachedAnalysis(String imageHash) async {
    if (imageHash.isEmpty) return null;

    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _buildCacheKey(imageHash);
      final rawJson = prefs.getString(key);

      if (rawJson == null || rawJson.isEmpty) {
        return null;
      }

      final Map<String, dynamic> decoded = json.decode(rawJson);
      final int version = decoded['version'] as int? ?? 0;
      if (version != currentAnalysisVersion) {
        debugPrint("[ScanFoodCache] Cache entry version mismatch ($version vs $currentAnalysisVersion). Invalidating.");
        await prefs.remove(key);
        return null;
      }

      final dynamic data = decoded['analysisData'];
      if (data is Map<String, dynamic>) {
        debugPrint("[ScanFoodCache] Cache HIT for image $imageHash (v$currentAnalysisVersion)");
        return Map<String, dynamic>.from(data);
      }
    } catch (e) {
      debugPrint("[ScanFoodCache] Error reading cache for $imageHash: $e");
    }
    return null;
  }

  /// Persists a completed analysis result to local device storage keyed by image hash.
  Future<void> saveAnalysis(String imageHash, Map<String, dynamic> analysisData) async {
    if (imageHash.isEmpty || analysisData.isEmpty) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _buildCacheKey(imageHash);
      final payload = {
        'imageHash': imageHash,
        'version': currentAnalysisVersion,
        'analyzedAt': DateTime.now().toIso8601String(),
        'analysisData': analysisData,
      };

      await prefs.setString(key, json.encode(payload));
      debugPrint("[ScanFoodCache] Cache SAVED for image $imageHash (v$currentAnalysisVersion)");
    } catch (e) {
      debugPrint("[ScanFoodCache] Error writing cache for $imageHash: $e");
    }
  }

  /// Removes cached analysis for a specific image hash (used when user requests "Re-run AI Analysis").
  Future<void> removeCachedAnalysis(String imageHash) async {
    if (imageHash.isEmpty) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _buildCacheKey(imageHash);
      await prefs.remove(key);
      debugPrint("[ScanFoodCache] Cache CLEARED for image $imageHash");
    } catch (e) {
      debugPrint("[ScanFoodCache] Error clearing cache for $imageHash: $e");
    }
  }

  /// Clears all stored scan food analysis cache entries.
  Future<void> clearAllCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((k) => k.startsWith(_cachePrefix)).toList();
      for (final k in keys) {
        await prefs.remove(k);
      }
      debugPrint("[ScanFoodCache] Cleared ${keys.length} cached scan entries.");
    } catch (e) {
      debugPrint("[ScanFoodCache] Error clearing all cache: $e");
    }
  }
}
