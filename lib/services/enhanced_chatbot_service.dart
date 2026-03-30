import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../utils/retry_utility.dart';
import '../utils/network_utility.dart';

class ChatbotService {
  final String? _apiKey;
  final http.Client _httpClient;

  ChatbotService({String? apiKey, http.Client? httpClient})
    : _apiKey = apiKey?.trim(),
      _httpClient = httpClient ?? http.Client();

  String _resolveApiKey() {
    final configuredKey = _apiKey;
    if (configuredKey != null && configuredKey.isNotEmpty) {
      return configuredKey;
    }

    try {
      return (dotenv.env['GEMINI_API_KEY'] ?? '').trim();
    } catch (_) {
      return '';
    }
  }

  /// Get a response from Gemini API with retry logic and error recovery
  ///
  /// [prompt] - The text prompt to send to Gemini
  /// [retryConfig] - Optional retry configuration (defaults to API config)
  /// [timeoutDuration] - Request timeout duration
  ///
  /// Returns the AI response or a user-friendly error message
  Future<String> getGeminiResponse(
    String prompt, {
    RetryConfig retryConfig = RetryConfig.apiDefault,
    Duration timeoutDuration = const Duration(seconds: 30),
  }) async {
    developer.log('=== Gemini request started ===', name: 'ChatbotService');

    // Validate API key first
    final apiKey = _resolveApiKey();
    if (apiKey.isEmpty) {
      return 'Error: Missing GEMINI_API_KEY. Please configure your API key in the app settings.';
    }

    // Validate prompt
    if (prompt.trim().isEmpty) {
      return 'Error: Please provide a valid prompt for the AI.';
    }

    try {
      // Execute with retry logic
      final result = await RetryUtility.execute<String>(
        () => _performGeminiRequest(prompt, apiKey, timeoutDuration),
        config: retryConfig,
        retryIf: RetryUtility.apiRetryCondition,
        onRetry: RetryUtility.createLoggingCallback('Gemini API'),
      );

      developer.log('=== Gemini response received successfully ===', name: 'ChatbotService');
      return result;

    } on MaxRetriesExceededException catch (e) {
      developer.log('Gemini request failed after all retries: $e', name: 'ChatbotService');
      return _buildUserFriendlyError(e.lastException);

    } on NetworkException catch (e) {
      developer.log('Network error in Gemini request: $e', name: 'ChatbotService');
      return 'Network Error: Please check your internet connection and try again.\n\nDetails: ${e.message}';

    } catch (e) {
      developer.log('Unexpected error in Gemini request: $e', name: 'ChatbotService');
      return _buildUserFriendlyError(Exception(e.toString()));
    }
  }

  /// Performs the actual Gemini API request
  Future<String> _performGeminiRequest(
    String prompt,
    String apiKey,
    Duration timeout,
  ) async {
    // Check network connectivity before making request
    final networkInfo = await NetworkUtility.checkConnectivity();
    if (!networkInfo.isReachable) {
      throw NetworkException('No internet connection available', networkInfo);
    }

    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$apiKey'
    );

    final requestBody = jsonEncode({
      "contents": [
        {
          "parts": [
            {"text": prompt}
          ]
        }
      ],
      "generationConfig": {
        "temperature": 0.7,
        "maxOutputTokens": 1024,
        "topK": 40,
        "topP": 0.95,
      }
    });

    developer.log('Making Gemini API request to: ${url.host}', name: 'ChatbotService');

    final response = await _httpClient
        .post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'User-Agent': 'DocPilot/1.0',
          },
          body: requestBody,
        )
        .timeout(timeout);

    return _processGeminiResponse(response);
  }

  /// Processes the Gemini API response
  String _processGeminiResponse(http.Response response) {
    developer.log('Gemini API response status: ${response.statusCode}', name: 'ChatbotService');

    if (response.statusCode == 200) {
      try {
        final data = jsonDecode(response.body) as Map<String, dynamic>;

        // Validate response structure
        if (!data.containsKey('candidates')) {
          throw Exception('Invalid response format: missing candidates');
        }

        final candidates = data['candidates'] as List;
        if (candidates.isEmpty) {
          return 'I apologize, but I cannot generate a response for this prompt. Please try rephrasing your request.';
        }

        final candidate = candidates[0] as Map<String, dynamic>;
        if (!candidate.containsKey('content')) {
          throw Exception('Invalid response format: missing content');
        }

        final content = candidate['content'] as Map<String, dynamic>;
        if (!content.containsKey('parts')) {
          throw Exception('Invalid response format: missing parts');
        }

        final parts = content['parts'] as List;
        if (parts.isEmpty) {
          return 'I apologize, but I cannot generate a response for this prompt. Please try rephrasing your request.';
        }

        final part = parts[0] as Map<String, dynamic>;
        final text = part['text'] as String? ?? '';

        if (text.trim().isEmpty) {
          return 'I apologize, but I cannot generate a response for this prompt. Please try rephrasing your request.';
        }

        return text.trim();

      } catch (e) {
        developer.log('Error parsing Gemini response: $e', name: 'ChatbotService');
        throw Exception('Failed to parse AI response: $e');
      }
    }

    // Handle different HTTP status codes
    _handleHttpError(response);

    // This should never be reached due to _handleHttpError throwing
    throw Exception('Unexpected response status: ${response.statusCode}');
  }

  /// Handles HTTP errors with appropriate exceptions
  void _handleHttpError(http.Response response) {
    final statusCode = response.statusCode;

    switch (statusCode) {
      case 400:
        throw Exception('Bad Request: Invalid prompt or request format');
      case 401:
        throw Exception('Authentication failed: Invalid API key');
      case 403:
        throw Exception('Access forbidden: Check API key permissions');
      case 404:
        throw Exception('API endpoint not found');
      case 429:
        throw Exception('Rate limit exceeded: Too many requests');
      case 500:
      case 502:
      case 503:
      case 504:
        throw Exception('Server error (${statusCode}): Service temporarily unavailable');
      default:
        String errorBody = '';
        try {
          final errorData = jsonDecode(response.body);
          errorBody = errorData['error']?['message'] ?? '';
        } catch (_) {
          errorBody = response.body;
        }

        throw Exception('API error (${statusCode}): ${errorBody.isNotEmpty ? errorBody : 'Unknown error'}');
    }
  }

  /// Builds user-friendly error messages
  String _buildUserFriendlyError(Exception exception) {
    final errorString = exception.toString().toLowerCase();

    // Network-related errors
    if (errorString.contains('network') ||
        errorString.contains('connection') ||
        errorString.contains('socket')) {
      return '''
Network Connection Error

Please check your internet connection and try again. Make sure you have a stable connection to the internet.

If the problem persists, try:
• Switching between Wi-Fi and mobile data
• Restarting your router
• Checking your firewall settings

Technical details: ${exception.toString()}
      '''.trim();
    }

    // Timeout errors
    if (errorString.contains('timeout')) {
      return '''
Request Timeout

The AI service is taking longer than usual to respond. This often happens during high traffic periods.

Please try again in a few moments. If the issue continues, consider:
• Shortening your prompt
• Trying at a different time
• Checking your internet speed

Technical details: ${exception.toString()}
      '''.trim();
    }

    // Authentication errors
    if (errorString.contains('authentication') ||
        errorString.contains('invalid api key') ||
        errorString.contains('unauthorized')) {
      return '''
Authentication Error

There is an issue with your API key configuration. Please:

• Check that your API key is correctly set in the app
• Verify that your API key is valid and active
• Ensure your API key has the necessary permissions

If you need help setting up your API key, please refer to the app documentation.
      '''.trim();
    }

    // Rate limiting errors
    if (errorString.contains('rate limit') ||
        errorString.contains('too many requests')) {
      return '''
Rate Limit Exceeded

You have made too many requests in a short period. Please wait a few minutes before trying again.

To avoid this in the future:
• Wait between requests
• Avoid rapid-fire submissions
• Consider shortening complex prompts

The system will automatically retry your request.
      '''.trim();
    }

    // Server errors
    if (errorString.contains('server error') ||
        errorString.contains('service unavailable')) {
      return '''
Service Temporarily Unavailable

The AI service is experiencing temporary issues. This is usually resolved quickly.

Please try again in a few minutes. The system is automatically retrying your request.

If the issue persists for more than 10 minutes, please check the service status online.
      '''.trim();
    }

    // Generic error
    return '''
Unexpected Error

An unexpected error occurred while processing your request. Please try again.

If this error continues to occur, please:
• Restart the app
• Check for app updates
• Contact support with the details below

Technical details: ${exception.toString()}
    '''.trim();
  }

  /// Validates the prompt before sending
  bool _isValidPrompt(String prompt) {
    final trimmed = prompt.trim();
    if (trimmed.isEmpty) return false;
    if (trimmed.length > 30000) return false;  // Reasonable limit
    return true;
  }

  /// Gets enhanced response with better error handling and validation
  Future<String> getEnhancedGeminiResponse(
    String prompt, {
    RetryConfig? retryConfig,
    Duration? timeout,
  }) async {
    // Pre-validation
    if (!_isValidPrompt(prompt)) {
      return 'Error: Please provide a valid prompt (1-30,000 characters).';
    }

    // Use enhanced retry config for critical medical operations
    final config = retryConfig ?? RetryConfig.critical;
    final timeoutDuration = timeout ?? const Duration(seconds: 45);

    return getGeminiResponse(
      prompt,
      retryConfig: config,
      timeoutDuration: timeoutDuration,
    );
  }

  /// Disposes of resources
  void dispose() {
    _httpClient.close();
  }
}