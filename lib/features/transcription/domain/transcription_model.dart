class TranscriptionModel {
  final String rawTranscript;
  final String summary;
  final String prescription;

  const TranscriptionModel({
    this.rawTranscript = '',
    this.summary = '',
    this.prescription = '',
  });

  TranscriptionModel copyWith({
    String? rawTranscript,
    String? summary,
    String? prescription,
  }) {
    return TranscriptionModel(
      rawTranscript: rawTranscript ?? this.rawTranscript,
      summary: summary ?? this.summary,
      prescription: prescription ?? this.prescription,
    );
  }
}