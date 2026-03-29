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

  Future<http.Response> _retryPost({
    required Uri uri,
    required Map<String, String> headers,
    required List<int> body,
    int retries = 3,
  }) async {
    for (int attempt = 0; attempt < retries; attempt++) {
      try {
        final response = await http
            .post(uri, headers: headers, body: body)
            .timeout(const Duration(seconds: 30));

        if (response.statusCode == 200) return response;

        if (response.statusCode >= 500) {
          await Future.delayed(Duration(seconds: 2 * (attempt + 1)));
          continue;
        } else {
          throw Exception('Deepgram failed: ${response.statusCode} - ${response.body}');
        }
      } on TimeoutException {
        if (attempt == retries - 1) throw Exception('Request timed out');
      } catch (e) {
        if (attempt == retries - 1) rethrow;
      }
      await Future.delayed(Duration(seconds: 2 * (attempt + 1)));
    }
    throw Exception('Failed after $retries retries');
  }

  Future<String> transcribe(String recordingPath) async {
    final apiKey = _resolveApiKey();
    if (apiKey.isEmpty) throw Exception('Missing DEEPGRAM_API_KEY');

    final file = File(recordingPath);
    if (!await file.exists()) throw Exception('Recording file not found');

    final bytes = await file.readAsBytes();
    final uri = Uri.parse('https://api.deepgram.com/v1/listen?model=nova-2&punctuate=true&smart_format=true');

    final response = await _retryPost(
      uri: uri,
      headers: {
        'Authorization': 'Token $apiKey',
        'Content-Type': 'application/octet-stream',
      },
      body: bytes,
    );

    return _parseTranscript(response.body);
  }

  String _parseTranscript(String responseBody) {
    try {
      final decoded = json.decode(responseBody);

      if (decoded is! Map<String, dynamic>) {
        return 'No speech detected';
      }

      final results = decoded['results'];
      final channels = results?['channels'];
      
      if (channels is List && channels.isNotEmpty) {
        final alternatives = channels[0]['alternatives'];
        if (alternatives is List && alternatives.isNotEmpty) {
          final transcript = alternatives[0]['transcript'];
          if (transcript is String && transcript.trim().isNotEmpty) {
            return transcript.trim();
          }
        }
      }

      return 'No speech detected';
    } catch (e) {
      throw Exception('Failed to parse Deepgram response: $e');
    }
  }
}
