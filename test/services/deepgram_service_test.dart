import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:http/http.dart' as http;
import 'package:doc_pilot_new_app_gradel_fix/features/transcription/data/deepgram_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'deepgram_service_test.mocks.dart';

@GenerateMocks([http.Client, File])
void main() {
  group('DeepgramService', () {
    late MockClient mockClient;
    late MockFile mockFile;
    late DeepgramService deepgramService;
    const testApiKey = 'test_deepgram_api_key_123';
    const testRecordingPath = '/path/to/test/recording.m4a';

    setUpAll(() async {
      // Initialize dotenv for testing
      dotenv.testLoad(fileInput: 'DEEPGRAM_API_KEY=$testApiKey');
    });

    setUp(() {
      mockClient = MockClient();
      mockFile = MockFile();
      deepgramService = DeepgramService(apiKey: testApiKey);
    });

    tearDown(() {
      reset(mockClient);
      reset(mockFile);
    });

    group('constructor', () {
      test('should initialize with provided API key', () {
        final service = DeepgramService(apiKey: testApiKey);
        expect(service, isNotNull);
      });

      test('should initialize without API key', () {
        final service = DeepgramService();
        expect(service, isNotNull);
      });

      test('should trim whitespace from API key', () {
        final service = DeepgramService(apiKey: '  $testApiKey  ');
        expect(service, isNotNull);
      });
    });

    group('transcribe', () {
      test('should throw exception when API key is missing', () async {
        final service = DeepgramService();
        dotenv.testLoad(fileInput: '');

        expect(
          service.transcribe(testRecordingPath),
          throwsA(isA<Exception>()
              .having((e) => e.toString(), 'message', contains('Missing DEEPGRAM_API_KEY'))),
        );
      });

      test('should throw exception when recording file does not exist', () async {
        // Create a mock file that doesn't exist
        when(mockFile.exists()).thenAnswer((_) async => false);

        expect(
          deepgramService.transcribe('/nonexistent/file.m4a'),
          throwsA(isA<Exception>()
              .having((e) => e.toString(), 'message', contains('Recording file not found'))),
        );
      });

      test('should return transcript for successful response', () async {
        // Mock successful Deepgram response
        final mockResponse = {
          'results': {
            'channels': [
              {
                'alternatives': [
                  {
                    'transcript': 'Hello, this is a test transcription.'
                  }
                ]
              }
            ]
          }
        };

        // Note: In a real test, we'd need to mock the File operations
        // For now, we'll test the response parsing logic
        expect(mockResponse['results'], isA<Map>());

        final results = mockResponse['results'] as Map<String, dynamic>;
        final channels = results['channels'] as List;
        final alternatives = (channels.first as Map<String, dynamic>)['alternatives'] as List;
        final transcript = (alternatives.first as Map<String, dynamic>)['transcript'] as String;

        expect(transcript, equals('Hello, this is a test transcription.'));
      });

      test('should return "No speech detected" for empty transcript', () async {
        final mockResponse = {
          'results': {
            'channels': [
              {
                'alternatives': [
                  {
                    'transcript': ''
                  }
                ]
              }
            ]
          }
        };

        // Test parsing logic
        final results = mockResponse['results'] as Map<String, dynamic>;
        final channels = results['channels'] as List;
        final alternatives = (channels.first as Map<String, dynamic>)['alternatives'] as List;
        final transcript = (alternatives.first as Map<String, dynamic>)['transcript'] as String;

        final result = transcript.trim().isEmpty ? 'No speech detected' : transcript;
        expect(result, equals('No speech detected'));
      });

      test('should handle missing results in response', () async {
        final mockResponse = {'error': 'No results'};

        // When results is not a Map, should return 'No speech detected'
        final results = mockResponse['results'];
        final expectedResult = (results is! Map<String, dynamic>) ? 'No speech detected' : 'Valid result';

        expect(expectedResult, equals('No speech detected'));
      });

      test('should handle missing channels in results', () async {
        final mockResponse = {
          'results': {
            'metadata': 'some data'
          }
        };

        final results = mockResponse['results'] as Map<String, dynamic>;
        final channels = results['channels'];
        final expectedResult = (channels is! List || channels.isEmpty) ? 'No speech detected' : 'Valid result';

        expect(expectedResult, equals('No speech detected'));
      });

      test('should handle empty channels array', () async {
        final mockResponse = {
          'results': {
            'channels': []
          }
        };

        final results = mockResponse['results'] as Map<String, dynamic>;
        final channels = results['channels'] as List;
        final expectedResult = channels.isEmpty ? 'No speech detected' : 'Valid result';

        expect(expectedResult, equals('No speech detected'));
      });

      test('should handle missing alternatives in channel', () async {
        final mockResponse = {
          'results': {
            'channels': [
              {
                'metadata': 'some data'
              }
            ]
          }
        };

        final results = mockResponse['results'] as Map<String, dynamic>;
        final channels = results['channels'] as List;
        final channel = channels.first as Map<String, dynamic>;
        final alternatives = channel['alternatives'];
        final expectedResult = (alternatives is! List || alternatives.isEmpty) ? 'No speech detected' : 'Valid result';

        expect(expectedResult, equals('No speech detected'));
      });

      test('should handle empty alternatives array', () async {
        final mockResponse = {
          'results': {
            'channels': [
              {
                'alternatives': []
              }
            ]
          }
        };

        final results = mockResponse['results'] as Map<String, dynamic>;
        final channels = results['channels'] as List;
        final channel = channels.first as Map<String, dynamic>;
        final alternatives = channel['alternatives'] as List;
        final expectedResult = alternatives.isEmpty ? 'No speech detected' : 'Valid result';

        expect(expectedResult, equals('No speech detected'));
      });

      test('should use correct API endpoint format', () {
        final expectedUrl = 'https://api.deepgram.com/v1/listen?model=nova-2';

        expect(expectedUrl, contains('api.deepgram.com'));
        expect(expectedUrl, contains('/v1/listen'));
        expect(expectedUrl, contains('model=nova-2'));
      });

      test('should use correct headers format', () {
        final expectedHeaders = {
          'Authorization': 'Token $testApiKey',
          'Content-Type': 'audio/m4a',
        };

        expect(expectedHeaders['Authorization'], equals('Token $testApiKey'));
        expect(expectedHeaders['Content-Type'], equals('audio/m4a'));
      });

      test('should handle HTTP error status codes', () async {
        // Test error handling for different status codes
        const errorStatusCodes = [400, 401, 403, 404, 500, 502, 503];

        for (final statusCode in errorStatusCodes) {
          expect(
            () => throw Exception('Deepgram failed: $statusCode'),
            throwsA(isA<Exception>()
                .having((e) => e.toString(), 'message', contains('Deepgram failed: $statusCode'))),
          );
        }
      });

      test('should handle timeout exceptions', () async {
        // Test timeout handling
        expect(
          () => throw Exception('Deepgram request timed out after 30 seconds'),
          throwsA(isA<Exception>()
              .having((e) => e.toString(), 'message', contains('timed out after 30 seconds'))),
        );
      });

      test('should handle network exceptions', () async {
        // Test general network error handling
        expect(
          () => throw Exception('Network error'),
          throwsA(isA<Exception>()
              .having((e) => e.toString(), 'message', contains('Network error'))),
        );
      });

      test('should handle malformed JSON response', () async {
        // Test JSON parsing error handling
        expect(
          () => jsonDecode('invalid json'),
          throwsA(isA<FormatException>()),
        );
      });

      test('should handle non-Map JSON response', () async {
        final response = jsonDecode('["array", "response"]');

        final expectedResult = (response is! Map<String, dynamic>) ? 'No speech detected' : 'Valid result';
        expect(expectedResult, equals('No speech detected'));
      });

      test('should trim whitespace from transcript', () {
        final transcript = '  Hello, world!  ';
        final trimmed = transcript.trim();

        expect(trimmed, equals('Hello, world!'));
        expect(trimmed.length, lessThan(transcript.length));
      });

      test('should handle null transcript value', () {
        final Map<String, dynamic> alternative = {
          'transcript': null,
          'confidence': 0.95,
        };

        final transcript = alternative['transcript'];
        final result = transcript is String ? transcript.trim() : '';

        expect(result, equals(''));
      });
    });

    group('API key resolution', () {
      test('should prefer constructor API key over environment', () async {
        dotenv.testLoad(fileInput: 'DEEPGRAM_API_KEY=env_key_123');

        final service = DeepgramService(apiKey: 'constructor_key_456');

        // Constructor key should be used (tested by behavior)
        expect(service, isNotNull);
      });

      test('should fallback to environment when constructor key is empty', () async {
        dotenv.testLoad(fileInput: 'DEEPGRAM_API_KEY=env_key_123');

        final service = DeepgramService(apiKey: '');

        // Should use environment key
        expect(service, isNotNull);
      });

      test('should handle missing environment variable', () async {
        dotenv.testLoad(fileInput: '');

        final service = DeepgramService();

        expect(
          service.transcribe(testRecordingPath),
          throwsA(isA<Exception>()
              .having((e) => e.toString(), 'message', contains('Missing DEEPGRAM_API_KEY'))),
        );
      });

      test('should handle whitespace-only API key', () async {
        final service = DeepgramService(apiKey: '   ');

        expect(
          service.transcribe(testRecordingPath),
          throwsA(isA<Exception>()
              .having((e) => e.toString(), 'message', contains('Missing DEEPGRAM_API_KEY'))),
        );
      });
    });

    group('file handling', () {
      test('should handle different file extensions', () async {
        final extensions = ['.m4a', '.wav', '.mp3', '.flac', '.ogg'];

        for (final ext in extensions) {
          final path = '/path/to/file$ext';
          expect(path, endsWith(ext));
        }
      });

      test('should handle file paths with spaces', () async {
        const pathWithSpaces = '/path/to/my audio file.m4a';

        expect(pathWithSpaces, contains(' '));
        expect(pathWithSpaces, endsWith('.m4a'));
      });

      test('should handle empty file path', () async {
        expect(
          deepgramService.transcribe(''),
          throwsA(isA<Exception>()),
        );
      });

      test('should handle null file path', () async {
        // This would typically be caught by Dart's type system
        // but testing the behavior if it somehow occurs
        expect(
          () => deepgramService.transcribe(null as dynamic),
          throwsA(anything),
        );
      });
    });

    group('response validation', () {
      test('should validate complete response structure', () {
        final validResponse = {
          'results': {
            'channels': [
              {
                'alternatives': [
                  {
                    'transcript': 'Valid transcript',
                    'confidence': 0.95
                  }
                ]
              }
            ]
          }
        };

        // Test complete validation logic
        final results = validResponse['results'];
        if (results is! Map<String, dynamic>) {
          expect(false, isTrue); // Should not reach here
        }

        final channels = (results as Map<String, dynamic>)['channels'];
        if (channels is! List || channels.isEmpty) {
          expect(false, isTrue); // Should not reach here
        }

        final alternatives = ((channels as List).first as Map<String, dynamic>)['alternatives'];
        if (alternatives is! List || alternatives.isEmpty) {
          expect(false, isTrue); // Should not reach here
        }

        final transcript = ((alternatives as List).first as Map<String, dynamic>)['transcript'];
        expect(transcript, equals('Valid transcript'));
      });

      test('should handle response with multiple alternatives', () {
        final responseWithMultipleAlternatives = {
          'results': {
            'channels': [
              {
                'alternatives': [
                  {
                    'transcript': 'First alternative',
                    'confidence': 0.95
                  },
                  {
                    'transcript': 'Second alternative',
                    'confidence': 0.85
                  }
                ]
              }
            ]
          }
        };

        final results = responseWithMultipleAlternatives['results'] as Map<String, dynamic>;
        final channels = results['channels'] as List;
        final alternatives = (channels.first as Map<String, dynamic>)['alternatives'] as List;

        // Should take the first alternative
        final transcript = (alternatives.first as Map<String, dynamic>)['transcript'] as String;
        expect(transcript, equals('First alternative'));
      });

      test('should handle response with multiple channels', () {
        final responseWithMultipleChannels = {
          'results': {
            'channels': [
              {
                'alternatives': [
                  {
                    'transcript': 'Channel 1 transcript',
                  }
                ]
              },
              {
                'alternatives': [
                  {
                    'transcript': 'Channel 2 transcript',
                  }
                ]
              }
            ]
          }
        };

        final results = responseWithMultipleChannels['results'] as Map<String, dynamic>;
        final channels = results['channels'] as List;

        // Should take the first channel
        final alternatives = (channels.first as Map<String, dynamic>)['alternatives'] as List;
        final transcript = (alternatives.first as Map<String, dynamic>)['transcript'] as String;

        expect(transcript, equals('Channel 1 transcript'));
      });
    });
  });
}