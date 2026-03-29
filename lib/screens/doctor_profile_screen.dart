import 'package:flutter/material.dart';
import '../models/health_models.dart';
import '../services/firebase/auth_service.dart';
import '../services/firebase/firestore_service.dart';
import '../theme/app_theme.dart';

class DoctorProfileScreen extends StatefulWidget {
  final DoctorProfile? initialProfile;

  const DoctorProfileScreen({
    super.key,
    this.initialProfile,
  });

  @override
  State<DoctorProfileScreen> createState() => _DoctorProfileScreenState();
}

class _DoctorProfileScreenState extends State<DoctorProfileScreen> {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();
  late DoctorProfile _profile;
  bool _isEditing = false;
  bool _isSaving = false;
  bool _isLoading = true;

  // Controllers for editing
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _licenseNumberController;
  late TextEditingController _specialtyController;
  late TextEditingController _hospitalNameController;
  late TextEditingController _contactNumberController;
  late TextEditingController _emailController;
  late TextEditingController _departmentNameController;
  late TextEditingController _degreeController;

  @override
  void initState() {
    super.initState();
    _profile = widget.initialProfile ??
        DoctorProfile(
          id: _authService.currentUser?.uid ?? '',
          firstName: 'Dr.',
          lastName: 'Smith',
          licenseNumber: 'MED-123456',
          specialty: 'General Medicine',
          hospitalName: 'City Hospital',
          contactNumber: '+1 (555) 123-4567',
          email: _authService.currentUser?.email ?? 'doctor@hospital.org',
          departmentName: 'Internal Medicine',
          degree: 'MD',
        );

    // Create controllers once in initState
    _firstNameController = TextEditingController(text: _profile.firstName);
    _lastNameController = TextEditingController(text: _profile.lastName);
    _licenseNumberController = TextEditingController(text: _profile.licenseNumber);
    _specialtyController = TextEditingController(text: _profile.specialty);
    _hospitalNameController = TextEditingController(text: _profile.hospitalName);
    _contactNumberController = TextEditingController(text: _profile.contactNumber);
    _emailController = TextEditingController(text: _profile.email);
    _departmentNameController = TextEditingController(text: _profile.departmentName ?? '');
    _degreeController = TextEditingController(text: _profile.degree ?? '');

    _loadSavedProfile();
  }

  Future<void> _loadSavedProfile() async {
    final doctorId = _authService.currentUser?.uid;
    if (doctorId == null || doctorId.isEmpty) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final savedProfile = await _firestoreService.loadDoctorProfile(doctorId);
      if (!mounted) return;

      if (savedProfile != null) {
        setState(() {
          _profile = savedProfile;
          _isLoading = false;
        });
        // Re-initialize controllers with the loaded profile data
        _initializeControllers();
      } else {
        setState(() => _isLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _initializeControllers() {
    // Update existing controllers' text instead of creating new ones to avoid memory leaks
    _firstNameController.text = _profile.firstName;
    _lastNameController.text = _profile.lastName;
    _licenseNumberController.text = _profile.licenseNumber;
    _specialtyController.text = _profile.specialty;
    _hospitalNameController.text = _profile.hospitalName;
    _contactNumberController.text = _profile.contactNumber;
    _emailController.text = _profile.email;
    _departmentNameController.text = _profile.departmentName ?? '';
    _degreeController.text = _profile.degree ?? '';
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _licenseNumberController.dispose();
    _specialtyController.dispose();
    _hospitalNameController.dispose();
    _contactNumberController.dispose();
    _emailController.dispose();
    _departmentNameController.dispose();
    _degreeController.dispose();
    super.dispose();
  }

  void _toggleEditMode() {
    if (_isEditing) {
      _saveProfile();
    } else {
      setState(() => _isEditing = true);
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);

    try {
      final updatedProfile = _profile.copyWith(
        firstName: _firstNameController.text,
        lastName: _lastNameController.text,
        licenseNumber: _licenseNumberController.text,
        specialty: _specialtyController.text,
        hospitalName: _hospitalNameController.text,
        contactNumber: _contactNumberController.text,
        email: _emailController.text,
        departmentName: _departmentNameController.text,
        degree: _degreeController.text,
      );

      // Save to Firestore
      await _firestoreService.saveDoctorProfile(updatedProfile);

      if (mounted) {
        setState(() {
          _profile = updatedProfile;
          _isEditing = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile saved successfully to cloud'),
            backgroundColor: AppTheme.successColor,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving profile: $error'),
            backgroundColor: AppTheme.dangerColor,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _cancelEdit() {
    _initializeControllers();
    setState(() => _isEditing = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Doctor Profile'),
        backgroundColor: AppTheme.surfaceColor,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        actions: [
          if (!_isEditing)
            IconButton(
              tooltip: 'Edit Profile',
              icon: const Icon(Icons.edit),
              onPressed: _toggleEditMode,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.lg),
        child: _isEditing ? _buildEditForm() : _buildProfileView(),
      ),
    );
  }

  Widget _buildProfileView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with initials
        Center(
          child: Column(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(40),
                ),
                child: Center(
                  child: Text(
                    '${_profile.firstName.isNotEmpty ? _profile.firstName[0] : ''}${_profile.lastName.isNotEmpty ? _profile.lastName[0] : ''}'.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.md),
              Text(
                _profile.fullName,
                style: AppTheme.headingMedium,
              ),
              const SizedBox(height: AppTheme.xs),
              if (_profile.degree != null && _profile.degree!.isNotEmpty)
                Text(
                  '${_profile.degree} • ${_profile.specialty}',
                  style: AppTheme.bodyMedium,
                ),
              if (_profile.degree == null || _profile.degree!.isEmpty)
                Text(
                  _profile.specialty,
                  style: AppTheme.bodyMedium,
                ),
            ],
          ),
        ),
        const SizedBox(height: AppTheme.xl),

        // License Information
        _buildSectionHeader('License Information'),
        const SizedBox(height: AppTheme.sm),
        _buildInfoCard(
          label: 'License Number',
          value: _profile.licenseNumber,
          icon: Icons.verified_user,
        ),
        const SizedBox(height: AppTheme.md),

        // Professional Details
        _buildSectionHeader('Professional Details'),
        const SizedBox(height: AppTheme.sm),
        _buildInfoCard(
          label: 'Specialty',
          value: _profile.specialty,
          icon: Icons.medical_services,
        ),
        const SizedBox(height: AppTheme.sm),
        if (_profile.departmentName != null && _profile.departmentName!.isNotEmpty)
          _buildInfoCard(
            label: 'Department',
            value: _profile.departmentName!,
            icon: Icons.business,
          ),
        const SizedBox(height: AppTheme.sm),
        _buildInfoCard(
          label: 'Hospital',
          value: _profile.hospitalName,
          icon: Icons.local_hospital,
        ),
        const SizedBox(height: AppTheme.md),

        // Contact Information
        _buildSectionHeader('Contact Information'),
        const SizedBox(height: AppTheme.sm),
        _buildInfoCard(
          label: 'Email',
          value: _profile.email,
          icon: Icons.email,
        ),
        const SizedBox(height: AppTheme.sm),
        _buildInfoCard(
          label: 'Phone',
          value: _profile.contactNumber,
          icon: Icons.phone,
        ),
      ],
    );
  }

  Widget _buildEditForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Basic Information'),
        const SizedBox(height: AppTheme.sm),
        _buildTextField(
          controller: _firstNameController,
          label: 'First Name',
        ),
        const SizedBox(height: AppTheme.sm),
        _buildTextField(
          controller: _lastNameController,
          label: 'Last Name',
        ),
        const SizedBox(height: AppTheme.sm),
        _buildTextField(
          controller: _degreeController,
          label: 'Degree (e.g., MD, BDS)',
        ),
        const SizedBox(height: AppTheme.md),

        _buildSectionHeader('License & Credentials'),
        const SizedBox(height: AppTheme.sm),
        _buildTextField(
          controller: _licenseNumberController,
          label: 'License Number',
        ),
        const SizedBox(height: AppTheme.md),

        _buildSectionHeader('Professional Details'),
        const SizedBox(height: AppTheme.sm),
        _buildTextField(
          controller: _specialtyController,
          label: 'Specialty',
        ),
        const SizedBox(height: AppTheme.sm),
        _buildTextField(
          controller: _departmentNameController,
          label: 'Department Name (Optional)',
        ),
        const SizedBox(height: AppTheme.sm),
        _buildTextField(
          controller: _hospitalNameController,
          label: 'Hospital Name',
        ),
        const SizedBox(height: AppTheme.md),

        _buildSectionHeader('Contact Information'),
        const SizedBox(height: AppTheme.sm),
        _buildTextField(
          controller: _emailController,
          label: 'Email',
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: AppTheme.sm),
        _buildTextField(
          controller: _contactNumberController,
          label: 'Phone Number',
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: AppTheme.xl),

        // Action Buttons
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _isSaving ? null : _cancelEdit,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: const BorderSide(color: AppTheme.primaryColor),
                ),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: AppTheme.md),
            Expanded(
              child: ElevatedButton(
                onPressed: _isSaving ? null : _toggleEditMode,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  disabledBackgroundColor: Colors.blue.withValues(alpha: 0.5),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Save Changes',
                        style: TextStyle(color: Colors.white),
                      ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: AppTheme.labelLarge.copyWith(
        color: AppTheme.primaryColor,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildInfoCard({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.md),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: AppTheme.mediumRadius,
        border: Border.all(
          color: AppTheme.dividerColor,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: AppTheme.primaryColor,
            size: 24,
          ),
          const SizedBox(width: AppTheme.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTheme.labelSmall,
                ),
                const SizedBox(height: AppTheme.xs),
                Text(
                  value,
                  style: AppTheme.bodyMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
      ),
    );
  }
}
