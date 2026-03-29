import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'app_exception.dart';

class AppErrorHandler {
  static String? _extractExceptionMessage(Object error) {
    final raw = error.toString().trim();
    if (raw.isEmpty) return null;

    if (raw.startsWith('Exception:')) {
      final message = raw.substring('Exception:'.length).trim();
      if (message.isNotEmpty) return message;
    }

    if (raw.startsWith('Bad state:')) {
      final message = raw.substring('Bad state:'.length).trim();
      if (message.isNotEmpty) return message;
    }

    return null;
  }

  static String userMessage(Object error) {
    if (error is AppException) {
      return error.message;
    }

    final exceptionMessage = _extractExceptionMessage(error);
    if (exceptionMessage != null) {
      return exceptionMessage;
    }

    final text = error.toString().toLowerCase();

    // Firebase specific errors
    if (text.contains('operation-not-allowed')) {
      return 'Google Sign-In is not enabled in Firebase Console. Please enable it.';
    }

    if (text.contains('invalid-credential') || text.contains('user-disabled')) {
      return 'Invalid credentials. Please check your Firebase configuration.';
    }

    if (text.contains('developer_error') || text.contains('apiexception: 10')) {
      return 'Google Sign-In is misconfigured for this build. Verify package name, SHA-1/SHA-256, and download the latest google-services.json from the same Firebase project.';
    }

    if (text.contains('account-exists-with-different-credential')) {
      return 'This account exists with a different sign-in method.';
    }

    if (text.contains('network') || text.contains('socket')) {
      return 'Network unavailable. Please check your connection and try again.';
    }

    if (text.contains('permission')) {
      return 'Required permission is missing. Please review app permissions.';
    }

    if (text.contains('sign-in-cancelled')) {
      return 'Sign-in was cancelled. Please try again.';
    }

    if (text.contains('google')) {
      return 'Google Sign-In failed. Please try again or check your internet connection.';
    }

    if (text.contains('failed-precondition') && text.contains('index')) {
      return 'Firestore query requires an index. Open the Firebase Console error link to create the required index, then retry.';
    }

    return 'Something went wrong. Please try again.';
  }

  static void showSnackBar(BuildContext context, Object error) {
    if (!context.mounted) return;

    final message = userMessage(error);

    try {
      // Try Material ScaffoldMessenger first
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (_) {
      // Fallback to Cupertino AlertDialog if ScaffoldMessenger is not available
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Error'),
          content: Text(message),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }
}
