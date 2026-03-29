import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../services/firebase/auth_service.dart';
import '../../services/firebase/firestore_service.dart';
import '../../services/chatbot_service.dart';
import '../../services/deepgram_service.dart';
import '../../services/firebase/api_credentials_service.dart';
import '../../theme/app_theme.dart';

/// Comprehensive integration testing and health monitoring
class AppHealthMonitor {
  static final AppHealthMonitor _instance = AppHealthMonitor._internal();
  factory AppHealthMonitor() => _instance;
  AppHealthMonitor._internal();

  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();
  final ChatbotService _chatbotService = ChatbotService();

  /// Test all critical app integrations
  Future<Map<String, dynamic>> runComprehensiveHealthCheck() async {
    final results = <String, dynamic>{
      'timestamp': DateTime.now().toIso8601String(),
      'overall_status': 'unknown',
      'tests': <String, dynamic>{}
    };

    try {
      // Test Firebase Authentication
      results['tests']['firebase_auth'] = await _testFirebaseAuth();

      // Test Firestore Connection
      results['tests']['firestore'] = await _testFirestore();

      // Test API Key Management
      results['tests']['api_keys'] = await _testApiKeys();

      // Test AI Services (if keys available)
      final keysAvailable = results['tests']['api_keys']['status'] == 'success';
      if (keysAvailable) {
        results['tests']['gemini_ai'] = await _testGeminiConnection();
        results['tests']['deepgram'] = await _testDeepgramConnection();
      }

      // Calculate overall status
      results['overall_status'] = _calculateOverallStatus(results['tests']);

    } catch (e) {
      results['overall_status'] = 'error';
      results['error'] = e.toString();
    }

    return results;
  }

  Future<Map<String, dynamic>> _testFirebaseAuth() async {
    try {
      final user = _authService.currentUser;
      return {
        'status': 'success',
        'authenticated': user != null,
        'user_id': user?.uid ?? 'none',
        'display_name': user?.displayName ?? 'none',
      };
    } catch (e) {
      return {
        'status': 'error',
        'error': e.toString(),
      };
    }
  }

  Future<Map<String, dynamic>> _testFirestore() async {
    try {
      final isAvailable = _firestoreService.isFirebaseAvailable;
      if (!isAvailable) {
        return {
          'status': 'unavailable',
          'message': 'Firebase not configured',
        };
      }

      // Try a simple read operation
      final doctorId = _authService.currentUser?.uid;
      if (doctorId != null) {
        final patients = await _firestoreService.getDoctorPatients(doctorId);
        return {
          'status': 'success',
          'patient_count': patients.length,
          'read_test': 'passed',
        };
      } else {
        return {
          'status': 'success',
          'message': 'Firestore available but no authenticated user',
        };
      }
    } catch (e) {
      return {
        'status': 'error',
        'error': e.toString(),
      };
    }
  }

  Future<Map<String, dynamic>> _testApiKeys() async {
    try {
      final geminiKey = await ApiCredentialsService.instance.getGeminiApiKey();
      final deepgramKey = await ApiCredentialsService.instance.getDeepgramApiKey();

      return {
        'status': 'success',
        'gemini_key_available': geminiKey.isNotEmpty,
        'deepgram_key_available': deepgramKey.isNotEmpty,
        'both_keys_ready': geminiKey.isNotEmpty && deepgramKey.isNotEmpty,
      };
    } catch (e) {
      return {
        'status': 'error',
        'error': e.toString(),
      };
    }
  }

  Future<Map<String, dynamic>> _testGeminiConnection() async {
    try {
      // Test with a simple prompt
      final response = await _chatbotService.getGeminiResponse(
        'Respond with exactly: "Connection test successful"'
      );

      final isSuccess = response.toLowerCase().contains('connection test successful');

      return {
        'status': isSuccess ? 'success' : 'warning',
        'response_received': response.isNotEmpty,
        'expected_response': isSuccess,
        'response_length': response.length,
      };
    } catch (e) {
      return {
        'status': 'error',
        'error': e.toString(),
      };
    }
  }

  Future<Map<String, dynamic>> _testDeepgramConnection() async {
    try {
      // We can't easily test Deepgram without an actual audio file
      // So we'll just check if the service can be instantiated
      final service = DeepgramService();

      return {
        'status': 'success',
        'service_available': true,
        'note': 'Audio transcription requires actual audio file for full testing',
      };
    } catch (e) {
      return {
        'status': 'error',
        'error': e.toString(),
      };
    }
  }

  String _calculateOverallStatus(Map<String, dynamic> tests) {
    final criticalTests = ['firebase_auth', 'firestore', 'api_keys'];
    final optionalTests = ['gemini_ai', 'deepgram'];

    // Check critical tests
    for (final test in criticalTests) {
      if (tests[test]?['status'] == 'error') {
        return 'critical_error';
      }
    }

    // Check if API keys are available
    final apiKeysTest = tests['api_keys'];
    final bothKeysReady = apiKeysTest?['both_keys_ready'] ?? false;

    if (!bothKeysReady) {
      return 'setup_required';
    }

    // Check optional AI services
    for (final test in optionalTests) {
      if (tests.containsKey(test) && tests[test]?['status'] == 'error') {
        return 'degraded';
      }
    }

    return 'healthy';
  }

  /// Quick health check for UI display
  Future<AppHealthStatus> quickHealthCheck() async {
    try {
      final user = _authService.currentUser;
      final firestoreAvailable = _firestoreService.isFirebaseAvailable;

      if (user == null) {
        return AppHealthStatus.authRequired;
      }

      if (!firestoreAvailable) {
        return AppHealthStatus.firebaseIssue;
      }

      // Quick API key check
      final geminiKey = await ApiCredentialsService.instance.getGeminiApiKey();
      final deepgramKey = await ApiCredentialsService.instance.getDeepgramApiKey();

      if (geminiKey.isEmpty || deepgramKey.isEmpty) {
        return AppHealthStatus.setupRequired;
      }

      return AppHealthStatus.healthy;

    } catch (e) {
      if (kDebugMode) {
        print('Quick health check error: $e');
      }
      return AppHealthStatus.error;
    }
  }
}

/// App health status enum
enum AppHealthStatus {
  healthy,
  degraded,
  setupRequired,
  authRequired,
  firebaseIssue,
  error,
}

extension AppHealthStatusExtension on AppHealthStatus {
  String get displayMessage {
    switch (this) {
      case AppHealthStatus.healthy:
        return 'All systems operational';
      case AppHealthStatus.degraded:
        return 'Some features may be limited';
      case AppHealthStatus.setupRequired:
        return 'API keys setup required';
      case AppHealthStatus.authRequired:
        return 'Sign in required';
      case AppHealthStatus.firebaseIssue:
        return 'Firebase connection issue';
      case AppHealthStatus.error:
        return 'System error detected';
    }
  }

  Color get statusColor {
    switch (this) {
      case AppHealthStatus.healthy:
        return AppTheme.successColor;
      case AppHealthStatus.degraded:
        return AppTheme.warningColor;
      case AppHealthStatus.setupRequired:
        return AppTheme.infoColor;
      case AppHealthStatus.authRequired:
        return AppTheme.primaryColor;
      case AppHealthStatus.firebaseIssue:
        return AppTheme.dangerColor;
      case AppHealthStatus.error:
        return AppTheme.dangerColor;
    }
  }

  IconData get statusIcon {
    switch (this) {
      case AppHealthStatus.healthy:
        return Icons.check_circle;
      case AppHealthStatus.degraded:
        return Icons.warning;
      case AppHealthStatus.setupRequired:
        return Icons.settings;
      case AppHealthStatus.authRequired:
        return Icons.login;
      case AppHealthStatus.firebaseIssue:
        return Icons.cloud_off;
      case AppHealthStatus.error:
        return Icons.error;
    }
  }
}

/// Health status widget for debugging
class HealthStatusWidget extends StatefulWidget {
  const HealthStatusWidget({super.key});

  @override
  State<HealthStatusWidget> createState() => _HealthStatusWidgetState();
}

class _HealthStatusWidgetState extends State<HealthStatusWidget> {
  AppHealthStatus _status = AppHealthStatus.error;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkHealth();
  }

  Future<void> _checkHealth() async {
    setState(() => _isLoading = true);

    final status = await AppHealthMonitor().quickHealthCheck();

    if (mounted) {
      setState(() {
        _status = status;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    return GestureDetector(
      onTap: _showDetailedStatus,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: _status.statusColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _status.statusColor.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _status.statusIcon,
              size: 14,
              color: _status.statusColor,
            ),
            const SizedBox(width: 4),
            Text(
              _getShortStatus(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: _status.statusColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getShortStatus() {
    switch (_status) {
      case AppHealthStatus.healthy:
        return 'OK';
      case AppHealthStatus.degraded:
        return 'WARN';
      case AppHealthStatus.setupRequired:
        return 'SETUP';
      case AppHealthStatus.authRequired:
        return 'AUTH';
      case AppHealthStatus.firebaseIssue:
        return 'FIREBASE';
      case AppHealthStatus.error:
        return 'ERROR';
    }
  }

  void _showDetailedStatus() async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    // Run comprehensive check
    final results = await AppHealthMonitor().runComprehensiveHealthCheck();

    if (!mounted) return;
    Navigator.pop(context); // Close loading dialog

    // Show results dialog
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('App Health Status'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Overall: ${results['overall_status']}'),
              const SizedBox(height: 16),
              ...results['tests'].entries.map<Widget>((entry) {
                final test = entry.value as Map<String, dynamic>;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    '${entry.key}: ${test['status'] ?? 'unknown'}',
                    style: TextStyle(
                      color: test['status'] == 'success'
                        ? AppTheme.successColor
                        : test['status'] == 'error'
                          ? AppTheme.dangerColor
                          : AppTheme.warningColor,
                    ),
                  ),
                );
              }).toList(),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}