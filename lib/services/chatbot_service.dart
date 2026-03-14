import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ChatbotService {
  // Get API key from .env file
  final String apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';

  // Get a response from Gemini based on a prompt
  Future<String> getGeminiResponse(String prompt) async {
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
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final result = data['candidates'][0]['content']['parts'][0]['text'];

        developer.log('Gemini response received', name: 'ChatbotService');

        return result;
      } else {
        developer.log('Gemini API error: ${response.statusCode}', name: 'ChatbotService');
        return "Error: Could not generate response. Status code: ${response.statusCode}";
      }
    } catch (e) {
      developer.log('Gemini request failed: $e', name: 'ChatbotService', error: e);
      return "Error: Could not connect to API: $e";
    }
  }
}