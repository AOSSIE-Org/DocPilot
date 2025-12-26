import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Return GEMINI API key from --dart-define or .env as fallback.
String getGeminiApiKey() {
  const envValue = String.fromEnvironment('GEMINI_API_KEY');
  if (envValue.isNotEmpty) return envValue;
  return dotenv.env['GEMINI_API_KEY'] ?? '';
}

/// Return DEEPGRAM API key from --dart-define or .env as fallback.
String getDeepgramApiKey() {
  const envValue = String.fromEnvironment('DEEPGRAM_API_KEY');
  if (envValue.isNotEmpty) return envValue;
  return dotenv.env['DEEPGRAM_API_KEY'] ?? '';
}
