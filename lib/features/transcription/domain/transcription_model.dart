import 'medical_insights.dart';

class TranscriptionModel {
  final String rawTranscript;
  final MedicalInsights? insights;

  const TranscriptionModel({
    this.rawTranscript = '',
    this.insights,
  });

  TranscriptionModel copyWith({
    String? rawTranscript,
    MedicalInsights? insights,
  }) {
    return TranscriptionModel(
      rawTranscript: rawTranscript ?? this.rawTranscript,
      insights: insights ?? this.insights,
    );
  }
}