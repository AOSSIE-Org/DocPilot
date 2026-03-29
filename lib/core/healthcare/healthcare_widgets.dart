import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../theme/app_theme.dart';

/// Standardized analysis button used across all healthcare features
/// Provides consistent loading states and styling
class HealthcareAnalysisButton extends StatelessWidget {
  final String label;
  final bool isAnalyzing;
  final VoidCallback? onPressed;
  final Color backgroundColor;
  final Color foregroundColor;
  final IconData icon;
  final String? loadingText;

  const HealthcareAnalysisButton({
    super.key,
    required this.label,
    required this.isAnalyzing,
    required this.onPressed,
    required this.icon,
    this.backgroundColor = Colors.blue,
    this.foregroundColor = Colors.white,
    this.loadingText,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: isAnalyzing ? null : onPressed,
        icon: isAnalyzing
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
          isAnalyzing ? (loadingText ?? 'Analyzing...') : label,
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          padding: const EdgeInsets.symmetric(vertical: AppTheme.lg),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: AppTheme.mediumRadius,
          ),
        ),
      ),
    );
  }
}

/// Standardized result sheet for displaying AI analysis results
/// Provides consistent presentation across all healthcare features
class HealthcareResultSheet extends StatelessWidget {
  final String title;
  final String content;
  final Color? accentColor;
  final IconData? icon;
  final List<Widget>? actions;

  const HealthcareResultSheet({
    super.key,
    required this.title,
    required this.content,
    this.accentColor,
    this.icon,
    this.actions,
  });

  static void show(
    BuildContext context, {
    required String title,
    required String content,
    Color? accentColor,
    IconData? icon,
    List<Widget>? actions,
  }) {
    if (content.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No $title available yet.')),
      );
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => HealthcareResultSheet(
        title: title,
        content: content,
        accentColor: accentColor,
        icon: icon,
        actions: actions,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = accentColor ?? AppTheme.primaryColor;
    final normalizedContent = _normalizeContent(content);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                if (icon != null) ...[
                  Container(
                    padding: const EdgeInsets.all(AppTheme.sm),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: AppTheme.mediumRadius,
                    ),
                    child: Icon(icon, color: color, size: 24),
                  ),
                  const SizedBox(width: AppTheme.md),
                ],
                Expanded(
                  child: Text(
                    title,
                    style: AppTheme.headingSmall.copyWith(color: color),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.md),
            const Divider(),
            const SizedBox(height: AppTheme.md),

            // Content
            Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.6,
              ),
              child: SingleChildScrollView(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppTheme.md),
                  decoration: BoxDecoration(
                    color: AppTheme.backgroundColor,
                    borderRadius: AppTheme.mediumRadius,
                    border: Border.all(color: AppTheme.dividerColor),
                  ),
                  child: MarkdownBody(
                    data: normalizedContent,
                    selectable: true,
                    styleSheet: MarkdownStyleSheet(
                      p: AppTheme.bodyMedium,
                      h1: AppTheme.headingSmall,
                      h2: AppTheme.headingSmall.copyWith(fontSize: 20),
                      h3: AppTheme.labelLarge,
                      strong: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w700),
                      listBullet: AppTheme.bodyMedium,
                      blockquote: AppTheme.bodySmall.copyWith(
                        color: AppTheme.textSecondary,
                        fontStyle: FontStyle.italic,
                      ),
                      horizontalRuleDecoration: const BoxDecoration(
                        border: Border(
                          top: BorderSide(color: AppTheme.dividerColor),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Actions
            if (actions != null && actions!.isNotEmpty) ...[
              const SizedBox(height: AppTheme.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: actions!,
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _normalizeContent(String raw) {
    var text = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n').trim();

    // Remove fenced code markers when model wraps markdown in code blocks.
    text = text.replaceAll(RegExp(r'```(?:markdown|md|text)?\n?', caseSensitive: false), '');
    text = text.replaceAll('```', '');

    // Replace template placeholders with a clinically meaningful fallback.
    text = text.replaceAllMapped(
      RegExp(r'\[(?:Insert|Enter|Add)[^\]]+\]', caseSensitive: false),
      (_) => 'Not available from transcript',
    );

    // Prevent large blank gaps.
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');

    return text.trim();
  }
}

/// Standardized header card for healthcare features
/// Provides consistent branding and patient info display
class HealthcareFeatureHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final LinearGradient gradient;
  final String? patientName;
  final String? patientDetails;

  const HealthcareFeatureHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradient,
    this.patientName,
    this.patientDetails,
  });

  @override
  Widget build(BuildContext context) {
    return GlossyCard(
      gradient: gradient,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white, size: 28),
              const SizedBox(width: AppTheme.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (patientName != null) ...[
            const Divider(color: Colors.white, height: AppTheme.lg),
            Text(
              'Patient: $patientName',
              style: const TextStyle(color: Colors.white, fontSize: 15),
            ),
            if (patientDetails != null)
              Text(
                patientDetails!,
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
          ],
        ],
      ),
    );
  }
}

/// Empty state widget for healthcare features
class HealthcareEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String? actionLabel;
  final VoidCallback? onAction;

  const HealthcareEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 80,
              color: AppTheme.textTertiary,
            ),
            const SizedBox(height: AppTheme.md),
            Text(
              title,
              style: AppTheme.headingMedium.copyWith(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: AppTheme.xs),
            Text(
              description,
              style: AppTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppTheme.lg),
              ElevatedButton(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Loading card widget for healthcare features
class HealthcareLoadingCard extends StatelessWidget {
  final String message;
  final Color? color;

  const HealthcareLoadingCard({
    super.key,
    required this.message,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GlossyCard(
      child: Row(
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(
                color ?? AppTheme.primaryColor,
              ),
            ),
          ),
          const SizedBox(width: AppTheme.md),
          Expanded(
            child: Text(
              message,
              style: AppTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}