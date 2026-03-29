import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Standardized button for clinical actions with consistent loading states
/// Provides unified styling across different healthcare features
class ClinicalActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool isLoading;
  final String loadingLabel;
  final Color backgroundColor;
  final Color foregroundColor;
  final bool isFullWidth;

  const ClinicalActionButton({
    super.key,
    required this.label,
    required this.icon,
    this.onPressed,
    this.isLoading = false,
    this.loadingLabel = '',
    this.backgroundColor = AppTheme.primaryColor,
    this.foregroundColor = Colors.white,
    this.isFullWidth = true,
  });

  /// Primary action button (default styling)
  const ClinicalActionButton.primary({
    super.key,
    required this.label,
    required this.icon,
    this.onPressed,
    this.isLoading = false,
    this.loadingLabel = '',
    this.isFullWidth = true,
  })  : backgroundColor = AppTheme.primaryColor,
        foregroundColor = Colors.white;

  /// Success action button (green)
  const ClinicalActionButton.success({
    super.key,
    required this.label,
    required this.icon,
    this.onPressed,
    this.isLoading = false,
    this.loadingLabel = '',
    this.isFullWidth = true,
  })  : backgroundColor = AppTheme.successColor,
        foregroundColor = Colors.white;

  /// Warning action button (orange/yellow)
  const ClinicalActionButton.warning({
    super.key,
    required this.label,
    required this.icon,
    this.onPressed,
    this.isLoading = false,
    this.loadingLabel = '',
    this.isFullWidth = true,
  })  : backgroundColor = AppTheme.warningColor,
        foregroundColor = Colors.white;

  /// Danger action button (red)
  const ClinicalActionButton.danger({
    super.key,
    required this.label,
    required this.icon,
    this.onPressed,
    this.isLoading = false,
    this.loadingLabel = '',
    this.isFullWidth = true,
  })  : backgroundColor = AppTheme.dangerColor,
        foregroundColor = Colors.white;

  @override
  Widget build(BuildContext context) {
    final Widget child = ElevatedButton.icon(
      onPressed: isLoading ? null : onPressed,
      icon: isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(Colors.white),
              ),
            )
          : Icon(icon),
      label: Text(
        isLoading && loadingLabel.isNotEmpty ? loadingLabel : label,
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        minimumSize: isFullWidth
            ? const Size.fromHeight(54)
            : const Size(120, 54),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: AppTheme.mediumRadius,
        ),
      ),
    );

    return isFullWidth
        ? SizedBox(width: double.infinity, child: child)
        : child;
  }
}

/// Secondary button for less prominent actions
class ClinicalSecondaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isFullWidth;

  const ClinicalSecondaryButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.isLoading = false,
    this.isFullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    final Widget child = icon != null
        ? OutlinedButton.icon(
            onPressed: isLoading ? null : onPressed,
            icon: isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(icon),
            label: Text(label),
            style: _buttonStyle,
          )
        : OutlinedButton(
            onPressed: isLoading ? null : onPressed,
            style: _buttonStyle,
            child: isLoading
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 8),
                      Text(label),
                    ],
                  )
                : Text(label),
          );

    return isFullWidth
        ? SizedBox(width: double.infinity, child: child)
        : child;
  }

  ButtonStyle get _buttonStyle => OutlinedButton.styleFrom(
        minimumSize: const Size(120, 48),
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: AppTheme.mediumRadius,
        ),
      );
}

/// Specialized buttons for common clinical actions
class ClinicalSpecialButtons {
  /// Analyze/Generate button for AI operations
  static Widget analyze({
    required VoidCallback? onPressed,
    bool isLoading = false,
    String label = 'Analyze',
    String loadingLabel = 'Analyzing...',
  }) {
    return ClinicalActionButton.primary(
      label: label,
      icon: Icons.psychology,
      onPressed: onPressed,
      isLoading: isLoading,
      loadingLabel: loadingLabel,
    );
  }

  /// Save button for data persistence
  static Widget save({
    required VoidCallback? onPressed,
    bool isLoading = false,
    String label = 'Save',
    String loadingLabel = 'Saving...',
  }) {
    return ClinicalActionButton.success(
      label: label,
      icon: Icons.save,
      onPressed: onPressed,
      isLoading: isLoading,
      loadingLabel: loadingLabel,
    );
  }

  /// Generate report button
  static Widget generateReport({
    required VoidCallback? onPressed,
    bool isLoading = false,
    String label = 'Generate Report',
    String loadingLabel = 'Generating...',
  }) {
    return ClinicalActionButton.success(
      label: label,
      icon: Icons.auto_awesome,
      onPressed: onPressed,
      isLoading: isLoading,
      loadingLabel: loadingLabel,
    );
  }

  /// Check safety button for medication screens
  static Widget checkSafety({
    required VoidCallback? onPressed,
    bool isLoading = false,
    String label = 'Check Safety & Interactions',
    String loadingLabel = 'Analyzing Safety...',
  }) {
    return ClinicalActionButton.warning(
      label: label,
      icon: Icons.security,
      onPressed: onPressed,
      isLoading: isLoading,
      loadingLabel: loadingLabel,
    );
  }

  /// Record voice button
  static Widget recordVoice({
    required VoidCallback? onPressed,
    bool isRecording = false,
    String label = 'Start Recording',
    String recordingLabel = 'Stop Recording',
  }) {
    return ClinicalActionButton(
      label: isRecording ? recordingLabel : label,
      icon: isRecording ? Icons.stop : Icons.mic,
      backgroundColor: isRecording ? AppTheme.dangerColor : AppTheme.primaryColor,
      onPressed: onPressed,
    );
  }
}