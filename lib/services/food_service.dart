import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/malaysian_food.dart';

class FoodService {
  static List<MalaysianFood>? _cachedFoods;

  /// Exposes currently cached Malaysian foods in memory.
  static List<MalaysianFood>? get cachedFoods => _cachedFoods;

  /// Sets or clears in-memory cached foods for testing.
  @visibleForTesting
  static void setCachedFoodsForTesting(List<MalaysianFood>? foods) {
    _cachedFoods = foods;
  }

  /// Fetches all Malaysian food records from the live backend API.
  ///
  /// Caches results in memory so subsequent searches/opens in the same app session
  /// do NOT trigger additional network requests or Render cold starts.
  static Future<List<MalaysianFood>> fetchMalaysianFoods({
    bool forceRefresh = false,
    http.Client? client,
  }) async {
    if (_cachedFoods != null && _cachedFoods!.isNotEmpty && !forceRefresh) {
      debugPrint('[FoodService] Returning ${_cachedFoods!.length} cached Malaysian foods.');
      return _cachedFoods!;
    }

    final httpClient = client ?? http.Client();
    final primaryUrl = Uri.parse('${AppConfig.apiBaseUrl}/api/v1/foods');

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

    try {
      debugPrint('[FoodService] Fetching Malaysian food database from $primaryUrl...');
      final response = await httpClient.get(primaryUrl, headers: headers).timeout(
        const Duration(seconds: AppConfig.requestTimeoutSeconds),
        onTimeout: () => throw Exception('Malaysian food database request timed out.'),
      );

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        final List<dynamic> rawList = decoded is List
            ? decoded
            : (decoded['data'] ?? decoded['foods'] ?? []);

        final foods = rawList
            .map((item) => MalaysianFood.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList();

        _cachedFoods = foods;
        debugPrint('[FoodService] Successfully loaded and cached ${foods.length} Malaysian foods.');
        return foods;
      } else {
        throw Exception('Backend returned status code ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[FoodService] Primary endpoint failed: $e');
      // If cached data already exists, gracefully return it
      if (_cachedFoods != null && _cachedFoods!.isNotEmpty) {
        debugPrint('[FoodService] Falling back to previously cached ${_cachedFoods!.length} foods.');
        return _cachedFoods!;
      }
      rethrow;
    }
  }

  /// Searches the loaded Malaysian food database locally with deterministic ranking.
  ///
  /// Ranking Order:
  /// 1. Exact name match (case-insensitive)
  /// 2. Starts-with name match
  /// 3. Contains in English name
  /// 4. Contains in Malay name (name_ms)
  /// 5. Contains in category
  static List<MalaysianFood> searchLocalFoods(
    String query, {
    List<MalaysianFood>? dataset,
    int limit = 30,
  }) {
    final list = dataset ?? _cachedFoods ?? [];
    final cleanQuery = query.trim().toLowerCase();

    if (cleanQuery.isEmpty) {
      return list.take(limit).toList();
    }

    final List<MalaysianFood> exactMatches = [];
    final List<MalaysianFood> startsWithMatches = [];
    final List<MalaysianFood> containsNameMatches = [];
    final List<MalaysianFood> malayNameMatches = [];
    final List<MalaysianFood> categoryMatches = [];
    final Set<int> seenIds = {};

    for (final food in list) {
      final nameLower = food.name.toLowerCase();
      final msLower = food.nameMs.toLowerCase();
      final catLower = food.category.toLowerCase();

      if (nameLower == cleanQuery) {
        exactMatches.add(food);
        seenIds.add(food.id);
      } else if (nameLower.startsWith(cleanQuery)) {
        startsWithMatches.add(food);
        seenIds.add(food.id);
      } else if (nameLower.contains(cleanQuery)) {
        containsNameMatches.add(food);
        seenIds.add(food.id);
      } else if (msLower.contains(cleanQuery)) {
        malayNameMatches.add(food);
        seenIds.add(food.id);
      } else if (catLower.contains(cleanQuery)) {
        categoryMatches.add(food);
        seenIds.add(food.id);
      }
    }

    final List<MalaysianFood> ordered = [
      ...exactMatches,
      ...startsWithMatches,
      ...containsNameMatches,
      ...malayNameMatches,
      ...categoryMatches,
    ];

    return ordered.take(limit).toList();
  }

  /// Legacy search method kept for backward compatibility with existing tests.
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
        'serving': '${f.servingName} (${f.servingGrams.toInt()}g)',
      }).toList();
    } catch (_) {
      return [];
    }
  }
}
