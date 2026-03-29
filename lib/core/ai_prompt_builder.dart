import '../models/health_models.dart';

/// Utility class for building AI prompts with consistent patient context
/// Eliminates duplicate prompt construction across different clinical screens
class AIPromptBuilder {
  /// Build standardized patient context section for AI prompts
  static String buildPatientContext(ProviderPatientRecord? patient) {
    if (patient == null) return '';

    final foodAllergies = patient.foodAllergies.isEmpty
        ? 'None reported'
        : patient.foodAllergies.join(', ');
    final medicineAllergies = patient.medicinalAllergies.isEmpty
        ? 'None reported'
        : patient.medicinalAllergies.join(', ');
    final history = patient.medicalHistory.isEmpty
        ? 'No major history documented'
        : patient.medicalHistory.join(', ');

    return '''Patient: ${patient.fullName}
Age: ${patient.age}
Gender: ${patient.gender}
Known Allergies (food): $foodAllergies
Known Allergies (medicine): $medicineAllergies
Medical History: $history''';
  }

  /// Build comprehensive clinical assistant prompt with optional patient context
  static String buildGeneralClinicalPrompt({
    required String request,
    String? transcript,
    ProviderPatientRecord? patient,
  }) {
    final patientSection = patient != null ? '${buildPatientContext(patient)}\n\n' : '';
    final transcriptSection = transcript != null && transcript.isNotEmpty
        ? 'Transcript:\n$transcript\n\n'
        : '';

    return '''You are a clinical assistant for healthcare providers.

$patientSection${transcriptSection}Provider request:
$request

Rules:
- Be concise and clinically useful.
- Do not invent facts not present in transcript/context.
- Flag safety concerns and uncertain information.''';
  }

  /// Build medication safety analysis prompt
  static String buildMedicationSafetyPrompt({
    required List<String> medications,
    ProviderPatientRecord? patient,
  }) {
    final medicationList = medications.join(', ');
    final patientContext = patient != null
        ? '''${buildPatientContext(patient)}

'''
        : '';

    return '''${patientContext}You are a clinical pharmacology assistant. Analyze the following medications for safety:

Medications: $medicationList

Please provide:
1. **Drug Interactions**: Any potentially harmful interactions between these medications
2. **Contraindications**: Conditions or factors that contraindicate these medications
3. **Monitoring**: Key parameters to monitor (labs, vitals, symptoms)
4. **Safety Alerts**: Any critical warnings or precautions
5. **Recommendations**: Clinical recommendations for safe administration

Format the response clearly with headers and bullet points.''';
  }

  /// Build shift handoff report prompt
  static String buildHandoffPrompt({
    required Map<String, String> sections,
    ProviderPatientRecord? patient,
  }) {
    final patientInfo = patient != null
        ? '''${buildPatientContext(patient)}

'''
        : '';

    final patientSummary = sections['patientSummary'] ?? 'No summary provided';
    final overnightEvents = sections['overnightEvents'] ?? 'No events reported';
    final pendingTasks = sections['pendingTasks'] ?? 'No pending tasks';
    final keyIssues = sections['keyIssues'] ?? 'No specific concerns';

    return '''${patientInfo}Generate a comprehensive shift handoff report using the following information:

**Patient Summary:**
$patientSummary

**Overnight Events:**
$overnightEvents

**Pending Tasks:**
$pendingTasks

**Key Issues/Concerns:**
$keyIssues

Please create a structured handoff report with:
1. **Patient Status**: Current condition and stability
2. **Overnight Events**: Summary of significant events
3. **Active Problems**: Current medical issues requiring attention
4. **Plan of Care**: Today's plan and pending tasks
5. **Alerts**: Any safety concerns or critical items
6. **Recommended Review**: Items the incoming clinician should review first

Format professionally for clinical handoff.''';
  }

  /// Build clinical notes prompt
  static String buildClinicalNotesPrompt({
    required String content,
    String? noteType,
    ProviderPatientRecord? patient,
  }) {
    final patientContext = patient != null
        ? '''${buildPatientContext(patient)}

'''
        : '';

    final type = noteType ?? 'clinical note';

    return '''${patientContext}You are a clinical documentation assistant. Help organize and enhance this $type:

Content to process:
$content

Please provide:
1. **Structured Format**: Organize content with appropriate medical headings
2. **Clinical Accuracy**: Ensure medical terminology and formatting are correct
3. **Completeness Check**: Identify any missing critical information
4. **Documentation Standards**: Follow standard clinical documentation practices

Format as a professional clinical note suitable for medical records.''';
  }

  /// Build document analysis prompt for scanned documents
  static String buildDocumentAnalysisPrompt({
    required String documentText,
    String? documentType,
    ProviderPatientRecord? patient,
  }) {
    final patientContext = patient != null
        ? '''${buildPatientContext(patient)}

'''
        : '';

    final type = documentType ?? 'medical document';

    return '''${patientContext}You are a clinical document analysis assistant. Analyze this $type:

Document Content:
$documentText

Please provide:
1. **Document Summary**: Key findings and information
2. **Clinical Relevance**: Important medical information extracted
3. **Action Items**: Any follow-up actions or recommendations
4. **Data Extraction**: Key dates, values, medications, or diagnoses
5. **Quality Assessment**: Note any unclear or missing information

Focus on clinically relevant information for healthcare providers.''';
  }

  /// Build prescription review prompt
  static String buildPrescriptionReviewPrompt({
    required String prescriptionContent,
    ProviderPatientRecord? patient,
  }) {
    final patientContext = patient != null
        ? '''${buildPatientContext(patient)}

'''
        : '';

    return '''${patientContext}You are a clinical pharmacy assistant. Review this prescription:

Prescription:
$prescriptionContent

Please analyze:
1. **Dosing Accuracy**: Verify doses are appropriate for patient age/condition
2. **Drug Interactions**: Check for interactions with known medications/allergies
3. **Contraindications**: Identify any contraindications based on patient history
4. **Monitoring Requirements**: Lab work or clinical monitoring needed
5. **Patient Education**: Key counseling points for the patient
6. **Safety Alerts**: Any critical safety considerations

Provide clinical recommendations for safe prescribing.''';
  }
}