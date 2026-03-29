import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../core/ai_prompt_builder.dart';
import '../core/base_patient_screen.dart';
import '../core/errors/app_error_handler.dart';
import '../models/health_models.dart';
import '../services/chatbot_service.dart';
import '../services/firebase/auth_service.dart';
import '../services/firebase/firestore_service.dart';
import '../theme/app_theme.dart';
import '../theme/app_animations.dart';

class ShiftHandoffScreen extends StatefulWidget {
  final String? patientId;

  const ShiftHandoffScreen({
    super.key,
    this.patientId,
  });

  @override
  State<ShiftHandoffScreen> createState() => _ShiftHandoffScreenState();
}

class _ShiftHandoffScreenState extends State<ShiftHandoffScreen>
    with BasePatientScreen<ShiftHandoffScreen> {
  final ChatbotService _chatbotService = ChatbotService();
  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();

  final TextEditingController _patientSummaryController = TextEditingController();
  final TextEditingController _overnightEventsController = TextEditingController();
  final TextEditingController _pendingTasksController = TextEditingController();
  final TextEditingController _keyIssuesController = TextEditingController();

  bool _isGenerating = false;
  bool _isSaving = false;
  bool _isLoadingHistory = false;
  String _handoffReport = '';
  List<ClinicalNote> _previousHandoffs = [];

  // Critical handoff checklist
  final Map<String, bool> _handoffChecklist = {
    'Patient identification verified': false,
    'Allergies and adverse reactions reviewed': false,
    'Current medications reconciled': false,
    'Vital signs and trends documented': false,
    'Pain assessment completed': false,
    'Code status confirmed': false,
    'Fall risk assessment': false,
    'Isolation precautions noted': false,
    'Pending orders/results reviewed': false,
    'Family/visitor restrictions noted': false,
    'Special equipment/devices documented': false,
    'Safety concerns identified': false,
  };

  // Voice recording states
  final Map<String, bool> _isRecording = {
    'patientSummary': false,
    'overnightEvents': false,
    'pendingTasks': false,
    'keyIssues': false,
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeScreen();
    });
  }

  @override
  void dispose() {
    _patientSummaryController.dispose();
    _overnightEventsController.dispose();
    _pendingTasksController.dispose();
    _keyIssuesController.dispose();
    super.dispose();
  }

  @override
  void onPatientLoaded(ProviderPatientRecord loadedPatient) {
    setState(() {
      _patientSummaryController.text = loadedPatient.lastVisitSummary;
    });
    _loadPreviousHandoffs();
  }

  Future<void> _initializeScreen() async {
    if (widget.patientId != null) {
      await loadPatientData(widget.patientId);
    }
  }

  Future<void> _loadPreviousHandoffs() async {
    final patientId = patient?.id;
    if (patientId == null) return;

    setState(() => _isLoadingHistory = true);

    try {
      final allNotes = await _firestoreService.getClinicalReports(patientId);
      final handoffs = allNotes.where((note) =>
        note.title.toLowerCase().contains('shift handoff') ||
        note.title.toLowerCase().contains('i-pass')).toList();

      if (mounted) {
        setState(() {
          _previousHandoffs = handoffs;
          _isLoadingHistory = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingHistory = false);
      }
    }
  }

  Future<void> _saveHandoffToNotes() async {
    if (_handoffReport.isEmpty) return;

    final patientId = patient?.id;
    if (patientId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select a patient to save the handoff report'),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final note = ClinicalNote(
        patientId: patientId,
        title: 'I-PASS Shift Handoff - ${DateFormat('MMM d, h:mm a').format(DateTime.now())}',
        content: '''Patient Summary: ${_patientSummaryController.text.trim().isEmpty ? 'Not provided' : _patientSummaryController.text.trim()}

Action Items/Plans: ${_overnightEventsController.text.trim().isEmpty ? 'Not provided' : _overnightEventsController.text.trim()}

Situation Awareness: ${_pendingTasksController.text.trim().isEmpty ? 'Not provided' : _pendingTasksController.text.trim()}

Synthesis by receiver: ${_keyIssuesController.text.trim().isEmpty ? 'Not provided' : _keyIssuesController.text.trim()}

--- AI-GENERATED I-PASS HANDOFF REPORT ---

$_handoffReport''',
        diagnosis: 'Shift Handoff Documentation',
        treatments: [],
        followUpItems: ['Next shift to review', 'Follow up on pending tasks'],
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
                Text('Handoff saved to clinical notes'),
              ],
            ),
            backgroundColor: AppTheme.successColor,
            duration: const Duration(seconds: 2),
          ),
        );
        _loadPreviousHandoffs(); // Refresh history
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        AppErrorHandler.showSnackBar(context, e);
      }
    }
  }

  void _simulateVoiceInput(String fieldKey, TextEditingController controller) {
    setState(() => _isRecording[fieldKey] = true);

    // Simulate voice recording with sample text after a short delay
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;

      String sampleText = '';
      switch (fieldKey) {
        case 'patientSummary':
          sampleText = 'Patient is a 65-year-old male admitted with chest pain, currently stable on telemetry monitoring. Primary diagnosis is NSTEMI.';
          break;
        case 'overnightEvents':
          sampleText = 'Patient remained hemodynamically stable overnight. Received morning medications as scheduled. No acute events or concerns.';
          break;
        case 'pendingTasks':
          sampleText = 'Cardiology consult pending for this afternoon. Repeat troponins due at 0800. Discharge planning to be initiated.';
          break;
        case 'keyIssues':
          sampleText = 'Patient is anxious about cardiac catheterization. Family meeting requested with cardiologist. Monitor for chest pain recurrence.';
          break;
      }

      controller.text = sampleText;
      setState(() => _isRecording[fieldKey] = false);
      HapticFeedback.lightImpact();
    });
  }

  Future<void> _shareReport() async {
    if (_handoffReport.isEmpty) return;

    final shareText = '''
SHIFT HANDOFF REPORT
Generated: ${DateFormat('MMM d, y • h:mm a').format(DateTime.now())}
Patient: ${hasPatient ? getPatientDisplayName() : 'No patient selected'}

$_handoffReport

---
Generated with DocPilot AI Assistant
''';

    try {
      await Clipboard.setData(ClipboardData(text: shareText));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Report copied to clipboard - you can now paste it in any app'),
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      AppErrorHandler.showSnackBar(context, e);
    }
  }

  Future<void> _generateHandoffReport() async {
    setState(() => _isGenerating = true);

    try {
      final handoffSections = {
        'patientSummary': _patientSummaryController.text,
        'overnightEvents': _overnightEventsController.text,
        'pendingTasks': _pendingTasksController.text,
        'keyIssues': _keyIssuesController.text,
      };

      final prompt = AIPromptBuilder.buildHandoffPrompt(
        sections: handoffSections,
        patient: patient,
      );

      final result = await _chatbotService.getGeminiResponse(prompt);

      if (!mounted) return;
      setState(() {
        _handoffReport = result;
        _isGenerating = false;
      });
      HapticFeedback.mediumImpact();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isGenerating = false);
      AppErrorHandler.showSnackBar(context, e);
    }
  }

  void _clearAll() {
    setState(() {
      _patientSummaryController.clear();
      _overnightEventsController.clear();
      _pendingTasksController.clear();
      _keyIssuesController.clear();
      _handoffReport = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header Info Card
                  SlideUpAnimation(
                    child: _buildHeaderCard(),
                  ),

                  const SizedBox(height: AppTheme.lg),

                  // Previous Handoffs History (if available)
                  if (_previousHandoffs.isNotEmpty) ...[
                    SlideUpAnimation(
                      delay: const Duration(milliseconds: 50),
                      child: _buildHistoryCard(),
                    ),
                    const SizedBox(height: AppTheme.lg),
                  ],

                  // Form Sections
                  SlideUpAnimation(
                    delay: const Duration(milliseconds: 100),
                    child: _buildFormSection(),
                  ),

                  const SizedBox(height: AppTheme.lg),

                  // Critical Handoff Checklist
                  SlideUpAnimation(
                    delay: const Duration(milliseconds: 150),
                    child: _buildHandoffChecklist(),
                  ),

                  const SizedBox(height: AppTheme.xl),

                  // Generate Button
                  ScaleAnimation(
                    delay: const Duration(milliseconds: 200),
                    child: _buildGenerateButton(),
                  ),

                  // Generated Report
                  if (_handoffReport.isNotEmpty) ...[
                    const SizedBox(height: AppTheme.xl),
                    FadeInAnimation(
                      child: _buildReportCard(),
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
      backgroundColor: Colors.teal.shade300,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          color: Colors.teal.shade300,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppTheme.lg, 0, AppTheme.lg, AppTheme.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                            width: 0.5,
                          ),
                        ),
                        child: const Icon(
                          CupertinoIcons.arrow_swap,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: AppTheme.md),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Shift Handoff',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              'I-PASS Communication Framework',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
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
        CupertinoButton(
          padding: const EdgeInsets.all(12),
          child: const Icon(
            CupertinoIcons.refresh_circled,
            color: Colors.white,
            size: 24,
          ),
          onPressed: _clearAll,
        ),
      ],
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: CupertinoColors.systemTeal.withValues(alpha: 0.2),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: CupertinoColors.systemTeal.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  CupertinoIcons.clock,
                  color: CupertinoColors.systemTeal,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('EEEE, MMMM d, yyyy').format(DateTime.now()),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1D1D1F),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Shift Time: ${DateFormat('h:mm a').format(DateTime.now())}',
                      style: TextStyle(
                        fontSize: 14,
                        color: CupertinoColors.systemGrey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (hasPatient) ...[
            const SizedBox(height: 20),
            Container(
              height: 0.5,
              color: CupertinoColors.systemGrey4,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF30D5C8),
                        Color(0xFF0891B2),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      getPatientDisplayName().substring(0, 1).toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppTheme.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        getPatientDisplayName(),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1D1D1F),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        getPatientInfo(),
                        style: TextStyle(
                          fontSize: 14,
                          color: CupertinoColors.systemGrey,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: CupertinoColors.systemGreen.withValues(alpha: 0.2),
                      width: 0.5,
                    ),
                  ),
                  child: const Text(
                    'Active',
                    style: TextStyle(
                      color: Color(0xFF34C759),
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFormSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: CupertinoColors.systemGrey5,
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
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
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: CupertinoColors.systemBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  CupertinoIcons.doc_text,
                  color: CupertinoColors.systemBlue,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppTheme.md),
              Expanded(
                child: Text(
                  'I-PASS Handoff Information',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1D1D1F),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Patient Summary (Illness Severity)
          _buildFormField(
            label: 'Patient Summary',
            subtitle: 'Illness severity & current condition',
            icon: CupertinoIcons.person_circle,
            iconColor: CupertinoColors.systemBlue,
            controller: _patientSummaryController,
            hint: 'Chief complaint, diagnosis, current condition...',
            fieldKey: 'patientSummary',
            maxLines: 3,
          ),
          const SizedBox(height: 20),

          // Overnight Events (Patient Summary)
          _buildFormField(
            label: 'Overnight Events',
            subtitle: 'What happened during the shift',
            icon: CupertinoIcons.moon_stars,
            iconColor: CupertinoColors.systemPurple,
            controller: _overnightEventsController,
            hint: 'Vital changes, procedures, medications given...',
            fieldKey: 'overnightEvents',
            maxLines: 3,
          ),
          const SizedBox(height: 20),

          // Pending Tasks (Action List)
          _buildFormField(
            label: 'Pending Tasks',
            subtitle: 'Action items for incoming team',
            icon: CupertinoIcons.checkmark_circle,
            iconColor: CupertinoColors.systemOrange,
            controller: _pendingTasksController,
            hint: 'Labs pending, imaging needed, consults requested...',
            fieldKey: 'pendingTasks',
            maxLines: 3,
          ),
          const SizedBox(height: 20),

          // Key Issues (Situation Awareness)
          _buildFormField(
            label: 'Key Issues & Concerns',
            subtitle: 'Situational awareness points',
            icon: CupertinoIcons.exclamationmark_triangle,
            iconColor: CupertinoColors.systemRed,
            controller: _keyIssuesController,
            hint: 'Safety concerns, family updates needed, critical items...',
            fieldKey: 'keyIssues',
            maxLines: 3,
          ),
        ],
      ),
    );
  }

  Widget _buildFormField({
    required String label,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required TextEditingController controller,
    required String hint,
    required String fieldKey,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 16, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1D1D1F),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: CupertinoColors.systemGrey,
                    ),
                  ),
                ],
              ),
            ),
            // Voice Input Button
            Container(
              decoration: BoxDecoration(
                color: _isRecording[fieldKey] == true
                  ? CupertinoColors.systemRed.withValues(alpha: 0.1)
                  : CupertinoColors.systemBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: CupertinoButton(
                padding: const EdgeInsets.all(8),
                minSize: 0,
                onPressed: _isRecording[fieldKey] == true
                  ? null
                  : () => _simulateVoiceInput(fieldKey, controller),
                child: Icon(
                  _isRecording[fieldKey] == true
                    ? CupertinoIcons.stop_circle_fill
                    : CupertinoIcons.mic_circle,
                  color: _isRecording[fieldKey] == true
                    ? CupertinoColors.systemRed
                    : CupertinoColors.systemBlue,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        CupertinoTextField(
          controller: controller,
          maxLines: maxLines,
          placeholder: hint,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: CupertinoColors.systemGrey6,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: CupertinoColors.systemGrey4,
              width: 0.5,
            ),
          ),
          style: const TextStyle(
            fontSize: 15,
            color: Color(0xFF1D1D1F),
          ),
          placeholderStyle: TextStyle(
            color: CupertinoColors.systemGrey.withValues(alpha: 0.6),
            fontSize: 15,
          ),
        ),
      ],
    );
  }

  Widget _buildGenerateButton() {
    return Container(
      height: 54,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: _isGenerating
            ? null
            : const LinearGradient(
                colors: [
                  Color(0xFF30D5C8), // iOS Teal
                  Color(0xFF0891B2), // iOS Cyan
                ],
              ),
        color: _isGenerating ? CupertinoColors.systemGrey4 : null,
        boxShadow: _isGenerating
            ? null
            : [
                BoxShadow(
                  color: const Color(0xFF30D5C8).withValues(alpha: 0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: _isGenerating ? null : _generateHandoffReport,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isGenerating) ...[
              const CupertinoActivityIndicator(
                color: Colors.white,
              ),
              const SizedBox(width: AppTheme.md),
              const Text(
                'Generating Report...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ] else ...[
              const Icon(
                CupertinoIcons.doc_text_fill,
                color: Colors.white,
                size: 22,
              ),
              const SizedBox(width: AppTheme.md),
              const Text(
                'Generate Handoff Report',
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
    );
  }

  Widget _buildReportCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: CupertinoColors.systemTeal.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.systemTeal.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  CupertinoColors.systemTeal.withValues(alpha: 0.08),
                  CupertinoColors.systemTeal.withValues(alpha: 0.03),
                ],
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemTeal.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    CupertinoIcons.checkmark_circle_fill,
                    color: CupertinoColors.systemTeal,
                    size: 24,
                  ),
                ),
                const SizedBox(width: AppTheme.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Handoff Report Ready',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: CupertinoColors.systemTeal,
                        ),
                      ),
                      Text(
                        'Generated using I-PASS framework',
                        style: TextStyle(
                          fontSize: 14,
                          color: CupertinoColors.systemGrey,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    CupertinoButton(
                      padding: const EdgeInsets.all(8),
                      minSize: 0,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: CupertinoColors.systemGrey5,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          CupertinoIcons.doc_on_clipboard,
                          color: CupertinoColors.systemGrey,
                          size: 18,
                        ),
                      ),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _handoffReport));
                        HapticFeedback.lightImpact();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Report copied to clipboard'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    CupertinoButton(
                      padding: const EdgeInsets.all(8),
                      minSize: 0,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: CupertinoColors.systemGrey5,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          CupertinoIcons.share,
                          color: CupertinoColors.systemGrey,
                          size: 18,
                        ),
                      ),
                      onPressed: _shareReport,
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(20),
            child: SelectableText(
              _handoffReport,
              style: const TextStyle(
                fontSize: 15,
                height: 1.6,
                color: Color(0xFF1D1D1F),
              ),
            ),
          ),
          // Footer with Save Button
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: CupertinoColors.systemGrey6,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Icon(
                  CupertinoIcons.clock,
                  size: 16,
                  color: CupertinoColors.systemGrey,
                ),
                const SizedBox(width: 8),
                Text(
                  DateFormat('MMM d, y • h:mm a').format(DateTime.now()),
                  style: TextStyle(
                    fontSize: 13,
                    color: CupertinoColors.systemGrey,
                  ),
                ),
                const SizedBox(width: AppTheme.sm),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemTeal.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: CupertinoColors.systemTeal.withValues(alpha: 0.2),
                      width: 0.5,
                    ),
                  ),
                  child: const Text(
                    'AI Generated',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF30D5C8),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const Spacer(),
                Container(
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        CupertinoColors.systemTeal,
                        CupertinoColors.systemTeal.darkColor,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    minSize: 0,
                    onPressed: _isSaving ? null : _saveHandoffToNotes,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_isSaving)
                          const CupertinoActivityIndicator(
                            color: Colors.white,
                          )
                        else
                          const Icon(
                            CupertinoIcons.floppy_disk,
                            color: Colors.white,
                            size: 16,
                          ),
                        const SizedBox(width: 6),
                        Text(
                          _isSaving ? 'Saving...' : 'Save to Notes',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: CupertinoColors.systemGrey5,
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
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
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: CupertinoColors.systemIndigo.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  CupertinoIcons.clock_fill,
                  color: CupertinoColors.systemIndigo,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppTheme.md),
              const Text(
                'Recent Handoffs',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1D1D1F),
                ),
              ),
              const Spacer(),
              if (_isLoadingHistory)
                const CupertinoActivityIndicator()
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemIndigo.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: CupertinoColors.systemIndigo.withValues(alpha: 0.2),
                      width: 0.5,
                    ),
                  ),
                  child: Text(
                    '${_previousHandoffs.length}',
                    style: TextStyle(
                      color: CupertinoColors.systemIndigo,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Show Recent Handoffs (Last 3)
          ...List.generate(_previousHandoffs.take(3).length, (index) {
            final handoff = _previousHandoffs[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: CupertinoColors.systemGrey6,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: CupertinoColors.systemGrey4.withValues(alpha: 0.7),
                  width: 0.5,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemTeal.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      CupertinoIcons.arrow_swap,
                      color: CupertinoColors.systemTeal,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          handoff.title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF1D1D1F),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatHistoryDate(handoff.createdAt),
                          style: TextStyle(
                            fontSize: 13,
                            color: CupertinoColors.systemGrey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    CupertinoIcons.chevron_right,
                    color: CupertinoColors.systemGrey2,
                    size: 16,
                  ),
                ],
              ),
            );
          }),

          if (_previousHandoffs.length > 3)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                '+ ${_previousHandoffs.length - 3} more handoffs in Clinical Notes',
                style: TextStyle(
                  fontSize: 13,
                  color: CupertinoColors.systemGrey,
                  fontStyle: FontStyle.italic,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }

  String _formatHistoryDate(DateTime date) {
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

  Widget _buildHandoffChecklist() {
    final completedItems = _handoffChecklist.values.where((completed) => completed).length;
    final totalItems = _handoffChecklist.length;
    final completionPercentage = (completedItems / totalItems * 100).round();

    return Container(
      padding: const EdgeInsets.all(AppTheme.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.successColor.withValues(alpha: 0.05),
            AppTheme.successColor.withValues(alpha: 0.02),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.successColor.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header section
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.successColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.checklist_rtl,
                  color: AppTheme.successColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Critical Handoff Checklist',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$completedItems of $totalItems items completed ($completionPercentage%)',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: AppTheme.md),

          // Progress indicator
          Container(
            height: 6,
            decoration: BoxDecoration(
              color: AppTheme.dividerColor,
              borderRadius: BorderRadius.circular(3),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: completedItems / totalItems,
              child: Container(
                decoration: BoxDecoration(
                  color: completionPercentage == 100
                      ? AppTheme.successColor
                      : AppTheme.warningColor,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),

          const SizedBox(height: AppTheme.lg),

          // Checklist items
          ...List.generate(_handoffChecklist.keys.length, (index) {
            final item = _handoffChecklist.keys.elementAt(index);
            final isCompleted = _handoffChecklist[item] ?? false;

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _handoffChecklist[item] = !isCompleted;
                      });
                      HapticFeedback.lightImpact();
                    },
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: isCompleted
                            ? AppTheme.successColor
                            : Colors.transparent,
                        border: Border.all(
                          color: isCompleted
                              ? AppTheme.successColor
                              : AppTheme.dividerColor,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: isCompleted
                          ? const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 16,
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: isCompleted
                            ? AppTheme.textSecondary
                            : AppTheme.textPrimary,
                        decoration: isCompleted
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),

          const SizedBox(height: AppTheme.md),

          // Completion status
          if (completionPercentage == 100)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.successColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppTheme.successColor.withValues(alpha: 0.3),
                ),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    color: AppTheme.successColor,
                    size: 16,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'All critical items verified - Ready for safe handoff',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.successColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.warningColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppTheme.warningColor.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber,
                    color: AppTheme.warningColor,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${totalItems - completedItems} critical items remaining',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.warningColor,
                        fontWeight: FontWeight.w600,
                      ),
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
