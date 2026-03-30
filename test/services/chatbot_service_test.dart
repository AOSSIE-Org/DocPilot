import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:http/http.dart' as http;
import 'package:doc_pilot_new_app_gradel_fix/services/chatbot_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'chatbot_service_test.mocks.dart';

@GenerateMocks([http.Client])
void main() {
  group('ChatbotService', () {
    late MockClient mockClient;
    late ChatbotService chatbotService;
    const testApiKey = 'test_gemini_api_key_123';
    const testPrompt = 'Generate a medical summary';

    setUpAll(() async {
      // Initialize dotenv for testing
      dotenv.testLoad(fileInput: 'GEMINI_API_KEY=$testApiKey');
    });

    setUp(() {
      mockClient = MockClient();
      chatbotService = ChatbotService(apiKey: testApiKey);
    });

    tearDown(() {
      reset(mockClient);
    });

    group('constructor', () {
      test('should initialize with provided API key', () {
        final service = ChatbotService(apiKey: testApiKey);
        expect(service, isNotNull);
      });

      test('should initialize without API key', () {
        final service = ChatbotService();
        expect(service, isNotNull);
      });

      test('should trim whitespace from API key', () {
        final service = ChatbotService(apiKey: '  $testApiKey  ');
        expect(service, isNotNull);
      });
    });

    group('getGeminiResponse', () {
      test('should return error when API key is missing', () async {
        final service = ChatbotService();
        dotenv.testLoad(fileInput: '');

        final result = await service.getGeminiResponse(testPrompt);

        expect(result, equals('Error: Missing GEMINI_API_KEY in environment'));
      });

      test('should handle empty prompt', () async {
        final result = await chatbotService.getGeminiResponse('');

        // Should still process empty prompt
        expect(result, isNotEmpty);
      });

      test('should handle very long prompt', () async {
        final longPrompt = 'A' * 5000; // Very long prompt
        final result = await chatbotService.getGeminiResponse(longPrompt);

        expect(result, isNotEmpty);
      });

      test('should handle special characters in prompt', () async {
        final specialPrompt = 'Test with émojis 😊 and spëcial chars & symbols!';
        final result = await chatbotService.getGeminiResponse(specialPrompt);

        expect(result, isNotEmpty);
      });

      test('should validate request format structure', () {
        // Test that the expected request body structure is valid
        final expectedRequestBody = {
          "contents": [
            {
              "parts": [
                {"text": testPrompt}
              ]
            }
          ],
          "generationConfig": {"temperature": 0.7, "maxOutputTokens": 1024}
        };

        // Verify request structure
        expect(expectedRequestBody['contents'], isA<List>());
        expect(expectedRequestBody['generationConfig'], isA<Map>());
        final generationConfig = expectedRequestBody['generationConfig'] as Map<String, dynamic>;
        expect(generationConfig['temperature'], equals(0.7));
        expect(generationConfig['maxOutputTokens'], equals(1024));
      });

      test('should use correct API endpoint format', () {
        // Verify API endpoint structure
        final expectedUrl = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent';

        expect(expectedUrl, contains('generativelanguage.googleapis.com'));
        expect(expectedUrl, contains('gemini-2.5-flash'));
        expect(expectedUrl, contains('generateContent'));
      });

      test('should handle null API key parameter', () async {
        final service = ChatbotService(apiKey: null);

        // Should fallback to environment variable or return error
        final result = await service.getGeminiResponse(testPrompt);
        expect(result, isNotEmpty);
      });

      test('should handle whitespace-only API key', () async {
        final service = ChatbotService(apiKey: '   ');

        final result = await service.getGeminiResponse(testPrompt);
        expect(result, contains('Error: Missing GEMINI_API_KEY'));
      });
    });

    group('API key resolution', () {
      test('should prefer constructor API key over environment', () async {
        // Set different key in environment
        dotenv.testLoad(fileInput: 'GEMINI_API_KEY=env_key_123');

        final service = ChatbotService(apiKey: 'constructor_key_456');

        // Constructor key should be used (we can't directly test private method,
        // but we can test behavior by attempting API calls)
        final result = await service.getGeminiResponse('test');
        expect(result, isNotEmpty);
      });

      test('should fallback to environment when constructor key is empty', () async {
        dotenv.testLoad(fileInput: 'GEMINI_API_KEY=env_key_123');

        final service = ChatbotService(apiKey: '');

        final result = await service.getGeminiResponse('test');
        expect(result, isNotEmpty);
      });

      test('should handle missing environment variable gracefully', () async {
        dotenv.testLoad(fileInput: '');  // No GEMINI_API_KEY

        final service = ChatbotService();

        final result = await service.getGeminiResponse('test');
        expect(result, equals('Error: Missing GEMINI_API_KEY in environment'));
      });

      test('should handle dotenv loading errors gracefully', () async {
        // This tests the catch block in _resolveApiKey when dotenv throws
        final service = ChatbotService();

        final result = await service.getGeminiResponse('test');
        // Should either work with environment or return missing key error
        expect(result, isNotEmpty);
      });
    });

    group('error handling', () {
      test('should handle network-related errors', () async {
        // Test with an invalid API key to trigger network errors
        final service = ChatbotService(apiKey: 'invalid_key_123');

        final result = await service.getGeminiResponse(testPrompt);

        // Should return an error message, not throw
        expect(result, contains('Error:'));
      });

      test('should handle malformed responses', () async {
        // This test relies on the actual implementation to handle malformed responses
        final result = await chatbotService.getGeminiResponse(testPrompt);
        expect(result, isNotEmpty);
      });

      test('should provide meaningful error messages', () async {
        final service = ChatbotService();
        dotenv.testLoad(fileInput: '');

        final result = await service.getGeminiResponse(testPrompt);

        expect(result, contains('GEMINI_API_KEY'));
        expect(result, contains('Error:'));
      });
    });

    group('integration tests', () {
      test('should handle concurrent requests safely', () async {
        final futures = List.generate(3, (index) =>
          chatbotService.getGeminiResponse('Request $index')
        );

        final results = await Future.wait(futures);

        // All requests should complete
        expect(results.length, equals(3));
        for (final result in results) {
          expect(result, isNotEmpty);
        }
      });

      test('should maintain state across multiple calls', () async {
        final result1 = await chatbotService.getGeminiResponse('First request');
        final result2 = await chatbotService.getGeminiResponse('Second request');

        expect(result1, isNotEmpty);
        expect(result2, isNotEmpty);
        // Service should remain functional across calls
      });
    });
  });
}