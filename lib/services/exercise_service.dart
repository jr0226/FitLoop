import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

class ExerciseService {
  /// Searches exercises by name from ExerciseDB via backend proxy or direct API fallback.
  static Future<List<dynamic>> searchExercises(String query) async {
    final cleanQuery = query.trim().toLowerCase();
    if (cleanQuery.isEmpty) return [];

    if (AppConfig.hasBackendProxy) {
      return await _searchViaBackend(cleanQuery);
    } else if (AppConfig.rapidApiKey.isNotEmpty) {
      return await _searchViaDirectRapidApi(cleanQuery);
    } else {
      throw Exception(
        'Exercise service not configured. Set API_BASE_URL or RAPIDAPI_KEY via --dart-define.',
      );
    }
  }

  static Future<List<dynamic>> _searchViaBackend(String query) async {
    final user = FirebaseAuth.instance.currentUser;
    final token = await user?.getIdToken();

    final url = Uri.parse('${AppConfig.apiBaseUrl}/api/exercises?query=$query');
    final response = await http.get(
      url,
      headers: {
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data is List ? data : [];
    } else {
      throw Exception('Backend Exercise Search failed: ${response.statusCode}');
    }
  }

  static Future<List<dynamic>> _searchViaDirectRapidApi(String query) async {
    final url = Uri.parse(
      'https://exercisedb.p.rapidapi.com/exercises/name/$query?limit=20',
    );
    final response = await http.get(
      url,
      headers: {
        'X-RapidAPI-Key': AppConfig.rapidApiKey,
        'X-RapidAPI-Host': 'exercisedb.p.rapidapi.com',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data is List ? data : [];
    } else {
      throw Exception('RapidAPI Error: ${response.statusCode}');
    }
  }
}
