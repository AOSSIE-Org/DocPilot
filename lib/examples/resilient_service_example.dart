import 'dart:developer' as developer;
import '../utils/retry_utility.dart';
import '../utils/network_utility.dart';

/// Example service demonstrating integration of retry logic and error handling
///
/// This service shows best practices for:
/// - Network connectivity checking
/// - Exponential backoff retry logic
/// - User-friendly error messages
/// - Resource management
class ResilientExampleService {
  /// Example of a critical operation that must succeed (e.g., saving patient data)
  Future<String> saveCriticalData(String data) async {
    developer.log('Saving critical data', name: 'ResilientExampleService');

    return await RetryUtility.execute<String>(
      () => _performCriticalSave(data),
      config: RetryConfig.critical,  // 5 attempts with longer backoff
      retryIf: RetryUtility.apiRetryCondition,
      onRetry: (exception, attempt) {
        developer.log(
          'Critical save failed, retrying (attempt $attempt): $exception',
          name: 'ResilientExampleService',
        );
      },
    );
  }

  /// Example of a standard API operation (e.g., getting AI response)
  Future<String> getAiResponse(String prompt) async {
    developer.log('Getting AI response', name: 'ResilientExampleService');

    try {
      return await RetryUtility.execute<String>(
        () => _performAiRequest(prompt),
        config: RetryConfig.apiDefault,  // 3 attempts with standard backoff
        retryIf: RetryUtility.apiRetryCondition,
        onRetry: RetryUtility.createLoggingCallback('AI API'),
      );

    } on MaxRetriesExceededException catch (e) {
      // Convert technical error to user-friendly message
      return _buildUserFriendlyAiError(e.lastException);

    } on NetworkException catch (e) {
      return '''
Network Connection Required

Please check your internet connection and try again.
The AI service requires a stable internet connection to process your request.

Details: ${e.message}
      '''.trim();
    }
  }

  /// Example of a fast operation where speed is prioritized (e.g., quick validation)
  Future<bool> validateQuickly(String input) async {
    developer.log('Performing quick validation', name: 'ResilientExampleService');

    try {
      return await RetryUtility.execute<bool>(
        () => _performQuickValidation(input),
        config: RetryConfig.fast,  // Only 2 attempts with short delays
        retryIf: (exception) {
          // For quick operations, only retry network issues
          return RetryUtility.isRetryableException(exception) &&
                 !exception.toString().contains('validation');
        },
      );

    } catch (e) {
      developer.log('Quick validation failed: $e', name: 'ResilientExampleService');
      return false;  // Fail safely for validation
    }
  }

  /// Example showing network connectivity checking before expensive operations
  Future<String> performExpensiveOperation(String data) async {
    developer.log('Starting expensive operation', name: 'ResilientExampleService');

    // Check network before starting expensive operation
    final networkInfo = await NetworkUtility.checkConnectivity();
    if (!networkInfo.isReachable) {
      throw NetworkException(
        'Internet connection required for this operation. '
        'Please connect to the internet and try again.',
        networkInfo,
      );
    }

    // Log network quality
    if (networkInfo.responseTimeMs != null && networkInfo.responseTimeMs! > 1000) {
      developer.log(
        'Slow network detected (${networkInfo.responseTimeMs}ms), operation may take longer',
        name: 'ResilientExampleService',
      );
    }

    return await RetryUtility.execute<String>(
      () => _performExpensiveRequest(data),
      config: RetryConfig.critical,
      retryIf: RetryUtility.apiRetryCondition,
      onRetry: (exception, attempt) {
        developer.log(
          'Expensive operation failed, retrying (attempt $attempt): $exception',
          name: 'ResilientExampleService',
        );
      },
    );
  }

  /// Example showing waiting for network recovery
  Future<String> waitAndRetryOperation(String data) async {
    developer.log('Operation with network wait', name: 'ResilientExampleService');

    try {
      return await RetryUtility.execute<String>(
        () => _performNetworkRequest(data),
        config: RetryConfig.apiDefault,
        retryIf: RetryUtility.apiRetryCondition,
      );

    } on NetworkException catch (e) {
      developer.log('Network error, waiting for connectivity', name: 'ResilientExampleService');

      // Wait for network recovery
      final recovered = await NetworkUtility.waitForConnectivity(
        maxWaitTime: const Duration(minutes: 1),
        checkInterval: const Duration(seconds: 5),
        onCheck: (networkInfo) {
          developer.log('Network check: ${networkInfo.status}', name: 'ResilientExampleService');
        },
      );

      if (recovered) {
        developer.log('Network recovered, retrying operation', name: 'ResilientExampleService');
        // Try once more after network recovery
        return await _performNetworkRequest(data);
      } else {
        throw NetworkException(
          'Network connection could not be restored. Please check your internet settings and try again.',
        );
      }
    }
  }

  /// Example showing multi-host connectivity checking
  Future<String> performWithMultipleHosts(String data) async {
    developer.log('Checking multiple hosts for best connectivity', name: 'ResilientExampleService');

    // Check connectivity to multiple hosts to find the best connection
    final networkInfo = await NetworkUtility.checkMultipleHosts(
      hosts: ['8.8.8.8', '1.1.1.1', '208.67.222.222'],  // Google, Cloudflare, OpenDNS
      timeout: const Duration(seconds: 5),
    );

    if (!networkInfo.isReachable) {
      throw NetworkException('No internet connection available from any tested host', networkInfo);
    }

    developer.log(
      'Best connectivity: ${networkInfo.responseTimeMs}ms response time',
      name: 'ResilientExampleService',
    );

    return await RetryUtility.execute<String>(
      () => _performNetworkRequest(data),
      config: RetryConfig.apiDefault,
      retryIf: RetryUtility.apiRetryCondition,
    );
  }

  /// Example showing custom retry logic with specific conditions
  Future<String> customRetryLogic(String data) async {
    developer.log('Operation with custom retry logic', name: 'ResilientExampleService');

    return await RetryUtility.execute<String>(
      () => _performSpecialOperation(data),
      config: const RetryConfig(
        maxAttempts: 4,
        baseDelay: Duration(milliseconds: 750),
        backoffMultiplier: 1.5,  // Slower backoff
        maxDelay: Duration(seconds: 20),
        useJitter: true,
      ),
      retryIf: (exception) {
        final errorString = exception.toString().toLowerCase();

        // Custom retry conditions
        if (errorString.contains('rate limit')) return true;   // Always retry rate limits
        if (errorString.contains('server busy')) return true;  // Retry server busy
        if (errorString.contains('timeout')) return true;      // Retry timeouts

        // Don't retry validation errors
        if (errorString.contains('invalid input')) return false;
        if (errorString.contains('bad format')) return false;

        // Default to standard retry condition
        return RetryUtility.isRetryableException(exception);
      },
      onRetry: (exception, attempt) {
        developer.log(
          'Custom retry attempt $attempt for: ${exception.toString()}',
          name: 'ResilientExampleService',
        );

        // Could add custom retry logic here, e.g.:
        // - Notify user of retry attempt
        // - Adjust request parameters
        // - Log to analytics service
      },
    );
  }

  // Mock implementation methods (replace with actual implementation)

  Future<String> _performCriticalSave(String data) async {
    await Future.delayed(const Duration(seconds: 2));
    // Simulate occasional failures
    if (DateTime.now().millisecond % 3 == 0) {
      throw Exception('Temporary server error');
    }
    return 'Data saved successfully';
  }

  Future<String> _performAiRequest(String prompt) async {
    await Future.delayed(const Duration(seconds: 1));
    // Simulate network issues
    if (DateTime.now().millisecond % 4 == 0) {
      throw Exception('Connection timeout');
    }
    return 'AI response for: $prompt';
  }

  Future<bool> _performQuickValidation(String input) async {
    await Future.delayed(const Duration(milliseconds: 500));
    // Simulate validation logic
    return input.isNotEmpty && input.length > 3;
  }

  Future<String> _performExpensiveRequest(String data) async {
    await Future.delayed(const Duration(seconds: 5));
    // Simulate expensive operation
    if (DateTime.now().millisecond % 5 == 0) {
      throw Exception('Service temporarily unavailable');
    }
    return 'Expensive operation completed for: $data';
  }

  Future<String> _performNetworkRequest(String data) async {
    // Check network connectivity as part of the operation
    final networkInfo = await NetworkUtility.checkConnectivity();
    if (!networkInfo.isReachable) {
      throw NetworkException('Network unavailable', networkInfo);
    }

    await Future.delayed(const Duration(seconds: 1));
    return 'Network operation completed';
  }

  Future<String> _performSpecialOperation(String data) async {
    await Future.delayed(const Duration(milliseconds: 1500));
    // Simulate special operation with various failure modes
    final random = DateTime.now().millisecond % 10;

    if (random < 3) throw Exception('Rate limit exceeded');
    if (random == 3) throw Exception('Server busy, please try again');
    if (random == 4) throw Exception('Request timeout');
    if (random == 5) throw Exception('Invalid input format');

    return 'Special operation completed';
  }

  String _buildUserFriendlyAiError(Exception exception) {
    final errorString = exception.toString().toLowerCase();

    if (errorString.contains('timeout')) {
      return '''
AI Service Timeout

The AI is taking longer than usual to respond. This can happen during busy periods.

Please try:
• Shortening your request
• Waiting a moment and trying again
• Checking your internet connection
      '''.trim();
    }

    if (errorString.contains('rate limit')) {
      return '''
Request Limit Reached

You've reached the temporary limit for AI requests. Please wait a moment before sending another request.

This helps ensure fair usage for all users.
      '''.trim();
    }

    if (errorString.contains('server error')) {
      return '''
AI Service Temporarily Unavailable

The AI service is experiencing temporary issues. This is usually resolved quickly.

Please try again in a few moments.
      '''.trim();
    }

    return '''
AI Request Failed

We couldn't process your request at this time. Please check your connection and try again.

If this continues, try restarting the app or contact support.
    '''.trim();
  }
}