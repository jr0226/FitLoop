import 'dart:convert';
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

  /// Fetches exercises by target body part (e.g. 'chest', 'back', 'cardio') via backend API.
  static Future<List<dynamic>> getExercisesByBodyPart(String bodyPart, {int limit = 20}) async {
    final cleanBodyPart = bodyPart.trim().toLowerCase();
    if (cleanBodyPart.isEmpty) return [];

    final user = FirebaseAuth.instance.currentUser;
    final token = await user?.getIdToken();

    final url = Uri.parse(
      '${AppConfig.apiBaseUrl}/api/exercises/body-part/${Uri.encodeComponent(cleanBodyPart)}?limit=$limit',
    );

    final response = await http.get(
      url,
      headers: {
        if (token != null) 'Authorization': 'Bearer $token',
      },
    ).timeout(
      const Duration(seconds: AppConfig.requestTimeoutSeconds),
      onTimeout: () => throw Exception('Exercise body-part request timed out.'),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data is List ? data : [];
    } else {
      throw Exception('Backend Exercise API error (${response.statusCode}): ${response.body}');
    }
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
