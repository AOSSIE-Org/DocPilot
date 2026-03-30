import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../../../utils/retry_utility.dart';
import '../../../utils/network_utility.dart';

class EnhancedDeepgramService {
  final String? _apiKey;
  final http.Client _httpClient;

  EnhancedDeepgramService({String? apiKey, http.Client? httpClient})
    : _apiKey = apiKey?.trim(),
      _httpClient = httpClient ?? http.Client();

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

  /// Transcribes audio with enhanced error handling and retry logic
  ///
  /// [recordingPath] - Path to the audio file to transcribe
  /// [retryConfig] - Optional retry configuration
  /// [model] - Deepgram model to use (default: nova-2)
  /// [language] - Language code (default: auto-detect)
  /// [includeConfidence] - Whether to include confidence scores
  ///
  /// Returns transcribed text or throws enhanced exceptions
  Future<TranscriptionResult> transcribeWithRetry(
    String recordingPath, {
    RetryConfig retryConfig = RetryConfig.critical,
    String model = 'nova-2',
    String? language,
    bool includeConfidence = true,
    Duration timeoutDuration = const Duration(seconds: 60),
  }) async {
    developer.log('=== Starting audio transcription ===', name: 'EnhancedDeepgramService');

    // Validate inputs
    final validationResult = await _validateInput(recordingPath);
    if (!validationResult.isValid) {
      throw TranscriptionException(validationResult.errorMessage!);
    }

    try {
      final result = await RetryUtility.execute<TranscriptionResult>(
        () => _performTranscription(
          recordingPath,
          model,
          language,
          includeConfidence,
          timeoutDuration,
        ),
        config: retryConfig,
        retryIf: RetryUtility.apiRetryCondition,
        onRetry: (exception, attempt) {
          developer.log(
            'Retrying transcription (attempt $attempt): $exception',
            name: 'EnhancedDeepgramService',
          );
        },
      );

      developer.log('=== Transcription completed successfully ===', name: 'EnhancedDeepgramService');
      return result;

    } on MaxRetriesExceededException catch (e) {
      developer.log('Transcription failed after all retries: $e', name: 'EnhancedDeepgramService');
      throw TranscriptionException(_buildUserFriendlyError(e.lastException));

    } on NetworkException catch (e) {
      developer.log('Network error during transcription: $e', name: 'EnhancedDeepgramService');
      throw TranscriptionException(
        'Network Error: Please check your internet connection and try again.\n\nDetails: ${e.message}'
      );
    }
  }

  /// Simplified transcribe method for backward compatibility
  Future<String> transcribe(String recordingPath) async {
    try {
      final result = await transcribeWithRetry(recordingPath);
      return result.transcript;
    } on TranscriptionException catch (e) {
      return 'Error: ${e.message}';
    } catch (e) {
      return 'Error: Unable to transcribe audio. Please try again.';
    }
  }

  /// Validates input parameters and file
  Future<ValidationResult> _validateInput(String recordingPath) async {
    // Check if path is provided
    if (recordingPath.trim().isEmpty) {
      return ValidationResult.invalid('Recording path cannot be empty');
    }

    // Check API key
    final apiKey = _resolveApiKey();
    if (apiKey.isEmpty) {
      return ValidationResult.invalid(
        'Missing DEEPGRAM_API_KEY. Please configure your API key in the app settings.'
      );
    }

    // Check if file exists
    final file = File(recordingPath);
    if (!await file.exists()) {
      return ValidationResult.invalid('Recording file not found at: $recordingPath');
    }

    // Check file size
    final fileSize = await file.length();
    if (fileSize == 0) {
      return ValidationResult.invalid('Recording file is empty');
    }

    // Check file size limits (Deepgram has a 200MB limit)
    const maxSizeMB = 150; // Leave some buffer
    const maxSizeBytes = maxSizeMB * 1024 * 1024;
    if (fileSize > maxSizeBytes) {
      return ValidationResult.invalid(
        'Recording file is too large (${(fileSize / 1024 / 1024).toStringAsFixed(1)}MB). Maximum size is ${maxSizeMB}MB.'
      );
    }

    // Check file extension
    final allowedExtensions = ['.m4a', '.mp3', '.wav', '.flac', '.ogg', '.aac'];
    final extension = recordingPath.toLowerCase().substring(recordingPath.lastIndexOf('.'));
    if (!allowedExtensions.contains(extension)) {
      return ValidationResult.invalid(
        'Unsupported audio format: $extension. Supported formats: ${allowedExtensions.join(', ')}'
      );
    }

    return ValidationResult.valid();
  }

  /// Performs the actual transcription
  Future<TranscriptionResult> _performTranscription(
    String recordingPath,
    String model,
    String? language,
    bool includeConfidence,
    Duration timeout,
  ) async {
    // Check network connectivity
    final networkInfo = await NetworkUtility.checkConnectivity();
    if (!networkInfo.isReachable) {
      throw NetworkException('No internet connection available', networkInfo);
    }

    final apiKey = _resolveApiKey();
    final file = File(recordingPath);
    final bytes = await file.readAsBytes();

    // Build URI with parameters
    final queryParams = <String, String>{
      'model': model,
      if (language != null) 'language': language,
      if (includeConfidence) 'include_metadata': 'true',
      'punctuate': 'true',
      'diarize': 'false',  // Can be made configurable
    };

    final uri = Uri.parse('https://api.deepgram.com/v1/listen').replace(
      queryParameters: queryParams,
    );

    // Determine content type based on file extension
    final contentType = _getContentType(recordingPath);

    developer.log(
      'Making transcription request: model=$model, size=${(bytes.length / 1024).round()}KB',
      name: 'EnhancedDeepgramService',
    );

    final response = await _httpClient
        .post(
          uri,
          headers: {
            'Authorization': 'Token $apiKey',
            'Content-Type': contentType,
            'User-Agent': 'DocPilot/1.0',
          },
          body: bytes,
        )
        .timeout(timeout);

    return _processTranscriptionResponse(response, includeConfidence);
  }

  /// Processes the transcription response
  TranscriptionResult _processTranscriptionResponse(
    http.Response response,
    bool includeConfidence,
  ) {
    developer.log(
      'Deepgram response: ${response.statusCode}',
      name: 'EnhancedDeepgramService',
    );

    if (response.statusCode != 200) {
      _handleHttpError(response);
    }

    try {
      final decodedResponse = json.decode(response.body);

      if (decodedResponse is! Map<String, dynamic>) {
        throw Exception('Invalid response format from Deepgram');
      }

      return _extractTranscriptionResult(decodedResponse, includeConfidence);

    } catch (e) {
      developer.log('Error parsing transcription response: $e', name: 'EnhancedDeepgramService');
      throw Exception('Failed to parse transcription response: $e');
    }
  }

  /// Extracts transcription result from response
  TranscriptionResult _extractTranscriptionResult(
    Map<String, dynamic> response,
    bool includeConfidence,
  ) {
    final results = response['results'];
    if (results is! Map<String, dynamic>) {
      return TranscriptionResult.noSpeech();
    }

    final channels = results['channels'];
    if (channels is! List || channels.isEmpty) {
      return TranscriptionResult.noSpeech();
    }

    final channel = channels.first;
    if (channel is! Map<String, dynamic>) {
      return TranscriptionResult.noSpeech();
    }

    final alternatives = channel['alternatives'];
    if (alternatives is! List || alternatives.isEmpty) {
      return TranscriptionResult.noSpeech();
    }

    final alternative = alternatives.first;
    if (alternative is! Map<String, dynamic>) {
      return TranscriptionResult.noSpeech();
    }

    final transcript = alternative['transcript'] as String? ?? '';
    final confidence = includeConfidence
        ? (alternative['confidence'] as num?)?.toDouble()
        : null;

    // Extract metadata if available
    final metadata = response['metadata'] as Map<String, dynamic>?;
    final duration = metadata?['duration'] as num?;

    if (transcript.trim().isEmpty) {
      return TranscriptionResult.noSpeech();
    }

    return TranscriptionResult(
      transcript: transcript.trim(),
      confidence: confidence,
      durationSeconds: duration?.toDouble(),
      model: metadata?['model'] as String?,
      language: metadata?['language'] as String?,
    );
  }

  /// Handles HTTP errors
  void _handleHttpError(http.Response response) {
    final statusCode = response.statusCode;

    switch (statusCode) {
      case 400:
        throw Exception('Bad Request: Invalid audio file or request parameters');
      case 401:
        throw Exception('Authentication failed: Invalid Deepgram API key');
      case 403:
        throw Exception('Access forbidden: Check API key permissions and usage limits');
      case 404:
        throw Exception('API endpoint not found');
      case 413:
        throw Exception('Audio file too large: Maximum supported size is 200MB');
      case 415:
        throw Exception('Unsupported audio format: Please use supported formats (MP3, WAV, M4A, etc.)');
      case 429:
        throw Exception('Rate limit exceeded: Too many transcription requests');
      case 500:
      case 502:
      case 503:
      case 504:
        throw Exception('Deepgram server error (${statusCode}): Service temporarily unavailable');
      default:
        String errorBody = '';
        try {
          final errorData = jsonDecode(response.body);
          errorBody = errorData['error']?['message'] ?? '';
        } catch (_) {
          errorBody = response.body;
        }

        throw Exception('Deepgram API error (${statusCode}): ${errorBody.isNotEmpty ? errorBody : 'Unknown error'}');
    }
  }

  /// Gets content type based on file extension
  String _getContentType(String filePath) {
    final extension = filePath.toLowerCase().substring(filePath.lastIndexOf('.'));

    switch (extension) {
      case '.mp3':
        return 'audio/mp3';
      case '.wav':
        return 'audio/wav';
      case '.m4a':
        return 'audio/m4a';
      case '.flac':
        return 'audio/flac';
      case '.ogg':
        return 'audio/ogg';
      case '.aac':
        return 'audio/aac';
      default:
        return 'audio/m4a'; // Default fallback
    }
  }

  /// Builds user-friendly error messages
  String _buildUserFriendlyError(Exception exception) {
    final errorString = exception.toString().toLowerCase();

    // Network errors
    if (errorString.contains('network') || errorString.contains('connection')) {
      return '''
Network Connection Error

Please check your internet connection and try again. Audio transcription requires a stable connection.

If the problem persists:
• Try connecting to a different network
• Check if your firewall allows the connection
• Ensure you have sufficient bandwidth for file upload
      '''.trim();
    }

    // Timeout errors
    if (errorString.contains('timeout')) {
      return '''
Transcription Timeout

The transcription is taking longer than expected. This can happen with longer audio files or during high traffic periods.

Please try:
• Breaking longer recordings into smaller segments
• Trying again in a few minutes
• Ensuring your internet connection is stable
      '''.trim();
    }

    // Authentication errors
    if (errorString.contains('authentication') || errorString.contains('api key')) {
      return '''
Authentication Error

There is an issue with your Deepgram API key configuration.

Please check:
• Your API key is correctly set in the app settings
• Your API key is valid and active
• Your account has sufficient credits for transcription
      '''.trim();
    }

    // File errors
    if (errorString.contains('file not found') || errorString.contains('recording file')) {
      return '''
File Error

The audio recording could not be found or accessed.

Please:
• Ensure the recording was saved successfully
• Try recording again
• Check available storage space
      '''.trim();
    }

    // Rate limiting
    if (errorString.contains('rate limit')) {
      return '''
Rate Limit Exceeded

You have made too many transcription requests. Please wait before trying again.

To avoid this:
• Wait between transcription requests
• Consider shorter audio files
• Check your account usage limits
      '''.trim();
    }

    // Generic error
    return '''
Transcription Error

An unexpected error occurred during transcription. Please try again.

If this error continues:
• Try with a different audio file
• Check for app updates
• Contact support if the issue persists
    '''.trim();
  }

  /// Disposes resources
  void dispose() {
    _httpClient.close();
  }
}

/// Result of input validation
class ValidationResult {
  final bool isValid;
  final String? errorMessage;

  const ValidationResult._(this.isValid, this.errorMessage);

  factory ValidationResult.valid() => const ValidationResult._(true, null);
  factory ValidationResult.invalid(String message) => ValidationResult._(false, message);
}

/// Represents the result of a transcription operation
class TranscriptionResult {
  final String transcript;
  final double? confidence;
  final double? durationSeconds;
  final String? model;
  final String? language;

  const TranscriptionResult({
    required this.transcript,
    this.confidence,
    this.durationSeconds,
    this.model,
    this.language,
  });

  /// Creates a result indicating no speech was detected
  factory TranscriptionResult.noSpeech() {
    return const TranscriptionResult(
      transcript: 'No speech detected in the audio recording. Please ensure the recording contains clear speech.',
    );
  }

  /// Whether speech was detected
  bool get hasSpeech => transcript != 'No speech detected in the audio recording. Please ensure the recording contains clear speech.';

  /// Confidence as percentage (0-100)
  double? get confidencePercent => confidence != null ? confidence! * 100 : null;

  @override
  String toString() {
    final parts = <String>[transcript];

    if (confidence != null) {
      parts.add('Confidence: ${confidencePercent!.toStringAsFixed(1)}%');
    }

    if (durationSeconds != null) {
      parts.add('Duration: ${durationSeconds!.toStringAsFixed(1)}s');
    }

    return parts.join(' | ');
  }
}

/// Exception for transcription-related errors
class TranscriptionException implements Exception {
  final String message;

  const TranscriptionException(this.message);

  @override
  String toString() => 'TranscriptionException: $message';
}