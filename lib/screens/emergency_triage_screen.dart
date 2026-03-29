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

class EmergencyTriageScreen extends StatefulWidget {
  final String? patientId;

  const EmergencyTriageScreen({
    super.key,
    this.patientId,
  });

  @override
  State<EmergencyTriageScreen> createState() => _EmergencyTriageScreenState();
}

class _EmergencyTriageScreenState extends State<EmergencyTriageScreen>
    with SingleTickerProviderStateMixin {
  final ChatbotService _chatbotService = ChatbotService();
  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();

  final TextEditingController _chiefComplaintController = TextEditingController();
  final TextEditingController _symptomsController = TextEditingController();

  // Structured Vital Signs Controllers
  final TextEditingController _bpSystolicController = TextEditingController();
  final TextEditingController _bpDiastolicController = TextEditingController();
  final TextEditingController _heartRateController = TextEditingController();
  final TextEditingController _respRateController = TextEditingController();
  final TextEditingController _tempController = TextEditingController();
  final TextEditingController _o2SatController = TextEditingController();

  late AnimationController _pulseController;

  bool _isAssessing = false;
  bool _isSaving = false;
  String _triageAssessment = '';
  String _priorityLevel = '';
  int _esiLevel = 0; // Emergency Severity Index (1-5)
  Color _priorityColor = AppTheme.primaryColor;
  IconData _priorityIcon = Icons.info;

  ProviderPatientRecord? _currentPatient;
  bool _isLoadingPatient = true;

  int _painLevel = 0;

  // Quick complaint templates for common emergencies
  final List<Map<String, dynamic>> _quickComplaintTemplates = [
    {
      'name': 'Chest Pain',
      'icon': Icons.favorite,
      'color': Color(0xFFDC2626),
      'complaint': 'Chest pain',
      'symptoms': 'Onset, location, radiation, quality (crushing/sharp), associated symptoms (shortness of breath, diaphoresis, nausea)',
    },
    {
      'name': 'SOB',
      'icon': Icons.air,
      'color': Color(0xFF2563EB),
      'complaint': 'Shortness of breath',
      'symptoms': 'Onset, severity, associated cough, wheezing, orthopnea, PND, leg swelling',
    },
    {
      'name': 'Stroke',
      'icon': Icons.psychology,
      'color': Color(0xFF7C3AED),
      'complaint': 'Suspected stroke - FAST positive',
      'symptoms': 'Facial droop, arm weakness, speech difficulty, time of onset',
    },
    {
      'name': 'Abdominal',
      'icon': Icons.sick,
      'color': Color(0xFFF59E0B),
      'complaint': 'Abdominal pain',
      'symptoms': 'Location, onset, character, radiation, associated nausea/vomiting, fever, bowel changes',
    },
    {
      'name': 'Trauma',
      'icon': Icons.personal_injury,
      'color': Color(0xFFEF4444),
      'complaint': 'Trauma / Injury',
      'symptoms': 'Mechanism of injury, location, deformity, neurovascular status, bleeding',
    },
    {
      'name': 'Altered Mental',
      'icon': Icons.psychology_alt,
      'color': Color(0xFF8B5CF6),
      'complaint': 'Altered mental status',
      'symptoms': 'Baseline mental status, onset, fluctuation, associated symptoms, medication/drug use',
    },
    {
      'name': 'Fever',
      'icon': Icons.thermostat,
      'color': Color(0xFFEA580C),
      'complaint': 'Fever / Infection',
      'symptoms': 'Duration, max temperature, source symptoms (cough, dysuria, wound), immunocompromised status',
    },
    {
      'name': 'Syncope',
      'icon': Icons.airline_seat_flat,
      'color': Color(0xFF0891B2),
      'complaint': 'Syncope / Near-syncope',
      'symptoms': 'Prodrome, witnesses, duration of LOC, post-event confusion, cardiac history',
    },
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _loadPatientData();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _chiefComplaintController.dispose();
    _symptomsController.dispose();
    _bpSystolicController.dispose();
    _bpDiastolicController.dispose();
    _heartRateController.dispose();
    _respRateController.dispose();
    _tempController.dispose();
    _o2SatController.dispose();
    super.dispose();
  }

  Future<void> _loadPatientData() async {
    if (widget.patientId == null || widget.patientId == 'no-patient') {
      setState(() => _isLoadingPatient = false);
      return;
    }

    try {
      // Get doctor's patients and find the specific one
      final doctorId = _authService.currentUser?.uid;
      if (doctorId == null) {
        setState(() => _isLoadingPatient = false);
        return;
      }

      final patients = await _firestoreService.getDoctorPatients(doctorId);
      ProviderPatientRecord? patient;
      try {
        patient = patients.firstWhere((p) => p.id == widget.patientId);
      } catch (_) {
        patient = patients.isNotEmpty ? patients.first : null;
      }
      if (mounted && patient != null) {
        setState(() {
          _currentPatient = patient;
          _isLoadingPatient = false;
        });
      } else {
        setState(() => _isLoadingPatient = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingPatient = false);
        AppErrorHandler.showSnackBar(context, e);
      }
    }
  }

  String _buildVitalSignsString() {
    final parts = <String>[];
    if (_bpSystolicController.text.isNotEmpty && _bpDiastolicController.text.isNotEmpty) {
      parts.add('BP: ${_bpSystolicController.text}/${_bpDiastolicController.text} mmHg');
    }
    if (_heartRateController.text.isNotEmpty) {
      parts.add('HR: ${_heartRateController.text} bpm');
    }
    if (_respRateController.text.isNotEmpty) {
      parts.add('RR: ${_respRateController.text}/min');
    }
    if (_tempController.text.isNotEmpty) {
      parts.add('Temp: ${_tempController.text}°F');
    }
    if (_o2SatController.text.isNotEmpty) {
      parts.add('SpO2: ${_o2SatController.text}%');
    }
    return parts.isEmpty ? 'Not provided' : parts.join(', ');
  }

  Future<void> _performTriageAssessment() async {
    if (_chiefComplaintController.text.trim().isEmpty) {
      AppErrorHandler.showSnackBar(
        context,
        'Please enter the chief complaint to proceed with triage assessment.',
      );
      return;
    }

    setState(() => _isAssessing = true);

    try {
      final vitalSigns = _buildVitalSignsString();
      final prompt = '''
As an experienced emergency medicine physician, perform a triage assessment using the Emergency Severity Index (ESI) 5-level system:

ESI Level Guide:
- ESI-1: Immediate life-threatening (requires immediate intervention)
- ESI-2: Emergent (high risk, confused/lethargic, severe pain)
- ESI-3: Urgent (needs multiple resources, stable)
- ESI-4: Less Urgent (needs one resource)
- ESI-5: Non-urgent (no resources needed)

**Chief Complaint:** ${_chiefComplaintController.text.trim()}
**Vital Signs:** $vitalSigns
**Symptoms:** ${_symptomsController.text.trim().isEmpty ? 'Not provided' : _symptomsController.text.trim()}
**Pain Level (0-10):** $_painLevel

${_currentPatient != null ? '''
**Patient Information:**
- Name: ${_currentPatient!.fullName}
- Age: ${_currentPatient!.age}
- Medical History: ${_currentPatient!.medicalHistory.isEmpty ? 'None documented' : _currentPatient!.medicalHistory.join(', ')}
- Allergies: ${_currentPatient!.allergies.isEmpty ? 'None known' : _currentPatient!.allergies.join(', ')}
''' : ''}

Please provide a structured assessment:

## ESI LEVEL
State the ESI level (1-5) with clear justification

## TRIAGE PRIORITY
(CRITICAL/HIGH/MEDIUM/LOW) based on ESI level

## IMMEDIATE ACTIONS
Steps to take within the first 15 minutes

## CLINICAL ASSESSMENT
Key observations and differential diagnoses to consider

## RECOMMENDED WORKUP
Diagnostic tests and procedures needed

## RED FLAGS
Warning signs requiring immediate escalation

## DISPOSITION RECOMMENDATION
Suggested next steps (admit, observe, discharge with follow-up)
''';

      final response = await _chatbotService.getGeminiResponse(prompt);

      if (mounted) {
        setState(() {
          _triageAssessment = response;
          _determinePriorityFromResponse(response);
          _isAssessing = false;
        });
        HapticFeedback.mediumImpact();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isAssessing = false);
        AppErrorHandler.showSnackBar(context, e);
      }
    }
  }

  void _determinePriorityFromResponse(String response) {
    final lowercaseResponse = response.toLowerCase();

    // Extract ESI Level
    final esiMatch = RegExp(r'esi[- ]?(\d)').firstMatch(lowercaseResponse);
    if (esiMatch != null) {
      _esiLevel = int.tryParse(esiMatch.group(1) ?? '') ?? 0;
    }

    if (lowercaseResponse.contains('critical') || lowercaseResponse.contains('emergent') || _esiLevel == 1) {
      _priorityLevel = 'CRITICAL';
      _priorityColor = AppTheme.dangerColor;
      _priorityIcon = Icons.warning_rounded;
      if (_esiLevel == 0) _esiLevel = 1;
    } else if (lowercaseResponse.contains('high') || lowercaseResponse.contains('urgent') || _esiLevel == 2) {
      _priorityLevel = 'HIGH';
      _priorityColor = AppTheme.warningColor;
      _priorityIcon = Icons.priority_high_rounded;
      if (_esiLevel == 0) _esiLevel = 2;
    } else if (lowercaseResponse.contains('medium') || lowercaseResponse.contains('moderate') || _esiLevel == 3) {
      _priorityLevel = 'MEDIUM';
      _priorityColor = AppTheme.primaryColor;
      _priorityIcon = Icons.info_rounded;
      if (_esiLevel == 0) _esiLevel = 3;
    } else {
      _priorityLevel = 'LOW';
      _priorityColor = AppTheme.successColor;
      _priorityIcon = Icons.check_circle_rounded;
      if (_esiLevel == 0) _esiLevel = 4;
    }
  }

  Future<void> _saveTriageToClinicalNotes() async {
    if (_triageAssessment.isEmpty) return;

    final patientId = _currentPatient?.id ?? widget.patientId;
    if (patientId == null || patientId == 'no-patient') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select a patient to save the triage assessment'),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final note = ClinicalNote(
        patientId: patientId,
        title: 'Emergency Triage - $_priorityLevel (ESI-$_esiLevel)',
        content: '''Chief Complaint: ${_chiefComplaintController.text.trim()}

Vital Signs: ${_buildVitalSignsString()}
Pain Level: $_painLevel/10
Symptoms: ${_symptomsController.text.trim().isEmpty ? 'Not provided' : _symptomsController.text.trim()}

--- AI TRIAGE ASSESSMENT ---.

$_triageAssessment''',
        diagnosis: 'Emergency Triage - $_priorityLevel Priority',
        treatments: [],
        followUpItems: ['Monitor vitals', 'Reassess as needed'],
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
                Text('Triage saved to clinical notes'),
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

  void _clearAssessment() {
    setState(() {
      _triageAssessment = '';
      _priorityLevel = '';
      _esiLevel = 0;
      _priorityColor = AppTheme.primaryColor;
      _chiefComplaintController.clear();
      _symptomsController.clear();
      _bpSystolicController.clear();
      _bpDiastolicController.clear();
      _heartRateController.clear();
      _respRateController.clear();
      _tempController.clear();
      _o2SatController.clear();
      _painLevel = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: _isLoadingPatient
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                // Professional Gradient App Bar
                _buildSliverAppBar(),

                // Content
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(AppTheme.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Patient Info Card (if available)
                        if (_currentPatient != null) ...[
                          SlideUpAnimation(
                            child: _buildPatientInfoCard(),
                          ),
                          const SizedBox(height: AppTheme.lg),
                        ],

                        // Quick Complaint Templates
                        SlideUpAnimation(
                          delay: const Duration(milliseconds: 50),
                          child: _buildQuickComplaintTemplates(),
                        ),
                        const SizedBox(height: AppTheme.lg),

                        // Priority Badge (if assessment done)
                        if (_priorityLevel.isNotEmpty) ...[
                          FadeInAnimation(
                            child: _buildPriorityBadge(),
                          ),
                          const SizedBox(height: AppTheme.lg),
                        ],

                        // Assessment Input Form
                        SlideUpAnimation(
                          delay: const Duration(milliseconds: 100),
                          child: _buildAssessmentForm(),
                        ),

                        const SizedBox(height: AppTheme.lg),

                        // Pain Level Slider
                        SlideUpAnimation(
                          delay: const Duration(milliseconds: 200),
                          child: _buildPainLevelCard(),
                        ),

                        const SizedBox(height: AppTheme.xl),

                        // Action Button
                        ScaleAnimation(
                          delay: const Duration(milliseconds: 300),
                          child: _buildAssessButton(),
                        ),

                        // Assessment Results
                        if (_triageAssessment.isNotEmpty) ...[
                          const SizedBox(height: AppTheme.xl),
                          FadeInAnimation(
                            delay: const Duration(milliseconds: 400),
                            child: _buildAssessmentResults(),
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
      backgroundColor: Colors.red.shade300,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          color: Colors.red.shade300,
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
                          Icons.emergency,
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
                              'Emergency Triage',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'AI-Powered Priority Assessment',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
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
        if (_triageAssessment.isNotEmpty)
          IconButton(
            onPressed: _clearAssessment,
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'New Assessment',
          ),
      ],
    );
  }

  Widget _buildPatientInfoCard() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.md),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: AppTheme.mediumRadius,
        border: Border.all(color: AppTheme.dividerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
            radius: 24,
            child: Text(
              _currentPatient!.fullName.substring(0, 1).toUpperCase(),
              style: TextStyle(
                color: AppTheme.primaryColor,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(width: AppTheme.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _currentPatient!.fullName,
                  style: AppTheme.labelLarge.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  'Age: ${_currentPatient!.age}',
                  style: AppTheme.bodySmall,
                ),
                if (_currentPatient!.medicalHistory.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Wrap(
                      spacing: 4,
                      children: _currentPatient!.medicalHistory.take(3).map((h) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.warningColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            h,
                            style: TextStyle(
                              fontSize: 10,
                              color: AppTheme.warningColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.dangerColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.emergency_outlined,
              color: AppTheme.dangerColor,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickComplaintTemplates() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.flash_on, size: 16, color: AppTheme.warningColor),
            const SizedBox(width: 6),
            Text(
              'Quick Complaint Templates',
              style: AppTheme.labelMedium.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.sm),
        SizedBox(
          height: 80,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _quickComplaintTemplates.length,
            separatorBuilder: (_, __) => const SizedBox(width: AppTheme.sm),
            itemBuilder: (context, index) {
              final template = _quickComplaintTemplates[index];
              final color = template['color'] as Color;
              return GestureDetector(
                onTap: () => _applyQuickTemplate(template),
                child: Container(
                  width: 85,
                  padding: const EdgeInsets.all(AppTheme.sm),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.08),
                    borderRadius: AppTheme.mediumRadius,
                    border: Border.all(color: color.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          template['icon'] as IconData,
                          color: color,
                          size: 20,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        template['name'] as String,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _applyQuickTemplate(Map<String, dynamic> template) {
    setState(() {
      _chiefComplaintController.text = template['complaint'] as String;
      _symptomsController.text = template['symptoms'] as String;
    });
    HapticFeedback.selectionClick();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Applied ${template['name']} template'),
        duration: const Duration(seconds: 1),
        backgroundColor: template['color'] as Color,
      ),
    );
  }

  Widget _buildPriorityBadge() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final scale = _priorityLevel == 'CRITICAL'
            ? 1.0 + (_pulseController.value * 0.02)
            : 1.0;
        return Transform.scale(
          scale: scale,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.lg,
              vertical: AppTheme.md,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _priorityColor.withValues(alpha: 0.15),
                  _priorityColor.withValues(alpha: 0.08),
                ],
              ),
              borderRadius: AppTheme.mediumRadius,
              border: Border.all(color: _priorityColor.withValues(alpha: 0.4), width: 2),
              boxShadow: [
                BoxShadow(
                  color: _priorityColor.withValues(alpha: 0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(_priorityIcon, color: _priorityColor, size: 28),
                const SizedBox(width: AppTheme.md),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TRIAGE PRIORITY',
                      style: TextStyle(
                        color: _priorityColor.withValues(alpha: 0.7),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                      ),
                    ),
                    Text(
                      _priorityLevel,
                      style: TextStyle(
                        color: _priorityColor,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
                if (_esiLevel > 0) ...[
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: _priorityColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _priorityColor.withValues(alpha: 0.4)),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'ESI',
                          style: TextStyle(
                            color: _priorityColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '$_esiLevel',
                          style: TextStyle(
                            color: _priorityColor,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAssessmentForm() {
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
                  color: AppTheme.dangerColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.assignment, color: AppTheme.dangerColor, size: 20),
              ),
              const SizedBox(width: AppTheme.md),
              Text('Patient Assessment', style: AppTheme.headingSmall),
            ],
          ),
          const SizedBox(height: AppTheme.lg),

          // Chief Complaint
          _buildFormField(
            label: 'Chief Complaint',
            required: true,
            icon: Icons.report_problem_outlined,
            controller: _chiefComplaintController,
            hint: 'Primary reason for emergency visit',
            maxLines: 2,
          ),
          const SizedBox(height: AppTheme.lg),

          // Structured Vital Signs
          _buildVitalSignsSection(),
          const SizedBox(height: AppTheme.md),

          // Symptoms
          _buildFormField(
            label: 'Current Symptoms',
            icon: Icons.medical_information_outlined,
            controller: _symptomsController,
            hint: 'Describe symptoms, duration, and severity',
            maxLines: 2,
          ),
        ],
      ),
    );
  }

  Widget _buildVitalSignsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.monitor_heart_outlined, size: 16, color: AppTheme.textSecondary),
            const SizedBox(width: 6),
            Text(
              'Vital Signs',
              style: AppTheme.labelMedium.copyWith(fontWeight: FontWeight.w500),
            ),
            const Spacer(),
            // Vital Signs Legend
            _buildVitalLegend(),
          ],
        ),
        const SizedBox(height: AppTheme.sm),

        // Blood Pressure Row
        Row(
          children: [
            Expanded(
              child: _buildVitalTextField(
                controller: _bpSystolicController,
                hint: 'Systolic',
                suffix: 'mmHg',
                normalMin: 90,
                normalMax: 140,
                criticalMin: 70,
                criticalMax: 180,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text('/', style: AppTheme.headingSmall),
            ),
            Expanded(
              child: _buildVitalTextField(
                controller: _bpDiastolicController,
                hint: 'Diastolic',
                normalMin: 60,
                normalMax: 90,
                criticalMin: 40,
                criticalMax: 110,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.sm),

        // Heart Rate, Resp Rate Row
        Row(
          children: [
            Expanded(
              child: _buildVitalTextField(
                controller: _heartRateController,
                hint: 'Heart Rate',
                suffix: 'bpm',
                normalMin: 60,
                normalMax: 100,
                criticalMin: 40,
                criticalMax: 150,
              ),
            ),
            const SizedBox(width: AppTheme.sm),
            Expanded(
              child: _buildVitalTextField(
                controller: _respRateController,
                hint: 'Resp Rate',
                suffix: '/min',
                normalMin: 12,
                normalMax: 20,
                criticalMin: 8,
                criticalMax: 30,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.sm),

        // Temp, O2 Sat Row
        Row(
          children: [
            Expanded(
              child: _buildVitalTextField(
                controller: _tempController,
                hint: 'Temp',
                suffix: '°F',
                normalMin: 97.0,
                normalMax: 99.5,
                criticalMin: 95.0,
                criticalMax: 104.0,
                isDecimal: true,
              ),
            ),
            const SizedBox(width: AppTheme.sm),
            Expanded(
              child: _buildVitalTextField(
                controller: _o2SatController,
                hint: 'SpO2',
                suffix: '%',
                normalMin: 95,
                normalMax: 100,
                criticalMin: 88,
                criticalMax: 100,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildVitalLegend() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: AppTheme.successColor,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text('Normal', style: TextStyle(fontSize: 9, color: AppTheme.textSecondary)),
        const SizedBox(width: 8),
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: AppTheme.warningColor,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text('Abnormal', style: TextStyle(fontSize: 9, color: AppTheme.textSecondary)),
        const SizedBox(width: 8),
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: AppTheme.dangerColor,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text('Critical', style: TextStyle(fontSize: 9, color: AppTheme.textSecondary)),
      ],
    );
  }

  Widget _buildVitalTextField({
    required TextEditingController controller,
    required String hint,
    String? suffix,
    required double normalMin,
    required double normalMax,
    required double criticalMin,
    required double criticalMax,
    bool isDecimal = false,
  }) {
    return StatefulBuilder(
      builder: (context, setLocalState) {
        Color getBorderColor() {
          final text = controller.text.trim();
          if (text.isEmpty) return AppTheme.dividerColor;

          final value = double.tryParse(text);
          if (value == null) return AppTheme.dividerColor;

          if (value < criticalMin || value > criticalMax) {
            return AppTheme.dangerColor;
          } else if (value < normalMin || value > normalMax) {
            return AppTheme.warningColor;
          }
          return AppTheme.successColor;
        }

        Color getIndicatorColor() {
          final text = controller.text.trim();
          if (text.isEmpty) return Colors.transparent;

          final value = double.tryParse(text);
          if (value == null) return Colors.transparent;

          if (value < criticalMin || value > criticalMax) {
            return AppTheme.dangerColor;
          } else if (value < normalMin || value > normalMax) {
            return AppTheme.warningColor;
          }
          return AppTheme.successColor;
        }

        final borderColor = getBorderColor();
        final indicatorColor = getIndicatorColor();

        return Stack(
          children: [
            TextField(
              controller: controller,
              keyboardType: isDecimal
                  ? const TextInputType.numberWithOptions(decimal: true)
                  : TextInputType.number,
              onChanged: (_) => setLocalState(() {}),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.6), fontSize: 13),
                suffixText: suffix,
                suffixStyle: AppTheme.bodySmall,
                filled: true,
                fillColor: AppTheme.backgroundColor,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: AppTheme.mediumRadius,
                  borderSide: BorderSide(color: borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: AppTheme.mediumRadius,
                  borderSide: BorderSide(color: borderColor, width: borderColor == AppTheme.dividerColor ? 1 : 2),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: AppTheme.mediumRadius,
                  borderSide: BorderSide(color: borderColor == AppTheme.dividerColor ? AppTheme.dangerColor : borderColor, width: 2),
                ),
              ),
            ),
            if (indicatorColor != Colors.transparent)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: indicatorColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildFormField({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    required String hint,
    bool required = false,
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
              style: AppTheme.labelMedium.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            if (required)
              Text(
                ' *',
                style: TextStyle(color: AppTheme.dangerColor, fontWeight: FontWeight.bold),
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
              borderSide: BorderSide(color: AppTheme.dangerColor, width: 1.5),
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

  Widget _buildPainLevelCard() {
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
                  color: _getPainColor().withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.sentiment_satisfied_alt, color: _getPainColor(), size: 20),
              ),
              const SizedBox(width: AppTheme.md),
              Text('Pain Level', style: AppTheme.headingSmall),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _getPainColor().withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$_painLevel / 10',
                  style: TextStyle(
                    color: _getPainColor(),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.lg),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: _getPainColor(),
              inactiveTrackColor: _getPainColor().withValues(alpha: 0.2),
              thumbColor: _getPainColor(),
              overlayColor: _getPainColor().withValues(alpha: 0.2),
              trackHeight: 8,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 14),
            ),
            child: Slider(
              value: _painLevel.toDouble(),
              min: 0,
              max: 10,
              divisions: 10,
              onChanged: (value) {
                setState(() {
                  _painLevel = value.toInt();
                });
                HapticFeedback.selectionClick();
              },
            ),
          ),
          const SizedBox(height: AppTheme.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('No Pain', style: AppTheme.bodySmall),
              Text(_getPainDescription(), style: AppTheme.labelMedium.copyWith(color: _getPainColor())),
              Text('Worst Pain', style: AppTheme.bodySmall),
            ],
          ),
        ],
      ),
    );
  }

  Color _getPainColor() {
    if (_painLevel <= 3) return AppTheme.successColor;
    if (_painLevel <= 6) return AppTheme.warningColor;
    return AppTheme.dangerColor;
  }

  String _getPainDescription() {
    if (_painLevel == 0) return 'None';
    if (_painLevel <= 3) return 'Mild';
    if (_painLevel <= 6) return 'Moderate';
    if (_painLevel <= 8) return 'Severe';
    return 'Extreme';
  }

  Widget _buildAssessButton() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: AppTheme.mediumRadius,
        gradient: _isAssessing
            ? null
            : const LinearGradient(
                colors: [Color(0xFFDC2626), Color(0xFFB91C1C)],
              ),
        boxShadow: _isAssessing
            ? null
            : [
                BoxShadow(
                  color: AppTheme.dangerColor.withValues(alpha: 0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isAssessing ? null : _performTriageAssessment,
          borderRadius: AppTheme.mediumRadius,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isAssessing) ...[
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
                    'Analyzing Patient...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ] else ...[
                  const Icon(Icons.medical_services, color: Colors.white, size: 24),
                  const SizedBox(width: AppTheme.md),
                  const Text(
                    'Perform Triage Assessment',
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

  Widget _buildAssessmentResults() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: AppTheme.largeRadius,
        border: Border.all(color: _priorityColor.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: _priorityColor.withValues(alpha: 0.1),
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
              color: _priorityColor.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Icon(Icons.medical_information, color: _priorityColor, size: 24),
                const SizedBox(width: AppTheme.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Triage Assessment Results',
                        style: AppTheme.headingSmall.copyWith(color: _priorityColor),
                      ),
                      Text(
                        DateFormat('MMM d, y • h:mm a').format(DateTime.now()),
                        style: AppTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy_outlined),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _triageAssessment));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Assessment copied to clipboard'),
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
              _triageAssessment,
              style: AppTheme.bodyMedium.copyWith(height: 1.6),
            ),
          ),
          // Footer with Save Button
          Container(
            padding: const EdgeInsets.all(AppTheme.md),
            decoration: BoxDecoration(
              color: AppTheme.backgroundColor,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: AppTheme.textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'AI-generated assessment. Clinical judgment required.',
                    style: AppTheme.bodySmall.copyWith(fontStyle: FontStyle.italic),
                  ),
                ),
                const SizedBox(width: AppTheme.md),
                TextButton.icon(
                  onPressed: _isSaving ? null : _saveTriageToClinicalNotes,
                  icon: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(Icons.save_outlined, color: AppTheme.successColor, size: 18),
                  label: Text(
                    _isSaving ? 'Saving...' : 'Save to Notes',
                    style: TextStyle(color: AppTheme.successColor),
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
