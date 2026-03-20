import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ChatbotService {
  final String? _apiKey;

  ChatbotService({String? apiKey}) : _apiKey = apiKey?.trim();

  String _resolveApiKey() {
    final configuredKey = _apiKey;
    if (configuredKey != null && configuredKey.isNotEmpty) {
      return configuredKey;
    }

    try {
      return (dotenv.env['GEMINI_API_KEY'] ?? '').trim();
    } catch (_) {
      return '';
    }
  }

  // Get a response from Gemini based on a prompt
  Future<String> getGeminiResponse(String prompt) async {
    developer.log('=== Gemini request started  ===', name: 'ChatbotService');

    final apiKey = _resolveApiKey();
    if (apiKey.isEmpty) {
      return 'Error: Missing GEMINI_API_KEY in environment';
    }

    final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$apiKey');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "contents": [
            {
              "parts": [
                {"text": prompt}
              ]
            }
          ],
          "generationConfig": {"temperature": 0.7, "maxOutputTokens": 1024}
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final result = data['candidates'][0]['content']['parts'][0]['text'];

        developer.log('===Gemini response received ===', name: 'ChatbotService');
        
        return result;
      } else {
        developer.log(
          'Gemini API error: ${response.statusCode}',
          name: 'ChatbotService',
        );
        return "Error: Could not generate response. Status code: ${response.statusCode}";
      }
    } catch (e) {
      developer.log('Gemini request exception: $e', name: 'ChatbotService');
      return "Error: Could not connect to API: $e";
    }
  }
}