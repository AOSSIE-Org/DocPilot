import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../../core/config/firebase_config.dart';
import 'auth_service.dart';
import 'firestore_service.dart';
import 'firebase_bootstrap_service.dart';

class NotificationService {
  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();

  FirebaseMessaging? get _messaging {
    if (!FirebaseConfig.fcmEnabled || !FirebaseBootstrapService.isInitialized) {
      return null;
    }
    try {
      return FirebaseMessaging.instance;
    } catch (_) {
      return null;
    }
  }

  static Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
    if (kDebugMode) {
      debugPrint('Handling a background message: ${message.messageId}');
    }
  }

  Future<void> initialize() async {
    final messaging = _messaging;
    if (messaging == null) return;

    try {
      // Request notification permission with proper error handling
      final settings = await messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
      
      if (kDebugMode) {
        debugPrint('Notification permission status: ${settings.authorizationStatus}');
      }
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Error requesting notification permission: $error');
      }
    }

    try {
      FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);

      FirebaseMessaging.onMessage.listen((message) {
        if (kDebugMode) {
          debugPrint('Foreground message: ${message.messageId}');
        }
      });

      await _syncToken();
      messaging.onTokenRefresh.listen((_) => _syncToken());
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Error initializing Firebase messaging: $error');
      }
    }
  }

  Future<void> _syncToken() async {
    final messaging = _messaging;
    if (messaging == null) return;

    final user = _authService.currentUser;
    if (user == null) return;

    final token = await messaging.getToken();
    if (token == null) return;

    await _firestoreService.saveDeviceToken(userId: user.uid, token: token);
  }
}
