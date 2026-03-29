import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/health_models.dart';
import '../services/firebase/auth_service.dart';
import '../services/firebase/firestore_service.dart';
import '../theme/app_theme.dart';

class DoctorPatientCreateEditScreen extends StatefulWidget {
  final ProviderPatientRecord? patient;

  const DoctorPatientCreateEditScreen({
    super.key,
    this.patient,
  });

  @override
  State<DoctorPatientCreateEditScreen> createState() =>
      _DoctorPatientCreateEditScreenState();
}

class _DoctorPatientCreateEditScreenState
    extends State<DoctorPatientCreateEditScreen> {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _dateOfBirthController;
  late TextEditingController _contactNumberController;
  late TextEditingController _emailController;
  late TextEditingController _lastVisitSummaryController;
  late TextEditingController _prescriptionController;
  late TextEditingController _reportController;
  late TextEditingController _foodAllergyController;
  late TextEditingController _medicinalAllergyController;
  late TextEditingController _medicalHistoryController;

  String _selectedGender = 'Male';
  String _selectedBloodType = 'O+';

  late List<String> _prescriptions;
  late List<String> _reports;
  late List<String> _foodAllergies;
  late List<String> _medicinalAllergies;
  late List<String> _medicalHistory;

  bool _isSaving = false;

  final _genderOptions = ['Male', 'Female', 'Other'];
  final _bloodTypeOptions = ['O+', 'O-', 'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-'];

  @override
  void initState() {
    super.initState();
    final patient = widget.patient;

    if (patient != null) {
      _firstNameController = TextEditingController(text: patient.firstName);
      _lastNameController = TextEditingController(text: patient.lastName);
      _dateOfBirthController = TextEditingController(text: patient.dateOfBirth);
      _contactNumberController =
          TextEditingController(text: patient.contactNumber);
      _emailController = TextEditingController(text: patient.email);
      _lastVisitSummaryController =
          TextEditingController(text: patient.lastVisitSummary);
      _selectedGender = patient.gender;
      _selectedBloodType = patient.bloodType;
      _prescriptions = List.from(patient.prescriptions);
      _reports = List.from(patient.reports);
      _foodAllergies = List.from(patient.foodAllergies);
      _medicinalAllergies = List.from(patient.medicinalAllergies);
      _medicalHistory = List.from(patient.medicalHistory);
    } else {
      _firstNameController = TextEditingController();
      _lastNameController = TextEditingController();
      _dateOfBirthController = TextEditingController();
      _contactNumberController = TextEditingController();
      _emailController = TextEditingController();
      _lastVisitSummaryController = TextEditingController();
      _prescriptions = [];
      _reports = [];
      _foodAllergies = [];
      _medicinalAllergies = [];
      _medicalHistory = [];
    }

    _prescriptionController = TextEditingController();
    _reportController = TextEditingController();
    _foodAllergyController = TextEditingController();
    _medicinalAllergyController = TextEditingController();
    _medicalHistoryController = TextEditingController();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _dateOfBirthController.dispose();
    _contactNumberController.dispose();
    _emailController.dispose();
    _lastVisitSummaryController.dispose();
    _prescriptionController.dispose();
    _reportController.dispose();
    _foodAllergyController.dispose();
    _medicinalAllergyController.dispose();
    _medicalHistoryController.dispose();
    super.dispose();
  }

  Future<void> _savePatient() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final doctorId = _authService.currentUser?.uid;
    if (doctorId == null) {
      _showError('Authorization error: Could not get doctor ID');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final now = DateTime.now();
      final record = (widget.patient?.copyWith(
            firstName: _firstNameController.text,
            lastName: _lastNameController.text,
            dateOfBirth: _dateOfBirthController.text,
            gender: _selectedGender,
            bloodType: _selectedBloodType,
            contactNumber: _contactNumberController.text,
            email: _emailController.text,
            lastVisitSummary: _lastVisitSummaryController.text,
            prescriptions: _prescriptions,
            reports: _reports,
            foodAllergies: _foodAllergies,
            medicinalAllergies: _medicinalAllergies,
            medicalHistory: _medicalHistory,
            updatedAt: now,
          )) ??
          ProviderPatientRecord(
            id: const Uuid().v4(),
            doctorId: doctorId,
            firstName: _firstNameController.text,
            lastName: _lastNameController.text,
            dateOfBirth: _dateOfBirthController.text,
            gender: _selectedGender,
            bloodType: _selectedBloodType,
            contactNumber: _contactNumberController.text,
            email: _emailController.text,
            lastVisitSummary: _lastVisitSummaryController.text,
            prescriptions: _prescriptions,
            reports: _reports,
            foodAllergies: _foodAllergies,
            medicinalAllergies: _medicinalAllergies,
            medicalHistory: _medicalHistory,
            createdAt: now,
            updatedAt: now,
          );

      await _firestoreService.savePatientRecord(record);

      if (mounted) {
        _showSuccess(
            widget.patient != null ? 'Patient updated successfully!' : 'Patient added successfully!');
        // Successfully saved - stay on screen to allow further edits
      }
    } catch (e) {
      _showError('Failed to save patient: $e');
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(widget.patient != null ? 'Edit Patient' : 'Add Patient'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Basic Information Section
              _buildSectionHeader('Basic Information'),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _firstNameController,
                label: 'First Name',
                hint: 'First Name',
                validator: (value) =>
                    value?.isEmpty ?? true ? 'First name required' : null,
              ),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _lastNameController,
                label: 'Last Name',
                hint: 'Last Name',
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Last name required' : null,
              ),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _dateOfBirthController,
                label: 'Date of Birth (YYYY-MM-DD)',
                hint: '1990-01-15',
                validator: (value) {
                  if (value?.isEmpty ?? true) return 'DOB required';
                  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value!)) {
                    return 'Use format YYYY-MM-DD';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              _buildDropdownField(
                label: 'Gender',
                value: _selectedGender,
                items: _genderOptions,
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedGender = value);
                  }
                },
              ),
              const SizedBox(height: 12),
              _buildDropdownField(
                label: 'Blood Type',
                value: _selectedBloodType,
                items: _bloodTypeOptions,
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedBloodType = value);
                  }
                },
              ),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _contactNumberController,
                label: 'Contact Number',
                hint: '+1 (555) 123-4567',
              ),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _emailController,
                label: 'Email',
                hint: 'patient@example.com',
                validator: (value) {
                  if (value?.isEmpty ?? true) return null;
                  if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value!)) {
                    return 'Invalid email format';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Clinical History Section
              _buildSectionHeader('Clinical History'),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _lastVisitSummaryController,
                label: 'Last Visit Summary',
                hint: 'Summary of the last visit...',
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              _buildListSection(
                title: 'Medical History',
                items: _medicalHistory,
                controller: _medicalHistoryController,
                onAdd: (value) {
                  if (value.isNotEmpty) {
                    setState(() {
                      _medicalHistory.add(value);
                      _medicalHistoryController.clear();
                    });
                  }
                },
                onRemove: (index) {
                  setState(() => _medicalHistory.removeAt(index));
                },
              ),
              const SizedBox(height: 24),

              // Allergies Section
              _buildSectionHeader('Allergies'),
              const SizedBox(height: 12),
              _buildListSection(
                title: 'Food Allergies',
                items: _foodAllergies,
                controller: _foodAllergyController,
                hint: 'e.g., Peanuts',
                onAdd: (value) {
                  if (value.isNotEmpty) {
                    setState(() {
                      _foodAllergies.add(value);
                      _foodAllergyController.clear();
                    });
                  }
                },
                onRemove: (index) {
                  setState(() => _foodAllergies.removeAt(index));
                },
              ),
              const SizedBox(height: 12),
              _buildListSection(
                title: 'Medicinal Allergies',
                items: _medicinalAllergies,
                controller: _medicinalAllergyController,
                hint: 'e.g., Penicillin',
                onAdd: (value) {
                  if (value.isNotEmpty) {
                    setState(() {
                      _medicinalAllergies.add(value);
                      _medicinalAllergyController.clear();
                    });
                  }
                },
                onRemove: (index) {
                  setState(() => _medicinalAllergies.removeAt(index));
                },
              ),
              const SizedBox(height: 24),

              // Prescriptions & Reports Section
              _buildSectionHeader('Prescriptions & Reports'),
              const SizedBox(height: 12),
              _buildListSection(
                title: 'Prescriptions',
                items: _prescriptions,
                controller: _prescriptionController,
                hint: 'e.g., Metformin 500 mg BID',
                onAdd: (value) {
                  if (value.isNotEmpty) {
                    setState(() {
                      _prescriptions.add(value);
                      _prescriptionController.clear();
                    });
                  }
                },
                onRemove: (index) {
                  setState(() => _prescriptions.removeAt(index));
                },
              ),
              const SizedBox(height: 12),
              _buildListSection(
                title: 'Reports',
                items: _reports,
                controller: _reportController,
                hint: 'e.g., CBC: normal',
                onAdd: (value) {
                  if (value.isNotEmpty) {
                    setState(() {
                      _reports.add(value);
                      _reportController.clear();
                    });
                  }
                },
                onRemove: (index) {
                  setState(() => _reports.removeAt(index));
                },
              ),
              const SizedBox(height: 32),

              // Save Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _savePatient,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    disabledBackgroundColor:
                        Colors.blue.withValues(alpha: 0.5),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          widget.patient != null ? 'Update Patient' : 'Add Patient',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: AppTheme.primaryColor,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      maxLines: maxLines,
      validator: validator,
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      items: items
          .map((item) => DropdownMenuItem(
                value: item,
                child: Text(item),
              ))
          .toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildListSection({
    required String title,
    required List<String> items,
    required TextEditingController controller,
    required Function(String) onAdd,
    required Function(int) onRemove,
    String hint = '',
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: hint.isNotEmpty ? hint : 'Add $title',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () => onAdd(controller.text),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              child: const Text(
                'Add',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'No $title added yet',
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 12,
              ),
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (int i = 0; i < items.length; i++)
                Chip(
                  label: Text(items[i]),
                  onDeleted: () => onRemove(i),
                  backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                )
            ],
          ),
      ],
    );
  }
}
