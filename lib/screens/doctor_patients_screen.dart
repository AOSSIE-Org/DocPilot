import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../core/errors/app_error_handler.dart';
import '../models/health_models.dart';
import '../services/firebase/auth_service.dart';
import '../services/firebase/firestore_service.dart';
import '../theme/app_theme.dart';
import '../theme/app_animations.dart';
import 'doctor_patient_create_edit_screen.dart';
import 'doctor_patient_detail_screen.dart';

class DoctorPatientsScreen extends StatefulWidget {
  const DoctorPatientsScreen({super.key});

  @override
  State<DoctorPatientsScreen> createState() => _DoctorPatientsScreenState();
}

class _DoctorPatientsScreenState extends State<DoctorPatientsScreen> {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();

  String? get _doctorId => _authService.currentUser?.uid;

  Future<void> _addQuickSamplePatient() async {
    final doctorId = _doctorId;
    if (doctorId == null) return;

    final now = DateTime.now();
    final newRecord = ProviderPatientRecord(
      id: const Uuid().v4(),
      doctorId: doctorId,
      firstName: 'New',
      lastName: 'Patient',
      dateOfBirth: '1985-04-12',
      gender: 'Female',
      bloodType: 'A+',
      contactNumber: '+1 000 000 0000',
      email: 'patient@hospital.org',
      lastVisitSummary:
          'Follow-up visit for chronic care review; vitals stable; continue current plan with 2-week review.',
      prescriptions: const ['Metformin 500 mg BID', 'Atorvastatin 10 mg nightly'],
      reports: const ['CBC: normal', 'Lipid profile: borderline high LDL'],
      foodAllergies: const ['Peanuts'],
      medicinalAllergies: const ['Penicillin'],
      medicalHistory: const ['Type 2 diabetes', 'Dyslipidemia'],
      createdAt: now,
      updatedAt: now,
    );

    try {
      await _firestoreService.savePatientRecord(newRecord);
    } catch (error) {
      if (!mounted) return;
      AppErrorHandler.showSnackBar(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final doctorId = _doctorId;

    if (doctorId == null) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('My Patients'),
        ),
        body: const Center(
          child: Text('Sign in is required to access your patient list.'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('My Patients'),
        backgroundColor: AppTheme.surfaceColor,
        elevation: 0,
      ),
      floatingActionButton: ScaleAnimation(
        delay: const Duration(milliseconds: 300),
        child: FloatingActionButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const DoctorPatientCreateEditScreen(),
              ),
            );
          },
          backgroundColor: Colors.blue,
          child: const Icon(Icons.add),
        ),
      ),
      body: StreamBuilder<List<ProviderPatientRecord>>(
        stream: _firestoreService.watchDoctorPatients(doctorId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.lg),
                child: Text(
                  'Unable to load patients. Please check Firebase connectivity.',
                  textAlign: TextAlign.center,
                  style: AppTheme.bodyMedium,
                ),
              ),
            );
          }

          final patients = snapshot.data ?? const [];
          if (patients.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.group_off, size: 48, color: AppTheme.textSecondary),
                    const SizedBox(height: AppTheme.md),
                    Text('No patients found for this doctor.', style: AppTheme.bodyMedium),
                    const SizedBox(height: AppTheme.sm),
                    Text(
                      'Add records in Firestore collection "patients" with your doctorId.',
                      textAlign: TextAlign.center,
                      style: AppTheme.bodySmall,
                    ),
                    const SizedBox(height: AppTheme.lg),
                    IosButton(
                      label: 'Add Sample Patient',
                      onPressed: _addQuickSamplePatient,
                      icon: Icons.person_add,
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(AppTheme.lg),
            itemCount: patients.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppTheme.md),
            itemBuilder: (context, index) {
              final patient = patients[index];
              return AnimatedListItem(
                index: index,
                baseDelay: const Duration(milliseconds: 50),
                child: GlossyCard(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DoctorPatientDetailScreen(patient: patient),
                      ),
                    );
                  },
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.12),
                          borderRadius: AppTheme.mediumRadius,
                        ),
                        child: Center(
                          child: Text(
                            patient.firstName.isNotEmpty
                                ? patient.firstName[0].toUpperCase()
                                : '?',
                            style: AppTheme.headingSmall.copyWith(color: AppTheme.primaryColor),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppTheme.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(patient.fullName, style: AppTheme.labelLarge),
                            const SizedBox(height: AppTheme.xs),
                            Text(
                              'Last visit: ${patient.lastVisitSummary}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppTheme.bodySmall,
                            ),
                            const SizedBox(height: AppTheme.xs),
                            Text(
                              'Food allergies: ${patient.foodAllergies.length} • Medication allergies: ${patient.medicinalAllergies.length}',
                              style: AppTheme.labelSmall,
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
