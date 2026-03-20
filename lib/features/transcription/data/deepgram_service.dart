import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class DeepgramService {
  final String? _apiKey;

  DeepgramService({String? apiKey}) : _apiKey = apiKey?.trim();

  String _resolveApiKey() {
    final configuredKey = _apiKey;
    if (configuredKey != null && configuredKey.isNotEmpty) {
      return configuredKey;
    }

    try {
      return (dotenv.env['DEEPGRAM_API_KEY'] ?? '').trim();
    } catch (_) {
      return '';
    }
  }

  Future<String> transcribe(String recordingPath) async {
    final apiKey = _resolveApiKey();
    if (apiKey.isEmpty) {
      throw Exception('Missing DEEPGRAM_API_KEY in environment');
    }

    final uri = Uri.parse('https://api.deepgram.com/v1/listen?model=nova-2');

    final file = File(recordingPath);
    if (!await file.exists()) {
      throw Exception('Recording file not found');
    }

    final bytes = await file.readAsBytes();

    http.Response response;
    try {
      response = await http.post(
        uri,
        headers: {
          'Authorization': 'Token $apiKey',
          'Content-Type': 'audio/m4a',
        },
        body: bytes,
      ).timeout(const Duration(seconds: 30));
    } on TimeoutException {
      throw Exception('Deepgram request timed out after 30 seconds');
    }

    if (response.statusCode == 200) {
      final decodedResponse = json.decode(response.body);

      if (decodedResponse is! Map<String, dynamic>) {
        throw Exception('Deepgram returned unexpected response format');
      }

      final results = decodedResponse['results'];
      if (results is! Map<String, dynamic>) {
        return 'No speech detected';
      }

      final channels = results['channels'];
      if (channels is! List || channels.isEmpty || channels.first is! Map<String, dynamic>) {
        return 'No speech detected';
      }

      final alternatives = (channels.first as Map<String, dynamic>)['alternatives'];
      if (alternatives is! List || alternatives.isEmpty || alternatives.first is! Map<String, dynamic>) {
        return 'No speech detected';
      }

      final transcript = (alternatives.first as Map<String, dynamic>)['transcript'];
      final result = transcript is String ? transcript.trim() : '';
      return result.isNotEmpty ? result : 'No speech detected';
    } else {
      throw Exception('Deepgram failed: ${response.statusCode}');
    }
  }
}