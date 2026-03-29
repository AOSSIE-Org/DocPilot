import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../core/config/firebase_config.dart';
import '../../core/errors/app_exception.dart';
import 'api_credentials_service.dart';
import 'firebase_bootstrap_service.dart';
import 'firestore_service.dart';

class AuthService {
  static final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  static Future<void>? _googleSignInInitialization;

  Future<void> _ensureGoogleSignInInitialized() {
    return _googleSignInInitialization ??= () async {
      await _googleSignIn.initialize();
    }();
  }

  Stream<User?> authStateChanges() {
    final auth = _auth;
    return auth?.authStateChanges() ?? const Stream<User?>.empty();
  }

  User? get currentUser => _auth?.currentUser;

  bool get _isFirebaseAvailable =>
      FirebaseConfig.isEnabled && FirebaseBootstrapService.isInitialized;

  FirebaseAuth? get _auth {
    if (!_isFirebaseAvailable) return null;
    try {
      return FirebaseAuth.instance;
    } catch (_) {
      return null;
    }
  }

  FirebaseAuth _requireAuth() {
    final auth = _auth;
    if (auth == null) {
      throw const AppException(
        code: 'firebase-not-configured',
        message: 'Firebase is not configured yet. Set FIREBASE_ENABLED=true after setup.',
      );
    }
    return auth;
  }

  Future<UserCredential> signInWithGoogle() async {
    try {
      final auth = _requireAuth();
      await _ensureGoogleSignInInitialized();

      if (kDebugMode) {
        debugPrint('Starting Google Sign-In...');
      }

      try {
        await _googleSignIn.signOut();
      } catch (_) {}

      final googleUser = await _googleSignIn.authenticate();

      if (kDebugMode) {
        debugPrint('Google Sign-In successful: ${googleUser.email}');
      }

      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;

      if (idToken == null) {
        if (kDebugMode) {
          debugPrint('Google authentication idToken is null');
        }
        throw const AppException(
          code: 'google-auth-failed',
          message: 'Failed to get Google authentication tokens.',
        );
      }

      final credential = GoogleAuthProvider.credential(
        idToken: idToken,
      );

      final userCredential = await auth.signInWithCredential(credential);

      await userCredential.user?.getIdToken(true);
      
      if (kDebugMode) {
        debugPrint('Firebase Sign-In successful: ${userCredential.user?.email}');
      }

      return userCredential;
    } on PlatformException catch (error) {
      final message = (error.message ?? error.code).toLowerCase();
      if (message.contains('developer_error') || message.contains('10')) {
        throw const AppException(
          code: 'google-developer-error',
          message:
              'Google Sign-In configuration mismatch detected. Verify package name, SHA-1/SHA-256, and reinstall app after refreshing google-services.json.',
        );
      }

      throw AppException(
        code: 'google-sign-in-platform-error',
        message: 'Google Sign-In failed on this device. Please retry.',
        cause: error,
      );
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Google Sign-In error: $error');
      }
      rethrow;
    }
  }

  Future<UserCredential> signInWithApple() async {
    if (!Platform.isIOS) {
      throw const AppException(
        code: 'apple-not-supported',
        message: 'Apple Sign-In is available on iOS only.',
      );
    }

    final auth = _requireAuth();

    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
    );

    final oauthCredential = OAuthProvider('apple.com').credential(
      idToken: appleCredential.identityToken,
      accessToken: appleCredential.authorizationCode,
    );

    return auth.signInWithCredential(oauthCredential);
  }

  Future<void> signOut() async {
    try {
      if (kDebugMode) {
        debugPrint('Signing out...');
      }

      // Clear caches immediately
      FirestoreService.clearAllCaches();
      ApiCredentialsService.instance.clearCache();

      // Run Firebase and Google sign out in parallel for speed
      try {
        await Future.wait([
          _signOutFromFirebase(),
          _signOutFromGoogle(),
        ]).timeout(const Duration(seconds: 10));
      } catch (e) {
        // Continue even if one fails
        if (kDebugMode) {
          debugPrint('Sign out operation error: $e');
        }
      }

      if (kDebugMode) {
        debugPrint('Sign out successful - all caches cleared');
      }
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Sign out error: $error');
      }
      rethrow;
    }
  }

  /// Sign out from Firebase authentication
  Future<void> _signOutFromFirebase() async {
    try {
      final auth = _auth;
      if (auth != null) {
        await auth.signOut().timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            if (kDebugMode) {
              debugPrint('Firebase sign out timeout, continuing...');
            }
          },
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Firebase sign out error: $e');
      }
    }
  }

  /// Sign out from Google (non-critical)
  Future<void> _signOutFromGoogle() async {
    try {
      // Add timeout to prevent hanging
      await _googleSignIn.signOut().timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          if (kDebugMode) {
            debugPrint('Google sign out timeout, continuing...');
          }
        },
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Google sign out error: $e');
      }
      // Don't throw - this is non-critical
    }
  }
}
