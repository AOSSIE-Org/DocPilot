class MedicalInsights {
  final String summary;
  final List<String> symptoms;
  final List<String> medicines;

  MedicalInsights({
    required this.summary,
    required this.symptoms,
    required this.medicines,
  });

  factory MedicalInsights.fromJson(Map<String, dynamic> json) {
    return MedicalInsights(
      summary: json['summary'] ?? '',
      symptoms: List<String>.from(json['symptoms'] ?? []),
      medicines: List<String>.from(json['medicines'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'summary': summary,
      'symptoms': symptoms,
      'medicines': medicines,
    };
  }
}