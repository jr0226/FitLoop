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
    required String userGoal,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    final token = await user?.getIdToken();

    final uri = Uri.parse('${AppConfig.apiBaseUrl}/api/ai/analyze-food');

    try {
      final request = http.MultipartRequest('POST', uri)
        ..fields['user_goal'] = userGoal
        ..files.add(
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

      final streamedResponse = await request.send().timeout(
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
        } else if (response.statusCode == 429) {
          throw Exception('AI quota exceeded: $errorDetail');
        } else if (response.statusCode >= 500) {
          throw Exception('Backend server error ($errorDetail)');
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
    required String userGoal,
    required String difficulty,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    final token = await user?.getIdToken();

    final uri = Uri.parse('${AppConfig.apiBaseUrl}/api/ai/generate-workout');

    try {
      final response = await http
          .post(
            uri,
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
}
