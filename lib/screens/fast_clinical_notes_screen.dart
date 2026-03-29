import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../core/errors/app_error_handler.dart';
import '../services/firebase/auth_service.dart';
import '../services/firebase/firestore_service.dart';
import '../models/health_models.dart';

/// Professional, fast-loading clinical notes screen optimized for emergency triage and ward rounds
class FastClinicalNotesScreen extends StatefulWidget {
  final String patientId;
  final String? screenTitle;
  final String? placeholder;

  const FastClinicalNotesScreen({
    super.key,
    required this.patientId,
    this.screenTitle,
    this.placeholder,
  });

  @override
  State<FastClinicalNotesScreen> createState() => _FastClinicalNotesScreenState();
}

class _FastClinicalNotesScreenState extends State<FastClinicalNotesScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _diagnosisController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();

  bool _isSaving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _diagnosisController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  bool get _isEmergency => widget.screenTitle?.contains('Emergency') == true;
  bool get _isWardRounds => widget.screenTitle?.contains('Ward') == true;

  Color get _primaryColor {
    if (_isEmergency) return AppTheme.dangerColor;
    if (_isWardRounds) return AppTheme.secondaryColor;
    return AppTheme.primaryColor;
  }

  IconData get _primaryIcon {
    if (_isEmergency) return Icons.emergency;
    if (_isWardRounds) return Icons.roundabout_left;
    return Icons.note_add;
  }

  String get _defaultTitle {
    if (_isEmergency) return 'Emergency Triage Assessment';
    if (_isWardRounds) return 'Ward Rounds Documentation';
    return 'Clinical Note';
  }

  String get _defaultPlaceholder {
    if (widget.placeholder != null) return widget.placeholder!;
    if (_isEmergency) {
      return 'Document patient presentation, vital signs, triage level (1-5), immediate actions, and diagnostic plan...';
    }
    if (_isWardRounds) {
      return 'Document patient status, overnight events, current issues, treatment response, and today\'s plan...';
    }
    return 'Enter clinical notes and observations...';
  }

  Future<void> _saveNote() async {
    if (_contentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.white),
              SizedBox(width: AppTheme.md),
              Text('Please enter clinical notes'),
            ],
          ),
          backgroundColor: AppTheme.warningColor,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final note = ClinicalNote(
        patientId: widget.patientId,
        title: _titleController.text.trim().isEmpty
            ? _defaultTitle
            : _titleController.text.trim(),
        content: _contentController.text.trim(),
        diagnosis: _diagnosisController.text.trim().isEmpty
            ? null
            : _diagnosisController.text.trim(),
        treatments: const [],
        followUpItems: const [],
        createdBy: _authService.currentUser?.displayName ?? 'Clinician',
      );

      await _firestoreService.saveClinicalReport(note);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_outline, color: Colors.white),
                SizedBox(width: AppTheme.md),
                Text('Clinical note saved successfully'),
              ],
            ),
            backgroundColor: AppTheme.successColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
        // Successfully saved - display success message and remain on screen
      }
    } catch (error) {
      if (mounted) {
        setState(() => _isSaving = false);
        AppErrorHandler.showSnackBar(context, error);
      }
    }
  }

  void _clearAll() {
    setState(() {
      _titleController.clear();
      _diagnosisController.clear();
      _contentController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(widget.screenTitle ?? 'Clinical Notes'),
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            onPressed: _clearAll,
            tooltip: 'Clear all fields',
          ),
        ],
      ),
      body: Column(
        children: [
          // Professional Header Banner
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_primaryColor, _primaryColor.withValues(alpha: 0.8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: _primaryColor.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.lg),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppTheme.md),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _primaryIcon,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: AppTheme.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Clinical Documentation',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _isEmergency
                              ? 'Rapid assessment for urgent cases'
                              : 'Structured documentation workflow',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Scrollable Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppTheme.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Title field
                  _buildFieldLabel('Title', Icons.title),
                  const SizedBox(height: AppTheme.sm),
                  _buildTextField(
                    controller: _titleController,
                    hintText: _defaultTitle,
                    icon: Icons.edit_note,
                    maxLines: 1,
                  ),
                  const SizedBox(height: AppTheme.xl),

                  // Diagnosis field
                  _buildFieldLabel('Diagnosis / Assessment', Icons.medical_information),
                  const SizedBox(height: AppTheme.sm),
                  _buildTextField(
                    controller: _diagnosisController,
                    hintText: 'Primary diagnosis or clinical assessment...',
                    icon: Icons.health_and_safety,
                    maxLines: 2,
                  ),
                  const SizedBox(height: AppTheme.xl),

                  // Clinical notes field
                  _buildFieldLabel('Clinical Notes', Icons.description),
                  const SizedBox(height: AppTheme.sm),
                  _buildTextField(
                    controller: _contentController,
                    hintText: _defaultPlaceholder,
                    icon: Icons.notes,
                    maxLines: 10,
                    isFocused: true,
                  ),
                  const SizedBox(height: AppTheme.xxl),

                  // Action Buttons Row
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _clearAll,
                          icon: Icon(Icons.clear_all),
                          label: Text('Clear'),
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: AppTheme.lg),
                            side: BorderSide(color: AppTheme.dividerColor),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppTheme.md),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: _isSaving ? null : _saveNote,
                          icon: _isSaving
                              ? SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : Icon(Icons.save_outlined),
                          label: Text(_isSaving ? 'Saving...' : 'Save Note'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: AppTheme.lg),
                            elevation: 2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldLabel(String label, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: _primaryColor),
        SizedBox(width: AppTheme.sm),
        Text(
          label,
          style: AppTheme.labelLarge.copyWith(
            color: _primaryColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    required int maxLines,
    bool isFocused = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: AppTheme.mediumRadius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: AppTheme.bodyMedium,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: AppTheme.bodySmall.copyWith(
            color: AppTheme.textSecondary,
          ),
          prefixIcon: Padding(
            padding: EdgeInsets.only(top: maxLines > 1 ? 12 : 0),
            child: Icon(icon, color: _primaryColor.withValues(alpha: 0.7)),
          ),
          border: OutlineInputBorder(
            borderRadius: AppTheme.mediumRadius,
            borderSide: BorderSide(color: AppTheme.dividerColor),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: AppTheme.mediumRadius,
            borderSide: BorderSide(color: AppTheme.dividerColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: AppTheme.mediumRadius,
            borderSide: BorderSide(color: _primaryColor, width: 2),
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: EdgeInsets.all(AppTheme.lg),
          alignLabelWithHint: true,
        ),
        textAlignVertical: TextAlignVertical.top,
      ),
    );
  }
}