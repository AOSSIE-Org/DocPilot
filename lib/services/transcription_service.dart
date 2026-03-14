import 'dart:io';
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Result returned by [TranscriptionService.transcribe].
///
/// On success [transcript] contains the recognised text and [error] is null.
/// On failure [error] describes what went wrong and [transcript] is null.
class TranscriptionResult {
  final String? transcript;
  final String? error;

  const TranscriptionResult.success(String this.transcript) : error = null;
  const TranscriptionResult.failure(String this.error) : transcript = null;

  bool get isSuccess => transcript != null;
}

/// Handles audio transcription via the Deepgram Nova-2 API.
///
/// Separating this from the UI layer makes the Deepgram integration
/// independently testable and keeps [TranscriptionScreen] free of HTTP logic.
class TranscriptionService {
  final String _apiKey;

  TranscriptionService() : _apiKey = dotenv.env['DEEPGRAM_API_KEY'] ?? '';

  bool get hasValidApiKey {
    final trimmed = _apiKey.trim();
    if (trimmed.isEmpty) return false;
    final lower = trimmed.toLowerCase();
    return !lower.contains('your_deepgram_api_key_here') &&
        !lower.contains('replace_with') &&
        !lower.contains('example') &&
        !lower.contains('dummy');
  }

  /// Transcribes the audio file at [filePath] using Deepgram's Nova-2 model.
  ///
  /// Returns a [TranscriptionResult] — callers should check [TranscriptionResult.isSuccess]
  /// before using the transcript.
  Future<TranscriptionResult> transcribe(String filePath) async {
    if (!hasValidApiKey) {
      return const TranscriptionResult.failure(
        'DEEPGRAM_API_KEY is missing or still a placeholder. Add a real key to .env.',
      );
    }

    final file = File(filePath);
    if (!await file.exists()) {
      return const TranscriptionResult.failure('Recording file not found.');
    }

    final uri = Uri.parse('https://api.deepgram.com/v1/listen?model=nova-2');

    try {
      final bytes = await file.readAsBytes();
      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Token $_apiKey',
          'Content-Type': 'audio/m4a',
        },
        body: bytes,
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text = data['results']?['channels']?[0]?['alternatives']?[0]?['transcript'] as String?;

        if (text == null || text.trim().isEmpty) {
          developer.log('Deepgram returned empty transcript', name: 'TranscriptionService');
          return const TranscriptionResult.success('');
        }

        developer.log('Transcription succeeded (${text.length} chars)', name: 'TranscriptionService');
        return TranscriptionResult.success(text.trim());
      } else {
        String message = 'Transcription failed (status ${response.statusCode}).';
        try {
          final body = jsonDecode(response.body);
          final detail = body['err_msg'] ?? body['error'] ?? body['message'];
          if (detail is String && detail.trim().isNotEmpty) {
            message = 'Transcription failed: $detail';
          }
        } catch (_) {}

        developer.log(
          'Deepgram error ${response.statusCode}: ${response.body}',
          name: 'TranscriptionService',
        );
        return TranscriptionResult.failure(message);
      }
    } catch (e) {
      developer.log('Transcription request failed: $e', name: 'TranscriptionService', error: e);
      return TranscriptionResult.failure(
        'Could not reach Deepgram. Check your connection and try again.',
      );
    }
  }
}
