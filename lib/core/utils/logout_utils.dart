import 'package:flutter/material.dart';

/// Logout utilities for consistent UI/UX across the app
class LogoutUtils {
  // Prevent instantiation
  LogoutUtils._();

  /// Show confirmation dialog before logout
  static Future<bool> showLogoutConfirmation(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text(
          'Are you sure you want to sign out? You will need to sign in again to access your account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    ) ?? false;

    return confirmed;
  }

  /// Show loading dialog during logout process
  static void showLoadingDialog(BuildContext context) {
    showDialog(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (BuildContext ctx) => PopScope(
        canPop: false,
        child: Dialog(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Signing out...'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Close loading or any dialog
  static void closeDialog(BuildContext context) {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  /// Safe logout with confirmation, loading state, and navigation
  /// Sets a 10-second timeout to prevent infinite loading
  static Future<void> performSafeLogout({
    required BuildContext context,
    required Future<void> Function() onLogout,
    required Function(dynamic error) onError,
    required Function() onSuccess,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    // Step 1: Ask for confirmation
    if (!await showLogoutConfirmation(context)) return;

    // Step 2: Show loading
    if (!context.mounted) return;
    final rootNavigator = Navigator.of(context, rootNavigator: true);
    var loadingClosed = false;

    void closeLoadingDialogSafely() {
      if (loadingClosed || !rootNavigator.mounted) return;
      if (rootNavigator.canPop()) {
        rootNavigator.pop();
      }
      loadingClosed = true;
    }

    showLoadingDialog(context);

    try {
      // Step 3: Execute logout with timeout
      await onLogout().timeout(
        timeout,
        onTimeout: () {
          throw Exception('Logout took too long (timeout). Please try again.');
        },
      );

      // Step 4: Close loading
      closeLoadingDialogSafely();
      if (context.mounted) {
        // Call success callback
        onSuccess();
      }
    } catch (error) {
      // Step 5: Handle error
      closeLoadingDialogSafely();
      if (context.mounted) {
        // Call error handler
        onError(error);
      }
    }
  }
}
