import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Supported Gemini/Gemma models via the Gemini API.
enum GeminiModel {
  flash('gemini-2.0-flash', 'Gemini 2.0 Flash', 'Fast responses, good for most tasks'),
  pro('gemini-1.5-pro', 'Gemini 1.5 Pro', 'Higher accuracy for complex reasoning'),
  gemma('gemma-3-27b-it', 'Gemma 3 27B', 'Open-weight model, efficient summarisation');

  final String modelId;
  final String displayName;
  final String description;

  const GeminiModel(this.modelId, this.displayName, this.description);
}

class ChatbotService {
  final String _apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';

  GeminiModel selectedModel;

  ChatbotService({this.selectedModel = GeminiModel.flash});

  bool get hasValidApiKey {
    final trimmed = _apiKey.trim();
    if (trimmed.isEmpty) return false;
    final lower = trimmed.toLowerCase();
    return !lower.contains('your_gemini_api_key_here') &&
        !lower.contains('replace_with') &&
        !lower.contains('example') &&
        !lower.contains('dummy');
  }

  Future<String> getGeminiResponse(String prompt) async {
    if (!hasValidApiKey) {
      return 'Error: GEMINI_API_KEY is missing. Add it to your .env file.';
    }

    developer.log(
      'Sending prompt to ${selectedModel.displayName}',
      name: 'ChatbotService',
    );

    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/${selectedModel.modelId}:generateContent?key=$_apiKey',
    );

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': prompt}
              ]
            }
          ],
          'generationConfig': {
            'temperature': 0.7,
            'maxOutputTokens': 1024,
          },
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final candidates = data['candidates'];
        if (candidates is List && candidates.isNotEmpty) {
          final text = candidates[0]['content']?['parts']?[0]?['text'];
          if (text is String && text.trim().isNotEmpty) {
            developer.log('Response received from ${selectedModel.displayName}', name: 'ChatbotService');
            return text;
          }
        }
        return 'Error: Unexpected response format from ${selectedModel.displayName}.';
      } else {
        String message = 'Error: ${selectedModel.displayName} request failed (status ${response.statusCode}).';
        try {
          final apiError = jsonDecode(response.body)['error']?['message'];
          if (apiError is String && apiError.trim().isNotEmpty) {
            message = 'Error: $apiError';
          }
        } catch (_) {}
        developer.log('API error ${response.statusCode}: ${response.body}', name: 'ChatbotService');
        return message;
      }
    } catch (e) {
      developer.log('Request failed: $e', name: 'ChatbotService', error: e);
      return 'Error: Could not reach ${selectedModel.displayName}. Check your connection and try again.';
    }
  }
}