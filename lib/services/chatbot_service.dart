import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ChatbotService {
  // Get API key from .env file
  final String apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';

  bool get hasValidApiKey => _isValidApiKey(apiKey);

  bool _isValidApiKey(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return false;
    }

    final normalized = trimmed.toLowerCase();
    return !normalized.contains('your_gemini_api_key_here') &&
        !normalized.contains('replace_with') &&
        !normalized.contains('example') &&
        !normalized.contains('dummy');
  }

  // Get a response from Gemini based on a prompt
  Future<String> getGeminiResponse(String prompt) async {
    if (!hasValidApiKey) {
      return 'Error: GEMINI_API_KEY is missing. Add it to your .env file.';
    }

    developer.log('Sending prompt to Gemini', name: 'ChatbotService');

    final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$apiKey');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "contents": [{"parts": [{"text": prompt}]}],
          "generationConfig": {
            "temperature": 0.7,
            "maxOutputTokens": 1024
          }
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final candidates = data['candidates'];
        if (candidates is List && candidates.isNotEmpty) {
          final content = candidates[0]['content'];
          final parts = content?['parts'];
          if (parts is List && parts.isNotEmpty) {
            final result = parts[0]['text'];
            if (result is String && result.trim().isNotEmpty) {
              developer.log('Gemini response received', name: 'ChatbotService');
              return result;
            }
          }
        }

        developer.log(
          'Gemini response format was not as expected: ${response.body}',
          name: 'ChatbotService',
        );
        return 'Error: Received an unexpected response format from Gemini.';
      } else {
        String errorMessage = 'Error: Gemini API request failed (status ${response.statusCode}).';
        try {
          final data = jsonDecode(response.body);
          final apiMessage = data['error']?['message'];
          if (apiMessage is String && apiMessage.trim().isNotEmpty) {
            errorMessage = 'Error: $apiMessage';
          }
        } catch (_) {}

        developer.log(
          'Gemini API error: ${response.statusCode} ${response.body}',
          name: 'ChatbotService',
        );
        return errorMessage;
      }
    } catch (e) {
      developer.log('Gemini request failed: $e', name: 'ChatbotService', error: e);
      return 'Error: Could not connect to Gemini API. Please try again.';
    }
  }
}