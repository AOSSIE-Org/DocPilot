library network_utility;

import 'dart:async';
import 'dart:io';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

/// Represents the network connectivity status
enum NetworkStatus {
  /// Connected to the internet
  connected,

  /// No internet connection
  disconnected,

  /// Connection status unknown/checking
  unknown,
}

/// Information about network connectivity
class NetworkInfo {
  /// Current network status
  final NetworkStatus status;

  /// Whether the network is reachable
  final bool isReachable;

  /// Response time in milliseconds (null if not reachable)
  final int? responseTimeMs;

  /// Error message if connection failed
  final String? errorMessage;

  /// Timestamp when this info was gathered
  final DateTime timestamp;

  const NetworkInfo({
    required this.status,
    required this.isReachable,
    this.responseTimeMs,
    this.errorMessage,
    required this.timestamp,
  });

  /// Creates a connected network info
  factory NetworkInfo.connected([int? responseTimeMs]) {
    return NetworkInfo(
      status: NetworkStatus.connected,
      isReachable: true,
      responseTimeMs: responseTimeMs,
      timestamp: DateTime.now(),
    );
  }

  /// Creates a disconnected network info
  factory NetworkInfo.disconnected([String? error]) {
    return NetworkInfo(
      status: NetworkStatus.disconnected,
      isReachable: false,
      errorMessage: error,
      timestamp: DateTime.now(),
    );
  }

  /// Creates an unknown status network info
  factory NetworkInfo.unknown() {
    return NetworkInfo(
      status: NetworkStatus.unknown,
      isReachable: false,
      timestamp: DateTime.now(),
    );
  }

  @override
  String toString() {
    if (status == NetworkStatus.connected) {
      return 'NetworkInfo: Connected${responseTimeMs != null ? ' (${responseTimeMs}ms)' : ''}';
    } else if (status == NetworkStatus.disconnected) {
      return 'NetworkInfo: Disconnected${errorMessage != null ? ' - $errorMessage' : ''}';
    } else {
      return 'NetworkInfo: Unknown';
    }
  }
}

/// Utility class for checking network connectivity
class NetworkUtility {
  static const String _defaultCheckHost = '8.8.8.8';  // Google DNS
  static const int _defaultCheckPort = 53;             // DNS port
  static const Duration _defaultTimeout = Duration(seconds: 5);

  /// Cache for network status (valid for 30 seconds)
  static NetworkInfo? _cachedInfo;
  static DateTime? _cacheTime;
  static const Duration _cacheValidDuration = Duration(seconds: 30);

  /// Private constructor to prevent instantiation
  const NetworkUtility._();

  /// Checks if the device has internet connectivity
  ///
  /// [useCache] - Whether to use cached results if available
  /// [timeout] - Timeout for the connectivity check
  /// [host] - Host to check connectivity against
  /// [port] - Port to check connectivity against
  ///
  /// Returns [NetworkInfo] with connectivity status and details
  static Future<NetworkInfo> checkConnectivity({
    bool useCache = true,
    Duration timeout = _defaultTimeout,
    String host = _defaultCheckHost,
    int port = _defaultCheckPort,
  }) async {
    // Return cached result if valid and requested
    if (useCache && _isCacheValid()) {
      developer.log('Returning cached network info', name: 'NetworkUtility');
      return _cachedInfo!;
    }

    final stopwatch = Stopwatch()..start();

    try {
      developer.log('Checking network connectivity to $host:$port', name: 'NetworkUtility');

      // Try to connect to the specified host
      final socket = await Socket.connect(host, port, timeout: timeout);
      await socket.close();

      stopwatch.stop();
      final responseTime = stopwatch.elapsedMilliseconds;

      final info = NetworkInfo.connected(responseTime);
      _updateCache(info);

      developer.log('Network connectivity confirmed (${responseTime}ms)', name: 'NetworkUtility');
      return info;

    } on SocketException catch (e) {
      stopwatch.stop();
      final info = NetworkInfo.disconnected('Socket error: ${e.message}');
      _updateCache(info);

      developer.log('Network connectivity failed: ${e.message}', name: 'NetworkUtility');
      return info;

    } on TimeoutException catch (e) {
      stopwatch.stop();
      final info = NetworkInfo.disconnected('Timeout: ${e.message}');
      _updateCache(info);

      developer.log('Network connectivity timeout', name: 'NetworkUtility');
      return info;

    } catch (e) {
      stopwatch.stop();
      final info = NetworkInfo.disconnected('Unknown error: $e');
      _updateCache(info);

      developer.log('Network connectivity check failed: $e', name: 'NetworkUtility');
      return info;
    }
  }

  /// Quick check for internet connectivity (uses cache aggressively)
  static Future<bool> isConnected() async {
    final info = await checkConnectivity(useCache: true);
    return info.isReachable;
  }

  /// Forces a fresh connectivity check (bypasses cache)
  static Future<NetworkInfo> forceCheck({
    Duration timeout = _defaultTimeout,
    String host = _defaultCheckHost,
    int port = _defaultCheckPort,
  }) async {
    return checkConnectivity(
      useCache: false,
      timeout: timeout,
      host: host,
      port: port,
    );
  }

  /// Waits for network connectivity to be restored
  ///
  /// [maxWaitTime] - Maximum time to wait for connection
  /// [checkInterval] - Interval between connectivity checks
  /// [onCheck] - Callback called on each check attempt
  ///
  /// Returns true if connectivity was restored, false if timeout
  static Future<bool> waitForConnectivity({
    Duration maxWaitTime = const Duration(minutes: 2),
    Duration checkInterval = const Duration(seconds: 5),
    void Function(NetworkInfo info)? onCheck,
  }) async {
    developer.log('Waiting for network connectivity restoration', name: 'NetworkUtility');

    final stopwatch = Stopwatch()..start();

    while (stopwatch.elapsed < maxWaitTime) {
      final info = await forceCheck();
      onCheck?.call(info);

      if (info.isReachable) {
        developer.log('Network connectivity restored', name: 'NetworkUtility');
        return true;
      }

      developer.log(
        'Still disconnected, waiting ${checkInterval.inSeconds}s before next check',
        name: 'NetworkUtility',
      );

      await Future.delayed(checkInterval);
    }

    developer.log('Network connectivity wait timeout', name: 'NetworkUtility');
    return false;
  }

  /// Checks connectivity to multiple hosts and returns the fastest
  static Future<NetworkInfo> checkMultipleHosts({
    List<String> hosts = const ['8.8.8.8', '1.1.1.1', '208.67.222.222'],
    int port = 53,
    Duration timeout = _defaultTimeout,
  }) async {
    developer.log('Checking connectivity to multiple hosts', name: 'NetworkUtility');

    final futures = hosts.map((host) =>
      checkConnectivity(useCache: false, host: host, port: port, timeout: timeout)
    );

    try {
      // Return the first successful result
      final result = await Future.any(futures.map((future) async {
        final info = await future;
        if (info.isReachable) return info;
        throw Exception('Host not reachable');
      }));

      developer.log('Multi-host connectivity check succeeded', name: 'NetworkUtility');
      return result;

    } catch (e) {
      // If all fail, return the first result (likely disconnected)
      final results = await Future.wait(futures);
      final failedInfo = results.first;

      developer.log('All hosts failed connectivity check', name: 'NetworkUtility');
      return failedInfo;
    }
  }

  /// Gets detailed network information for debugging
  static Future<Map<String, dynamic>> getNetworkDetails() async {
    final info = await forceCheck();

    final details = <String, dynamic>{
      'status': info.status.name,
      'isReachable': info.isReachable,
      'responseTimeMs': info.responseTimeMs,
      'errorMessage': info.errorMessage,
      'timestamp': info.timestamp.toIso8601String(),
      'cacheAge': _getCacheAge()?.inSeconds,
      'platform': kIsWeb ? 'web' : Platform.operatingSystem,
    };

    // Add platform-specific information
    if (!kIsWeb) {
      try {
        details['hostName'] = Platform.localHostname;
      } catch (e) {
        details['hostNameError'] = e.toString();
      }
    }

    return details;
  }

  /// Clears the connectivity cache
  static void clearCache() {
    _cachedInfo = null;
    _cacheTime = null;
    developer.log('Network connectivity cache cleared', name: 'NetworkUtility');
  }

  /// Checks if the cached network info is still valid
  static bool _isCacheValid() {
    if (_cachedInfo == null || _cacheTime == null) return false;

    final age = DateTime.now().difference(_cacheTime!);
    return age <= _cacheValidDuration;
  }

  /// Updates the cache with new network info
  static void _updateCache(NetworkInfo info) {
    _cachedInfo = info;
    _cacheTime = DateTime.now();
  }

  /// Gets the age of cached data
  static Duration? _getCacheAge() {
    if (_cacheTime == null) return null;
    return DateTime.now().difference(_cacheTime!);
  }
}

/// Exception indicating network connectivity issues
class NetworkException implements Exception {
  final String message;
  final NetworkInfo? networkInfo;

  const NetworkException(this.message, [this.networkInfo]);

  @override
  String toString() => 'NetworkException: $message';

  /// Creates a network exception with connectivity check
  static Future<NetworkException> create(String message) async {
    final info = await NetworkUtility.checkConnectivity();
    return NetworkException(message, info);
  }
}

/// Extension for easier network checking
extension FutureNetworkExtension<T> on Future<T> {
  /// Wraps a future with network connectivity checking
  Future<T> withNetworkCheck() async {
    final isConnected = await NetworkUtility.isConnected();
    if (!isConnected) {
      throw const NetworkException('No internet connection available');
    }
    return this;
  }
}