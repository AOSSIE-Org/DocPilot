import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'firebase/api_credentials_service.dart';

/// Diagnostic service for debugging Gemini API issues
class GeminiApiDiagnostic {
  GeminiApiDiagnostic._(); // Prevent instantiation

  static const List<String> _apiVersions = ['v1', 'v1beta'];
  static const String _targetModel = 'gemini-2.5-flash-lite';

  /// Test Gemini API connection and get detailed diagnostics
  static Future<Map<String, dynamic>> testGeminiConnection() async {
    final results = <String, dynamic>{
      'timestamp': DateTime.now().toIso8601String(),
      'status': 'unknown',
      'api_key_available': false,
      'api_key_length': 0,
      'endpoint_accessible': false,
      'model_accessible': false,
      'authentication_ok': false,
      'error': null,
      'suggestions': <String>[],
    };

    try {
      // Get API key
      final apiKey = await ApiCredentialsService.instance.getGeminiApiKey();
      results['api_key_available'] = apiKey.isNotEmpty;
      results['api_key_length'] = apiKey.length;

      if (apiKey.isEmpty) {
        results['status'] = 'error';
        results['error'] = 'API key not found in Firebase';
        results['suggestions'] = [
          'Verify Gemini API key is in Firestore (collection: app_runtime, document: api_keys)',
          'Check field name is one of: geminiApiKey, gemini_api_key, GEMINI_API_KEY, etc.',
          'Ensure API key is not empty or a placeholder',
          'Sign in to Firebase before testing',
        ];
        return results;
      }

      debugPrint('[GeminiApiDiagnostic] API Key found: ${apiKey.length} chars');

      final availableModels = await getAvailableModels(apiKey);
      results['available_models'] = availableModels;

      final testModel = _targetModel;
      results['test_model'] = testModel;

      // Test 1: Basic connectivity with simple request
      debugPrint('[GeminiApiDiagnostic] Testing endpoint accessibility...');
      String? selectedVersion;

      for (final version in _apiVersions) {
        final testUrl = Uri.parse(
          'https://generativelanguage.googleapis.com/$version/models/$testModel?key=$apiKey',
        );

        final headRequest = await http
            .head(testUrl)
            .timeout(const Duration(seconds: 10))
            .catchError((e) => http.Response('', 0));

        if (headRequest.statusCode == 200 || headRequest.statusCode == 400) {
          selectedVersion = version;
          results['endpoint_accessible'] = true;
          results['api_version'] = version;
          debugPrint('[GeminiApiDiagnostic] Endpoint accessible on $version: ${headRequest.statusCode}');
          break;
        }

        if (headRequest.statusCode == 404) {
          continue;
        }

        results['error'] = 'HTTP ${headRequest.statusCode}';
      }

      if (selectedVersion == null) {
        results['error'] = results['error'] ?? '404 - Model or endpoint not found';
        results['suggestions'] = [
          'Model access differs by API key and project.',
          'Check Google AI Studio model access for this key.',
          'Verify this API key belongs to the same project where Gemini API is enabled.',
          'Try regenerating the key from https://aistudio.google.com/app/apikey.',
        ];
      }

      // Test 2: Try actual generateContent request
      debugPrint('[GeminiApiDiagnostic] Testing generateContent endpoint...');
      final requestVersion = selectedVersion ?? 'v1';
      final contentUrl = Uri.parse(
        'https://generativelanguage.googleapis.com/$requestVersion/models/$testModel:generateContent?key=$apiKey',
      );

      final testResponse = await http
          .post(
            contentUrl,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'contents': [
                {
                  'parts': [
                    {'text': 'test'}
                  ]
                }
              ]
            }),
          )
          .timeout(const Duration(seconds: 10))
          .catchError((e) => http.Response(jsonEncode({'error': e.toString()}), 0));

      if (testResponse.statusCode == 200) {
        results['model_accessible'] = true;
        results['authentication_ok'] = true;
        results['status'] = 'success';
        debugPrint('[GeminiApiDiagnostic] ✅ Gemini API working correctly!');
      } else if (testResponse.statusCode == 404) {
        results['status'] = 'error';
        results['error'] = '404 - Model endpoint not found';
        results['suggestions'] = [
          'The model is not accessible for this API key/project.',
          'Use the available models list returned by diagnostics.',
          'Try v1beta compatibility endpoint if v1 fails for your key.',
          'Regenerate the key in Google AI Studio and re-save it in Firestore.',
        ];
        debugPrint('[GeminiApiDiagnostic] ❌ 404 Error');
      } else if (testResponse.statusCode == 401 || testResponse.statusCode == 403) {
        results['status'] = 'error';
        results['error'] = 'Authentication failed (${testResponse.statusCode})';
        results['authentication_ok'] = false;
        results['suggestions'] = [
          '❌ API key is invalid or revoked',
          'Generate a new API key from https://aistudio.google.com/app/apikey',
          'Check that the key is correctly stored in Firestore',
          'Verify the key has not expired',
        ];
      } else if (testResponse.statusCode == 400) {
        results['status'] = 'error';
        results['error'] = 'Bad request (${testResponse.statusCode})';
        final errorBody = testResponse.body;
        results['error_details'] = errorBody;
        results['suggestions'] = [
          'Request format might be incorrect',
          'Try a different model from the available models list',
          'Check request body format matches API documentation',
        ];
        debugPrint('[GeminiApiDiagnostic] Bad request: $errorBody');
      } else {
        results['status'] = 'error';
        results['error'] = 'HTTP ${testResponse.statusCode}';
        results['response_body'] = testResponse.body;
        debugPrint('[GeminiApiDiagnostic] Error ${testResponse.statusCode}: ${testResponse.body}');
      }
    } catch (e) {
      results['status'] = 'error';
      results['error'] = e.toString();
      results['suggestions'] = [
        'Network error - check internet connection',
        'API endpoint might be down',
        'Timeout - API server not responding',
      ];
      debugPrint('[GeminiApiDiagnostic] Exception: $e');
    }

    if (kDebugMode) {
      debugPrint('[GeminiApiDiagnostic] Results: $results');
    }

    return results;
  }

  /// Get list of available models (requires working API)
  static Future<List<String>> getAvailableModels(String apiKey) async {
    final discovered = <String>{};

    try {
      for (final version in _apiVersions) {
        final url = Uri.parse(
          'https://generativelanguage.googleapis.com/$version/models?key=$apiKey',
        );

        final response = await http.get(url).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final models = (data['models'] as List?)
                  ?.map((m) => (m['name'] as String? ?? '').replaceFirst('models/', ''))
                  .where((m) => m.isNotEmpty)
                  .toList() ??
              [];

          discovered.addAll(models.cast<String>());
        } else {
          debugPrint('[GeminiApiDiagnostic] Failed to fetch models from $version: ${response.statusCode}');
        }
      }

      final models = discovered.toList()..sort();
      debugPrint('[GeminiApiDiagnostic] Available models: $models');
      return models;
    } catch (e) {
      debugPrint('[GeminiApiDiagnostic] Error fetching models: $e');
      return [];
    }
  }
}
