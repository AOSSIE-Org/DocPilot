class TranscriptionHistoryModel {
  final String transcript;
  final String summary;
  final List<String> symptoms;
  final List<String> medicines;
  final DateTime createdAt;

  TranscriptionHistoryModel({
    required this.transcript,
    required this.summary,
    required this.symptoms,
    required this.medicines,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'transcript': transcript,
        'summary': summary,
        'symptoms': symptoms,
        'medicines': medicines,
        'createdAt': createdAt.toIso8601String(),
      };

  factory TranscriptionHistoryModel.fromJson(Map<String, dynamic> json) {
    return TranscriptionHistoryModel(
      transcript: json['transcript'],
      summary: json['summary'],
      symptoms: List<String>.from(json['symptoms']),
      medicines: List<String>.from(json['medicines']),
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}