import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/config/firebase_config.dart';
import '../../firebase_options.dart';

class FirebaseBootstrapService {
  static bool _initialized = false;

  static bool get isInitialized => _initialized;

  static Future<void> initialize() async {
    if (!FirebaseConfig.isEnabled || _initialized) return;

    // Check if Firebase is already initialized
    if (Firebase.apps.isNotEmpty) {
      _initialized = true;
      if (kDebugMode) {
        debugPrint('[Firebase] Already initialized, skipping...');
      }
      return;
    }

    try {
      // Always pass the correct Firebase options for the current platform
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      if (kDebugMode) {
        debugPrint('[Firebase] Initialized with project: ${Firebase.app().options.projectId}');
      }

      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );

      if (FirebaseConfig.useEmulator) {
        await FirebaseAuth.instance
            .useAuthEmulator(FirebaseConfig.authHost, FirebaseConfig.authPort);
        FirebaseFirestore.instance.useFirestoreEmulator(
          FirebaseConfig.firestoreHost,
          FirebaseConfig.firestorePort,
        );
      }

      _initialized = true;
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Firebase initialization skipped: $error');
      }
      _initialized = false;
    }
  }
}
