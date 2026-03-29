import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';

class FirebaseConfig {
  static bool _isInitialized = false;

  static String _env(String key, {String fallback = ''}) {
    try {
      return dotenv.env[key] ?? fallback;
    } catch (_) {
      return fallback;
    }
  }

  static bool get isEnabled =>
      _env('FIREBASE_ENABLED', fallback: 'true').toLowerCase() == 'true';

  static bool get useEmulator =>
      _env('FIREBASE_USE_EMULATOR', fallback: 'false').toLowerCase() == 'true';

  static String get firestoreHost =>
      _env('FIRESTORE_EMULATOR_HOST', fallback: 'localhost');

  static int get firestorePort =>
      int.tryParse(_env('FIRESTORE_EMULATOR_PORT')) ?? 8080;

  static String get authHost =>
      _env('AUTH_EMULATOR_HOST', fallback: 'localhost');

  static int get authPort =>
      int.tryParse(_env('AUTH_EMULATOR_PORT')) ?? 9099;

  static bool get fcmEnabled =>
      _env('FCM_ENABLED', fallback: 'false').toLowerCase() == 'true';

  static String get apiKeysCollection =>
      _env('FIREBASE_KEYS_COLLECTION', fallback: 'app_runtime');

  static String get apiKeysDocument =>
      _env('FIREBASE_KEYS_DOCUMENT', fallback: 'api_keys');

  static String get googleWebClientId =>
      _env('GOOGLE_WEB_CLIENT_ID', fallback: '');

  /// Check if Firebase has been initialized
  static bool get isInitialized => _isInitialized;

  /// Initialize Firebase with proper configuration and validation
  static Future<void> initialize() async {
    try {
      if (_isInitialized) {
        if (kDebugMode) {
          debugPrint('[FirebaseConfig] Already initialized');
        }
        return;
      }

      // Check if Firebase is already initialized by another service
      if (Firebase.apps.isNotEmpty) {
        _isInitialized = true;
        if (kDebugMode) {
          debugPrint('[FirebaseConfig] Firebase already initialized by another service');
        }
        return;
      }

      if (!isEnabled) {
        if (kDebugMode) {
          debugPrint('[FirebaseConfig] Firebase disabled by configuration');
        }
        return;
      }

      // Initialize Firebase
      await Firebase.initializeApp();
      _isInitialized = true;

      if (kDebugMode) {
        debugPrint('[FirebaseConfig] ✅ Firebase initialized successfully');
        debugPrint('[FirebaseConfig] App name: ${Firebase.app().name}');
        debugPrint('[FirebaseConfig] Project ID: ${Firebase.app().options.projectId}');
        debugPrint('[FirebaseConfig] Bundle ID: ${Firebase.app().options.iosBundleId ?? 'N/A'}');
      }
    } catch (e) {
      _isInitialized = false;

      if (kDebugMode) {
        debugPrint('[FirebaseConfig] ❌ Failed to initialize Firebase: $e');
        debugPrint('[FirebaseConfig] App will run in offline-only mode');
      }
      rethrow;
    }
  }

  /// Validate Firebase connection and configuration
  static Future<bool> validateConnection() async {
    if (!isEnabled || !_isInitialized) {
      return false;
    }

    try {
      // Check if Firebase is properly configured
      final app = Firebase.app();
      final isValid = app.name.isNotEmpty &&
                     app.options.projectId.isNotEmpty;

      if (kDebugMode) {
        debugPrint('[FirebaseConfig] Connection validation: ${isValid ? '✅ PASSED' : '❌ FAILED'}');
        if (isValid) {
          debugPrint('[FirebaseConfig] Project ID: ${app.options.projectId}');
          debugPrint('[FirebaseConfig] App ID: ${app.options.appId}');
        }
      }

      return isValid;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[FirebaseConfig] Connection validation failed: $e');
      }
      return false;
    }
  }

  /// Get detailed Firebase project information
  static Map<String, String> getProjectInfo() {
    if (!_isInitialized) {
      return {'status': 'Not initialized'};
    }

    try {
      final app = Firebase.app();
      return {
        'status': 'Connected',
        'projectId': app.options.projectId,
        'appId': app.options.appId,
        'storageBucket': app.options.storageBucket ?? 'Unknown',
        'messagingSenderId': app.options.messagingSenderId,
        'bundleId': app.options.iosBundleId ?? 'Unknown',
        'databaseURL': app.options.databaseURL ?? 'Unknown',
      };
    } catch (e) {
      return {'status': 'Error: $e'};
    }
  }
}
