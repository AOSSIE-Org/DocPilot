import 'package:flutter/material.dart';

import '../core/navigation/app_router.dart';
import '../core/errors/app_error_handler.dart';
import '../models/health_models.dart';
import '../services/firebase/firestore_service.dart';
import '../theme/app_theme.dart';
import 'doctor_patient_create_edit_screen.dart';

class DoctorPatientDetailScreen extends StatefulWidget {
  final ProviderPatientRecord patient;

  const DoctorPatientDetailScreen({super.key, required this.patient});

  @override
  State<DoctorPatientDetailScreen> createState() => _DoctorPatientDetailScreenState();
}

class _DoctorPatientDetailScreenState extends State<DoctorPatientDetailScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  bool _isDeleting = false;

  Future<void> _confirmAndDeletePatient() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Patient'),
        content: Text(
          'Are you sure you want to delete ${widget.patient.fullName}? '
          'This action cannot be undone and will also remove all associated records.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.dangerColor),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isDeleting = true);

    try {
      await _firestoreService.deletePatientRecord(widget.patient.id);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Patient deleted successfully'),
          backgroundColor: AppTheme.successColor,
        ),
      );
      Navigator.of(context).pop(true); // Return true to indicate deletion
    } catch (error) {
      if (!mounted) return;
      AppErrorHandler.showSnackBar(context, error);
    } finally {
      if (mounted) {
        setState(() => _isDeleting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(widget.patient.fullName),
        backgroundColor: AppTheme.surfaceColor,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Edit Patient',
            icon: const Icon(Icons.edit),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DoctorPatientCreateEditScreen(patient: widget.patient),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Delete Patient',
            icon: _isDeleting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.delete_outline, color: AppTheme.dangerColor),
            onPressed: _isDeleting ? null : _confirmAndDeletePatient,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            GlossyCard(
              margin: const EdgeInsets.all(AppTheme.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Patient Snapshot', style: AppTheme.headingSmall),
                  const SizedBox(height: AppTheme.md),
                  _row('Age', '${widget.patient.age} years'),
                  _row('Gender', widget.patient.gender),
                  _row('Blood Type', widget.patient.bloodType),
                  _row('Phone', widget.patient.contactNumber),
                  _row('Email', widget.patient.email),
                ],
              ),
            ),

            // Quick Action Buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.lg),
              child: Row(
                children: [
                  Expanded(
                    child: _actionButton(
                      context,
                      icon: Icons.mic_none,
                      label: 'Consultation',
                      color: AppTheme.primaryColor,
                      onTap: () => Navigator.pushNamed(
                        context,
                        AppRouter.voiceAssistant,
                        arguments: {
                          'patientId': widget.patient.id,
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: AppTheme.sm),
                  Expanded(
                    child: _actionButton(
                      context,
                      icon: Icons.note_alt,
                      label: 'Notes',
                      color: AppTheme.secondaryColor,
                      onTap: () => Navigator.pushNamed(
                        context,
                        AppRouter.clinicalNotes,
                        arguments: widget.patient.id,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppTheme.sm),
                  Expanded(
                    child: _actionButton(
                      context,
                      icon: Icons.document_scanner,
                      label: 'Scan Doc',
                      color: AppTheme.warningColor,
                      onTap: () => Navigator.pushNamed(
                        context,
                        AppRouter.documentScanner,
                        arguments: widget.patient.id,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.sm),

            _section('Last Visit Summary', [widget.patient.lastVisitSummary]),
            _section('Prescriptions', widget.patient.prescriptions),
            _section('Reports', widget.patient.reports),
            _section('Food Allergies', widget.patient.foodAllergies),
            _section('Medicinal Allergies', widget.patient.medicinalAllergies),
            _section('Medical History', widget.patient.medicalHistory),
            const SizedBox(height: AppTheme.xxl),
          ],
        ),
      ),
    );
  }

  Widget _actionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppTheme.md),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: AppTheme.mediumRadius,
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: AppTheme.xs),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.xs),
      child: Row(
        children: [
          SizedBox(width: 120, child: Text(label, style: AppTheme.bodySmall)),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(String title, List<String> values) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.lg),
      child: Column(
        children: [
          SectionHeader(title: title),
          GlossyCard(
            child: values.isEmpty
                ? Text('None recorded', style: AppTheme.bodySmall)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: values
                        .map(
                          (value) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: AppTheme.xs),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.only(top: 6),
                                  child: Icon(Icons.circle, size: 7, color: AppTheme.primaryColor),
                                ),
                                const SizedBox(width: AppTheme.sm),
                                Expanded(child: Text(value, style: AppTheme.bodyMedium)),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  ),
          ),
          const SizedBox(height: AppTheme.md),
        ],
      ),
    );
  }
}
