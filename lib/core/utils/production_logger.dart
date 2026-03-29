import 'package:flutter/foundation.dart';

/// Production-safe logging utility for DocPilot
/// - Only prints in debug mode
/// - Can be disabled via environment variable
/// - Respects kDebugMode and kProfileMode
class ProductionLogger {
  static const String _prefix = '[DocPilot]';

  /// Log debug message (only in debug mode)
  static void debug(String message) {
    _log(message, level: 'DEBUG');
  }

  /// Log info message (only in debug mode)
  static void info(String message) {
    _log(message, level: 'INFO');
  }

  /// Log warning message (only in debug mode)
  static void warning(String message) {
    _log(message, level: 'WARN');
  }

  /// Log error message (only in debug mode)
  static void error(String message) {
    _log(message, level: 'ERROR');
  }

  /// Internal logging with level
  static void _log(String message, {required String level}) {
    // Only log in debug/profile mode, never in production
    if (!kDebugMode && !kProfileMode) {
      return;
    }

    // Format: [DocPilot] [LEVEL] message
    final formattedMessage = '$_prefix [$level] $message';

    if (kDebugMode) {
      debugPrint(formattedMessage);
    }
  }
}
