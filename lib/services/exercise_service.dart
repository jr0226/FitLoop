import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

class ExerciseService {
  /// Searches exercises by name via the backend API.
  /// 
  /// The mobile app never transmits or holds private RapidAPI credentials.
  static Future<List<dynamic>> searchExercises(String query, {int limit = 20}) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return [];

    final user = FirebaseAuth.instance.currentUser;
    final token = await user?.getIdToken();

    final url = Uri.parse(
      '${AppConfig.apiBaseUrl}/api/exercises/search?query=${Uri.encodeComponent(cleanQuery)}&limit=$limit',
    );

    final response = await http.get(
      url,
      headers: {
        if (token != null) 'Authorization': 'Bearer $token',
      },
    ).timeout(
      const Duration(seconds: AppConfig.requestTimeoutSeconds),
      onTimeout: () => throw Exception('Exercise search request timed out.'),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data is List ? data : [];
    } else {
      throw Exception('Backend Exercise API error (${response.statusCode}): ${response.body}');
    }
  }

  /// Fetches exercises by target body part (e.g. 'chest', 'back', 'cardio', 'core', 'arms', 'legs') via backend API.
  static Future<List<dynamic>> getExercisesByBodyPart(String bodyPart, {int limit = 20}) async {
    final cleanBodyPart = bodyPart.trim().toLowerCase();
    if (cleanBodyPart.isEmpty) return [];

    // 'core' maps to ExerciseDB's canonical bodyPart 'waist' (abs, crunches, sit-ups)
    final targetPart = cleanBodyPart == 'core' ? 'waist' : cleanBodyPart;

    final user = FirebaseAuth.instance.currentUser;
    final token = await user?.getIdToken();

    Future<List<dynamic>> fetchRaw(String part, int queryLimit) async {
      final url = Uri.parse(
        '${AppConfig.apiBaseUrl}/api/exercises/body-part/${Uri.encodeComponent(part)}?limit=$queryLimit',
      );

      final response = await http.get(
        url,
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ).timeout(
        const Duration(seconds: AppConfig.requestTimeoutSeconds),
        onTimeout: () => throw TimeoutException('Exercise body-part request timed out.'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data is List ? data : [];
      } else if (response.statusCode == 404) {
        return [];
      } else if (response.statusCode == 502 || response.statusCode == 503) {
        throw Exception('Exercise service temporarily unavailable.');
      } else if (response.statusCode == 504 || response.statusCode == 408) {
        throw TimeoutException('Exercise service timed out.');
      } else {
        throw Exception('Backend Exercise API error (${response.statusCode}): ${response.body}');
      }
    }

    // Support composite categories (arms, legs) with backward-compatibility for legacy backend instances
    if (targetPart == 'arms' || targetPart == 'legs') {
      try {
        return await fetchRaw(targetPart, limit);
      } catch (e) {
        // If the backend returns 400 (legacy server before redeployment),
        // gracefully fetch and merge the composite sub-parts directly.
        final subParts = targetPart == 'arms'
            ? ['upper arms', 'lower arms']
            : ['upper legs', 'lower legs'];
        final subLimit = max(10, (limit / 2).ceil());

        final results = await Future.wait(
          subParts.map((sp) => fetchRaw(sp, subLimit).catchError((_) => <dynamic>[])),
        );

        final merged = <dynamic>[];
        final seenIds = <String>{};
        final maxLen = results.fold<int>(0, (m, list) => list.length > m ? list.length : m);

        for (int i = 0; i < maxLen; i++) {
          for (final list in results) {
            if (i < list.length) {
              final item = list[i];
              final id = item is Map ? item['id']?.toString() : null;
              if (id == null || seenIds.add(id)) {
                merged.add(item);
                if (merged.length >= limit) break;
              }
            }
          }
          if (merged.length >= limit) break;
        }

        if (merged.isNotEmpty) {
          return merged;
        }
        rethrow;
      }
    }

    return await fetchRaw(targetPart, limit);
  }

  /// Fetches single exercise details by unique exercise ID.
  static Future<Map<String, dynamic>?> getExerciseById(String exerciseId) async {
    final cleanId = exerciseId.trim();
    if (cleanId.isEmpty) return null;

    final user = FirebaseAuth.instance.currentUser;
    final token = await user?.getIdToken();

    final url = Uri.parse(
      '${AppConfig.apiBaseUrl}/api/exercises/${Uri.encodeComponent(cleanId)}',
    );

    final response = await http.get(
      url,
      headers: {
        if (token != null) 'Authorization': 'Bearer $token',
      },
    ).timeout(
      const Duration(seconds: AppConfig.requestTimeoutSeconds),
      onTimeout: () => throw Exception('Exercise detail request timed out.'),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    } else if (response.statusCode == 404) {
      return null;
    } else {
      throw Exception('Backend Exercise API error (${response.statusCode}): ${response.body}');
    }
  }
}
