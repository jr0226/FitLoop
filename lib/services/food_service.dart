import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/malaysian_food.dart';

class FoodService {
  static const String cacheNamespace = 'myfcd_food_catalog_v3';
  static List<MalaysianFood>? _cachedFoods;

  /// Exposes currently cached Malaysian foods in memory.
  static List<MalaysianFood>? get cachedFoods => _cachedFoods;

  /// Sets or clears in-memory cached foods for testing.
  @visibleForTesting
  static void setCachedFoodsForTesting(List<MalaysianFood>? foods) {
    _cachedFoods = foods;
  }

  /// Fetches verified Malaysian food records from the live MyFCD v3 backend API.
  ///
  /// Caches results in memory under `myfcd_food_catalog_v3` so subsequent opens
  /// do NOT trigger extra network roundtrips.
  static Future<List<MalaysianFood>> fetchMalaysianFoods({
    bool forceRefresh = false,
    http.Client? client,
  }) async {
    if (_cachedFoods != null && _cachedFoods!.isNotEmpty && !forceRefresh) {
      debugPrint('[FoodService] Returning ${_cachedFoods!.length} cached MyFCD foods ($cacheNamespace).');
      return _cachedFoods!;
    }

    final httpClient = client ?? http.Client();
    String? token;
    try {
      final user = FirebaseAuth.instance.currentUser;
      token = await user?.getIdToken();
    } catch (_) {
      // In tests or unauthenticated guest flows, proceed without auth token
    }

    final headers = <String, String>{
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
    final primaryUrl = Uri.parse(
      '${AppConfig.apiBaseUrl}/api/v3/foods?only_searchable=true&only_primary=true&limit=500',
    );

    try {
      debugPrint('[FoodService] Fetching official MyFCD v3 database from $primaryUrl...');
      final response = await httpClient.get(primaryUrl, headers: headers).timeout(
        const Duration(seconds: AppConfig.requestTimeoutSeconds),
        onTimeout: () => throw Exception('Official MyFCD database request timed out.'),
      );

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        final List<dynamic> rawList = decoded is List
            ? decoded
            : (decoded['data'] ?? decoded['foods'] ?? []);

        final foods = rawList
            .map((item) => MalaysianFood.fromJson(Map<String, dynamic>.from(item as Map)))
            .where((f) => f.isValidForLogging)
            .toList();

        _cachedFoods = foods;
        debugPrint('[FoodService] Successfully loaded and cached ${foods.length} official MyFCD foods ($cacheNamespace).');
        return foods;
      } else {
        throw Exception('Backend returned status code ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[FoodService] MyFCD v3 endpoint error: $e');
      if (_cachedFoods != null && _cachedFoods!.isNotEmpty) {
        debugPrint('[FoodService] Falling back to previously cached ${_cachedFoods!.length} MyFCD foods.');
        return _cachedFoods!;
      }
      rethrow;
    }
  }

  /// Searches the loaded MyFCD database locally with deterministic ranking across:
  /// 1. display_name / name
  /// 2. official_name
  /// 3. name_ms (Malay alias)
  /// 4. category / normalizedCategory
  static List<MalaysianFood> searchLocalFoods(
    String query, {
    List<MalaysianFood>? dataset,
    String? category,
    int limit = 50,
  }) {
    final list = dataset ?? _cachedFoods ?? [];
    final cleanQuery = query.trim().toLowerCase();

    // Filter by category and validity
    final filtered = list.where((food) {
      if (!food.isValidForLogging) return false;
      if (category != null && category != 'All' && category.isNotEmpty) {
        final matchNorm = food.normalizedCategory?.toLowerCase() == category.toLowerCase();
        final matchOrig = food.category.toLowerCase() == category.toLowerCase();
        if (!matchNorm && !matchOrig) return false;
      }
      return true;
    }).toList();

    if (cleanQuery.isEmpty) {
      return filtered.take(limit).toList();
    }

    final List<MalaysianFood> exactMatches = [];
    final List<MalaysianFood> startsWithMatches = [];
    final List<MalaysianFood> containsNameMatches = [];
    final List<MalaysianFood> malayNameMatches = [];
    final List<MalaysianFood> tokenMatches = [];
    final List<MalaysianFood> categoryMatches = [];
    final Set<String> seenKeys = {};

    final queryWords = cleanQuery.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

    for (final food in filtered) {
      final nameLower = food.name.toLowerCase();
      final officialLower = food.officialName?.toLowerCase() ?? '';
      final msLower = food.nameMs.toLowerCase();
      final catLower = food.category.toLowerCase();
      final normCatLower = food.normalizedCategory?.toLowerCase() ?? '';
      final key = '${food.sourceDatabase}_${food.sourceId}_${food.id}';

      if (seenKeys.contains(key)) continue;

      if (nameLower == cleanQuery || officialLower == cleanQuery) {
        exactMatches.add(food);
        seenKeys.add(key);
      } else if (nameLower.startsWith(cleanQuery) || officialLower.startsWith(cleanQuery)) {
        startsWithMatches.add(food);
        seenKeys.add(key);
      } else if (nameLower.contains(cleanQuery) || officialLower.contains(cleanQuery)) {
        containsNameMatches.add(food);
        seenKeys.add(key);
      } else if (msLower.isNotEmpty && (msLower == cleanQuery || msLower.contains(cleanQuery))) {
        malayNameMatches.add(food);
        seenKeys.add(key);
      } else if (queryWords.length > 1 && queryWords.every((w) =>
          nameLower.contains(w) ||
          officialLower.contains(w) ||
          msLower.contains(w) ||
          catLower.contains(w) ||
          normCatLower.contains(w))) {
        tokenMatches.add(food);
        seenKeys.add(key);
      } else if (catLower.contains(cleanQuery) || normCatLower.contains(cleanQuery)) {
        categoryMatches.add(food);
        seenKeys.add(key);
      }
    }

    final List<MalaysianFood> ordered = [
      ...exactMatches,
      ...startsWithMatches,
      ...containsNameMatches,
      ...malayNameMatches,
      ...tokenMatches,
      ...categoryMatches,
    ];

    return ordered.take(limit).toList();
  }

  /// Legacy search method kept for backward compatibility with existing unit tests.
  static Future<List<dynamic>> searchFood(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return [];

    try {
      final foods = await fetchMalaysianFoods();
      final matches = searchLocalFoods(cleanQuery, dataset: foods);
      return matches.map((f) => {
        'name': f.name,
        'calories': f.servingCalories,
        'protein': f.servingProtein,
        'carbs': f.servingCarbs,
        'fat': f.servingFat,
        'serving': f.servingSummary,
      }).toList();
    } catch (_) {
      return [];
    }
  }
}
