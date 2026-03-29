import '../../models/health_models.dart';
import '../../services/chatbot_service.dart';
import '../../services/deepgram_service.dart';
import '../../services/firebase/api_credentials_service.dart';
import '../../services/firebase/auth_service.dart';
import '../../services/firebase/firestore_service.dart';
import '../../services/firebase/storage_service.dart';
import '../ai_prompt_builder.dart';

/// Singleton manager for all healthcare-related services
/// Eliminates the need to initialize services in every screen
class HealthcareServicesManager {
  static final HealthcareServicesManager _instance = HealthcareServicesManager._internal();
  factory HealthcareServicesManager() => _instance;
  HealthcareServicesManager._internal();

  // Service instances
  final ChatbotService _chatbotService = ChatbotService();
  final DeepgramService _deepgramService = DeepgramService();
  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();
  final StorageService _storageService = StorageService();

  // Getters for services
  ChatbotService get chatbot => _chatbotService;
  DeepgramService get deepgram => _deepgramService;
  FirestoreService get firestore => _firestoreService;
  AuthService get auth => _authService;
  StorageService get storage => _storageService;

  /// Get current doctor ID
  String get currentDoctorId => _authService.currentUser?.uid ?? '';

  /// Check if Firebase API keys are available
  Future<bool> ensureApiKeysAvailable() async {
    for (var attempt = 0; attempt < 5; attempt++) {
      try {
        await ApiCredentialsService.instance.preload();
        final hasKeys = await ApiCredentialsService.instance.hasKeys();
        if (hasKeys) return true;
      } catch (e) {
        // Continue trying
      }

      if (attempt < 4) {
        await Future<void>.delayed(const Duration(milliseconds: 300));
      }
    }
    return false;
  }

  /// Load patient data by ID
  Future<ProviderPatientRecord?> loadPatient(String patientId) async {
    if (patientId.isEmpty || patientId == 'demo-patient' || patientId == 'no-patient') {
      return null;
    }

    try {
      final doctorId = currentDoctorId;
      if (doctorId.isEmpty) return null;

      final patients = await _firestoreService.getDoctorPatients(doctorId);
      return patients.firstWhere(
        (p) => p.id == patientId,
        orElse: () => patients.isNotEmpty ? patients.first : throw Exception('Patient not found'),
      );
    } catch (e) {
      return null;
    }
  }

  /// Perform AI analysis with optional patient context
  Future<String> analyzeWithAI({
    required String prompt,
    ProviderPatientRecord? patient,
    String? imagePath,
  }) async {
    final contextualPrompt = _buildContextualPrompt(prompt, patient);

    if (imagePath != null) {
      return await _chatbotService.getGeminiVisionResponse(
        prompt: contextualPrompt,
        imagePath: imagePath,
      );
    } else {
      return await _chatbotService.getGeminiResponse(contextualPrompt);
    }
  }

  /// Build a complete contextual prompt with patient info and clinical rules
  String _buildContextualPrompt(String userPrompt, ProviderPatientRecord? patient) {
    final patientContext = AIPromptBuilder.buildPatientContext(patient);

    return '''You are a clinical assistant for healthcare providers.

${patientContext}Provider request:
$userPrompt

Rules:
- Be concise and clinically useful.
- Do not invent facts not present in transcript/context.
- Flag safety concerns and uncertain information.
- Provide structured output when appropriate.
''';
  }

  /// Persist consultation session with optional audio
  Future<void> persistConsultation({
    required ProviderPatientRecord patient,
    required String transcript,
    required String summary,
    required String prescription,
    String source = 'unknown',
    String? audioUrl,
    int durationSeconds = 0,
  }) async {
    final doctorId = currentDoctorId;
    if (doctorId.isEmpty) return;

    final session = ConsultationSession(
      doctorId: doctorId,
      patientId: patient.id,
      patientName: patient.fullName,
      transcript: transcript,
      summary: summary,
      prescription: prescription,
      source: source,
      audioUrl: audioUrl,
      durationSeconds: durationSeconds,
    );

    await _firestoreService.saveConsultationSession(session);
  }

  /// Upload audio file and return download URL
  Future<String?> uploadConsultationAudio({
    required String filePath,
    required String sessionId,
  }) async {
    final doctorId = currentDoctorId;
    if (doctorId.isEmpty) return null;

    return await _storageService.uploadAudioFile(
      filePath: filePath,
      doctorId: doctorId,
      sessionId: sessionId,
    );
  }

  /// Delete consultation session and its audio file
  Future<void> deleteConsultation(ConsultationSession session) async {
    // Delete audio file from storage if exists
    if (session.hasAudio) {
      await _storageService.deleteAudioFile(session.audioUrl!);
    }
    // Delete session from Firestore
    await _firestoreService.deleteConsultationSession(session.id);
  }

  /// Save clinical note
  Future<void> saveClinicalNote({
    required String patientId,
    required String title,
    required String content,
    String? diagnosis,
    List<String> treatments = const [],
    List<String> followUpItems = const [],
  }) async {
    final note = ClinicalNote(
      patientId: patientId,
      title: title,
      content: content,
      diagnosis: diagnosis,
      treatments: treatments,
      followUpItems: followUpItems,
      createdBy: _authService.currentUser?.displayName ?? 'Doctor',
    );

    await _firestoreService.saveClinicalReport(note);
  }
}