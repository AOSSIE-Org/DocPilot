import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'firebase/api_credentials_service.dart';

class ChatbotService {
  final ApiCredentialsService _credentialsService = ApiCredentialsService.instance;

  // Exact model chosen for cost-effective production usage.
  static const String _modelId = 'gemini-2.5-flash-lite';

  // Keep API-version fallback for compatibility, but keep a single model ID.
  static const List<String> _apiVersions = ['v1', 'v1beta'];

  /// Get API key from Firebase or fallback to .env
  Future<String> _getGeminiApiKey() async {
    try {
      // Try Firebase first
      final firebaseKey = await _credentialsService.getGeminiApiKey();
      if (firebaseKey.isNotEmpty) {
        debugPrint('[ChatbotService] ✅ Using Gemini API key from Firebase');
        return firebaseKey;
      }
    } catch (e) {
      debugPrint('[ChatbotService] ⚠️ Firebase API key failed: $e');
    }

    // Fallback to .env file
    final envKey = dotenv.env['GEMINI_API_KEY'] ?? '';
    if (envKey.isNotEmpty && !envKey.contains('your_')) {
      debugPrint('[ChatbotService] ✅ Using Gemini API key from .env');
      return envKey;
    }

    debugPrint('[ChatbotService] ❌ No valid Gemini API key found');
    return '';
  }

  String _extractTextFromResponse(Map<String, dynamic> data) {
    final candidates = data['candidates'];
    if (candidates is! List || candidates.isEmpty) {
      return '';
    }

    for (final candidate in candidates) {
      if (candidate is! Map<String, dynamic>) {
        continue;
      }

      final content = candidate['content'];
      if (content is! Map<String, dynamic>) {
        continue;
      }

      final parts = content['parts'];
      if (parts is! List) {
        continue;
      }

      for (final part in parts) {
        if (part is Map<String, dynamic>) {
          final text = part['text'];
          if (text is String && text.trim().isNotEmpty) {
            return text;
          }
        }
      }
    }

    return '';
  }

  /// Call one exact model with API-version fallback.
  Future<String> _callGemini(
    String apiKey,
    List<Map<String, dynamic>> parts,
  ) async {
    Exception? lastError;

    for (final apiVersion in _apiVersions) {
      try {
        debugPrint('[ChatbotService] Trying model: $_modelId on $apiVersion');

        final url = Uri.parse(
          'https://generativelanguage.googleapis.com/$apiVersion/models/$_modelId:generateContent?key=$apiKey',
        );

        final response = await http
            .post(
              url,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'contents': [
                  {'parts': parts}
                ],
                'generationConfig': {
                  'temperature': 0.7,
                  'maxOutputTokens': 2048,
                },
              }),
            )
            .timeout(const Duration(seconds: 30));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final text = _extractTextFromResponse(data);
          if (text.trim().isNotEmpty) {
            debugPrint('[ChatbotService] ✅ Model $_modelId successful on $apiVersion');
            return text;
          }

          lastError = Exception('Model $_modelId returned an empty response');
          continue;
        }

        if (response.statusCode == 404) {
          debugPrint('[ChatbotService] ⚠️ Model $_modelId not found on $apiVersion');
          lastError = Exception('Model $_modelId not found');
          continue;
        }

        if (response.statusCode == 401 || response.statusCode == 403) {
          debugPrint('[ChatbotService] ❌ Authentication error: ${response.statusCode}');
          throw Exception('Invalid API key or insufficient permissions');
        }

        final errorMsg = response.body;
        debugPrint('[ChatbotService] Error ${response.statusCode} ($apiVersion/$_modelId): $errorMsg');
        lastError = Exception('HTTP ${response.statusCode}: $errorMsg');
      } catch (e) {
        debugPrint('[ChatbotService] Model $_modelId error: $e');
        lastError = Exception(e.toString());
      }
    }

    throw lastError ?? Exception('Gemini model $_modelId failed. Check API key and project access.');
  }

  /// Get a response from Gemini based on a prompt
  Future<String> getGeminiResponse(String prompt) async {
    debugPrint('\n=== GEMINI PROMPT ===');
    debugPrint(prompt);

    try {
      final apiKey = await _getGeminiApiKey();

      if (apiKey.isEmpty) {
        return "Error: Gemini API key not configured. Please add it to Firebase (app_runtime/api_keys) or update .env file.";
      }

      debugPrint('[ChatbotService] Calling Gemini API ($_modelId)...');

      return await _callGemini(
        apiKey,
        [{'text': prompt}],
      );
    } catch (e) {
      final errorMsg = e.toString();
      debugPrint('[ChatbotService] Exception: $errorMsg');

      if (errorMsg.contains('404')) {
        return "Error: Gemini API model not found (404). This typically means:\n"
            "1. The API key is invalid\n"
            "2. The model is deprecated\n"
            "3. Your project doesn't have access to Gemini\n\n"
            "Fix: Generate a new API key from https://aistudio.google.com/app/apikey and update Firebase.";
      } else if (errorMsg.contains('401') || errorMsg.contains('403')) {
        return "Error: Authentication failed. API key is invalid or has insufficient permissions.\n"
            "Fix: Generate a new API key from https://aistudio.google.com/app/apikey";
      }

      return "Error: Could not connect to Gemini API: $errorMsg";
    }
  }

  /// Get a response from Gemini based on image (vision)
  Future<String> getGeminiVisionResponse({
    required String prompt,
    String? imagePath,
  }) async {
    debugPrint('\n=== GEMINI VISION PROMPT ===');
    debugPrint(prompt);

    try {
      final apiKey = await _getGeminiApiKey();

      if (apiKey.isEmpty) {
        return "Error: Gemini API key not configured. Please add it to Firebase (app_runtime/api_keys) or update .env file.";
      }

      final List<Map<String, dynamic>> parts = [
        {"text": prompt}
      ];

      // Add image if provided
      if (imagePath != null && imagePath.isNotEmpty) {
        try {
          final file = File(imagePath);
          if (await file.exists()) {
            final imageBytes = await file.readAsBytes();
            final imageBase64 = base64Encode(imageBytes);

            // Determine MIME type from file extension
            String mimeType = 'image/jpeg';
            if (imagePath.toLowerCase().endsWith('.png')) {
              mimeType = 'image/png';
            } else if (imagePath.toLowerCase().endsWith('.gif')) {
              mimeType = 'image/gif';
            } else if (imagePath.toLowerCase().endsWith('.webp')) {
              mimeType = 'image/webp';
            }

            parts.add({
              "inline_data": {
                "mime_type": mimeType,
                "data": imageBase64
              }
            });
          }
        } catch (e) {
          debugPrint('[ChatbotService] Error reading image file: $e');
        }
      }

      debugPrint('[ChatbotService] Calling Gemini Vision API ($_modelId)...');

      return await _callGemini(
        apiKey,
        parts,
      );
    } catch (e) {
      final errorMsg = e.toString();
      debugPrint('[ChatbotService] Exception: $errorMsg');

      if (errorMsg.contains('404')) {
        return "Error: Gemini Vision API model not found (404). Check your API key.";
      } else if (errorMsg.contains('401') || errorMsg.contains('403')) {
        return "Error: Authentication failed for vision API.";
      }

      return "Error: Could not process image with Gemini Vision: $errorMsg";
    }
  }
}