import 'medical_insights.dart';

class TranscriptionHistoryModel {
  final String transcript;
  final String summary;
  final List<String> symptoms;
  final List<String> medicines;
  final DateTime createdAt;

  const TranscriptionHistoryModel({
    required this.transcript,
    required this.summary,
    required this.symptoms,
    required this.medicines,
    required this.createdAt,
  });

  factory TranscriptionHistoryModel.fromJson(Map<String, dynamic> json) {
    return TranscriptionHistoryModel(
      transcript: json['transcript'] ?? '',
      summary: json['summary'] ?? '',
      // FIXED: Use null-coalescing and casting to prevent crashes on missing lists
      symptoms: (json['symptoms'] as List?)?.map((e) => e.toString()).toList() ?? [],
      medicines: (json['medicines'] as List?)?.map((e) => e.toString()).toList() ?? [],
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt']) 
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'transcript': transcript,
      'summary': summary,
      'symptoms': symptoms,
      'medicines': medicines,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
