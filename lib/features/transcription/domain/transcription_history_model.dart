import 'medical_insights.dart';

class TranscriptionModel {
  final String rawTranscript;
  final String summary;
  final String prescription;
  final MedicalInsights? insights;

  const TranscriptionModel({
    this.rawTranscript = '',
    this.summary = '',
    this.prescription = '',
    this.insights,
  });

  TranscriptionModel copyWith({
    String? rawTranscript,
    String? summary,
    String? prescription,
    MedicalInsights? insights,
  }) {
    return TranscriptionModel(
      rawTranscript: rawTranscript ?? this.rawTranscript,
      summary: summary ?? this.summary,
      prescription: prescription ?? this.prescription,
      insights: insights ?? this.insights,
    );
  }
}
