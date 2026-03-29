import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../core/config/firebase_config.dart';
import '../../core/errors/app_exception.dart';
import 'auth_service.dart';
import 'firebase_bootstrap_service.dart';

class ApiCredentials {
  final String geminiApiKey;
  final String deepgramApiKey;
  final String source;

  const ApiCredentials({
    required this.geminiApiKey,
    required this.deepgramApiKey,
    required this.source,
  });
}

class ApiCredentialsService {
  ApiCredentialsService._();

  static final ApiCredentialsService instance = ApiCredentialsService._();

  ApiCredentials? _cached;
  String? _cachedUserId;

  // All possible locations where API keys might be stored in Firestore
  static const List<Map<String, String>> _possibleKeyLocations = [
    {'collection': 'app_runtime', 'document': 'api_keys'},
    {'collection': 'app_runtime', 'document': 'config'},
    {'collection': 'api_keys', 'document': 'config'},
    {'collection': 'api_keys', 'document': 'keys'},
    {'collection': 'apiKeys', 'document': 'config'},
    {'collection': 'apiKeys', 'document': 'keys'},
    {'collection': 'config', 'document': 'api_keys'},
    {'collection': 'config', 'document': 'apiKeys'},
    {'collection': 'config', 'document': 'keys'},
    {'collection': 'runtime', 'document': 'api_keys'},
    {'collection': 'runtime', 'document': 'config'},
    {'collection': 'settings', 'document': 'api_keys'},
    {'collection': 'settings', 'document': 'apiKeys'},
  ];

  // All possible field names for Gemini API key
  static const List<String> _geminiKeyFields = [
    'geminiApiKey',
    'gemini_api_key',
    'GEMINI_API_KEY',
    'geminiKey',
    'gemini_key',
    'aiApiKey',
    'ai_api_key',
  ];

  // All possible field names for Deepgram API key
  static const List<String> _deepgramKeyFields = [
    'deepgramApiKey',
    'deepgram_api_key',
    'DEEPGRAM_API_KEY',
    'deepgramKey',
    'deepgram_key',
    'speechApiKey',
    'speech_api_key',
  ];

  void clearCache() {
    _cached = null;
    _cachedUserId = null;
  }

  Future<void> preload() async {
    try {
      await _load();
    } catch (_) {}
  }

  Future<String> getGeminiApiKey() async {
    final creds = await _load();
    return creds.geminiApiKey;
  }

  Future<String> getDeepgramApiKey() async {
    final creds = await _load();
    return creds.deepgramApiKey;
  }

  Future<bool> hasKeys() async {
    try {
      final creds = await _load();
      return creds.geminiApiKey.isNotEmpty && creds.deepgramApiKey.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<ApiCredentials> _load() async {
    final userId = AuthService().currentUser?.uid;
    if (userId == null || userId.isEmpty) {
      clearCache();
      throw const AppException(
        code: 'not-authenticated',
        message: 'Sign in is required before loading runtime API keys.',
      );
    }

    if (_cached != null && _cachedUserId == userId) {
      return _cached!;  // Force unwrap - we just checked it's not null
    }

    if (_cachedUserId != null && _cachedUserId != userId) {
      clearCache();
    }

    // Try to load from all possible Firestore locations
    final primaryCreds = await _loadFromAllPossibleLocations();
    if (primaryCreds != null) {
      _cached = primaryCreds;
      _cachedUserId = userId;
      if (kDebugMode) {
        debugPrint('[ApiCredentialsService] ✅ Keys loaded from: ${primaryCreds.source}');
      }
      return primaryCreds;
    }

    throw const AppException(
      code: 'api-keys-unavailable',
      message:
          'API keys not configured in Firebase. Please add geminiApiKey and deepgramApiKey to collection: app_runtime, document: api_keys.',
    );
  }

  Future<ApiCredentials?> _loadFromAllPossibleLocations() async {
    if (!FirebaseConfig.isEnabled || !FirebaseBootstrapService.isInitialized) {
      return null;
    }

    final firestore = _primaryFirestore;
    if (firestore == null) return null;

    // First try the configured location from env
    final envCreds = await _tryLoadFromPath(
      firestore,
      FirebaseConfig.apiKeysCollection,
      FirebaseConfig.apiKeysDocument,
    );
    if (envCreds != null) return envCreds;

    // Then try all other possible locations
    for (final location in _possibleKeyLocations) {
      final collection = location['collection'];
      final document = location['document'];

      if (collection == null || document == null) {
        continue;
      }

      final creds = await _tryLoadFromPath(firestore, collection, document);
      if (creds != null) return creds;
    }

    return null;
  }

  Future<ApiCredentials?> _tryLoadFromPath(
    FirebaseFirestore firestore,
    String collection,
    String document,
  ) async {
    try {
      final snapshot = await firestore
          .collection(collection)
          .doc(document)
          .get();

      final data = snapshot.data();
      if (data == null) return null;

      // Try all possible field names for Gemini key
      String? gemini;
      for (final field in _geminiKeyFields) {
        final value = _sanitizeKey(data[field] as String?);
        if (value.isNotEmpty) {
          gemini = value;
          break;
        }
      }

      // Try all possible field names for Deepgram key
      String? deepgram;
      for (final field in _deepgramKeyFields) {
        final value = _sanitizeKey(data[field] as String?);
        if (value.isNotEmpty) {
          deepgram = value;
          break;
        }
      }

      if (gemini == null || gemini.isEmpty || deepgram == null || deepgram.isEmpty) {
        return null;
      }

      if (kDebugMode) {
        debugPrint('[ApiCredentialsService] Found keys at $collection/$document');
      }

      return ApiCredentials(
        geminiApiKey: gemini,
        deepgramApiKey: deepgram,
        source: 'firestore:$collection/$document',
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ApiCredentialsService] Error reading $collection/$document: $e');
      }
      return null;
    }
  }

  FirebaseFirestore? get _primaryFirestore {
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  String _sanitizeKey(String? raw) {
    final value = (raw ?? '').trim();
    if (value.isEmpty) return '';
    if (value.startsWith('your_')) return '';
    if (value.contains('placeholder')) return '';
    if (value.contains('YOUR_')) return '';
    if (value.contains('PLACEHOLDER')) return '';
    if (value == 'null') return '';
    if (value == 'undefined') return '';
    return value;
  }
}
