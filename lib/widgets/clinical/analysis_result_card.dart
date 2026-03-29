import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_theme.dart';

/// Standardized card for displaying AI analysis results
/// Provides consistent formatting and actions across clinical screens
class AnalysisResultCard extends StatelessWidget {
  final String title;
  final String content;
  final IconData icon;
  final Color iconColor;
  final VoidCallback? onShare;
  final VoidCallback? onSave;
  final bool showActions;

  const AnalysisResultCard({
    super.key,
    required this.title,
    required this.content,
    this.icon = Icons.check_circle,
    this.iconColor = AppTheme.successColor,
    this.onShare,
    this.onSave,
    this.showActions = true,
  });

  @override
  Widget build(BuildContext context) {
    return GlossyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppTheme.sm),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: AppTheme.smallRadius,
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: AppTheme.md),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
              if (showActions) ...[
                IconButton(
                  onPressed: () => _copyToClipboard(context),
                  icon: const Icon(Icons.copy),
                  tooltip: 'Copy to clipboard',
                  iconSize: 20,
                ),
                if (onShare != null)
                  IconButton(
                    onPressed: onShare,
                    icon: const Icon(Icons.share),
                    tooltip: 'Share',
                    iconSize: 20,
                  ),
              ],
            ],
          ),
          const Divider(height: AppTheme.xl),
          SelectableText(
            content,
            style: AppTheme.bodyMedium,
          ),
          if (showActions && (onSave != null || onShare != null)) ...[
            const SizedBox(height: AppTheme.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (onSave != null)
                  TextButton.icon(
                    onPressed: onSave,
                    icon: const Icon(Icons.save),
                    label: const Text('Save'),
                  ),
                if (onShare != null)
                  const SizedBox(width: AppTheme.sm),
                if (onShare != null)
                  FilledButton.icon(
                    onPressed: onShare,
                    icon: const Icon(Icons.share),
                    label: const Text('Share'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _copyToClipboard(BuildContext context) {
    Clipboard.setData(ClipboardData(text: content));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}

/// Loading state for analysis results
class AnalysisLoadingCard extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;
  final Color iconColor;

  const AnalysisLoadingCard({
    super.key,
    required this.title,
    this.message = 'Analyzing...',
    this.icon = Icons.psychology,
    this.iconColor = AppTheme.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return GlossyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppTheme.sm),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: AppTheme.smallRadius,
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: AppTheme.md),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                ),
              ),
            ],
          ),
          const Divider(height: AppTheme.xl),
          Row(
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                ),
              ),
              const SizedBox(width: AppTheme.sm),
              Text(
                message,
                style: AppTheme.bodyMedium.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Empty state when no analysis has been performed
class AnalysisEmptyState extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;
  final Color iconColor;
  final VoidCallback? onAction;
  final String actionLabel;

  const AnalysisEmptyState({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.analytics_outlined,
    this.iconColor = AppTheme.textSecondary,
    this.onAction,
    this.actionLabel = 'Start Analysis',
  });

  @override
  Widget build(BuildContext context) {
    return GlossyCard(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 48,
              color: iconColor,
            ),
            const SizedBox(height: AppTheme.md),
            Text(
              title,
              style: AppTheme.headingMedium.copyWith(
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.sm),
            Text(
              message,
              style: AppTheme.bodySmall.copyWith(
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            if (onAction != null) ...[
              const SizedBox(height: AppTheme.lg),
              OutlinedButton(
                onPressed: onAction,
                child: Text(actionLabel),
              ),
            ],
          ],
        ),
      ),
    );
  }
}