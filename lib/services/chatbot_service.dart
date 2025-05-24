import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ChatbotService {
  // Get API key from .env file
  final String apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';

  // Get a response from Gemini based on a prompt
  Future<String> getGeminiResponse(String prompt) async {
    print('\n=== GEMINI PROMPT ===');
    print(prompt);

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

        print('\n=== GEMINI RESPONSE ===');
        print(result);

        return result;
      } else {
        print('API Error: ${response.statusCode}');
        return "Error: Could not generate response. Status code: ${response.statusCode}";
      }
    } catch (e) {
      print('Exception: $e');
      return "Error: Could not connect to API: $e";
    }
  }
}