import 'package:flutter/material.dart';
import '../core/errors/app_error_handler.dart';
import '../theme/app_theme.dart';
import '../models/health_models.dart';
import '../services/firebase/auth_service.dart';
import '../services/firebase/firestore_service.dart';

class PatientProfileScreen extends StatefulWidget {
  final PatientProfile? initialProfile;
  final String? patientId;

  const PatientProfileScreen({
    super.key,
    this.initialProfile,
    this.patientId,
  });

  @override
  State<PatientProfileScreen> createState() => _PatientProfileScreenState();
}

class _PatientProfileScreenState extends State<PatientProfileScreen> {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();

  ProviderPatientRecord? _patientRecord;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPatientData();
  }

  Future<void> _loadPatientData() async {
    if (widget.patientId == null || widget.patientId!.isEmpty || widget.patientId == 'no-patient') {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final doctorId = _authService.currentUser?.uid;
      if (doctorId == null) {
        setState(() => _isLoading = false);
        return;
      }

      final patients = await _firestoreService.getDoctorPatients(doctorId);
      final patient = patients.firstWhere(
        (p) => p.id == widget.patientId,
        orElse: () => throw Exception('Patient not found'),
      );

      if (mounted) {
        setState(() {
          _patientRecord = patient;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        AppErrorHandler.showSnackBar(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('Patient Chart'),
          backgroundColor: AppTheme.surfaceColor,
          elevation: 0,
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_patientRecord == null) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('Patient Chart'),
          backgroundColor: AppTheme.surfaceColor,
          elevation: 0,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.person_off_outlined,
                size: 64,
                color: Colors.grey.withValues(alpha: 0.3),
              ),
              const SizedBox(height: AppTheme.md),
              Text(
                'Patient Not Found',
                style: AppTheme.headingMedium.copyWith(color: Colors.grey),
              ),
              const SizedBox(height: AppTheme.xs),
              Text(
                'Unable to load patient information',
                style: AppTheme.bodySmall,
              ),
            ],
          ),
        ),
      );
    }

    final patient = _patientRecord!;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Patient Chart'),
        backgroundColor: AppTheme.surfaceColor,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Profile Header
            GlossyCard(
              padding: const EdgeInsets.all(AppTheme.lg),
              margin: const EdgeInsets.all(AppTheme.lg),
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        (patient.firstName.isNotEmpty ? patient.firstName[0] : '') +
                            (patient.lastName.isNotEmpty ? patient.lastName[0] : ''),
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppTheme.md),
                  Text(
                    patient.fullName,
                    style: AppTheme.headingMedium,
                  ),
                  const SizedBox(height: AppTheme.xs),
                  Text(
                    '${patient.age} years old • ${patient.bloodType}',
                    style: AppTheme.bodySmall,
                  ),
                ],
              ),
            ),

            // Basic Information Section
            _buildProfileView(patient),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileView(ProviderPatientRecord patient) {
    return Column(
      children: [
        _buildSection(
          'Clinical Demographics',
          [
            _buildProfileItem('Full Name', patient.fullName),
            _buildProfileItem('Age', '${patient.age} years'),
            _buildProfileItem('Gender', patient.gender),
            _buildProfileItem('Blood Type', patient.bloodType),
            _buildProfileItem('Phone', patient.contactNumber),
            _buildProfileItem('Email', patient.email),
          ],
        ),
        _buildSection(
          'Medical History',
          [
            _buildMedicalList('Food Allergies', patient.foodAllergies),
            _buildMedicalList('Medicine Allergies', patient.medicinalAllergies),
            _buildMedicalList('Medical History', patient.medicalHistory),
            _buildMedicalList('Current Prescriptions', patient.prescriptions),
          ],
        ),
        if (patient.lastVisitSummary.isNotEmpty)
          _buildSection(
            'Last Visit',
            [
              Padding(
                padding: const EdgeInsets.all(AppTheme.lg),
                child: Text(
                  patient.lastVisitSummary,
                  style: AppTheme.bodyMedium,
                ),
              ),
            ],
          ),
        const SizedBox(height: AppTheme.xxl),
      ],
    );
  }

  Widget _buildSection(String title, List<Widget> items) {
    return Column(
      children: [
        SectionHeader(title: title),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.lg),
          child: GlossyCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: List.generate(
                items.length,
                (index) => Column(
                  children: [
                    items[index],
                    if (index < items.length - 1)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: AppTheme.lg),
                        child: Divider(height: 1, color: AppTheme.dividerColor),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.lg,
        vertical: AppTheme.md,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(label, style: AppTheme.bodyMedium),
          ),
          const SizedBox(width: AppTheme.md),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.bodyMedium.copyWith(
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicalList(String label, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.lg,
            vertical: AppTheme.md,
          ),
          child: Text(label, style: AppTheme.bodyMedium),
        ),
        if (items.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(AppTheme.lg, 0, AppTheme.lg, AppTheme.md),
            child: Wrap(
              spacing: AppTheme.sm,
              runSpacing: AppTheme.sm,
              children: items
                  .map(
                    (item) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.md,
                        vertical: AppTheme.xs,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                        borderRadius: AppTheme.mediumRadius,
                      ),
                      child: Text(
                        item,
                        style: AppTheme.labelMedium.copyWith(
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.fromLTRB(AppTheme.lg, 0, AppTheme.lg, AppTheme.md),
            child: Text('None recorded', style: AppTheme.bodySmall),
          ),
      ],
    );
  }
}
