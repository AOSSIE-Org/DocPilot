/// Model class representing doctor information for PDF customization
class DoctorInfo {
  final String name;
  final String licenseNumber;
  final String specialization;
  final String phone;
  final String email;

  const DoctorInfo({
    required this.name,
    required this.licenseNumber,
    required this.specialization,
    required this.phone,
    required this.email,
  });

  /// Creates a DoctorInfo from JSON
  factory DoctorInfo.fromJson(Map<String, dynamic> json) {
    return DoctorInfo(
      name: json['name'] as String? ?? '',
      licenseNumber: json['licenseNumber'] as String? ?? '',
      specialization: json['specialization'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      email: json['email'] as String? ?? '',
    );
  }

  /// Converts DoctorInfo to JSON
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'licenseNumber': licenseNumber,
      'specialization': specialization,
      'phone': phone,
      'email': email,
    };
  }

  /// Creates an empty DoctorInfo
  factory DoctorInfo.empty() {
    return const DoctorInfo(
      name: '',
      licenseNumber: '',
      specialization: '',
      phone: '',
      email: '',
    );
  }

  /// Checks if the doctor info is complete
  bool get isComplete {
    return name.isNotEmpty &&
        licenseNumber.isNotEmpty &&
        specialization.isNotEmpty;
  }

  /// Creates a copy with updated fields
  DoctorInfo copyWith({
    String? name,
    String? licenseNumber,
    String? specialization,
    String? phone,
    String? email,
  }) {
    return DoctorInfo(
      name: name ?? this.name,
      licenseNumber: licenseNumber ?? this.licenseNumber,
      specialization: specialization ?? this.specialization,
      phone: phone ?? this.phone,
      email: email ?? this.email,
    );
  }
}

/// Model class representing clinic information for PDF customization
class ClinicInfo {
  final String name;
  final String address;
  final String city;
  final String phone;
  final String email;
  final String website;

  const ClinicInfo({
    required this.name,
    required this.address,
    required this.city,
    required this.phone,
    required this.email,
    required this.website,
  });

  /// Creates a ClinicInfo from JSON
  factory ClinicInfo.fromJson(Map<String, dynamic> json) {
    return ClinicInfo(
      name: json['name'] as String? ?? '',
      address: json['address'] as String? ?? '',
      city: json['city'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      email: json['email'] as String? ?? '',
      website: json['website'] as String? ?? '',
    );
  }

  /// Converts ClinicInfo to JSON
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'address': address,
      'city': city,
      'phone': phone,
      'email': email,
      'website': website,
    };
  }

  /// Creates an empty ClinicInfo
  factory ClinicInfo.empty() {
    return const ClinicInfo(
      name: '',
      address: '',
      city: '',
      phone: '',
      email: '',
      website: '',
    );
  }

  /// Checks if the clinic info is complete
  bool get isComplete {
    return name.isNotEmpty && address.isNotEmpty && city.isNotEmpty;
  }

  /// Creates a copy with updated fields
  ClinicInfo copyWith({
    String? name,
    String? address,
    String? city,
    String? phone,
    String? email,
    String? website,
  }) {
    return ClinicInfo(
      name: name ?? this.name,
      address: address ?? this.address,
      city: city ?? this.city,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      website: website ?? this.website,
    );
  }
}

/// Model class representing PDF template preferences
class PdfTemplate {
  final String headerColor;
  final bool includeDoctorInfo;
  final bool includeClinicInfo;
  final bool includePatientInfo;
  final String footerText;

  const PdfTemplate({
    this.headerColor = 'deepPurple',
    this.includeDoctorInfo = true,
    this.includeClinicInfo = true,
    this.includePatientInfo = false,
    this.footerText = '',
  });

  /// Creates a PdfTemplate from JSON
  factory PdfTemplate.fromJson(Map<String, dynamic> json) {
    return PdfTemplate(
      headerColor: json['headerColor'] as String? ?? 'deepPurple',
      includeDoctorInfo: json['includeDoctorInfo'] as bool? ?? true,
      includeClinicInfo: json['includeClinicInfo'] as bool? ?? true,
      includePatientInfo: json['includePatientInfo'] as bool? ?? false,
      footerText: json['footerText'] as String? ?? '',
    );
  }

  /// Converts PdfTemplate to JSON
  Map<String, dynamic> toJson() {
    return {
      'headerColor': headerColor,
      'includeDoctorInfo': includeDoctorInfo,
      'includeClinicInfo': includeClinicInfo,
      'includePatientInfo': includePatientInfo,
      'footerText': footerText,
    };
  }

  /// Creates a copy with updated fields
  PdfTemplate copyWith({
    String? headerColor,
    bool? includeDoctorInfo,
    bool? includeClinicInfo,
    bool? includePatientInfo,
    String? footerText,
  }) {
    return PdfTemplate(
      headerColor: headerColor ?? this.headerColor,
      includeDoctorInfo: includeDoctorInfo ?? this.includeDoctorInfo,
      includeClinicInfo: includeClinicInfo ?? this.includeClinicInfo,
      includePatientInfo: includePatientInfo ?? this.includePatientInfo,
      footerText: footerText ?? this.footerText,
    );
  }
}
