import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../core/errors/app_exception.dart';
import 'firebase/api_credentials_service.dart';

class DeepgramService {
  Future<String> transcribeAudioFile(String audioFilePath) async {
    final apiKey = await ApiCredentialsService.instance.getDeepgramApiKey();

    if (apiKey.isEmpty) {
      throw const AppException(
        code: 'missing-deepgram-api-key',
        message:
            'Deepgram API key not configured. Please add deepgramApiKey to Firebase collection: app_runtime/api_keys.',
      );
    }

    final audioFile = File(audioFilePath);
    if (!await audioFile.exists()) {
      throw const AppException(
        code: 'audio-file-not-found',
        message: 'Recorded audio file was not found for transcription.',
      );
    }

    final uri = Uri.parse(
      'https://api.deepgram.com/v1/listen?model=nova-2&smart_format=true&punctuate=true&diarize=true',
    );

    try {
      final request = http.Request('POST', uri)
        ..headers['Authorization'] = 'Token $apiKey'
        ..headers['Content-Type'] = 'audio/m4a'
        ..bodyBytes = await audioFile.readAsBytes();

      final streamedResponse = await http.Client().send(request);
      final responseBody = await streamedResponse.stream.bytesToString();

      if (streamedResponse.statusCode != 200) {
        throw AppException(
          code: 'deepgram-http-${streamedResponse.statusCode}',
          message: 'Deepgram transcription request failed.',
        );
      }

      final json = jsonDecode(responseBody) as Map<String, dynamic>;
      final results = json['results'] as Map<String, dynamic>?;
      final channels = results?['channels'] as List<dynamic>?;
      final firstChannel =
        (channels != null && channels.isNotEmpty) ? channels.first : null;
      final alternatives =
        (firstChannel as Map<String, dynamic>?)?['alternatives'] as List<dynamic>?;
      final firstAlternative = (alternatives != null && alternatives.isNotEmpty)
        ? alternatives.first as Map<String, dynamic>?
        : null;

      // Try to parse diarized response with speaker labels
      final words = firstAlternative?['words'] as List<dynamic>?;
      String text;

      if (words != null && words.isNotEmpty) {
        text = _formatDiarizedTranscript(words);
      } else {
        // Fallback to plain transcript if no word-level data
        text = (firstAlternative?['transcript'] as String?) ?? '';
      }

      if (text.trim().isEmpty) {
        throw const AppException(
          code: 'empty-transcription',
          message:
              'No speech was detected. Please speak clearly and try recording again.',
        );
      }

      return text.trim();
    } catch (error) {
      if (error is AppException) rethrow;
      throw AppException(
        code: 'deepgram-request-failed',
        message: 'Unable to transcribe audio right now. Please try again.',
        cause: error,
      );
    }
  }

  /// Formats diarized transcript with speaker labels (Doctor/Patient)
  String _formatDiarizedTranscript(List<dynamic> words) {
    if (words.isEmpty) return '';

    final buffer = StringBuffer();
    int? currentSpeaker;
    final wordBuffer = <String>[];

    for (final wordData in words) {
      final word = wordData['word'] as String? ?? '';
      final speaker = wordData['speaker'] as int?;

      if (speaker != currentSpeaker && wordBuffer.isNotEmpty) {
        // Write previous speaker's text
        final label = _getSpeakerLabel(currentSpeaker);
        buffer.writeln('$label: ${wordBuffer.join(' ')}');
        buffer.writeln();
        wordBuffer.clear();
      }

      currentSpeaker = speaker;
      if (word.isNotEmpty) {
        wordBuffer.add(word);
      }
    }

    // Write remaining words
    if (wordBuffer.isNotEmpty) {
      final label = _getSpeakerLabel(currentSpeaker);
      buffer.writeln('$label: ${wordBuffer.join(' ')}');
    }

    return buffer.toString().trim();
  }

  /// Maps speaker numbers to labels
  /// Speaker 0 = Doctor (typically speaks first in consultation)
  /// Speaker 1 = Patient
  String _getSpeakerLabel(int? speaker) {
    switch (speaker) {
      case 0:
        return 'Doctor';
      case 1:
        return 'Patient';
      default:
        return 'Speaker ${(speaker ?? 0) + 1}';
    }
  }
}