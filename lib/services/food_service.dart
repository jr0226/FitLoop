import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/malaysian_food.dart';

class FoodService {
  static const String cacheNamespace = 'myfcd_food_catalog_v3';

  /// Browse-page cache: first 100 foods for the empty-query state.
  /// This is NOT the full database — use [searchFoodsOnServer] for full search.
  static List<MalaysianFood>? _cachedFoods;

  /// Page size for browse (no query) — keeps first-open fast.
  static const int _browsePageSize = 100;

  /// Page size for server-side search results.
  static const int _searchPageSize = 50;

  /// Exposes currently cached first-page foods (for browse / testing).
  static List<MalaysianFood>? get cachedFoods => _cachedFoods;

  /// Sets or clears in-memory cached foods for testing.
  @visibleForTesting
  static void setCachedFoodsForTesting(List<MalaysianFood>? foods) {
    _cachedFoods = foods;
  }

  /// Optional HTTP client injected by tests for server-side search calls.
  static http.Client? _testSearchClient;

  /// Injects a mock HTTP client for [searchFoodsOnServer] in tests.
  @visibleForTesting
  static void setSearchClientForTesting(http.Client? client) {
    _testSearchClient = client;
  }

  // -------------------------------------------------------------------------
  // Internal helpers
  // -------------------------------------------------------------------------

  static Future<Map<String, String>> _buildHeaders() async {
    String? token;
    try {
      final user = FirebaseAuth.instance.currentUser;
      token = await user?.getIdToken();
    } catch (_) {
      // Tests / unauthenticated flows — proceed without token
    }
    return <String, String>{
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static List<MalaysianFood> _parseFoodList(http.Response response) {
    final decoded = json.decode(response.body);
    final List<dynamic> rawList = decoded is List
        ? decoded
        : (decoded['data'] ?? decoded['foods'] ?? []);
    return rawList
        .map((item) => MalaysianFood.fromJson(Map<String, dynamic>.from(item as Map)))
        .where((f) => f.isValidForLogging)
        .toList();
  }

  // -------------------------------------------------------------------------
  // 1. Browse — paginated first-page fetch for the empty-query state
  // -------------------------------------------------------------------------

  /// Fetches a page of verified MyFCD v3 foods for browse display.
  ///
  /// Page 1 with no category is cached in memory. Subsequent pages or category
  /// filters always hit the network.
  ///
  /// This is NOT a search — it only covers [_browsePageSize] records per page.
  /// For search across the FULL 1,239-record database use [searchFoodsOnServer].
  static Future<List<MalaysianFood>> fetchMalaysianFoods({
    bool forceRefresh = false,
    int page = 1,
    String? category,
    http.Client? client,
  }) async {
    // Return memory cache only for the default first-page browse
    if (_cachedFoods != null &&
        _cachedFoods!.isNotEmpty &&
        !forceRefresh &&
        page == 1 &&
        category == null) {
      debugPrint('[FoodService] Returning ${_cachedFoods!.length} cached MyFCD foods ($cacheNamespace).');
      return _cachedFoods!;
    }

    final httpClient = client ?? http.Client();
    final headers = await _buildHeaders();

    final params = <String, String>{
      'only_searchable': 'true',
      'only_primary': 'true',
      'limit': '$_browsePageSize',
      'page': '$page',
      if (category != null && category != 'All') 'normalized_category': category,
    };
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/api/v3/foods')
        .replace(queryParameters: params);

    try {
      debugPrint('[FoodService] Fetching official MyFCD v3 database (page $page) from $uri...');
      final response = await httpClient.get(uri, headers: headers).timeout(
        const Duration(seconds: AppConfig.requestTimeoutSeconds),
        onTimeout: () => throw Exception('Official MyFCD database request timed out.'),
      );

      if (response.statusCode == 200) {
        final foods = _parseFoodList(response);

        // Cache only for first-page, no-category browse
        if (page == 1 && category == null) {
          _cachedFoods = foods;
          debugPrint('[FoodService] Cached ${foods.length} official MyFCD foods ($cacheNamespace).');
        }
        return foods;
      } else {
        throw Exception('Backend returned status code ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[FoodService] MyFCD v3 browse error: $e');
      if (_cachedFoods != null && _cachedFoods!.isNotEmpty) {
        debugPrint('[FoodService] Falling back to previously cached ${_cachedFoods!.length} MyFCD foods.');
        return _cachedFoods!;
      }
      rethrow;
    }
  }

  // -------------------------------------------------------------------------
  // 2. Server-side search — queries the FULL database, never the local cache
  // -------------------------------------------------------------------------

  /// Searches the FULL MyFCD v3 database on the server.
  ///
  /// Unlike [searchLocalFoods], this always sends a network request and can
  /// match foods that were never downloaded to the device cache.
  /// This is the authoritative search — it covers all 1,239 searchable records.
  ///
  /// Returns an empty list (not an exception) on network failure so the UI can
  /// gracefully show "No results found".
  static Future<List<MalaysianFood>> searchFoodsOnServer(
    String query, {
    String? category,
    int limit = _searchPageSize,
    http.Client? client,
  }) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return [];

    final httpClient = client ?? _testSearchClient ?? http.Client();
    final headers = await _buildHeaders();

    final params = <String, String>{
      'q': cleanQuery,
      'only_searchable': 'true',
      'only_primary': 'true',
      'limit': '$limit',
      if (category != null && category != 'All') 'normalized_category': category,
    };
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/api/v3/foods')
        .replace(queryParameters: params);

    try {
      debugPrint('[FoodService] Server search: $uri');
      final response = await httpClient.get(uri, headers: headers).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw Exception('Search request timed out.'),
      );

      if (response.statusCode == 200) {
        final foods = _parseFoodList(response);
        debugPrint('[FoodService] Server search "$cleanQuery" → ${foods.length} results.');
        return foods;
      } else {
        debugPrint('[FoodService] Server search returned ${response.statusCode}.');
        return [];
      }
    } catch (e) {
      debugPrint('[FoodService] Server search error: $e');
      // Graceful fallback to local cache if network is unavailable
      if (_cachedFoods != null && _cachedFoods!.isNotEmpty) {
        debugPrint('[FoodService] Falling back to local cache search for "$cleanQuery".');
        return searchLocalFoods(cleanQuery, dataset: _cachedFoods, category: category);
      }
      return [];
    }
  }

  // -------------------------------------------------------------------------
  // 3. Local search — operates on an explicit dataset (tests + offline fallback)
  // -------------------------------------------------------------------------

  /// Searches [dataset] (or the browse cache) locally with deterministic ranking.
  ///
  /// This should only be called with an explicit [dataset] from tests, or as an
  /// offline fallback inside [searchFoodsOnServer]. Do NOT rely on this as the
  /// primary search path — it only covers the first browse page, not the full DB.
  ///
  /// Ranking: exact → starts-with → contains → Malay name → token → category.
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

  // -------------------------------------------------------------------------
  // 4. Legacy compatibility
  // -------------------------------------------------------------------------

  /// Legacy search method kept for backward compatibility with existing callers.
  static Future<List<dynamic>> searchFood(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return [];

    try {
      final matches = await searchFoodsOnServer(cleanQuery);
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
