import 'package:uuid/uuid.dart';

class ProviderPatientRecord {
  final String id;
  final String doctorId;
  final String firstName;
  final String lastName;
  final String dateOfBirth;
  final String gender;
  final String bloodType;
  final String contactNumber;
  final String email;
  final String lastVisitSummary;
  final List<String> prescriptions;
  final List<String> reports;
  final List<String> foodAllergies;
  final List<String> medicinalAllergies;
  final List<String> medicalHistory;
  final DateTime createdAt;
  final DateTime updatedAt;

  ProviderPatientRecord({
    required this.id,
    required this.doctorId,
    required this.firstName,
    required this.lastName,
    required this.dateOfBirth,
    required this.gender,
    required this.bloodType,
    required this.contactNumber,
    required this.email,
    required this.lastVisitSummary,
    this.prescriptions = const [],
    this.reports = const [],
    this.foodAllergies = const [],
    this.medicinalAllergies = const [],
    this.medicalHistory = const [],
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  String get fullName => '$firstName $lastName';

  List<String> get allergies => [...foodAllergies, ...medicinalAllergies];

  int get age {
    try {
      if (dateOfBirth.isEmpty) return 0;
      return DateTime.now().year - int.parse(dateOfBirth.split('-')[0]);
    } catch (_) {
      return 0;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'doctorId': doctorId,
      'firstName': firstName,
      'lastName': lastName,
      'dateOfBirth': dateOfBirth,
      'gender': gender,
      'bloodType': bloodType,
      'contactNumber': contactNumber,
      'email': email,
      'lastVisitSummary': lastVisitSummary,
      'prescriptions': prescriptions,
      'reports': reports,
      'foodAllergies': foodAllergies,
      'medicinalAllergies': medicinalAllergies,
      'medicalHistory': medicalHistory,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory ProviderPatientRecord.fromMap(Map<String, dynamic> map) {
    return ProviderPatientRecord(
      id: (map['id'] ?? '') is String ? map['id'] as String : '',
      doctorId: (map['doctorId'] ?? '') is String ? map['doctorId'] as String : '',
      firstName: (map['firstName'] ?? '') is String ? map['firstName'] as String : '',
      lastName: (map['lastName'] ?? '') is String ? map['lastName'] as String : '',
      dateOfBirth: (map['dateOfBirth'] ?? '1990-01-01') is String ? map['dateOfBirth'] as String : '1990-01-01',
      gender: (map['gender'] ?? 'Unknown') is String ? map['gender'] as String : 'Unknown',
      bloodType: (map['bloodType'] ?? 'Unknown') is String ? map['bloodType'] as String : 'Unknown',
      contactNumber: (map['contactNumber'] ?? '') is String ? map['contactNumber'] as String : '',
      email: (map['email'] ?? '') is String ? map['email'] as String : '',
      lastVisitSummary: (map['lastVisitSummary'] ?? 'No summary available.') is String ? map['lastVisitSummary'] as String : 'No summary available.',
      prescriptions: (map['prescriptions'] is List) ? List<String>.from(map['prescriptions']) : const [],
      reports: (map['reports'] is List) ? List<String>.from(map['reports']) : const [],
      foodAllergies: (map['foodAllergies'] is List) ? List<String>.from(map['foodAllergies']) : const [],
      medicinalAllergies: (map['medicinalAllergies'] is List) ? List<String>.from(map['medicinalAllergies']) : const [],
      medicalHistory: (map['medicalHistory'] is List) ? List<String>.from(map['medicalHistory']) : const [],
      createdAt: map['createdAt'] is String ? DateTime.tryParse(map['createdAt']) : null,
      updatedAt: map['updatedAt'] is String ? DateTime.tryParse(map['updatedAt']) : null,
    );
  }

  ProviderPatientRecord copyWith({
    String? id,
    String? doctorId,
    String? firstName,
    String? lastName,
    String? dateOfBirth,
    String? gender,
    String? bloodType,
    String? contactNumber,
    String? email,
    String? lastVisitSummary,
    List<String>? prescriptions,
    List<String>? reports,
    List<String>? foodAllergies,
    List<String>? medicinalAllergies,
    List<String>? medicalHistory,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProviderPatientRecord(
      id: id ?? this.id,
      doctorId: doctorId ?? this.doctorId,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      gender: gender ?? this.gender,
      bloodType: bloodType ?? this.bloodType,
      contactNumber: contactNumber ?? this.contactNumber,
      email: email ?? this.email,
      lastVisitSummary: lastVisitSummary ?? this.lastVisitSummary,
      prescriptions: prescriptions ?? this.prescriptions,
      reports: reports ?? this.reports,
      foodAllergies: foodAllergies ?? this.foodAllergies,
      medicinalAllergies: medicinalAllergies ?? this.medicinalAllergies,
      medicalHistory: medicalHistory ?? this.medicalHistory,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class PatientProfile {
  final String id;
  final String firstName;
  final String lastName;
  final String dateOfBirth;
  final String gender;
  final String bloodType;
  final String contactNumber;
  final String email;
  final List<String> allergies;
  final List<String> chronicConditions;
  final List<String> medications;
  final String emergencyContact;
  final String emergencyPhone;
  final DateTime createdAt;
  final DateTime updatedAt;

  PatientProfile({
    String? id,
    required this.firstName,
    required this.lastName,
    required this.dateOfBirth,
    required this.gender,
    required this.bloodType,
    required this.contactNumber,
    required this.email,
    this.allergies = const [],
    this.chronicConditions = const [],
    this.medications = const [],
    required this.emergencyContact,
    required this.emergencyPhone,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  PatientProfile copyWith({
    String? id,
    String? firstName,
    String? lastName,
    String? dateOfBirth,
    String? gender,
    String? bloodType,
    String? contactNumber,
    String? email,
    List<String>? allergies,
    List<String>? chronicConditions,
    List<String>? medications,
    String? emergencyContact,
    String? emergencyPhone,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PatientProfile(
      id: id ?? this.id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      gender: gender ?? this.gender,
      bloodType: bloodType ?? this.bloodType,
      contactNumber: contactNumber ?? this.contactNumber,
      email: email ?? this.email,
      allergies: allergies ?? this.allergies,
      chronicConditions: chronicConditions ?? this.chronicConditions,
      medications: medications ?? this.medications,
      emergencyContact: emergencyContact ?? this.emergencyContact,
      emergencyPhone: emergencyPhone ?? this.emergencyPhone,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  String get fullName => '$firstName $lastName';
  int get age {
    try {
      if (dateOfBirth.isEmpty) return 0;
      return DateTime.now().year - int.parse(dateOfBirth.split('-')[0]);
    } catch (_) {
      return 0;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'firstName': firstName,
      'lastName': lastName,
      'dateOfBirth': dateOfBirth,
      'gender': gender,
      'bloodType': bloodType,
      'contactNumber': contactNumber,
      'email': email,
      'allergies': allergies,
      'chronicConditions': chronicConditions,
      'medications': medications,
      'emergencyContact': emergencyContact,
      'emergencyPhone': emergencyPhone,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory PatientProfile.fromMap(Map<String, dynamic> map) {
    return PatientProfile(
      id: map['id'] as String?,
      firstName: map['firstName'] as String? ?? '',
      lastName: map['lastName'] as String? ?? '',
      dateOfBirth: map['dateOfBirth'] as String? ?? '1990-01-01',
      gender: map['gender'] as String? ?? 'Unknown',
      bloodType: map['bloodType'] as String? ?? 'Unknown',
      contactNumber: map['contactNumber'] as String? ?? '',
      email: map['email'] as String? ?? '',
      allergies: List<String>.from(map['allergies'] ?? const []),
      chronicConditions: List<String>.from(map['chronicConditions'] ?? const []),
      medications: List<String>.from(map['medications'] ?? const []),
      emergencyContact: map['emergencyContact'] as String? ?? '',
      emergencyPhone: map['emergencyPhone'] as String? ?? '',
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? ''),
      updatedAt: DateTime.tryParse(map['updatedAt'] as String? ?? ''),
    );
  }
}

class MedicalRecord {
  final String id;
  final String patientId;
  final String title;
  final String content;
  final String type; // 'consultation', 'prescription', 'report'
  final DateTime dateCreated;
  final String doctorName;
  final String? imagePath;
  final List<String> attachments;

  MedicalRecord({
    String? id,
    required this.patientId,
    required this.title,
    required this.content,
    required this.type,
    DateTime? dateCreated,
    required this.doctorName,
    this.imagePath,
    this.attachments = const [],
  })  : id = id ?? const Uuid().v4(),
        dateCreated = dateCreated ?? DateTime.now();

  MedicalRecord copyWith({
    String? id,
    String? patientId,
    String? title,
    String? content,
    String? type,
    DateTime? dateCreated,
    String? doctorName,
    String? imagePath,
    List<String>? attachments,
  }) {
    return MedicalRecord(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      title: title ?? this.title,
      content: content ?? this.content,
      type: type ?? this.type,
      dateCreated: dateCreated ?? this.dateCreated,
      doctorName: doctorName ?? this.doctorName,
      imagePath: imagePath ?? this.imagePath,
      attachments: attachments ?? this.attachments,
    );
  }
}

class VoiceSession {
  final String id;
  final String patientId;
  final String audioPath;
  final String transcription;
  final String summary;
  final String prescription;
  final DateTime startTime;
  final DateTime endTime;
  final String doctorName;
  final bool isProcessed;

  VoiceSession({
    String? id,
    required this.patientId,
    required this.audioPath,
    required this.transcription,
    required this.summary,
    required this.prescription,
    required this.startTime,
    required this.endTime,
    required this.doctorName,
    this.isProcessed = false,
  }) : id = id ?? const Uuid().v4();

  Duration get duration => endTime.difference(startTime);
  String get formattedDuration {
    int seconds = duration.inSeconds;
    int minutes = seconds ~/ 60;
    int secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }
}

class HealthMetric {
  final String id;
  final String patientId;
  final String metricType; // 'heart_rate', 'blood_pressure', 'temperature', 'oxygen'
  final double value;
  final String unit;
  final DateTime timestamp;
  final String? notes;

  HealthMetric({
    String? id,
    required this.patientId,
    required this.metricType,
    required this.value,
    required this.unit,
    DateTime? timestamp,
    this.notes,
  })  : id = id ?? const Uuid().v4(),
        timestamp = timestamp ?? DateTime.now();
}

class DocumentScan {
  final String id;
  final String patientId;
  final String imagePath;
  final String documentType; // 'lab_report', 'xray', 'scan', 'prescription'
  final String? extractedText;
  final String? analysis;
  final DateTime dateScanned;
  final bool isProcessed;

  DocumentScan({
    String? id,
    required this.patientId,
    required this.imagePath,
    required this.documentType,
    this.extractedText,
    this.analysis,
    DateTime? dateScanned,
    this.isProcessed = false,
  })  : id = id ?? const Uuid().v4(),
        dateScanned = dateScanned ?? DateTime.now();

  DocumentScan copyWith({
    String? id,
    String? patientId,
    String? imagePath,
    String? documentType,
    String? extractedText,
    String? analysis,
    DateTime? dateScanned,
    bool? isProcessed,
  }) {
    return DocumentScan(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      imagePath: imagePath ?? this.imagePath,
      documentType: documentType ?? this.documentType,
      extractedText: extractedText ?? this.extractedText,
      analysis: analysis ?? this.analysis,
      dateScanned: dateScanned ?? this.dateScanned,
      isProcessed: isProcessed ?? this.isProcessed,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'patientId': patientId,
      'imagePath': imagePath,
      'documentType': documentType,
      'extractedText': extractedText,
      'analysis': analysis,
      'dateScanned': dateScanned.toIso8601String(),
      'isProcessed': isProcessed,
    };
  }

  factory DocumentScan.fromMap(Map<String, dynamic> map) {
    return DocumentScan(
      id: map['id'] as String?,
      patientId: map['patientId'] as String? ?? '',
      imagePath: map['imagePath'] as String? ?? '',
      documentType: map['documentType'] as String? ?? 'scan',
      extractedText: map['extractedText'] as String?,
      analysis: map['analysis'] as String?,
      dateScanned: DateTime.tryParse(map['dateScanned'] as String? ?? ''),
      isProcessed: map['isProcessed'] as bool? ?? false,
    );
  }
}

class ClinicalNote {
  final String id;
  final String patientId;
  final String title;
  final String content;
  final String? diagnosis;
  final List<String> treatments;
  final List<String> followUpItems;
  final DateTime createdAt;
  final String createdBy; // doctor/nurse name
  final String? attachmentPath;

  ClinicalNote({
    String? id,
    required this.patientId,
    required this.title,
    required this.content,
    this.diagnosis,
    this.treatments = const [],
    this.followUpItems = const [],
    DateTime? createdAt,
    required this.createdBy,
    this.attachmentPath,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'patientId': patientId,
      'title': title,
      'content': content,
      'diagnosis': diagnosis,
      'treatments': treatments,
      'followUpItems': followUpItems,
      'createdAt': createdAt.toIso8601String(),
      'createdBy': createdBy,
      'attachmentPath': attachmentPath,
    };
  }

  factory ClinicalNote.fromMap(Map<String, dynamic> map) {
    return ClinicalNote(
      id: map['id'] as String?,
      patientId: map['patientId'] as String? ?? '',
      title: map['title'] as String? ?? '',
      content: map['content'] as String? ?? '',
      diagnosis: map['diagnosis'] as String?,
      treatments: List<String>.from(map['treatments'] ?? const []),
      followUpItems: List<String>.from(map['followUpItems'] ?? const []),
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? ''),
      createdBy: map['createdBy'] as String? ?? 'Unknown',
      attachmentPath: map['attachmentPath'] as String?,
    );
  }

  ClinicalNote copyWith({
    String? id,
    String? patientId,
    String? title,
    String? content,
    String? diagnosis,
    List<String>? treatments,
    List<String>? followUpItems,
    DateTime? createdAt,
    String? createdBy,
    String? attachmentPath,
  }) {
    return ClinicalNote(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      title: title ?? this.title,
      content: content ?? this.content,
      diagnosis: diagnosis ?? this.diagnosis,
      treatments: treatments ?? this.treatments,
      followUpItems: followUpItems ?? this.followUpItems,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
      attachmentPath: attachmentPath ?? this.attachmentPath,
    );
  }
}

class DoctorProfile {
  final String id;
  final String firstName;
  final String lastName;
  final String licenseNumber;
  final String specialty;
  final String hospitalName;
  final String contactNumber;
  final String email;
  final String? departmentName;
  final String? degree;

  DoctorProfile({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.licenseNumber,
    required this.specialty,
    required this.hospitalName,
    required this.contactNumber,
    required this.email,
    this.departmentName,
    this.degree,
  });

  String get fullName => '$firstName $lastName';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'firstName': firstName,
      'lastName': lastName,
      'licenseNumber': licenseNumber,
      'specialty': specialty,
      'hospitalName': hospitalName,
      'contactNumber': contactNumber,
      'email': email,
      'departmentName': departmentName,
      'degree': degree,
    };
  }

  factory DoctorProfile.fromMap(Map<String, dynamic> map) {
    return DoctorProfile(
      id: map['id'] as String? ?? '',
      firstName: map['firstName'] as String? ?? '',
      lastName: map['lastName'] as String? ?? '',
      licenseNumber: map['licenseNumber'] as String? ?? '',
      specialty: map['specialty'] as String? ?? '',
      hospitalName: map['hospitalName'] as String? ?? '',
      contactNumber: map['contactNumber'] as String? ?? '',
      email: map['email'] as String? ?? '',
      departmentName: map['departmentName'] as String?,
      degree: map['degree'] as String?,
    );
  }

  DoctorProfile copyWith({
    String? id,
    String? firstName,
    String? lastName,
    String? licenseNumber,
    String? specialty,
    String? hospitalName,
    String? contactNumber,
    String? email,
    String? departmentName,
    String? degree,
  }) {
    return DoctorProfile(
      id: id ?? this.id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      licenseNumber: licenseNumber ?? this.licenseNumber,
      specialty: specialty ?? this.specialty,
      hospitalName: hospitalName ?? this.hospitalName,
      contactNumber: contactNumber ?? this.contactNumber,
      email: email ?? this.email,
      departmentName: departmentName ?? this.departmentName,
      degree: degree ?? this.degree,
    );
  }
}

class ConsultationSession {
  final String id;
  final String doctorId;
  final String patientId;
  final String patientName;
  final String transcript;
  final String summary;
  final String prescription;
  final String source;
  final String? audioUrl;
  final int durationSeconds;
  final DateTime createdAt;
  final DateTime updatedAt;

  ConsultationSession({
    String? id,
    required this.doctorId,
    required this.patientId,
    required this.patientName,
    required this.transcript,
    required this.summary,
    this.prescription = '',
    this.source = 'voice',
    this.audioUrl,
    this.durationSeconds = 0,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  String get formattedDuration {
    final minutes = durationSeconds ~/ 60;
    final seconds = durationSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  bool get hasAudio => audioUrl != null && audioUrl!.isNotEmpty;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'doctorId': doctorId,
      'patientId': patientId,
      'patientName': patientName,
      'transcript': transcript,
      'summary': summary,
      'prescription': prescription,
      'source': source,
      'audioUrl': audioUrl,
      'durationSeconds': durationSeconds,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory ConsultationSession.fromMap(Map<String, dynamic> map) {
    return ConsultationSession(
      id: map['id'] as String?,
      doctorId: map['doctorId'] as String? ?? '',
      patientId: map['patientId'] as String? ?? '',
      patientName: map['patientName'] as String? ?? 'Unknown Patient',
      transcript: map['transcript'] as String? ?? '',
      summary: map['summary'] as String? ?? '',
      prescription: map['prescription'] as String? ?? '',
      source: map['source'] as String? ?? 'voice',
      audioUrl: map['audioUrl'] as String?,
      durationSeconds: map['durationSeconds'] as int? ?? 0,
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? ''),
      updatedAt: DateTime.tryParse(map['updatedAt'] as String? ?? ''),
    );
  }
}
