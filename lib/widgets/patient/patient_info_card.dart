import 'package:flutter/material.dart';

import '../../models/health_models.dart';
import '../../theme/app_theme.dart';

/// Reusable patient information display card
/// Provides consistent patient info UI across different clinical screens
class PatientInfoCard extends StatelessWidget {
  final ProviderPatientRecord patient;
  final VoidCallback? onTap;
  final bool showDetails;
  final Widget? trailing;

  const PatientInfoCard({
    super.key,
    required this.patient,
    this.onTap,
    this.showDetails = true,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return GlossyCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              borderRadius: AppTheme.smallRadius,
            ),
            child: const Icon(
              Icons.person,
              color: AppTheme.primaryColor,
              size: 28,
            ),
          ),
          const SizedBox(width: AppTheme.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  patient.fullName,
                  style: AppTheme.headingSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (showDetails) ...[
                  const SizedBox(height: AppTheme.xs),
                  Text(
                    '${patient.age} yrs • ${patient.gender}',
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  if (_hasAllergies) ...[
                    const SizedBox(height: AppTheme.xs),
                    Text(
                      'Allergies: ${_getAllergies()}',
                      style: AppTheme.labelSmall.copyWith(
                        color: AppTheme.warningColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: AppTheme.sm),
            trailing!,
          ],
        ],
      ),
    );
  }

  bool get _hasAllergies {
    return patient.foodAllergies.isNotEmpty || patient.medicinalAllergies.isNotEmpty;
  }

  String _getAllergies() {
    final allAllergies = [
      ...patient.foodAllergies,
      ...patient.medicinalAllergies,
    ];
    return allAllergies.join(', ');
  }
}

/// Compact patient info header for screens with limited space
class PatientInfoHeader extends StatelessWidget {
  final ProviderPatientRecord patient;
  final IconData icon;
  final Color iconColor;
  final String subtitle;

  const PatientInfoHeader({
    super.key,
    required this.patient,
    this.icon = Icons.person,
    this.iconColor = AppTheme.primaryColor,
    this.subtitle = '',
  });

  @override
  Widget build(BuildContext context) {
    return GlossyCard(
      child: Row(
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  patient.fullName,
                  style: AppTheme.labelLarge,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle.isNotEmpty ? subtitle : '${patient.age} yrs • ${patient.gender}',
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Empty state widget when no patient is selected
class NoPatientSelected extends StatelessWidget {
  final String message;
  final VoidCallback? onAddPatient;

  const NoPatientSelected({
    super.key,
    this.message = 'No patient selected',
    this.onAddPatient,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.person_outline,
            size: 60,
            color: Colors.grey.withValues(alpha: 0.5),
          ),
          const SizedBox(height: AppTheme.md),
          Text(
            message,
            style: AppTheme.bodyMedium.copyWith(
              color: AppTheme.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          if (onAddPatient != null) ...[
            const SizedBox(height: AppTheme.lg),
            OutlinedButton.icon(
              onPressed: onAddPatient,
              icon: const Icon(Icons.person_add),
              label: const Text('Add Patient'),
            ),
          ],
        ],
      ),
    );
  }
}