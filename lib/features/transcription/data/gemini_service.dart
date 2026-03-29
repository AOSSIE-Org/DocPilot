import 'dart:convert';
import '../domain/medical_insights.dart';
import 'package:doc_pilot_new_app_gradel_fix/services/chatbot_service.dart';

class GeminiService {
  final ChatbotService _chatbotService = ChatbotService();

  Future<MedicalInsights> generateInsights(String transcription) async {
    final prompt = """
Extract structured medical information from the conversation.

Return ONLY valid JSON in this format:
{
  "summary": "short summary",
  "symptoms": ["symptom1", "symptom2"],
  "medicines": ["medicine1", "medicine2"]
}

Conversation:
$transcription
""";

    final response = await _chatbotService.getGeminiResponse(prompt);

    try {
      final cleaned = _extractJson(response);
      final jsonData = json.decode(cleaned);
      return MedicalInsights.fromJson(jsonData);
    } catch (e) {
      throw Exception('Failed to parse Gemini JSON response');
    }
  }

  // Handles messy AI responses
  String _extractJson(String response) {
    final start = response.indexOf('{');
    final end = response.lastIndexOf('}');

    if (start != -1 && end != -1) {
      return response.substring(start, end + 1);
    }

    throw Exception('Invalid JSON format from AI');
  }
}