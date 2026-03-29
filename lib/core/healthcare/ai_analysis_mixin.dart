import 'package:flutter/material.dart';
import '../errors/app_error_handler.dart';
import '../../models/health_models.dart';
import 'healthcare_services_manager.dart';

/// Mixin that provides shared AI analysis functionality
/// Eliminates duplicate AI analysis patterns across healthcare screens
mixin AIAnalysisMixin<T extends StatefulWidget> on State<T> {
  bool _isAnalyzing = false;
  bool get isAnalyzing => _isAnalyzing;

  final HealthcareServicesManager _services = HealthcareServicesManager();

  /// Perform AI analysis with standardized loading states and error handling
  ///
  /// [prompt] - The AI prompt for analysis
  /// [patient] - Optional patient context for personalized analysis
  /// [imagePath] - Optional image path for vision analysis
  /// [onSuccess] - Callback when analysis completes successfully
  /// [onError] - Optional custom error handler
  Future<String?> performAIAnalysis({
    required String prompt,
    ProviderPatientRecord? patient,
    String? imagePath,
    void Function(String result)? onSuccess,
    void Function(dynamic error)? onError,
  }) async {
    if (_isAnalyzing) return null;

    setState(() => _isAnalyzing = true);

    try {
      final result = await _services.analyzeWithAI(
        prompt: prompt,
        patient: patient,
        imagePath: imagePath,
      );

      if (!mounted) return null;

      setState(() => _isAnalyzing = false);

      if (onSuccess != null) {
        onSuccess(result);
      }

      return result;
    } catch (error) {
      if (!mounted) return null;

      setState(() => _isAnalyzing = false);

      if (onError != null) {
        onError(error);
      } else {
        AppErrorHandler.showSnackBar(context, error);
      }

      return null;
    }
  }

  /// Perform AI analysis and show result in a bottom sheet
  Future<void> performAnalysisWithSheet({
    required String prompt,
    required String resultTitle,
    ProviderPatientRecord? patient,
    String? imagePath,
    Color? accentColor,
  }) async {
    final result = await performAIAnalysis(
      prompt: prompt,
      patient: patient,
      imagePath: imagePath,
    );

    if (result != null && mounted) {
      _showResultSheet(
        title: resultTitle,
        content: result,
        accentColor: accentColor,
      );
    }
  }

  /// Show analysis result in a standardized bottom sheet
  void _showResultSheet({
    required String title,
    required String content,
    Color? accentColor,
  }) {
    if (content.trim().isEmpty) {
      AppErrorHandler.showSnackBar(
        context,
        Exception('No $title available yet.'),
      );
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const Divider(),
              Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.6,
                ),
                child: SingleChildScrollView(
                  child: Text(
                    content,
                    style: const TextStyle(fontSize: 14, height: 1.4),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build specialized prompts for different healthcare analysis types
  String buildMedicationSafetyPrompt(List<String> medications) {
    final medicationList = medications.join(', ');
    return '''Analyze the following medications for safety:

Medications: $medicationList

Please provide:
1. **Drug Interactions**: Any potentially harmful interactions between these medications
2. **Contraindications**: Conditions or factors that contraindicate these medications
3. **Monitoring**: Key parameters to monitor (labs, vitals, symptoms)
4. **Safety Alerts**: Any critical warnings or precautions
5. **Recommendations**: Clinical recommendations for safe administration

Format the response clearly with headers and bullet points.''';
  }

  String buildShiftHandoffPrompt({
    required String patientSummary,
    required String overnightEvents,
    required String pendingTasks,
    required String keyIssues,
  }) {
    return '''Generate a comprehensive shift handoff report using the following information:

**Patient Summary:**
${patientSummary.isNotEmpty ? patientSummary : 'No summary provided'}

**Overnight Events:**
${overnightEvents.isNotEmpty ? overnightEvents : 'No events reported'}

**Pending Tasks:**
${pendingTasks.isNotEmpty ? pendingTasks : 'No pending tasks'}

**Key Issues/Concerns:**
${keyIssues.isNotEmpty ? keyIssues : 'No specific concerns'}

Please create a structured handoff report with:
1. **Patient Status**: Current condition and stability
2. **Overnight Events**: Summary of significant events
3. **Active Problems**: Current medical issues requiring attention
4. **Plan of Care**: Today's plan and pending tasks
5. **Alerts**: Any safety concerns or critical items
6. **Recommended Review**: Items the incoming clinician should review first

Format professionally for clinical handoff.''';
  }

  String buildDocumentAnalysisPrompt() {
    return '''Analyze this medical document image and provide:
1. **Document Type Confirmation**: What type of medical document this is
2. **Key Health Metrics/Values**: Important numbers, results, measurements
3. **Important Findings**: Significant medical findings or abnormalities
4. **Recommended Actions**: Clinical recommendations based on the results
5. **Risk Assessment**: Any concerning findings that need immediate attention

Provide the analysis in a structured format with clear headers.''';
  }

  String buildConsultationSummaryPrompt() {
    return 'Summarize the consultation transcript. Return sections: Chief Concerns, Assessment, Plan, Safety Flags, Follow-up.';
  }

  String buildPrescriptionPrompt() {
    return 'Based on the transcript, suggest a prescription draft with medication, dose, frequency, duration, cautions. Mention that final prescription is clinician-validated.';
  }
}