import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

class FoodService {
  /// Searches food nutrition database via the backend API.
  /// 
  /// Flutter delegates external Food/Nutrition API calls to the backend to protect API secrets.
  static Future<List<dynamic>> searchFood(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return [];

    final user = FirebaseAuth.instance.currentUser;
    final token = await user?.getIdToken();

    final url = Uri.parse(
      '${AppConfig.apiBaseUrl}/api/food?query=${Uri.encodeComponent(cleanQuery)}',
    );
    final response = await http.get(
      url,
      headers: {
        if (token != null) 'Authorization': 'Bearer $token',
      },
    ).timeout(
      const Duration(seconds: AppConfig.requestTimeoutSeconds),
      onTimeout: () => throw Exception('Food search request timed out.'),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data is List
          ? data
          : (data['data'] ?? data['results'] ?? data['items'] ?? []);
    } else {
      throw Exception('Backend Food API error (${response.statusCode}): ${response.body}');
    }
  }
}
