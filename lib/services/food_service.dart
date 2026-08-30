import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

class FoodService {
  /// Searches food database via backend proxy or direct API fallback.
  static Future<List<dynamic>> searchFood(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return [];

    if (AppConfig.hasBackendProxy) {
      return await _searchViaBackend(cleanQuery);
    } else if (AppConfig.apiNinjasKey.isNotEmpty) {
      return await _searchViaDirectApiNinjas(cleanQuery);
    } else {
      throw Exception(
        'Food database service not configured. Set API_BASE_URL or API_NINJAS_KEY via --dart-define.',
      );
    }
  }

  static Future<List<dynamic>> _searchViaBackend(String query) async {
    final user = FirebaseAuth.instance.currentUser;
    final token = await user?.getIdToken();

    final url = Uri.parse('${AppConfig.apiBaseUrl}/api/food?query=${Uri.encodeComponent(query)}');
    final response = await http.get(
      url,
      headers: {
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data is List
          ? data
          : (data['data'] ?? data['results'] ?? data['items'] ?? []);
    } else {
      throw Exception('Backend Food Search failed: ${response.statusCode}');
    }
  }

  static Future<List<dynamic>> _searchViaDirectApiNinjas(String query) async {
    final url = Uri.parse('https://api-ninjas.com/api/food?query=${Uri.encodeComponent(query)}');
    final response = await http.get(
      url,
      headers: {
        'X-API-Key': AppConfig.apiNinjasKey,
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data is List
          ? data
          : (data['data'] ?? data['results'] ?? data['items'] ?? []);
    } else {
      throw Exception('API Ninjas Error: ${response.statusCode}');
    }
  }
}
