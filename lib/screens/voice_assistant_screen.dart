import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';

import '../core/errors/app_error_handler.dart';
import '../core/healthcare/healthcare_services_manager.dart';
import '../core/healthcare/ai_analysis_mixin.dart';
import '../core/healthcare/patient_loading_mixin.dart';
import '../core/healthcare/healthcare_widgets.dart';
import '../theme/app_theme.dart';
import '../theme/app_animations.dart';
import '../widgets/audio_visualizer.dart';
import 'doctor_patient_create_edit_screen.dart';
import 'consultation_history_screen.dart';

class InteractiveVoiceAssistantScreen extends StatefulWidget {
  final String patientId;
  final String? initialPrompt;

  const InteractiveVoiceAssistantScreen({
    super.key,
    required this.patientId,
    this.initialPrompt,
  });

  @override
  State<InteractiveVoiceAssistantScreen> createState() =>
      _InteractiveVoiceAssistantScreenState();
}

class _InteractiveVoiceAssistantScreenState
    extends State<InteractiveVoiceAssistantScreen>
    with
      SingleTickerProviderStateMixin,
      AIAnalysisMixin,
      PatientLoadingMixin {

  // Shared services via singleton
  final HealthcareServicesManager _services = HealthcareServicesManager();

  // Voice-specific components
  AudioRecorder? _audioRecorder; // Make nullable to recreate
  final TextEditingController _messageController = TextEditingController();

  late AnimationController _pulseController;

  // Voice assistant specific state
  bool _isRecording = false;
  String _latestTranscript = '';
  String _latestSummary = '';
  String _latestPrescription = '';
  DateTime? _recordingStartedAt;
  Duration _recordingDuration = Duration.zero;
  Timer? _recordingTimer;
  StreamSubscription<Amplitude>? _amplitudeSubscription;
  bool _keysAvailable = false;
  double _currentAudioLevel = 0.0; // Audio decibel level for visualization
  bool _isTranscribing = false;

  @override
  void initState() {
    super.initState();
    _setupAnimation();
    _initializeScreen();
  }

  void _setupAnimation() {
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
  }

  Future<void> _initializeScreen() async {
    // Load patient data using mixin
    if (widget.patientId.trim().isNotEmpty && widget.patientId != 'demo-patient') {
      await loadPatientData(widget.patientId);
    }

    // Start watching patients for selection
    startWatchingPatients();

    // Check API keys and run initial prompt
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeWithKeyCheck();
    });
  }

  Future<void> _initializeWithKeyCheck() async {
    final keysReady = await _services.ensureApiKeysAvailable();
    if (!mounted) return;

    setState(() => _keysAvailable = keysReady);

    if (!keysReady) {
      _showFirebaseSetupMessage();
      return;
    }

    // Run auto-prompt if provided
    final prompt = widget.initialPrompt;
    if (prompt != null && prompt.trim().isNotEmpty) {
      _runQuickPrompt(prompt);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _audioRecorder?.dispose();
    _messageController.dispose();
    _recordingTimer?.cancel();
    _amplitudeSubscription?.cancel();
    super.dispose();
  }

  Future<void> _showFirebaseSetupMessage() async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.cloud_off, color: Colors.orange),
            SizedBox(width: 8),
            Text('Firebase Setup Required'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'The AI features require API keys to be configured in Firebase.',
              style: TextStyle(fontSize: 15),
            ),
            SizedBox(height: 16),
            Text(
              'Please ensure the following are set in Firebase Firestore:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            SizedBox(height: 8),
            Text('📍 Collection: app_runtime'),
            Text('📄 Document: api_keys'),
            SizedBox(height: 8),
            Text('🔑 Fields needed:', style: TextStyle(fontWeight: FontWeight.w500)),
            Text('  • geminiApiKey: [Your Gemini API key]'),
            Text('  • deepgramApiKey: [Your Deepgram API key]'),
            SizedBox(height: 16),
            Text(
              'Once configured, restart the app and the AI features will work automatically.',
              style: TextStyle(color: Colors.green, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Got it'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              // Retry loading keys
              await _initializeWithKeyCheck();
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Future<void> _runQuickPrompt(String text) async {
    if (text.trim().isEmpty) return;

    // Use AI analysis mixin
    await performAIAnalysis(
      prompt: text,
      patient: patient,
      onSuccess: (result) {
        setState(() => _latestSummary = _sanitizeClinicalAiText(result));
      },
    );
  }

  Future<void> _toggleRecording() async {
    if (isAnalyzing || _isTranscribing) return;
    if (_isRecording) {
      await _stopRecordingAndProcess();
      return;
    }

    // Ensure API keys are configured before recording
    final keysReady = await _services.ensureApiKeysAvailable();
    if (!keysReady) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'AI features require Firebase configuration. Please check Firestore for API keys.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      // Create a fresh recorder every time
      _audioRecorder?.dispose();
      _audioRecorder = AudioRecorder();

      final hasPermission = await _audioRecorder!.hasPermission();
      if (!hasPermission) {
        throw Exception('Microphone permission is required.');
      }

      final tempDir = await getTemporaryDirectory();
      final audioPath =
          '${tempDir.path}/consultation_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _audioRecorder!.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: audioPath,
      );

      if (!mounted) return;
      setState(() {
        _isRecording = true;
        _recordingStartedAt = DateTime.now();
        _recordingDuration = Duration.zero;
        _currentAudioLevel = 0.0;
      });
      _pulseController.repeat(reverse: true);

      // Duration timer
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted && _recordingStartedAt != null) {
          setState(() {
            _recordingDuration = DateTime.now().difference(_recordingStartedAt!);
          });
        }
      });

      // Cancel old subscription without await (don't hang)
      _amplitudeSubscription?.cancel();
      _amplitudeSubscription = null;

      // Wait for recorder to be ready
      await Future.delayed(const Duration(milliseconds: 150));

      // Create amplitude subscription
      _amplitudeSubscription = _audioRecorder!.onAmplitudeChanged(
        const Duration(milliseconds: 50),
      ).listen(
        (amplitude) {
          if (!mounted || !_isRecording) return;

          final db = amplitude.current;
          double normalized;
          if (db < -50) {
            normalized = 0.0;
          } else if (db > -5) {
            normalized = 1.0;
          } else {
            normalized = (db + 50) / 45;
          }

          setState(() {
            _currentAudioLevel = normalized.clamp(0.0, 1.0);
          });
        },
        onError: (e) {},
        cancelOnError: false,
      );
    } catch (error) {
      if (!mounted) return;
      AppErrorHandler.showSnackBar(context, error);
    }
  }

  Future<void> _stopRecordingAndProcess() async {
    _recordingTimer?.cancel();
    _recordingTimer = null;

    _amplitudeSubscription?.cancel();
    _amplitudeSubscription = null;

    // Capture duration before resetting
    final recordedDuration = _recordingDuration;

    try {
      setState(() {
        _isRecording = false;
        _currentAudioLevel = 0.0;
        _isTranscribing = true;
      });
      _pulseController.stop();
      _pulseController.reset();

      final filePath = await _audioRecorder?.stop();
      if (filePath == null || filePath.trim().isEmpty) {
        throw Exception('No audio was captured. Please try again.');
      }

      // Generate session ID for audio upload
      final sessionId = const Uuid().v4();

      // Transcribe audio
      final transcript = await _services.deepgram.transcribeAudioFile(filePath);

      if (mounted) {
        setState(() => _isTranscribing = false);
      }

      // Update transcript immediately so user can see it
      if (mounted) {
        setState(() {
          _latestTranscript = transcript;
        });
      }

      // Upload audio to Firebase Storage (in parallel with AI analysis)
      String? audioUrl;
      final audioUploadFuture = _services.uploadConsultationAudio(
        filePath: filePath,
        sessionId: sessionId,
      );

      // Generate summary using AI mixin - INCLUDE THE TRANSCRIPT
      final rawSummary = await performAIAnalysis(
        prompt: _buildConsultationSummaryPromptWithTranscript(transcript),
        patient: patient,
      );
      final summary = rawSummary == null ? null : _sanitizeClinicalAiText(rawSummary);

      // Generate prescription using AI mixin - INCLUDE THE TRANSCRIPT
      final rawPrescription = await performAIAnalysis(
        prompt: _buildPrescriptionPromptWithTranscript(transcript),
        patient: patient,
      );
      final prescription = rawPrescription == null
          ? null
          : _sanitizeClinicalAiText(rawPrescription);

      // Wait for audio upload to complete
      try {
        audioUrl = await audioUploadFuture;
      } catch (e) {
        // Audio upload failed, but continue without it
      }

      // Save consultation if patient is selected
      if (patient != null && summary != null && prescription != null) {
        await _services.persistConsultation(
          patient: patient!,
          transcript: transcript,
          summary: summary,
          prescription: prescription,
          source: 'voice',
          audioUrl: audioUrl,
          durationSeconds: recordedDuration.inSeconds,
        );

        // Save clinical note
        await _services.saveClinicalNote(
          patientId: patient!.id,
          title: 'Consultation Summary • ${DateFormat('MMM d, HH:mm').format(DateTime.now())}',
          content: summary,
        );
      }

      if (!mounted) return;
      setState(() {
        _latestTranscript = transcript;
        _latestSummary = summary ?? '';
        _latestPrescription = prescription ?? '';
      });
    } catch (error) {
      _recordingTimer?.cancel();
      _recordingTimer = null;
      _amplitudeSubscription?.cancel();
      _amplitudeSubscription = null;

      if (!mounted) return;
      setState(() {
        _isRecording = false;
        _isTranscribing = false;
      });
      _pulseController.stop();
      _pulseController.reset();
      AppErrorHandler.showSnackBar(context, error);
    }
  }

  void _openAddPatient() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const DoctorPatientCreateEditScreen(),
      ),
    );
  }

  void _openHistoryDetails() {
    final doctorId = _services.currentDoctorId;
    if (doctorId.isEmpty) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ConsultationHistoryScreen(
          onSessionSelected: (session) {
            setPatient(findPatientById(session.patientId));
            setState(() {
              _latestTranscript = session.transcript;
              _latestSummary = _sanitizeClinicalAiText(session.summary);
              _latestPrescription = _sanitizeClinicalAiText(session.prescription);
            });
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Clinical Assistant'),
        backgroundColor: AppTheme.surfaceColor,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: _keysAvailable ? 'Firebase API Keys Active' : 'Firebase Setup Required',
            onPressed: _keysAvailable ? null : _showFirebaseSetupMessage,
            icon: Icon(
              _keysAvailable ? Icons.cloud_done : Icons.cloud_off,
              color: _keysAvailable ? AppTheme.successColor : AppTheme.dangerColor,
            ),
          ),
          IconButton(
            tooltip: 'Consultation history',
            onPressed: _services.currentDoctorId.isEmpty ? null : _openHistoryDetails,
            icon: const Icon(Icons.history),
          ),
        ],
      ),
      body: Column(
        children: [
          // Patient selection using shared mixin
          if (_services.currentDoctorId.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(AppTheme.lg, AppTheme.md, AppTheme.lg, 0),
              child: buildPatientContextWidget(
                onTap: () async {
                  final selectedPatient = await showPatientSelector();
                  if (selectedPatient != null) {
                    setPatient(selectedPatient);
                  }
                },
                onAdd: _openAddPatient,
              ),
            ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppTheme.lg),
              child: Column(
                children: [
                  const SizedBox(height: AppTheme.xxl),

                  // Professional Audio Visualizer - ECG Style
                  GestureDetector(
                    onTap: (isAnalyzing || _isTranscribing) ? null : _toggleRecording,
                    child: AudioVisualizer(
                      isRecording: _isRecording,
                      primaryColor: Colors.blue,
                      secondaryColor: Colors.blue.shade300,
                      size: 280,
                      audioLevel: _currentAudioLevel,
                    ),
                  ),
                  const SizedBox(height: AppTheme.xxl),

                  // Recording Timer
                  if (_isRecording && _recordingStartedAt != null)
                    FadeInAnimation(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.lg,
                          vertical: AppTheme.sm,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: AppTheme.mediumRadius,
                          border: Border.all(
                            color: Colors.red.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.fiber_manual_record,
                              color: Colors.red,
                              size: 16,
                            ),
                            const SizedBox(width: AppTheme.sm),
                            Text(
                              '${_recordingDuration.inMinutes.toString().padLeft(2, '0')}:${(_recordingDuration.inSeconds % 60).toString().padLeft(2, '0')}',
                              style: AppTheme.labelMedium.copyWith(
                                color: Colors.red,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: AppTheme.md),

                  // Status Text with Animation and Processing Indicator
                  if (isAnalyzing || _isTranscribing)
                    FadeInAnimation(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.lg,
                          vertical: AppTheme.md,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.08),
                          borderRadius: AppTheme.mediumRadius,
                          border: Border.all(
                            color: AppTheme.primaryColor.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppTheme.primaryColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: AppTheme.md),
                            Text(
                              _isTranscribing
                                  ? 'Converting speech to text...'
                                  : 'Analyzing consultation...',
                              style: AppTheme.bodyMedium.copyWith(
                                color: AppTheme.primaryColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    GestureDetector(
                      onTap: _isRecording ? _toggleRecording : null,
                      child: SlideUpAnimation(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppTheme.xl,
                            vertical: AppTheme.md,
                          ),
                          decoration: BoxDecoration(
                            color: _isRecording
                                ? Colors.red.withValues(alpha: 0.1)
                                : Colors.blue.withValues(alpha: 0.1),
                            borderRadius: AppTheme.largeRadius,
                            border: Border.all(
                              color: _isRecording
                                  ? Colors.red.withValues(alpha: 0.3)
                                  : Colors.blue.withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _isRecording ? Icons.stop_circle : Icons.touch_app,
                                color: _isRecording ? Colors.red : Colors.blue,
                                size: 20,
                              ),
                              const SizedBox(width: AppTheme.sm),
                              Flexible(
                                child: Text(
                                  _isRecording
                                      ? 'Recording… tap to stop'
                                      : 'Tap the microphone to start consultation capture',
                                  textAlign: TextAlign.center,
                                  style: AppTheme.bodyMedium.copyWith(
                                    color: _isRecording ? Colors.red : Colors.blue,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: AppTheme.lg),

                  // Result Action Cards - Improved UI
                  _buildResultCard(
                    label: 'Transcription',
                    description: _latestTranscript.trim().isNotEmpty
                        ? '${_latestTranscript.split(' ').take(8).join(' ')}...'
                        : 'Voice recording will be transcribed here',
                    icon: Icons.record_voice_over,
                    hasContent: _latestTranscript.trim().isNotEmpty,
                    color: AppTheme.primaryColor,
                    onTap: () => HealthcareResultSheet.show(
                      context,
                      title: 'Transcription',
                      content: _latestTranscript,
                      icon: Icons.record_voice_over,
                    ),
                  ),
                  const SizedBox(height: AppTheme.md),
                  _buildResultCard(
                    label: 'Clinical Summary',
                    description: _latestSummary.trim().isNotEmpty
                        ? '${_previewText(_latestSummary)}...'
                        : 'AI-generated clinical summary',
                    icon: Icons.summarize,
                    hasContent: _latestSummary.trim().isNotEmpty,
                    color: AppTheme.successColor,
                    onTap: () => HealthcareResultSheet.show(
                      context,
                      title: 'Clinical Summary',
                      content: _latestSummary,
                      icon: Icons.summarize,
                      accentColor: AppTheme.successColor,
                    ),
                  ),
                  const SizedBox(height: AppTheme.md),
                  _buildResultCard(
                    label: 'Prescription Suggestions',
                    description: _latestPrescription.trim().isNotEmpty
                        ? '${_previewText(_latestPrescription)}...'
                        : 'AI-assisted prescription draft',
                    icon: Icons.medication,
                    hasContent: _latestPrescription.trim().isNotEmpty,
                    color: AppTheme.warningColor,
                    onTap: () => HealthcareResultSheet.show(
                      context,
                      title: 'Prescription Suggestions',
                      content: _latestPrescription,
                      icon: Icons.medication,
                      accentColor: AppTheme.warningColor,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Manual Input Bar
          Container(
            padding: const EdgeInsets.all(AppTheme.md),
            decoration: const BoxDecoration(
              color: AppTheme.surfaceColor,
              border: Border(
                top: BorderSide(color: AppTheme.dividerColor),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: 'Ask me anything…',
                        border: OutlineInputBorder(
                          borderRadius: AppTheme.mediumRadius,
                          borderSide: const BorderSide(color: AppTheme.dividerColor),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: AppTheme.mediumRadius,
                          borderSide: const BorderSide(color: AppTheme.dividerColor),
                        ),
                      ),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (value) {
                        final text = value.trim();
                        if (text.isEmpty || _isTranscribing) return;
                        _runQuickPrompt(text);
                        _messageController.clear();
                      },
                    ),
                  ),
                  const SizedBox(width: AppTheme.sm),
                  Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.primaryColor,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white),
                        onPressed: isAnalyzing || _isTranscribing
                          ? null
                          : () {
                              final text = _messageController.text.trim();
                              if (text.isEmpty) return;
                              _runQuickPrompt(text);
                              _messageController.clear();
                            },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard({
    required String label,
    required String description,
    required IconData icon,
    required bool hasContent,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: hasContent && !isAnalyzing && !_isTranscribing ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(AppTheme.md),
        decoration: BoxDecoration(
          color: hasContent
              ? color.withValues(alpha: 0.08)
              : AppTheme.surfaceColor,
          borderRadius: AppTheme.mediumRadius,
          border: Border.all(
            color: hasContent
                ? color.withValues(alpha: 0.3)
                : AppTheme.dividerColor,
            width: hasContent ? 1.5 : 1,
          ),
          boxShadow: hasContent
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            // Icon Container
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: hasContent
                    ? color.withValues(alpha: 0.15)
                    : AppTheme.backgroundColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: hasContent ? color : AppTheme.textSecondary,
                size: 24,
              ),
            ),
            const SizedBox(width: AppTheme.md),
            // Text Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        label,
                        style: AppTheme.labelLarge.copyWith(
                          color: hasContent ? color : AppTheme.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (hasContent) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Ready',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: color,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // Arrow Indicator
            Icon(
              Icons.chevron_right,
              color: hasContent ? color : AppTheme.textSecondary.withValues(alpha: 0.5),
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  /// Generate consultation summary prompt WITH the actual transcript included
  String _buildConsultationSummaryPromptWithTranscript(String transcript) {
    final patientContext = patient != null
        ? '''
**Patient Information:**
- Name: ${patient!.fullName}
- Age: ${patient!.age}
- Medical History: ${patient!.medicalHistory.isEmpty ? 'None documented' : patient!.medicalHistory.join(', ')}
'''
        : '';

    return '''As a clinical documentation assistant, analyze this consultation transcript and create a comprehensive clinical summary.

$patientContext

**Consultation Transcript:**
$transcript

Please provide a structured clinical summary with the following sections:

## CHIEF CONCERNS
- Primary reason for visit
- Patient's main complaints

## HISTORY OF PRESENT ILLNESS
- Onset, duration, and progression of symptoms
- Associated symptoms
- Relevant context

## CLINICAL ASSESSMENT
- Key findings from the consultation
- Clinical impression
- Differential considerations

## PLAN
- Recommended investigations
- Treatment approach
- Follow-up instructions

## SAFETY FLAGS
- Red flag symptoms to watch for
- Warning signs requiring immediate attention

## FOLLOW-UP
- Recommended follow-up timing
- Additional referrals if needed

Format clearly with headers and bullet points for easy clinical review.
Do not include template placeholders like [Insert Date Here] or [Insert Name].
If information is missing, explicitly write: Not available from transcript.''';
  }

  /// Generate prescription prompt WITH the actual transcript included
  String _buildPrescriptionPromptWithTranscript(String transcript) {
    final patientContext = patient != null
        ? '''
**Patient Information:**
- Name: ${patient!.fullName}
- Age: ${patient!.age}
- Medical History: ${patient!.medicalHistory.isEmpty ? 'None documented' : patient!.medicalHistory.join(', ')}
'''
        : '';

    return '''As a clinical prescribing assistant, based on this consultation, suggest appropriate prescription recommendations.

$patientContext

**Consultation Transcript:**
$transcript

Please provide prescription suggestions with the following format for each medication:

## PRESCRIPTION RECOMMENDATIONS

For each recommended medication:
- **Medication Name** (Generic/Brand)
- **Dose**: Specific dosage
- **Route**: How to administer
- **Frequency**: How often
- **Duration**: How long to take
- **Special Instructions**: Food requirements, timing, etc.

## CAUTIONS & CONTRAINDICATIONS
- Drug interactions to watch for
- Conditions that may contraindicate use
- Side effects to monitor

## PATIENT EDUCATION
- Key instructions for the patient
- When to seek medical attention

## DISCLAIMER
⚠️ These are AI-generated suggestions only. Final prescription decisions must be made by a licensed healthcare provider after clinical evaluation.

Format clearly for easy clinical review.
Do not include template placeholders like [Insert ...].
If information is missing, explicitly write: Not available from transcript.''';
  }

  String _sanitizeClinicalAiText(String raw) {
    var text = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n').trim();

    // Models sometimes wrap markdown in fenced code blocks.
    text = text.replaceAll(
      RegExp(r'```(?:markdown|md|text)?\n?', caseSensitive: false),
      '',
    );
    text = text.replaceAll('```', '');

    // Replace placeholder template slots with useful fallback text.
    text = text.replaceAllMapped(
      RegExp(r'\[(?:Insert|Enter|Add)[^\]]+\]', caseSensitive: false),
      (_) => 'Not available from transcript',
    );

    // Keep spacing readable but compact.
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');

    return text.trim();
  }

  String _previewText(String raw) {
    final normalized = _sanitizeClinicalAiText(raw)
        .replaceAll(RegExp(r'[#*_`>|\[\]\(\)]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (normalized.isEmpty) {
      return 'Tap to view details';
    }

    return normalized.split(' ').take(8).join(' ');
  }
}