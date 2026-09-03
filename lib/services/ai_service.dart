import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../config/app_config.dart';

class AiService {
  /// Analyzes a food image to calculate nutritional breakdown via the FitLoop backend API.
  ///
  /// Transmits image bytes via multipart/form-data directly to:
  /// `POST ${AppConfig.apiBaseUrl}/api/ai/analyze-food`
  ///
  /// Protects secrets by never embedding or transmitting AI API keys from the Flutter client.
  static Future<Map<String, dynamic>> analyzeFoodImage({
    required Uint8List imageBytes,
    String userGoal = 'Maintenance',
    int? calorieTarget,
    String dietPreference = 'Standard',
    List<String> allergies = const [],
    http.Client? httpClient,
  }) async {
    String? token;
    try {
      final user = FirebaseAuth.instance.currentUser;
      token = await user?.getIdToken();
    } catch (_) {
      // In unit test environments without Firebase initialized, continue without token
    }

    final uri = Uri.parse('${AppConfig.apiBaseUrl}/api/ai/analyze-food');

    try {
      final request = http.MultipartRequest('POST', uri)
        ..fields['user_goal'] = userGoal
        ..fields['diet_preference'] = dietPreference;

      if (calorieTarget != null && calorieTarget > 0) {
        request.fields['calorie_target'] = calorieTarget.toString();
      }

      if (allergies.isNotEmpty) {
        request.fields['allergies'] = json.encode(allergies);
      }

      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          imageBytes,
          filename: 'food_scan.jpg',
          contentType: MediaType('image', 'jpeg'),
        ),
      );

      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      final client = httpClient ?? http.Client();
      final streamedResponse = await client.send(request).timeout(
        const Duration(seconds: AppConfig.requestTimeoutSeconds),
        onTimeout: () => throw TimeoutException('Food scanning timed out after ${AppConfig.requestTimeoutSeconds}s.'),
      );

      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is Map<String, dynamic>) {
          return data;
        }
        throw const FormatException('Expected JSON map response from backend.');
      } else {
        // Attempt to parse server-provided error detail
        String errorDetail = response.body;
        try {
          final errorJson = json.decode(response.body);
          if (errorJson is Map && errorJson.containsKey('detail')) {
            errorDetail = errorJson['detail'].toString();
          }
        } catch (_) {}

        if (response.statusCode == 400) {
          throw Exception('Invalid image data: $errorDetail');
        } else if (response.statusCode == 403) {
          throw Exception('Backend authentication failed: $errorDetail');
        } else if (response.statusCode == 503) {
          throw Exception(errorDetail.isNotEmpty ? errorDetail : 'AI service is temporarily busy. Please try again shortly.');
        } else if (response.statusCode >= 500) {
          throw Exception('Backend server error: $errorDetail');
        } else {
          throw Exception('Backend error (${response.statusCode}): $errorDetail');
        }
      }
    } on SocketException {
      throw Exception(
        'Cannot connect to backend at ${AppConfig.apiBaseUrl}. Ensure the FastAPI server is running.',
      );
    } on TimeoutException {
      throw Exception(
        'Food analysis request timed out. Please check your network and backend server.',
      );
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Unexpected error during food scan: $e');
    }
  }

  /// Generates custom workout routine plans via the backend API.
  static Future<List<Map<String, dynamic>>> generateWorkoutPlan({
    String userGoal = 'Maintenance',
    String difficulty = 'Intermediate',
    List<String> equipment = const [],
    List<String> preferredWorkoutTypes = const [],
    String? recentWorkoutsSummary,
    http.Client? httpClient,
  }) async {
    String? token;
    try {
      final user = FirebaseAuth.instance.currentUser;
      token = await user?.getIdToken();
    } catch (_) {
      // In unit test environments without Firebase initialized, continue without token
    }

    final uri = Uri.parse('${AppConfig.apiBaseUrl}/api/ai/generate-workout');

    try {
      final client = httpClient ?? http.Client();
      final bodyPayload = <String, dynamic>{
        'userGoal': userGoal,
        'difficulty': difficulty,
        'equipment': equipment,
        'preferredWorkoutTypes': preferredWorkoutTypes,
      };
      if (recentWorkoutsSummary != null && recentWorkoutsSummary.trim().isNotEmpty) {
        bodyPayload['recentWorkoutsSummary'] = recentWorkoutsSummary.trim();
      }

      final response = await client
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              if (token != null) 'Authorization': 'Bearer $token',
            },
            body: json.encode(bodyPayload),
          )
          .timeout(
            const Duration(seconds: AppConfig.requestTimeoutSeconds),
            onTimeout: () => throw TimeoutException('Workout generation request timed out.'),
          );

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded is List) {
          return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
        throw Exception('Invalid workout plan structure received from backend.');
      } else {
        String errorDetail = response.body;
        try {
          final errorJson = json.decode(response.body);
          if (errorJson is Map && errorJson.containsKey('detail')) {
            errorDetail = errorJson['detail'].toString();
          }
        } catch (_) {}
        throw Exception('Backend error (${response.statusCode}): $errorDetail');
      }
    } on SocketException {
      throw Exception(
        'Cannot connect to backend at ${AppConfig.apiBaseUrl}. Ensure the FastAPI server is running.',
      );
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Unexpected workout generation error: $e');
    }
  }

  /// Generates an intelligent Help & FAQ fallback answer via Gemini 3.8 Flash
  /// when local FAQ keywords/topics do not provide a confident match.
  static Future<Map<String, dynamic>?> getFaqFallback({
    required String question,
    String? context,
    http.Client? httpClient,
  }) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/api/ai/faq-fallback');
    try {
      final client = httpClient ?? http.Client();
      final response = await client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'question': question,
              'context': ?context,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
      }
    } catch (e) {
      debugPrint('[AiService] FAQ fallback error: $e');
    }
    return null;
  }
}
