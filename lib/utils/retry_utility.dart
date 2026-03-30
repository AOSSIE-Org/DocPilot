library retry_utility;

import 'dart:async';
import 'dart:io';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

/// Configuration class for retry behavior
class RetryConfig {
  /// Maximum number of retry attempts
  final int maxAttempts;

  /// Base delay between retries (will be multiplied by backoff factor)
  final Duration baseDelay;

  /// Exponential backoff multiplier
  final double backoffMultiplier;

  /// Maximum delay between retries
  final Duration maxDelay;

  /// Whether to add jitter to prevent thundering herd
  final bool useJitter;

  const RetryConfig({
    this.maxAttempts = 3,
    this.baseDelay = const Duration(milliseconds: 500),
    this.backoffMultiplier = 2.0,
    this.maxDelay = const Duration(seconds: 30),
    this.useJitter = true,
  });

  /// Default configuration for API calls
  static const apiDefault = RetryConfig(
    maxAttempts: 3,
    baseDelay: Duration(milliseconds: 1000),  // 1 second
    backoffMultiplier: 2.0,                   // 1s, 2s, 4s
    maxDelay: Duration(seconds: 10),
    useJitter: true,
  );

  /// Configuration for critical operations
  static const critical = RetryConfig(
    maxAttempts: 5,
    baseDelay: Duration(milliseconds: 500),   // 0.5s, 1s, 2s, 4s, 8s
    backoffMultiplier: 2.0,
    maxDelay: Duration(seconds: 15),
    useJitter: true,
  );

  /// Configuration for quick operations
  static const fast = RetryConfig(
    maxAttempts: 2,
    baseDelay: Duration(milliseconds: 250),   // 250ms, 500ms
    backoffMultiplier: 2.0,
    maxDelay: Duration(seconds: 2),
    useJitter: false,
  );
}

/// Exception indicating that all retry attempts have failed
class MaxRetriesExceededException implements Exception {
  final String message;
  final int attempts;
  final Exception lastException;

  const MaxRetriesExceededException(
    this.message,
    this.attempts,
    this.lastException,
  );

  @override
  String toString() => 'MaxRetriesExceededException: $message (after $attempts attempts). Last error: $lastException';
}

/// Type definitions for retry functionality
typedef RetryFunction<T> = Future<T> Function();
typedef RetryCondition = bool Function(Exception exception);
typedef OnRetryCallback = void Function(Exception exception, int attempt);

/// Utility class providing retry functionality with exponential backoff
class RetryUtility {
  const RetryUtility._();

  /// Executes a function with retry logic and exponential backoff
  ///
  /// [operation] - The async operation to retry
  /// [config] - Retry configuration (defaults to [RetryConfig.apiDefault])
  /// [retryIf] - Condition function to determine if retry should happen
  /// [onRetry] - Callback executed on each retry attempt
  ///
  /// Returns the result of the operation or throws [MaxRetriesExceededException]
  static Future<T> execute<T>(
    RetryFunction<T> operation, {
    RetryConfig config = RetryConfig.apiDefault,
    RetryCondition? retryIf,
    OnRetryCallback? onRetry,
  }) async {
    Exception? lastException;

    for (int attempt = 1; attempt <= config.maxAttempts; attempt++) {
      try {
        // Log attempt for debugging
        if (kDebugMode && attempt > 1) {
          developer.log(
            'Retry attempt $attempt/${config.maxAttempts}',
            name: 'RetryUtility',
          );
        }

        return await operation();

      } catch (e) {
        lastException = e is Exception ? e : Exception(e.toString());

        // Check if we should retry this exception
        if (retryIf != null && !retryIf(lastException)) {
          developer.log(
            'Not retrying due to retry condition: $e',
            name: 'RetryUtility',
          );
          rethrow;
        }

        // Don't retry on the last attempt
        if (attempt == config.maxAttempts) {
          developer.log(
            'Max retries exceeded. Last error: $e',
            name: 'RetryUtility',
          );
          break;
        }

        // Call retry callback
        onRetry?.call(lastException, attempt);

        // Calculate delay with exponential backoff
        final delay = _calculateDelay(attempt, config);

        developer.log(
          'Retrying in ${delay.inMilliseconds}ms after error: $e',
          name: 'RetryUtility',
        );

        await Future.delayed(delay);
      }
    }

    throw MaxRetriesExceededException(
      'Operation failed after ${config.maxAttempts} attempts',
      config.maxAttempts,
      lastException ?? Exception('Unknown error'),
    );
  }

  /// Calculates the delay for the given attempt with exponential backoff
  static Duration _calculateDelay(int attempt, RetryConfig config) {
    // Calculate base delay with exponential backoff
    final exponentialDelay = config.baseDelay *
        (config.backoffMultiplier.pow(attempt - 1));

    // Apply maximum delay limit
    Duration delay = exponentialDelay > config.maxDelay
        ? config.maxDelay
        : exponentialDelay;

    // Add jitter if enabled (±25% randomization)
    if (config.useJitter) {
      final jitterRange = delay.inMilliseconds * 0.25;
      final jitter = (DateTime.now().millisecond % (jitterRange * 2)) - jitterRange;
      delay = Duration(
        milliseconds: (delay.inMilliseconds + jitter).round().clamp(
          config.baseDelay.inMilliseconds,
          config.maxDelay.inMilliseconds,
        ),
      );
    }

    return delay;
  }

  /// Determines if an exception is retryable (network/HTTP related)
  static bool isRetryableException(Exception exception) {
    final errorString = exception.toString().toLowerCase();

    // Network connectivity issues
    if (exception is SocketException) return true;

    // Timeout issues
    if (exception is TimeoutException) return true;

    // HTTP client errors that are retryable
    if (errorString.contains('connection')) return true;
    if (errorString.contains('timeout')) return true;
    if (errorString.contains('network')) return true;
    if (errorString.contains('unreachable')) return true;

    // HTTP status codes that are retryable
    if (errorString.contains('status code: 429')) return true;  // Rate limit
    if (errorString.contains('status code: 500')) return true;  // Server error
    if (errorString.contains('status code: 502')) return true;  // Bad gateway
    if (errorString.contains('status code: 503')) return true;  // Service unavailable
    if (errorString.contains('status code: 504')) return true;  // Gateway timeout

    // Certificate and TLS issues (might be temporary)
    if (errorString.contains('certificate')) return true;
    if (errorString.contains('handshake')) return true;

    return false;
  }

  /// Checks if HTTP status code is retryable
  static bool isRetryableHttpStatus(int statusCode) {
    return statusCode == 408 ||  // Request Timeout
           statusCode == 429 ||  // Too Many Requests
           statusCode == 502 ||  // Bad Gateway
           statusCode == 503 ||  // Service Unavailable
           statusCode == 504 ||  // Gateway Timeout
           statusCode >= 500;    // Other 5xx server errors
  }

  /// Creates a retry condition for HTTP operations
  static RetryCondition httpRetryCondition = (Exception exception) {
    return isRetryableException(exception);
  };

  /// Creates a retry condition for API operations with additional checks
  static RetryCondition apiRetryCondition = (Exception exception) {
    // Don't retry client errors (4xx except specific ones)
    final errorString = exception.toString().toLowerCase();

    // Don't retry authentication errors
    if (errorString.contains('status code: 401')) return false;  // Unauthorized
    if (errorString.contains('status code: 403')) return false;  // Forbidden
    if (errorString.contains('invalid api key')) return false;
    if (errorString.contains('authentication')) return false;

    // Don't retry not found errors
    if (errorString.contains('status code: 404')) return false;  // Not Found

    // Don't retry bad request errors
    if (errorString.contains('status code: 400')) return false;  // Bad Request

    return isRetryableException(exception);
  };

  /// Creates an onRetry callback that logs retry attempts
  static OnRetryCallback createLoggingCallback(String operationName) {
    return (Exception exception, int attempt) {
      developer.log(
        'Retrying $operationName (attempt $attempt): ${exception.toString()}',
        name: 'RetryUtility',
      );
    };
  }
}

/// Extension for exponential calculation
extension DoubleExtension on double {
  double pow(num exponent) {
    return dart.math.pow(this, exponent).toDouble();
  }
}

// Add missing import
import 'dart:math' as dart.math;