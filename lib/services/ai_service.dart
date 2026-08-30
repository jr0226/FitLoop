import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

class AiService {
  /// Analyzes a food image to calculate nutritional breakdown.
  /// 
  /// Routes through backend proxy if [AppConfig.hasBackendProxy] is configured,
  /// otherwise uses direct Gemini client via [AppConfig.geminiApiKey].
  static Future<Map<String, dynamic>> analyzeFoodImage({
    required Uint8List imageBytes,
    required String userGoal,
  }) async {
    if (AppConfig.hasBackendProxy) {
      return await _analyzeFoodViaBackend(imageBytes: imageBytes, userGoal: userGoal);
    } else if (AppConfig.geminiApiKey.isNotEmpty) {
      return await _analyzeFoodViaDirectGemini(imageBytes: imageBytes, userGoal: userGoal);
    } else {
      throw Exception(
        'AI Service is not configured. Please configure API_BASE_URL or GEMINI_API_KEY via --dart-define.',
      );
    }
  }

  /// Generates custom workout routine plans based on user goal and difficulty.
  static Future<List<Map<String, dynamic>>> generateWorkoutPlan({
    required String userGoal,
    required String difficulty,
  }) async {
    if (AppConfig.hasBackendProxy) {
      return await _generatePlanViaBackend(userGoal: userGoal, difficulty: difficulty);
    } else if (AppConfig.geminiApiKey.isNotEmpty) {
      return await _generatePlanViaDirectGemini(userGoal: userGoal, difficulty: difficulty);
    } else {
      throw Exception(
        'AI Service is not configured. Please configure API_BASE_URL or GEMINI_API_KEY via --dart-define.',
      );
    }
  }

  // ==========================================
  // Backend Proxy Implementation (Production)
  // ==========================================
  static Future<Map<String, dynamic>> _analyzeFoodViaBackend({
    required Uint8List imageBytes,
    required String userGoal,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    final token = await user?.getIdToken();

    final url = Uri.parse('${AppConfig.apiBaseUrl}/api/ai/analyze-food');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: json.encode({
        'imageBase64': base64Encode(imageBytes),
        'userGoal': userGoal,
      }),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Backend AI Error: ${response.statusCode} - ${response.body}');
    }
  }

  static Future<List<Map<String, dynamic>>> _generatePlanViaBackend({
    required String userGoal,
    required String difficulty,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    final token = await user?.getIdToken();

    final url = Uri.parse('${AppConfig.apiBaseUrl}/api/ai/generate-workout');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: json.encode({
        'userGoal': userGoal,
        'difficulty': difficulty,
      }),
    );

    if (response.statusCode == 200) {
      final decoded = json.decode(response.body);
      if (decoded is List) {
        return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      throw Exception('Invalid response format from backend.');
    } else {
      throw Exception('Backend Workout AI Error: ${response.statusCode}');
    }
  }

  // ==========================================================
  // Direct Gemini Fallback (Development / Configured API Key)
  // ==========================================================
  static Future<Map<String, dynamic>> _analyzeFoodViaDirectGemini({
    required Uint8List imageBytes,
    required String userGoal,
  }) async {
    final model = GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: AppConfig.geminiApiKey,
    );

    final prompt = '''
    You are an elite AI sports nutritionist. Analyze the food in this image.
    The user's fitness goal is "$userGoal".
    Return ONLY a valid JSON object matching this exact structure (no markdown backticks):
    {
      "foods": [
        {"name": "string", "calories": int, "proteins": int, "carbs": int, "fats": int}
      ],
      "totalCalories": int,
      "totalProteins": int,
      "totalCarbs": int,
      "totalFats": int,
      "score": int,
      "explanation": "string",
      "alternatives": ["string", "string"]
    }
    ''';

    final content = [
      Content.multi([TextPart(prompt), DataPart('image/jpeg', imageBytes)]),
    ];

    final response = await model.generateContent(content);
    if (response.text == null || response.text!.isEmpty) {
      throw Exception('Empty AI response.');
    }

    String rawText = response.text!;
    int startIndex = rawText.indexOf('{');
    int endIndex = rawText.lastIndexOf('}');

    if (startIndex != -1 && endIndex != -1) {
      String cleanJson = rawText.substring(startIndex, endIndex + 1);
      return json.decode(cleanJson) as Map<String, dynamic>;
    } else {
      throw Exception('Invalid JSON received from Gemini.');
    }
  }

  static Future<List<Map<String, dynamic>>> _generatePlanViaDirectGemini({
    required String userGoal,
    required String difficulty,
  }) async {
    final model = GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: AppConfig.geminiApiKey,
    );

    final prompt = '''
    The user's fitness goal is "$userGoal" and their level is "$difficulty".
    Create 2 distinct workout routines (e.g., Upper Body, Lower Body).
    Each routine should have exactly 3 exercises.
    Return ONLY a valid JSON array of objects. Do not include any markdown formatting, backticks, or conversational text.
    [
      {
        "routineName": "String",
        "level": "$difficulty",
        "category": "Full Body",
        "image": "https://images.unsplash.com/photo-1517836357463-d25dfeac3438?w=400",
        "exercises": [
          {
            "name": "Exercise Name",
            "category": "Target Muscle",
            "sets": "3 sets x 10 reps",
            "image": "https://images.unsplash.com/photo-1599058945522-28d584b6f0ff?w=400",
            "desc": "Brief form instruction."
          }
        ]
      }
    ]
    ''';

    final response = await model.generateContent([Content.text(prompt)]);
    if (response.text == null || response.text!.isEmpty) {
      throw Exception('Empty AI response.');
    }

    String rawText = response.text!;
    debugPrint('==== GEMINI RAW RESPONSE ====');
    debugPrint(rawText);
    debugPrint('=============================');

    String cleanText = rawText.replaceAll('```json', '').replaceAll('```', '').trim();
    int start = cleanText.indexOf('[');
    int end = cleanText.lastIndexOf(']');

    if (start != -1 && end != -1) {
      String finalJsonString = cleanText.substring(start, end + 1);
      final List<dynamic> generatedRoutines = json.decode(finalJsonString);
      return generatedRoutines.map((r) => Map<String, dynamic>.from(r as Map)).toList();
    } else {
      throw Exception('Invalid JSON array formatting from Gemini.');
    }
  }
}
