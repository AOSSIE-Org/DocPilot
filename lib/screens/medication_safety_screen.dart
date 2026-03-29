import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../core/base_patient_screen.dart';
import '../core/errors/app_error_handler.dart';
import '../models/health_models.dart';
import '../services/chatbot_service.dart';
import '../services/firebase/firestore_service.dart';
import '../theme/app_theme.dart';
import '../theme/app_animations.dart';

class MedicationSafetyScreen extends StatefulWidget {
  final String? patientId;

  const MedicationSafetyScreen({
    super.key,
    this.patientId,
  });

  @override
  State<MedicationSafetyScreen> createState() => _MedicationSafetyScreenState();
}

class _MedicationSafetyScreenState extends State<MedicationSafetyScreen>
    with BasePatientScreen<MedicationSafetyScreen> {
  final ChatbotService _chatbotService = ChatbotService();
  final FirestoreService _firestoreService = FirestoreService();

  final TextEditingController _medicationController = TextEditingController();
  final TextEditingController _doseController = TextEditingController();
  final FocusNode _medicationFocus = FocusNode();
  final List<String> _currentMedications = [];

  // Common medications for quick selection
  final List<String> _commonMedications = [
    'Aspirin',
    'Metformin',
    'Lisinopril',
    'Atorvastatin',
    'Amlodipine',
    'Metoprolol',
    'Omeprazole',
    'Simvastatin',
    'Hydrochlorothiazide',
    'Losartan',
    'Gabapentin',
    'Prednisone',
    'Albuterol',
    'Warfarin',
    'Clopidogrel',
    'Furosemide',
    'Tramadol',
    'Ibuprofen',
    'Acetaminophen',
    'Sertraline'
  ];

  bool _isAnalyzing = false;
  bool _isSaving = false;
  String _analysisResult = '';
  Map<String, String> _severityResults = {}; // Track severity levels for interactions

  // Dosage calculator state
  bool _showDosageCalculator = false;
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  String _selectedMedForDosage = '';
  String _calculatedDosage = '';

  // Common medication dosage data (mg per kg per dose)
  final Map<String, Map<String, dynamic>> _dosageData = {
    'Acetaminophen': {
      'pediatric': {'min': 10.0, 'max': 15.0, 'unit': 'mg/kg', 'frequency': 'q4-6h', 'maxDaily': 75.0},
      'adult': {'dose': '325-1000 mg', 'frequency': 'q4-6h', 'maxDaily': '4000 mg'},
    },
    'Ibuprofen': {
      'pediatric': {'min': 5.0, 'max': 10.0, 'unit': 'mg/kg', 'frequency': 'q6-8h', 'maxDaily': 40.0},
      'adult': {'dose': '400-800 mg', 'frequency': 'q6-8h', 'maxDaily': '2400 mg'},
    },
    'Amoxicillin': {
      'pediatric': {'min': 25.0, 'max': 50.0, 'unit': 'mg/kg', 'frequency': 'q8-12h', 'maxDaily': 100.0},
      'adult': {'dose': '500-875 mg', 'frequency': 'q8-12h', 'maxDaily': '2625 mg'},
    },
    'Prednisolone': {
      'pediatric': {'min': 1.0, 'max': 2.0, 'unit': 'mg/kg/day', 'frequency': 'daily-bid', 'maxDaily': 60.0},
      'adult': {'dose': '5-60 mg', 'frequency': 'daily', 'maxDaily': '80 mg'},
    },
    'Albuterol': {
      'pediatric': {'dose': '2.5 mg', 'frequency': 'q4-6h prn', 'route': 'nebulizer'},
      'adult': {'dose': '2.5-5 mg', 'frequency': 'q4-6h prn', 'route': 'nebulizer'},
    },
  };

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  @override
  void dispose() {
    _medicationController.dispose();
    _doseController.dispose();
    _medicationFocus.dispose();
    _weightController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  @override
  void onPatientLoaded(ProviderPatientRecord loadedPatient) {
    setState(() {
      _currentMedications.addAll(loadedPatient.prescriptions.take(5));
    });
  }

  Future<void> _initializeScreen() async {
    if (widget.patientId != null) {
      await loadPatientData(widget.patientId);
    }
  }

  void _addMedication() {
    final med = _medicationController.text.trim();
    final dose = _doseController.text.trim();

    if (med.isEmpty) {
      _medicationFocus.requestFocus();
      return;
    }

    final medWithDose = dose.isEmpty ? med : '$med ($dose)';
    setState(() {
      _currentMedications.add(medWithDose);
      _medicationController.clear();
      _doseController.clear();
    });
    HapticFeedback.lightImpact();
    _medicationFocus.requestFocus();
  }

  void _removeMedication(int index) {
    setState(() {
      _currentMedications.removeAt(index);
    });
    HapticFeedback.lightImpact();
  }

  Future<void> _analyzeMedicationSafety() async {
    if (_currentMedications.isEmpty) {
      AppErrorHandler.showSnackBar(
        context,
        Exception('Please add at least one medication to check'),
      );
      return;
    }

    setState(() => _isAnalyzing = true);

    try {
      final prompt = '''
As a clinical pharmacist, analyze the following medications for drug interactions, contraindications, and safety concerns:

**Medications to Analyze:**
${_currentMedications.map((med) => '• $med').join('\n')}

${patient != null ? '''
**Patient Context:**
- Age: ${patient!.age}
- Medical History: ${patient!.medicalHistory.isEmpty ? 'No documented conditions' : patient!.medicalHistory.join(', ')}
- Known Allergies: ${patient!.allergies.isEmpty ? 'None documented' : patient!.allergies.join(', ')}
''' : ''}

Please provide a comprehensive safety analysis with the following structured format:

## INTERACTION SEVERITY ASSESSMENT
For each interaction found, specify:
- CRITICAL (life-threatening, contraindicated)
- HIGH (significant risk, requires monitoring)
- MODERATE (caution advised, may need adjustment)
- LOW (minimal risk, awareness sufficient)

## DRUG-DRUG INTERACTIONS
List all significant interactions with severity levels and clinical significance

## CONTRAINDICATIONS & WARNINGS
Patient-specific contraindications based on age, conditions, and allergies

## MONITORING RECOMMENDATIONS
- Laboratory tests needed
- Clinical parameters to monitor
- Frequency of monitoring

## DOSING CONSIDERATIONS
Age-appropriate dosing and renal/hepatic adjustments if applicable

## PATIENT EDUCATION POINTS
Key safety information the patient should know

## ALTERNATIVE SUGGESTIONS
Safer alternative medications if high-risk interactions are found

Format each section clearly with severity indicators (🔴 CRITICAL, 🟠 HIGH, 🟡 MODERATE, 🟢 LOW)
''';

      final result = await _chatbotService.getGeminiResponse(prompt);

      if (!mounted) return;

      // Extract severity information
      _extractSeverityInfo(result);

      setState(() {
        _analysisResult = result;
        _isAnalyzing = false;
      });
      HapticFeedback.mediumImpact();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isAnalyzing = false);
      AppErrorHandler.showSnackBar(context, e);
    }
  }

  void _extractSeverityInfo(String analysisText) {
    _severityResults.clear();
    final lines = analysisText.toLowerCase().split('\n');

    for (final line in lines) {
      if (line.contains('critical') || line.contains('🔴')) {
        _severityResults['overall'] = 'CRITICAL';
        break;
      } else if (line.contains('high') || line.contains('🟠')) {
        _severityResults['overall'] = 'HIGH';
      } else if (line.contains('moderate') || line.contains('🟡') && !_severityResults.containsKey('overall')) {
        _severityResults['overall'] = 'MODERATE';
      } else if (line.contains('low') || line.contains('🟢') && !_severityResults.containsKey('overall')) {
        _severityResults['overall'] = 'LOW';
      }
    }

    // Default to LOW if no severity found
    _severityResults['overall'] ??= 'LOW';
  }

  Future<void> _saveMedicationAnalysisToNotes() async {
    if (_analysisResult.isEmpty) return;

    final patientId = patient?.id;
    if (patientId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select a patient to save the medication safety analysis'),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final severity = _severityResults['overall'] ?? 'LOW';
      final note = ClinicalNote(
        patientId: patientId,
        title: 'Medication Safety Analysis - $severity Risk',
        content: '''Medications Analyzed: ${_currentMedications.join(', ')}

--- MEDICATION SAFETY ANALYSIS ---

$_analysisResult''',
        diagnosis: 'Medication Safety Review - $severity Risk Level',
        treatments: [],
        followUpItems: [
          'Monitor for drug interactions',
          'Review medication list regularly',
          'Patient education provided'
        ],
        createdBy: 'Clinical Pharmacist',
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
                Text('Medication analysis saved to clinical notes'),
              ],
            ),
            backgroundColor: Colors.green,
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

  void _clearAll() {
    setState(() {
      _currentMedications.clear();
      _analysisResult = '';
      _medicationController.clear();
      _doseController.clear();
    });
  }

  void _calculateDosage() {
    final weight = double.tryParse(_weightController.text);
    final age = int.tryParse(_ageController.text);

    if (weight == null || _selectedMedForDosage.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter weight and select medication'),
          backgroundColor: AppTheme.warningColor,
        ),
      );
      return;
    }

    if (!_dosageData.containsKey(_selectedMedForDosage)) {
      setState(() {
        _calculatedDosage = 'Dosage data not available for $_selectedMedForDosage';
      });
      return;
    }

    final medData = _dosageData[_selectedMedForDosage]!;
    final isPediatric = age != null && age < 18;
    String result = '';

    if (isPediatric && medData.containsKey('pediatric')) {
      final pedData = medData['pediatric'];
      if (pedData.containsKey('min') && pedData.containsKey('max')) {
        final minDose = (weight * pedData['min']).round();
        final maxDose = (weight * pedData['max']).round();
        final maxDailyDose = (weight * pedData['maxDaily']).round();

        result = '''
📊 Pediatric Dosing for $_selectedMedForDosage
Weight: ${weight}kg, Age: ${age}y

💊 Dose per administration:
   ${minDose} - ${maxDose} mg ${pedData['frequency']}

📅 Maximum daily dose:
   ${maxDailyDose} mg/day

⚠️ Always verify with current pediatric dosing guidelines
        ''';
      } else {
        result = '''
📊 Pediatric Dosing for $_selectedMedForDosage
Weight: ${weight}kg, Age: ${age}y

💊 Standard Dose: ${pedData['dose']}
📅 Frequency: ${pedData['frequency']}
${pedData.containsKey('route') ? '🎯 Route: ${pedData['route']}' : ''}

⚠️ Always verify with current pediatric dosing guidelines
        ''';
      }
    } else if (medData.containsKey('adult')) {
      final adultData = medData['adult'];
      result = '''
📊 Adult Dosing for $_selectedMedForDosage
Weight: ${weight}kg${age != null ? ', Age: ${age}y' : ''}

💊 Standard Dose: ${adultData['dose']}
📅 Frequency: ${adultData['frequency']}
📊 Maximum daily: ${adultData['maxDaily']}

⚠️ Adjust for renal/hepatic impairment as needed
      ''';
    }

    setState(() {
      _calculatedDosage = result;
    });
    HapticFeedback.mediumImpact();
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
                  // Patient Info Card
                  if (hasPatient) ...[
                    SlideUpAnimation(
                      child: _buildPatientCard(),
                    ),
                    const SizedBox(height: AppTheme.lg),
                  ],

                  // Add Medication Section
                  SlideUpAnimation(
                    delay: const Duration(milliseconds: 100),
                    child: _buildAddMedicationCard(),
                  ),

                  const SizedBox(height: AppTheme.lg),

                  // Current Medications List
                  if (_currentMedications.isNotEmpty) ...[
                    SlideUpAnimation(
                      delay: const Duration(milliseconds: 200),
                      child: _buildMedicationsList(),
                    ),
                    const SizedBox(height: AppTheme.xl),
                    ScaleAnimation(
                      delay: const Duration(milliseconds: 300),
                      child: _buildCheckSafetyButton(),
                    ),
                    const SizedBox(height: AppTheme.md),
                    ScaleAnimation(
                      delay: const Duration(milliseconds: 400),
                      child: _buildDosageCalculatorButton(),
                    ),
                  ],

                  // Analysis Results
                  if (_analysisResult.isNotEmpty) ...[
                    const SizedBox(height: AppTheme.xl),
                    FadeInAnimation(
                      child: _buildAnalysisCard(),
                    ),
                  ],

                  // Dosage Calculator Results
                  if (_showDosageCalculator) ...[
                    const SizedBox(height: AppTheme.lg),
                    SlideUpAnimation(
                      child: _buildDosageCalculatorCard(),
                    ),
                  ],

                  // Empty State
                  if (_currentMedications.isEmpty && _analysisResult.isEmpty)
                    SlideUpAnimation(
                      delay: const Duration(milliseconds: 200),
                      child: _buildEmptyState(),
                    ),

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
      backgroundColor: Colors.orange.shade300,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          color: Colors.orange.shade300,
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
                          CupertinoIcons.shield_lefthalf_fill,
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
                              'Medication Safety',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              'Drug Interaction Analysis',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_currentMedications.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3),
                              width: 0.5,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                CupertinoIcons.number,
                                color: Colors.white,
                                size: 12,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${_currentMedications.length}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
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
        if (_currentMedications.isNotEmpty || _analysisResult.isNotEmpty)
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

  Widget _buildPatientCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: CupertinoColors.systemOrange.withValues(alpha: 0.2),
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
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFFF6B35),
                  Color(0xFFE55D4A),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF6B35).withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Text(
                getPatientDisplayName().substring(0, 1).toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
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
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: CupertinoColors.systemOrange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              CupertinoIcons.person_badge_plus,
              color: CupertinoColors.systemOrange,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddMedicationCard() {
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
                  CupertinoIcons.add_circled,
                  color: CupertinoColors.systemBlue,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppTheme.md),
              const Text(
                'Add Medications',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1D1D1F),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Medication Name
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Medication Name',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: CupertinoColors.systemGrey,
                ),
              ),
              const SizedBox(height: 8),
              CupertinoTextField(
                controller: _medicationController,
                focusNode: _medicationFocus,
                textCapitalization: TextCapitalization.words,
                placeholder: 'e.g., Aspirin, Metformin, Lisinopril',
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: CupertinoColors.systemGrey6,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: CupertinoColors.systemGrey4,
                    width: 0.5,
                  ),
                ),
                prefix: Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Icon(
                    CupertinoIcons.capsule,
                    color: CupertinoColors.systemGrey,
                    size: 20,
                  ),
                ),
                onSubmitted: (_) => _addMedication(),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Dose (Optional)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Dose (Optional)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: CupertinoColors.systemGrey,
                ),
              ),
              const SizedBox(height: 8),
              CupertinoTextField(
                controller: _doseController,
                placeholder: 'e.g., 100mg daily, 500mg twice daily',
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: CupertinoColors.systemGrey6,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: CupertinoColors.systemGrey4,
                    width: 0.5,
                  ),
                ),
                prefix: Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Icon(
                    CupertinoIcons.gauge,
                    color: CupertinoColors.systemGrey,
                    size: 20,
                  ),
                ),
                onSubmitted: (_) => _addMedication(),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Add Button
          Container(
            width: double.infinity,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.circular(12),
            ),
            child: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _addMedication,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    CupertinoIcons.add,
                    color: Colors.white,
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Add to List',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Quick Selection Section
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    CupertinoIcons.bolt_fill,
                    size: 16,
                    color: CupertinoColors.systemOrange,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Quick Selection',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: CupertinoColors.systemGrey,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _commonMedications.take(10).map((medication) {
                  return GestureDetector(
                    onTap: () {
                      _medicationController.text = medication;
                      _addMedication();
                      HapticFeedback.lightImpact();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemGrey6,
                        border: Border.all(
                          color: CupertinoColors.systemGrey4,
                          width: 0.5,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        medication,
                        style: TextStyle(
                          fontSize: 13,
                          color: CupertinoColors.systemGrey,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMedicationsList() {
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
                  CupertinoIcons.list_bullet,
                  color: CupertinoColors.systemIndigo,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppTheme.md),
              const Text(
                'Current Medications',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1D1D1F),
                ),
              ),
              const Spacer(),
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
                  '${_currentMedications.length}',
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
          ...List.generate(_currentMedications.length, (index) {
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
                      color: CupertinoColors.systemOrange.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      CupertinoIcons.capsule_fill,
                      color: CupertinoColors.systemOrange,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _currentMedications[index],
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF1D1D1F),
                      ),
                    ),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    minSize: 32,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemRed.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        CupertinoIcons.xmark,
                        size: 14,
                        color: CupertinoColors.systemRed,
                      ),
                    ),
                    onPressed: () {
                      _removeMedication(index);
                      HapticFeedback.lightImpact();
                    },
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildCheckSafetyButton() {
    return Container(
      height: 54,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: _isAnalyzing
            ? null
            : const LinearGradient(
                colors: [
                  Color(0xFF34C759), // iOS Green
                  Color(0xFF28A745),
                ],
              ),
        color: _isAnalyzing ? CupertinoColors.systemGrey4 : null,
        boxShadow: _isAnalyzing
            ? null
            : [
                BoxShadow(
                  color: const Color(0xFF34C759).withValues(alpha: 0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: _isAnalyzing ? null : _analyzeMedicationSafety,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isAnalyzing) ...[
              const CupertinoActivityIndicator(
                color: Colors.white,
              ),
              const SizedBox(width: AppTheme.md),
              const Text(
                'Analyzing Safety...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ] else ...[
              const Icon(
                CupertinoIcons.shield_lefthalf_fill,
                color: Colors.white,
                size: 22,
              ),
              const SizedBox(width: AppTheme.md),
              const Text(
                'Check Drug Interactions',
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

  Widget _buildAnalysisCard() {
    final severity = _severityResults['overall'] ?? 'LOW';
    final severityColor = _getSeverityColor(severity);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: severityColor.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: severityColor.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Severity Indicator
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  severityColor.withValues(alpha: 0.08),
                  severityColor.withValues(alpha: 0.03),
                ],
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: severityColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _getSeverityIcon(severity),
                        color: severityColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: AppTheme.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Safety Analysis Complete',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: severityColor,
                            ),
                          ),
                          Text(
                            '${_currentMedications.length} medications analyzed',
                            style: TextStyle(
                              fontSize: 14,
                              color: CupertinoColors.systemGrey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: CupertinoColors.systemGrey5,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          CupertinoIcons.doc_on_clipboard,
                          color: CupertinoColors.systemGrey,
                          size: 20,
                        ),
                      ),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _analysisResult));
                        HapticFeedback.lightImpact();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Analysis copied to clipboard'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Severity Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: severityColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: severityColor.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getSeverityIcon(severity),
                        color: severityColor,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$severity RISK LEVEL',
                        style: TextStyle(
                          color: severityColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(20),
            child: SelectableText(
              _analysisResult,
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
                  CupertinoIcons.info_circle,
                  size: 16,
                  color: CupertinoColors.systemGrey,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Always verify with clinical pharmacist',
                    style: TextStyle(
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      color: CupertinoColors.systemGrey,
                    ),
                  ),
                ),
                const SizedBox(width: AppTheme.sm),
                Text(
                  DateFormat('h:mm a').format(DateTime.now()),
                  style: TextStyle(
                    fontSize: 13,
                    color: CupertinoColors.systemGrey,
                  ),
                ),
                const SizedBox(width: AppTheme.md),
                Container(
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        CupertinoColors.systemOrange,
                        CupertinoColors.systemOrange.darkColor,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    minSize: 0,
                    onPressed: _isSaving ? null : _saveMedicationAnalysisToNotes,
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

  Color _getSeverityColor(String severity) {
    switch (severity) {
      case 'CRITICAL':
        return CupertinoColors.systemRed;
      case 'HIGH':
        return CupertinoColors.systemOrange;
      case 'MODERATE':
        return CupertinoColors.systemBlue;
      case 'LOW':
      default:
        return CupertinoColors.systemGreen;
    }
  }

  IconData _getSeverityIcon(String severity) {
    switch (severity) {
      case 'CRITICAL':
        return CupertinoIcons.exclamationmark_triangle_fill;
      case 'HIGH':
        return CupertinoIcons.exclamationmark_circle_fill;
      case 'MODERATE':
        return CupertinoIcons.info_circle_fill;
      case 'LOW':
      default:
        return CupertinoIcons.checkmark_shield_fill;
    }
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.xl * 2),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  CupertinoColors.systemOrange.withValues(alpha: 0.15),
                  CupertinoColors.systemOrange.withValues(alpha: 0.05),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              CupertinoIcons.capsule,
              size: 48,
              color: CupertinoColors.systemOrange,
            ),
          ),
          const SizedBox(height: AppTheme.lg),
          const Text(
            'No Medications Added',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1D1D1F),
            ),
          ),
          const SizedBox(height: AppTheme.sm),
          Text(
            'Add medications above to check for\ndrug interactions and safety concerns',
            style: TextStyle(
              fontSize: 15,
              color: CupertinoColors.systemGrey,
              fontWeight: FontWeight.w400,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDosageCalculatorButton() {
    return OutlinedButton.icon(
      onPressed: () {
        setState(() {
          _showDosageCalculator = !_showDosageCalculator;
          if (!_showDosageCalculator) {
            _calculatedDosage = '';
            _weightController.clear();
            _ageController.clear();
            _selectedMedForDosage = '';
          }
        });
      },
      icon: Icon(
        _showDosageCalculator ? Icons.calculate_outlined : Icons.calculate,
        color: AppTheme.primaryColor,
      ),
      label: Text(
        _showDosageCalculator ? 'Hide Calculator' : 'Dosage Calculator',
        style: const TextStyle(
          color: AppTheme.primaryColor,
          fontWeight: FontWeight.w600,
        ),
      ),
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: AppTheme.primaryColor, width: 2),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildDosageCalculatorCard() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor.withValues(alpha: 0.05),
            AppTheme.primaryColor.withValues(alpha: 0.02),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.calculate,
                  color: AppTheme.primaryColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Pediatric & Adult Dosage Calculator',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.lg),

          // Patient Info Row
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _weightController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Weight (kg)',
                    hintText: 'e.g. 70.5',
                    suffixText: 'kg',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _ageController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Age (y)',
                    hintText: 'e.g. 25',
                    suffixText: 'years',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.md),

          // Medication Selection
          DropdownButtonFormField<String>(
            value: _selectedMedForDosage.isEmpty ? null : _selectedMedForDosage,
            decoration: const InputDecoration(
              labelText: 'Select Medication',
              border: OutlineInputBorder(),
            ),
            items: _dosageData.keys.map((String medication) {
              return DropdownMenuItem<String>(
                value: medication,
                child: Text(medication),
              );
            }).toList(),
            onChanged: (String? newValue) {
              setState(() {
                _selectedMedForDosage = newValue ?? '';
                _calculatedDosage = '';
              });
            },
          ),
          const SizedBox(height: AppTheme.lg),

          // Calculate Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _calculateDosage,
              icon: const Icon(Icons.calculate),
              label: const Text(
                'Calculate Dosage',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),

          // Results
          if (_calculatedDosage.isNotEmpty) ...[
            const SizedBox(height: AppTheme.lg),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppTheme.md),
              decoration: BoxDecoration(
                color: AppTheme.successColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.successColor.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: AppTheme.successColor,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Calculated Dosage',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    _calculatedDosage,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppTheme.textPrimary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: AppTheme.md),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.warningColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.warning_amber,
                  color: AppTheme.warningColor,
                  size: 16,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Always verify dosage with current clinical guidelines and consider patient-specific factors',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.warningColor,
                      fontWeight: FontWeight.w500,
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
