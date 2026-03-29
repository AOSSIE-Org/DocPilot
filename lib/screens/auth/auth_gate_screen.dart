import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';

import '../../core/config/firebase_config.dart';
import '../../services/firebase/auth_service.dart';
import '../../services/firebase/api_credentials_service.dart';
import '../../services/firebase/firebase_bootstrap_service.dart';
import '../home_dashboard_screen.dart';
import 'sign_in_screen.dart';

class AuthGateScreen extends StatefulWidget {
  const AuthGateScreen({super.key});

  @override
  State<AuthGateScreen> createState() => _AuthGateScreenState();
}

class _AuthGateScreenState extends State<AuthGateScreen> {
  final AuthService _authService = AuthService();
  String? _preloadedKeysForUid;

  // Track auth state to avoid unnecessary rebuilds
  bool _isLoading = true;
  bool _isSignedIn = false;
  StreamSubscription<User?>? _authSubscription;

  @override
  void initState() {
    super.initState();
    if (FirebaseConfig.isEnabled && FirebaseBootstrapService.isInitialized) {
      _authSubscription = _authService.authStateChanges().listen(_onAuthChanged);
      // Add timeout to prevent infinite loading
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted && _isLoading) {
          setState(() {
            _isLoading = false;
          });
        }
      });
    } else {
      // Firebase not available, skip loading state
      _isLoading = false;
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  void _onAuthChanged(User? user) {
    final nowSignedIn = user != null;

    if (user != null) {
      _handleSignedInUser(user);
    } else {
      _handleSignedOutUser();
    }

    // Only rebuild if the signed-in status actually changed
    if (_isLoading || _isSignedIn != nowSignedIn) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isSignedIn = nowSignedIn;
        });
      }
    }
  }

  void _handleSignedInUser(User user) {
    if (_preloadedKeysForUid == user.uid) return;

    _preloadedKeysForUid = user.uid;

    if (kDebugMode) {
      debugPrint('[AuthGate] User signed in (${user.email}), preloading API keys...');
    }

    // Preload API keys immediately without delay
    ApiCredentialsService.instance.preload().then((_) {
      if (kDebugMode) {
        debugPrint('[AuthGate] ✅ API keys preloaded successfully');
      }
    }).catchError((error) {
      if (kDebugMode) {
        debugPrint('[AuthGate] Note: API keys not ready yet. Will retry on first use.');
      }
    });
  }

  void _handleSignedOutUser() {
    _preloadedKeysForUid = null;
    ApiCredentialsService.instance.clearCache();
  }

  @override
  Widget build(BuildContext context) {
    if (!FirebaseConfig.isEnabled) {
      return const SignInScreen();
    }

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_isSignedIn) {
      return const HomeDashboardScreen();
    }

    return const SignInScreen();
  }
}
