import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/config/app_branding.dart';
import '../../core/config/firebase_config.dart';
import '../../core/errors/app_error_handler.dart';
import '../../services/firebase/api_credentials_service.dart';
import '../../services/firebase/auth_service.dart';
import '../../services/firebase/firebase_bootstrap_service.dart';
import '../../theme/app_theme.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final AuthService _authService = AuthService();
  bool _isLoadingGoogle = false;
  bool _isLoadingApple = false;

  Future<void> _signInWithGoogle() async {
    if (_isLoadingGoogle) return;
    setState(() => _isLoadingGoogle = true);

    try {
      final credential = await _authService.signInWithGoogle();
      await credential.user?.getIdToken(true);
      await Future<void>.delayed(const Duration(milliseconds: 400));
      await ApiCredentialsService.instance.preload();
    } catch (error) {
      if (!mounted) return;
      AppErrorHandler.showSnackBar(context, error);
    } finally {
      _isLoadingGoogle = false;
      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<void> _signInWithApple() async {
    if (_isLoadingApple) return;
    setState(() => _isLoadingApple = true);

    try {
      await _authService.signInWithApple();
    } catch (error) {
      if (!mounted) return;
      AppErrorHandler.showSnackBar(context, error);
    } finally {
      _isLoadingApple = false;
      if (mounted) {
        setState(() {});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isFirebaseConfigured =
        FirebaseConfig.isEnabled && FirebaseBootstrapService.isInitialized;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // App logo
                  Center(
                    child: Image.asset(
                      'assets/images/docpilot_logo.png',
                      height: 100,
                      width: 100,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: AppTheme.lg),
                  Text(
                    'DocPilot',
                    textAlign: TextAlign.center,
                    style: AppTheme.headingLarge,
                  ),
                  const SizedBox(height: AppTheme.sm),
                  Text(
                    AppBranding.appDescription,
                    textAlign: TextAlign.center,
                    style: AppTheme.bodyMedium,
                    maxLines: 6,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppTheme.xxl),
                  IosButton(
                    label: 'Sign in with Google',
                    iconWidget: Image.asset(
                      'assets/images/google_logo.png',
                      height: 24,
                      width: 24,
                    ),
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black87,
                    isLoading: _isLoadingGoogle,
                    onPressed: _signInWithGoogle,
                  ),
                  if (Platform.isIOS) ...[
                    const SizedBox(height: AppTheme.md),
                    IosButton(
                      label: 'Sign in with Apple',
                      icon: Icons.apple,
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      isLoading: _isLoadingApple,
                      onPressed: _signInWithApple,
                    ),
                  ],
                  const SizedBox(height: AppTheme.lg),
                  Text(
                    isFirebaseConfigured
                        ? 'Secure cloud sync is available.'
                        : 'Firebase setup is required before sign-in can be used.',
                    textAlign: TextAlign.center,
                    style: AppTheme.bodySmall,
                  ),
                  const SizedBox(height: AppTheme.sm),
                  Text(
                    AppBranding.privacyDisclaimer,
                    textAlign: TextAlign.center,
                    style: AppTheme.labelMedium,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
