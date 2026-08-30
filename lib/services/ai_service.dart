import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

class AiService {
  /// Analyzes a food image to calculate nutritional breakdown via the backend API.
  /// 
  /// Flutter never interacts directly with third-party AI APIs or stores AI credentials.
  static Future<Map<String, dynamic>> analyzeFoodImage({
    required Uint8List imageBytes,
    required String userGoal,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    final token = await user?.getIdToken();

    final url = Uri.parse('${AppConfig.apiBaseUrl}/api/ai/analyze-food');
    final response = await http
        .post(
          url,
          headers: {
            'Content-Type': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
          },
          body: json.encode({
            'imageBase64': base64Encode(imageBytes),
            'userGoal': userGoal,
          }),
        )
        .timeout(
          const Duration(seconds: AppConfig.requestTimeoutSeconds),
          onTimeout: () => throw Exception('AI analysis request timed out.'),
        );

    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception(
        'Backend AI error (${response.statusCode}): ${response.body}',
      );
    }
  }

  /// Generates custom workout routine plans via the backend API.
  static Future<List<Map<String, dynamic>>> generateWorkoutPlan({
    required String userGoal,
    required String difficulty,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    final token = await user?.getIdToken();

    final url = Uri.parse('${AppConfig.apiBaseUrl}/api/ai/generate-workout');
    final response = await http
        .post(
          url,
          headers: {
            'Content-Type': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
          },
          body: json.encode({
            'userGoal': userGoal,
            'difficulty': difficulty,
          }),
        )
        .timeout(
          const Duration(seconds: AppConfig.requestTimeoutSeconds),
          onTimeout: () => throw Exception('Workout generation request timed out.'),
        );

    if (response.statusCode == 200) {
      final decoded = json.decode(response.body);
      if (decoded is List) {
        return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      throw Exception('Invalid workout plan structure received from backend.');
    } else {
      throw Exception(
        'Backend AI error (${response.statusCode}): ${response.body}',
      );
    }
  }
}
