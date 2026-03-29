import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../core/errors/app_error_handler.dart';
import '../models/health_models.dart';
import '../services/chatbot_service.dart';
import '../services/firebase/firestore_service.dart';
import '../services/firebase/auth_service.dart';
import '../theme/app_theme.dart';
import '../theme/app_animations.dart';

class WardRoundsScreen extends StatefulWidget {
  final String? patientId;

  const WardRoundsScreen({
    super.key,
    this.patientId,
  });

  @override
  State<WardRoundsScreen> createState() => _WardRoundsScreenState();
}

class _WardRoundsScreenState extends State<WardRoundsScreen> {
  final ChatbotService _chatbotService = ChatbotService();
  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();

  final TextEditingController _progressNotesController = TextEditingController();
  final TextEditingController _planController = TextEditingController();
  final TextEditingController _ordersController = TextEditingController();

  bool _isGenerating = false;
  bool _isSaving = false;
  String _roundsSummary = '';

  List<ProviderPatientRecord> _wardPatients = [];
  ProviderPatientRecord? _selectedPatient;
  bool _isLoadingPatients = true;

  // Track previous rounds for history
  List<ClinicalNote> _previousRounds = [];
  bool _isLoadingHistory = false;

  @override
  void initState() {
    super.initState();
    _loadWardPatients();
  }

  @override
  void dispose() {
    _progressNotesController.dispose();
    _planController.dispose();
    _ordersController.dispose();
    super.dispose();
  }

  Future<void> _loadWardPatients() async {
    final doctorId = _authService.currentUser?.uid;
    if (doctorId == null || doctorId.isEmpty) {
      setState(() => _isLoadingPatients = false);
      return;
    }

    try {
      final patients = await _firestoreService.getDoctorPatients(doctorId);
      if (mounted) {
        setState(() {
          _wardPatients = patients;
          _isLoadingPatients = false;

          if (widget.patientId != null && widget.patientId != 'no-patient') {
            try {
              _selectedPatient = patients.firstWhere((p) => p.id == widget.patientId);
            } catch (_) {
              _selectedPatient = patients.isNotEmpty ? patients.first : null;
            }
          } else if (patients.isNotEmpty) {
            _selectedPatient = patients.first;
          }

          // Load previous rounds for the selected patient
          if (_selectedPatient != null) {
            _loadPreviousRounds();
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingPatients = false);
        AppErrorHandler.showSnackBar(context, e);
      }
    }
  }

  Future<void> _generateRoundsSummary() async {
    if (_selectedPatient == null) {
      AppErrorHandler.showSnackBar(
        context,
        'Please select a patient to generate ward rounds summary.',
      );
      return;
    }

    setState(() => _isGenerating = true);

    try {
      final prompt = '''
As an attending physician conducting ward rounds, create a comprehensive patient summary for:

**Patient:** ${_selectedPatient!.fullName}, Age ${_selectedPatient!.age}
**Medical History:** ${_selectedPatient!.medicalHistory.isEmpty ? 'No significant history documented' : _selectedPatient!.medicalHistory.join(', ')}

**Current Progress Notes:** ${_progressNotesController.text.trim().isEmpty ? 'No specific notes provided' : _progressNotesController.text.trim()}
**Treatment Plan Updates:** ${_planController.text.trim().isEmpty ? 'No updates provided' : _planController.text.trim()}
**New Orders/Medications:** ${_ordersController.text.trim().isEmpty ? 'No new orders' : _ordersController.text.trim()}

Please provide a structured ward rounds summary including:

## SUBJECTIVE
- Patient's reported symptoms and concerns
- Review of systems findings

## OBJECTIVE
- Current vital signs and physical exam findings
- Laboratory and diagnostic results (if available)
- Progress since last assessment

## ASSESSMENT
- Current clinical status and stability
- Response to current treatment
- Any changes in condition or new concerns

## PLAN
- Medication adjustments or new prescriptions
- Diagnostic tests or procedures needed
- Goals for next 24-48 hours
- Discharge planning considerations (if applicable)

##  FOLLOW-UP ACTIONS
- Specific monitoring parameters
- When to reassess
- Communication needed with patient/family

Format each section clearly with bullet points for easy reading during rounds.
''';

      final response = await _chatbotService.getGeminiResponse(prompt);

      if (mounted) {
        setState(() {
          _roundsSummary = response;
          _isGenerating = false;
        });
        HapticFeedback.mediumImpact();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isGenerating = false);
        AppErrorHandler.showSnackBar(context, e);
      }
    }
  }

  Future<void> _saveRoundsToClinicalNotes() async {
    if (_roundsSummary.isEmpty || _selectedPatient == null) return;

    setState(() => _isSaving = true);

    try {
      final note = ClinicalNote(
        patientId: _selectedPatient!.id,
        title: 'Ward Rounds - ${DateFormat('MMM d, y').format(DateTime.now())}',
        content: '''Progress Notes: ${_progressNotesController.text.trim().isEmpty ? 'Not provided' : _progressNotesController.text.trim()}

Treatment Plan Updates: ${_planController.text.trim().isEmpty ? 'No updates provided' : _planController.text.trim()}

New Orders/Medications: ${_ordersController.text.trim().isEmpty ? 'No new orders' : _ordersController.text.trim()}

--- AI SOAP SUMMARY ---

$_roundsSummary''',
        diagnosis: 'Ward Rounds Summary',
        treatments: [],
        followUpItems: ['Continue monitoring', 'Reassess in next rounds'],
        createdBy: _authService.currentUser?.displayName ?? 'Clinician',
      );

      await _firestoreService.saveClinicalReport(note);

      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Ward rounds saved to clinical notes'),
              ],
            ),
            backgroundColor: AppTheme.successColor,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        AppErrorHandler.showSnackBar(context, e);
      }
    }
  }

  Future<void> _loadPreviousRounds() async {
    if (_selectedPatient == null) return;

    setState(() => _isLoadingHistory = true);

    try {
      final allNotes = await _firestoreService.getClinicalReports(_selectedPatient!.id);
      final rounds = allNotes.where((note) =>
        note.title.toLowerCase().contains('ward rounds')).toList();

      if (mounted) {
        setState(() {
          _previousRounds = rounds;
          _isLoadingHistory = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingHistory = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: _isLoadingPatients
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                _buildSliverAppBar(),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(AppTheme.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Patient Selection
                        SlideUpAnimation(
                          child: _buildPatientSelection(),
                        ),

                        if (_selectedPatient != null) ...[
                          const SizedBox(height: AppTheme.lg),

                          // Selected Patient Card
                          SlideUpAnimation(
                            delay: const Duration(milliseconds: 100),
                            child: _buildSelectedPatientCard(),
                          ),

                          const SizedBox(height: AppTheme.lg),

                          // Previous Rounds History (if available)
                          if (_previousRounds.isNotEmpty) ...[
                            SlideUpAnimation(
                              delay: const Duration(milliseconds: 150),
                              child: _buildPreviousRoundsCard(),
                            ),
                            const SizedBox(height: AppTheme.lg),
                          ],

                          // Rounds Input Form
                          SlideUpAnimation(
                            delay: const Duration(milliseconds: 200),
                            child: _buildRoundsForm(),
                          ),

                          const SizedBox(height: AppTheme.xl),

                          // Action Button
                          ScaleAnimation(
                            delay: const Duration(milliseconds: 300),
                            child: _buildGenerateButton(),
                          ),

                          // Rounds Summary Results
                          if (_roundsSummary.isNotEmpty) ...[
                            const SizedBox(height: AppTheme.xl),
                            FadeInAnimation(
                              delay: const Duration(milliseconds: 400),
                              child: _buildRoundsSummaryCard(),
                            ),
                          ],
                        ],

                        // Empty State
                        if (_wardPatients.isEmpty && !_isLoadingPatients) ...[
                          const SizedBox(height: AppTheme.xl * 2),
                          FadeInAnimation(
                            child: _buildEmptyState(),
                          ),
                        ],

                        const SizedBox(height: AppTheme.xl),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      automaticallyImplyLeading: false,
      expandedHeight: 80,
      floating: false,
      pinned: true,
      backgroundColor: Colors.blue.shade300,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          color: Colors.blue.shade300,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppTheme.lg, 0, AppTheme.lg, AppTheme.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.local_hospital,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: AppTheme.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Ward Rounds',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              DateFormat('EEEE, MMM d').format(DateTime.now()),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${_wardPatients.length} Patients',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      actions: [
        if (_roundsSummary.isNotEmpty)
          IconButton(
            onPressed: _clearSummary,
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'New Round',
          ),
      ],
    );
  }

  Widget _buildPatientSelection() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.lg),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: AppTheme.largeRadius,
        border: Border.all(color: AppTheme.dividerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.person_search, color: AppTheme.primaryColor, size: 20),
              ),
              const SizedBox(width: AppTheme.md),
              Text('Select Patient', style: AppTheme.headingSmall),
            ],
          ),
          const SizedBox(height: AppTheme.md),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.backgroundColor,
              borderRadius: AppTheme.mediumRadius,
              border: Border.all(color: AppTheme.dividerColor),
            ),
            child: DropdownButtonFormField<ProviderPatientRecord>(
              value: _selectedPatient,
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: AppTheme.md),
                hintText: 'Choose patient for rounds...',
              ),
              dropdownColor: AppTheme.surfaceColor,
              items: _wardPatients.map((patient) {
                return DropdownMenuItem(
                  value: patient,
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                        child: Text(
                          patient.fullName.substring(0, 1).toUpperCase(),
                          style: TextStyle(
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppTheme.sm),
                      Text('${patient.fullName} (${patient.age})'),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (patient) {
                setState(() {
                  _selectedPatient = patient;
                  _roundsSummary = '';
                  _previousRounds = [];
                });
                if (patient != null) {
                  _loadPreviousRounds();
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedPatientCard() {
    if (_selectedPatient == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(AppTheme.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor.withValues(alpha: 0.08),
            AppTheme.primaryColor.withValues(alpha: 0.03),
          ],
        ),
        borderRadius: AppTheme.largeRadius,
        border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppTheme.primaryColor,
            child: Text(
              _selectedPatient!.fullName.substring(0, 1).toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 22,
              ),
            ),
          ),
          const SizedBox(width: AppTheme.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedPatient!.fullName,
                  style: AppTheme.labelLarge.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _buildInfoChip(Icons.cake, 'Age ${_selectedPatient!.age}'),
                    const SizedBox(width: 8),
                    if (_selectedPatient!.medicalHistory.isNotEmpty)
                      _buildInfoChip(
                        Icons.history,
                        '${_selectedPatient!.medicalHistory.length} conditions',
                      ),
                  ],
                ),
                if (_selectedPatient!.medicalHistory.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: _selectedPatient!.medicalHistory.take(3).map((h) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.warningColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          h,
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.warningColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.medical_information, color: AppTheme.primaryColor),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppTheme.textSecondary),
          const SizedBox(width: 4),
          Text(text, style: AppTheme.bodySmall),
        ],
      ),
    );
  }

  Widget _buildRoundsForm() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.lg),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: AppTheme.largeRadius,
        border: Border.all(color: AppTheme.dividerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.assignment, color: AppTheme.primaryColor, size: 20),
              ),
              const SizedBox(width: AppTheme.md),
              Text('Rounds Documentation', style: AppTheme.headingSmall),
            ],
          ),
          const SizedBox(height: AppTheme.lg),

          // Progress Notes
          _buildFormField(
            label: 'Progress Notes',
            icon: Icons.note_alt_outlined,
            controller: _progressNotesController,
            hint: 'Current status, symptoms, response to treatment...',
            maxLines: 3,
          ),
          const SizedBox(height: AppTheme.md),

          // Treatment Plan
          _buildFormField(
            label: 'Treatment Plan Updates',
            icon: Icons.healing_outlined,
            controller: _planController,
            hint: 'Changes to plan, goals, discharge planning...',
            maxLines: 3,
          ),
          const SizedBox(height: AppTheme.md),

          // New Orders
          _buildFormField(
            label: 'New Orders/Medications',
            icon: Icons.medication_outlined,
            controller: _ordersController,
            hint: 'New medications, lab orders, diagnostic tests...',
            maxLines: 2,
          ),
        ],
      ),
    );
  }

  Widget _buildFormField({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: AppTheme.textSecondary),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTheme.labelMedium.copyWith(fontWeight: FontWeight.w500),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.xs),
        TextField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.6)),
            filled: true,
            fillColor: AppTheme.backgroundColor,
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
              borderSide: BorderSide(color: AppTheme.primaryColor, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppTheme.md,
              vertical: AppTheme.sm,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGenerateButton() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: AppTheme.mediumRadius,
        gradient: _isGenerating
            ? null
            : const LinearGradient(
                colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
              ),
        boxShadow: _isGenerating
            ? null
            : [
                BoxShadow(
                  color: AppTheme.primaryColor.withValues(alpha: 0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isGenerating ? null : _generateRoundsSummary,
          borderRadius: AppTheme.mediumRadius,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isGenerating) ...[
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  const SizedBox(width: AppTheme.md),
                  const Text(
                    'Generating Summary...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ] else ...[
                  const Icon(Icons.assignment, color: Colors.white, size: 24),
                  const SizedBox(width: AppTheme.md),
                  const Text(
                    'Generate SOAP Summary',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoundsSummaryCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: AppTheme.largeRadius,
        border: Border.all(color: AppTheme.successColor.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.successColor.withValues(alpha: 0.1),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(AppTheme.md),
            decoration: BoxDecoration(
              color: AppTheme.successColor.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: AppTheme.successColor, size: 24),
                const SizedBox(width: AppTheme.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ward Rounds Summary',
                        style: AppTheme.headingSmall.copyWith(color: AppTheme.successColor),
                      ),
                      Text(
                        'Patient: ${_selectedPatient!.fullName}',
                        style: AppTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy_outlined),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _roundsSummary));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Summary copied to clipboard'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  tooltip: 'Copy to clipboard',
                ),
              ],
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(AppTheme.lg),
            child: SelectableText(
              _roundsSummary,
              style: AppTheme.bodyMedium.copyWith(height: 1.6),
            ),
          ),
          // Footer
          Container(
            padding: const EdgeInsets.all(AppTheme.md),
            decoration: BoxDecoration(
              color: AppTheme.backgroundColor,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Icon(Icons.access_time, size: 16, color: AppTheme.textSecondary),
                const SizedBox(width: 8),
                Text(
                  DateFormat('MMM d, y • h:mm a').format(DateTime.now()),
                  style: AppTheme.bodySmall,
                ),
                const SizedBox(width: AppTheme.sm),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.successColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'AI Generated',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.successColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _isSaving ? null : _saveRoundsToClinicalNotes,
                  icon: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(Icons.save_outlined, color: AppTheme.primaryColor, size: 18),
                  label: Text(
                    _isSaving ? 'Saving...' : 'Save to Notes',
                    style: TextStyle(color: AppTheme.primaryColor),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _clearSummary() {
    setState(() {
      _roundsSummary = '';
      _progressNotesController.clear();
      _planController.clear();
      _ordersController.clear();
    });
  }

  Widget _buildPreviousRoundsCard() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.lg),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: AppTheme.largeRadius,
        border: Border.all(color: AppTheme.dividerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.history, color: AppTheme.primaryColor, size: 20),
              ),
              const SizedBox(width: AppTheme.md),
              Text('Previous Rounds', style: AppTheme.headingSmall),
              const Spacer(),
              if (_isLoadingHistory)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_previousRounds.length}',
                    style: TextStyle(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppTheme.md),

          // Show Recent Rounds (Last 3)
          ...List.generate(_previousRounds.take(3).length, (index) {
            final round = _previousRounds[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: AppTheme.sm),
              child: Container(
                padding: const EdgeInsets.all(AppTheme.sm),
                decoration: BoxDecoration(
                  color: AppTheme.backgroundColor,
                  borderRadius: AppTheme.mediumRadius,
                  border: Border.all(color: AppTheme.dividerColor),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(Icons.assignment, color: AppTheme.primaryColor, size: 16),
                    ),
                    const SizedBox(width: AppTheme.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            round.title,
                            style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w500),
                          ),
                          Text(
                            _formatDate(round.createdAt),
                            style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: AppTheme.textSecondary, size: 16),
                  ],
                ),
              ),
            );
          }),

          if (_previousRounds.length > 3)
            Padding(
              padding: const EdgeInsets.only(top: AppTheme.sm),
              child: Text(
                '+ ${_previousRounds.length - 3} more rounds available in Clinical Notes',
                style: AppTheme.bodySmall.copyWith(
                  color: AppTheme.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today at ${DateFormat('h:mm a').format(date)}';
    } else if (difference.inDays == 1) {
      return 'Yesterday at ${DateFormat('h:mm a').format(date)}';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return DateFormat('MMM d, y').format(date);
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.local_hospital_outlined,
              size: 48,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: AppTheme.lg),
          Text(
            'No Patients Available',
            style: AppTheme.headingSmall,
          ),
          const SizedBox(height: AppTheme.sm),
          Text(
            'Add patients to your roster to conduct ward rounds.',
            style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
