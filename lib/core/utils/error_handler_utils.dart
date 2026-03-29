import 'package:flutter/foundation.dart';
import '../constants/app_constants.dart';

/// Custom exception types
abstract class AppException implements Exception {
  String get message;
  String get code;

  factory AppException.from(dynamic error) {
    if (error is AppException) {
      return error;
    }
    if (error is String) {
      return AppGeneralException(error);
    }
    return AppGeneralException(error.toString());
  }
}

class AppGeneralException implements AppException {
  @override
  final String message;
  @override
  final String code = 'GENERAL_ERROR';

  AppGeneralException(this.message);

  @override
  String toString() => 'AppGeneralException: $message';
}

class NetworkException implements AppException {
  @override
  final String message;
  @override
  final String code = 'NETWORK_ERROR';

  NetworkException([this.message = AppConstants.errorNoInternet]);

  @override
  String toString() => 'NetworkException: $message';
}

class FirebaseException implements AppException {
  @override
  final String message;
  @override
  final String code = 'FIREBASE_ERROR';
  final dynamic originalError;

  FirebaseException(this.message, [this.originalError]);

  @override
  String toString() => 'FirebaseException: $message';
}

class ValidationException implements AppException {
  @override
  final String message;
  @override
  final String code = 'VALIDATION_ERROR';

  ValidationException(this.message);

  @override
  String toString() => 'ValidationException: $message';
}

class AuthException implements AppException {
  @override
  final String message;
  @override
  final String code = 'AUTH_ERROR';

  AuthException(this.message);

  @override
  String toString() => 'AuthException: $message';
}

class DatabaseException implements AppException {
  @override
  final String message;
  @override
  final String code = 'DATABASE_ERROR';

  DatabaseException(this.message);

  @override
  String toString() => 'DatabaseException: $message';
}

/// Safe error handling wrapper
class ErrorHandler {
  // Prevent instantiation
  ErrorHandler._();

  /// Log error with context
  static void logError(
    String tag,
    dynamic error, {
    StackTrace? stackTrace,
    bool showDebug = true,
  }) {
    if (kDebugMode && showDebug) {
      debugPrint('[$tag] ERROR: $error');
      if (stackTrace != null) {
        debugPrint('[$tag] STACK TRACE:\n$stackTrace');
      }
    }
  }

  /// Safe execute function with error handling
  static Future<T?> safeExecute<T>(
    Future<T> Function() operation, {
    String tag = 'ErrorHandler',
    T? defaultValue,
    Function(dynamic error)? onError,
  }) async {
    try {
      return await operation();
    } catch (e, stackTrace) {
      logError(tag, e, stackTrace: stackTrace);
      onError?.call(e);
      return defaultValue;
    }
  }

  /// Safe execute sync function with error handling
  static T? safeExecuteSync<T>(
    T Function() operation, {
    String tag = 'ErrorHandler',
    T? defaultValue,
    Function(dynamic error)? onError,
  }) {
    try {
      return operation();
    } catch (e, stackTrace) {
      logError(tag, e, stackTrace: stackTrace);
      onError?.call(e);
      return defaultValue;
    }
  }

  /// Get user-friendly error message
  static String getUserMessage(dynamic error) {
    if (error == null) return AppConstants.errorGeneric;

    if (error is AppException) {
      return error.message;
    }

    if (error is NetworkException) {
      return AppConstants.errorNoInternet;
    }

    if (error is ValidationException) {
      return error.message;
    }

    if (error is AuthException) {
      return 'Authentication failed. Please try again.';
    }

    if (error is DatabaseException) {
      return 'Database error. Please try again.';
    }

    final errorStr = error.toString();
    if (errorStr.contains('SocketException')) {
      return AppConstants.errorNoInternet;
    }
    if (errorStr.contains('TimeoutException')) {
      return 'Request timed out. Please check your connection.';
    }
    if (errorStr.contains('FormatException')) {
      return 'Invalid data format received.';
    }

    return AppConstants.errorGeneric;
  }

  /// Check if error is network related
  static bool isNetworkError(dynamic error) {
    if (error is NetworkException) return true;
    final errorStr = error.toString().toLowerCase();
    return errorStr.contains('socket') ||
        errorStr.contains('network') ||
        errorStr.contains('timeout') ||
        errorStr.contains('connection') ||
        errorStr.contains('failed host lookup');
  }

  /// Check if error is authorization related
  static bool isAuthError(dynamic error) {
    if (error is AuthException) return true;
    final errorStr = error.toString().toLowerCase();
    return errorStr.contains('unauthorized') ||
        errorStr.contains('permission denied') ||
        errorStr.contains('forbidden');
  }

  /// Check if error is validation related
  static bool isValidationError(dynamic error) {
    if (error is ValidationException) return true;
    final errorStr = error.toString().toLowerCase();
    return errorStr.contains('validation') ||
        errorStr.contains('invalid') ||
        errorStr.contains('required');
  }

  /// Retry operation with exponential backoff
  static Future<T> retryWithBackoff<T>(
    Future<T> Function() operation, {
    int maxAttempts = AppConstants.maxRetryAttempts,
    Duration initialDelay = const Duration(milliseconds: 100),
  }) async {
    Duration delay = initialDelay;

    for (int i = 0; i < maxAttempts; i++) {
      try {
        return await operation();
      } catch (e) {
        if (i == maxAttempts - 1) rethrow;

        await Future.delayed(delay);
        delay *= 2; // Double the delay for next attempt
      }
    }

    // This line should never be reached, but required for type safety
    throw Exception('Retry exhausted');
  }
}

/// Mixin for providing error handling to providers/services
mixin SafeAsyncMixin {
  /// Execute async operation with error handling
  Future<T?> safeAsync<T>(
    Future<T> Function() operation, {
    String tag = 'SafeAsyncMixin',
    T? defaultValue,
  }) =>
      ErrorHandler.safeExecute<T>(
        operation,
        tag: tag,
        defaultValue: defaultValue,
      );

  /// Execute sync operation with error handling
  T? safeSync<T>(
    T Function() operation, {
    String tag = 'SafeAsyncMixin',
    T? defaultValue,
  }) =>
      ErrorHandler.safeExecuteSync<T>(
        operation,
        tag: tag,
        defaultValue: defaultValue,
      );
}
