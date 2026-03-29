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
      summary: json['summary']?.toString() ?? '',
      
      symptoms: _parseList(json['symptoms']),
      medicines: _parseList(json['medicines']),
    );
  }

  static List<String> _parseList(dynamic jsonValue) {
    if (jsonValue is! List) return [];
    return jsonValue
        .where((item) => item != null)
        .map((item) => item.toString())
        .toList();
  }

  Map<String, dynamic> toJson() {
    return {
      'summary': summary,
      'symptoms': symptoms,
      'medicines': medicines,
    };
  }
}
