import 'package:doc_pilot_new_app_gradel_fix/services/chatbot_service.dart';

class GeminiService {
  final ChatbotService _chatbotService = ChatbotService();

  Future<String> generateSummary(String transcription) async {
    return await _chatbotService.getGeminiResponse(
      "Generate a summary of the conversation based on this transcription: $transcription",
    );
  }

  Future<String> generatePrescription(String transcription) async {
    return await _chatbotService.getGeminiResponse(
      "Generate a prescription based on the conversation in this transcription: $transcription",
    );
  }
}