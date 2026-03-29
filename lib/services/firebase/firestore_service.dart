import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/config/firebase_config.dart';
import '../../core/errors/app_exception.dart';
import '../../models/health_models.dart';
import 'firebase_bootstrap_service.dart';

class FirestoreService {
  static final Map<String, List<ProviderPatientRecord>> _patientsCacheByDoctor = {};
  static final Map<String, List<ClinicalNote>> _clinicalCacheByPatient = {};
  static final Map<String, List<ConsultationSession>> _consultationCacheByKey = {};
  static final Map<String, List<DocumentScan>> _documentScansCacheByPatient = {};

  /// Clears all static caches. Call this on user logout to prevent data leakage.
  static void clearAllCaches() {
    _patientsCacheByDoctor.clear();
    _clinicalCacheByPatient.clear();
    _consultationCacheByKey.clear();
    _documentScansCacheByPatient.clear();
  }

  bool get _isFirebaseAvailable =>
      FirebaseConfig.isEnabled && FirebaseBootstrapService.isInitialized;

  bool get isFirebaseAvailable => _isFirebaseAvailable;

  FirebaseFirestore? get _firestore {
    if (!_isFirebaseAvailable) return null;
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  FirebaseFirestore _requireFirestore() {
    final firestore = _firestore;
    if (firestore == null) {
      throw const AppException(
        code: 'firestore-not-configured',
        message: 'Firestore is not configured yet.',
      );
    }
    return firestore;
  }

  CollectionReference<Map<String, dynamic>> get _clinicalReportsCollection =>
      _requireFirestore().collection('clinical_reports');

  CollectionReference<Map<String, dynamic>> get _patientsCollection =>
      _requireFirestore().collection('patients');

  CollectionReference<Map<String, dynamic>> get _doctorsCollection =>
      _requireFirestore().collection('doctors');

  CollectionReference<Map<String, dynamic>> get _usersCollection =>
      _requireFirestore().collection('users');

  CollectionReference<Map<String, dynamic>> get _consultationSessionsCollection =>
      _requireFirestore().collection('consultation_sessions');

  CollectionReference<Map<String, dynamic>> get _documentScansCollection =>
      _requireFirestore().collection('document_scans');

  String _consultationCacheKey(String doctorId, String? patientId) {
    final patientSegment = (patientId ?? '').trim();
    return '$doctorId::$patientSegment';
  }

  Future<void> saveClinicalReport(ClinicalNote note) async {
    if (!_isFirebaseAvailable) return;

    try {
      await _clinicalReportsCollection.doc(note.id).set(note.toMap());
    } catch (error) {
      throw AppException(
        code: 'save-clinical-report-failed',
        message: 'Unable to save clinical report to cloud.',
        cause: error,
      );
    }
  }

  Future<void> updateClinicalReport(ClinicalNote note) async {
    if (!_isFirebaseAvailable) return;

    try {
      await _clinicalReportsCollection.doc(note.id).update(note.toMap());
    } catch (error) {
      throw AppException(
        code: 'update-clinical-report-failed',
        message: 'Unable to update clinical report in cloud.',
        cause: error,
      );
    }
  }

  Stream<List<ClinicalNote>> watchClinicalReports(String patientId) {
    if (!_isFirebaseAvailable) {
      return Stream.value(_clinicalCacheByPatient[patientId] ?? const []);
    }

    return _clinicalReportsCollection
        .where('patientId', isEqualTo: patientId)
        .snapshots()
        .map(
          (snapshot) {
            final notes = snapshot.docs
              .map((doc) => ClinicalNote.fromMap(doc.data()))
              .toList()
              ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
            _clinicalCacheByPatient[patientId] = notes;
            return notes;
          },
        );
  }

  Future<List<ClinicalNote>> getClinicalReports(String patientId) async {
    if (!_isFirebaseAvailable) {
      return _clinicalCacheByPatient[patientId] ?? const [];
    }

    try {
      final snapshot = await _clinicalReportsCollection
          .where('patientId', isEqualTo: patientId)
          .get(const GetOptions(source: Source.serverAndCache));
      final notes = snapshot.docs
          .map((doc) => ClinicalNote.fromMap(doc.data()))
          .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _clinicalCacheByPatient[patientId] = notes;
      return notes;
    } catch (_) {
      return _clinicalCacheByPatient[patientId] ?? const [];
    }
  }

  Future<void> saveDeviceToken({
    required String userId,
    required String token,
  }) async {
    if (!_isFirebaseAvailable) return;

    await _usersCollection.doc(userId).set(
      {
        'fcmToken': token,
        'updatedAt': DateTime.now().toIso8601String(),
      },
      SetOptions(merge: true),
    );
  }

  Stream<List<ProviderPatientRecord>> watchDoctorPatients(String doctorId) {
    if (!_isFirebaseAvailable) {
      return Stream.value(_patientsCacheByDoctor[doctorId] ?? const []);
    }

    return _patientsCollection
        .where('doctorId', isEqualTo: doctorId)
        .snapshots()
        .map(
          (snapshot) {
            final patients = snapshot.docs
              .map((doc) => ProviderPatientRecord.fromMap(doc.data()))
              .toList()
              ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
            _patientsCacheByDoctor[doctorId] = patients;
            return patients;
          },
        );
  }

  Future<List<ProviderPatientRecord>> getDoctorPatients(String doctorId) async {
    if (!_isFirebaseAvailable) {
      return _patientsCacheByDoctor[doctorId] ?? const [];
    }

    try {
      final snapshot = await _patientsCollection
          .where('doctorId', isEqualTo: doctorId)
          .get();
      final patients = snapshot.docs
          .map((doc) => ProviderPatientRecord.fromMap(doc.data()))
          .toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      _patientsCacheByDoctor[doctorId] = patients;
      return patients;
    } catch (_) {
      return _patientsCacheByDoctor[doctorId] ?? const [];
    }
  }

  Future<void> savePatientRecord(ProviderPatientRecord record) async {
    if (!_isFirebaseAvailable) return;

    try {
      await _patientsCollection.doc(record.id).set(record.toMap());
    } catch (error) {
      throw AppException(
        code: 'save-patient-record-failed',
        message: 'Unable to save patient record to cloud.',
        cause: error,
      );
    }
  }

  /// Delete a patient record from Firestore
  Future<void> deletePatientRecord(String patientId) async {
    if (!_isFirebaseAvailable) return;

    try {
      await _patientsCollection.doc(patientId).delete();
      // Clear from cache
      for (final key in _patientsCacheByDoctor.keys) {
        _patientsCacheByDoctor[key]?.removeWhere((p) => p.id == patientId);
      }
    } catch (error) {
      throw AppException(
        code: 'delete-patient-record-failed',
        message: 'Unable to delete patient record from cloud.',
        cause: error,
      );
    }
  }

  /// Delete a clinical report from Firestore
  Future<void> deleteClinicalReport(String reportId) async {
    if (!_isFirebaseAvailable) return;

    try {
      await _clinicalReportsCollection.doc(reportId).delete();
      // Clear from cache
      for (final key in _clinicalCacheByPatient.keys) {
        _clinicalCacheByPatient[key]?.removeWhere((r) => r.id == reportId);
      }
    } catch (error) {
      throw AppException(
        code: 'delete-clinical-report-failed',
        message: 'Unable to delete clinical report from cloud.',
        cause: error,
      );
    }
  }

  /// Delete a consultation session from Firestore
  Future<void> deleteConsultationSession(String sessionId) async {
    if (!_isFirebaseAvailable) return;

    try {
      await _consultationSessionsCollection.doc(sessionId).delete();
      // Clear from cache
      for (final key in _consultationCacheByKey.keys) {
        _consultationCacheByKey[key]?.removeWhere((s) => s.id == sessionId);
      }
    } catch (error) {
      throw AppException(
        code: 'delete-consultation-session-failed',
        message: 'Unable to delete consultation session from cloud.',
        cause: error,
      );
    }
  }

  /// Delete a document scan from Firestore
  Future<void> deleteDocumentScan(String scanId) async {
    if (!_isFirebaseAvailable) return;

    try {
      await _documentScansCollection.doc(scanId).delete();
      // Clear from cache
      for (final key in _documentScansCacheByPatient.keys) {
        _documentScansCacheByPatient[key]?.removeWhere((s) => s.id == scanId);
      }
    } catch (error) {
      throw AppException(
        code: 'delete-document-scan-failed',
        message: 'Unable to delete document scan from cloud.',
        cause: error,
      );
    }
  }

  Future<Map<String, dynamic>?> loadRuntimeApiConfig() async {
    if (!_isFirebaseAvailable) return null;
    final snapshot = await _requireFirestore()
        .collection(FirebaseConfig.apiKeysCollection)
        .doc(FirebaseConfig.apiKeysDocument)
        .get();
    return snapshot.data();
  }

  /// Save doctor profile to Firestore 'doctors' collection
  /// Uses doctor ID as the document ID for easy retrieval
  Future<void> saveDoctorProfile(DoctorProfile profile) async {
    if (!_isFirebaseAvailable) return;

    try {
      await _doctorsCollection.doc(profile.id).set(
        {
          ...profile.toMap(),
          'updatedAt': DateTime.now().toIso8601String(),
        },
        SetOptions(merge: true),
      );
    } catch (error) {
      throw AppException(
        code: 'save-doctor-profile-failed',
        message: 'Unable to save doctor profile to cloud.',
        cause: error,
      );
    }
  }

  /// Load doctor profile from Firestore 'doctors' collection
  Future<DoctorProfile?> loadDoctorProfile(String doctorId) async {
    if (!_isFirebaseAvailable) return null;

    try {
      final snapshot = await _doctorsCollection.doc(doctorId).get();
      if (!snapshot.exists) return null;
      return DoctorProfile.fromMap(snapshot.data() ?? {});
    } catch (error) {
      throw AppException(
        code: 'load-doctor-profile-failed',
        message: 'Unable to load doctor profile from cloud.',
        cause: error,
      );
    }
  }

  /// Watch doctor profile changes in real-time
  /// Returns a stream of doctor profile updates
  Stream<DoctorProfile?> watchDoctorProfile(String doctorId) {
    if (!_isFirebaseAvailable) {
      return const Stream<DoctorProfile?>.empty();
    }

    return _doctorsCollection.doc(doctorId).snapshots().map(
      (snapshot) {
        if (!snapshot.exists) return null;
        return DoctorProfile.fromMap(snapshot.data() ?? {});
      },
    );
  }

  Future<void> saveConsultationSession(ConsultationSession session) async {
    if (!_isFirebaseAvailable) return;

    try {
      await _consultationSessionsCollection.doc(session.id).set(session.toMap());
    } catch (error) {
      throw AppException(
        code: 'save-consultation-session-failed',
        message: 'Unable to save consultation session to cloud.',
        cause: error,
      );
    }
  }

  Stream<List<ConsultationSession>> watchConsultationHistory({
    required String doctorId,
    String? patientId,
    int limit = 20,
  }) {
    final cacheKey = _consultationCacheKey(doctorId, patientId);
    if (!_isFirebaseAvailable) {
      return Stream.value(_consultationCacheByKey[cacheKey] ?? const []);
    }

    Query<Map<String, dynamic>> query =
      _consultationSessionsCollection.where('doctorId', isEqualTo: doctorId);

    if (patientId != null && patientId.isNotEmpty) {
      query = query.where('patientId', isEqualTo: patientId);
    }

    return query.snapshots().map((snapshot) {
      final sessions = snapshot.docs
          .map((doc) => ConsultationSession.fromMap(doc.data()))
          .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      final mapped = sessions.take(limit).toList();
      _consultationCacheByKey[cacheKey] = mapped;
      return mapped;
    });
  }

  Future<List<ConsultationSession>> getConsultationHistory({
    required String doctorId,
    String? patientId,
    int limit = 20,
  }) async {
    final cacheKey = _consultationCacheKey(doctorId, patientId);
    if (!_isFirebaseAvailable) {
      return _consultationCacheByKey[cacheKey] ?? const [];
    }

    Query<Map<String, dynamic>> query =
      _consultationSessionsCollection.where('doctorId', isEqualTo: doctorId);

    if (patientId != null) {
      query = query.where('patientId', isEqualTo: patientId);
    }

    try {
      final snapshot = await query.get(
        const GetOptions(source: Source.serverAndCache),
      );
      final sessions = snapshot.docs
          .map((doc) => ConsultationSession.fromMap(doc.data()))
          .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      final mapped = sessions.take(limit).toList();
      _consultationCacheByKey[cacheKey] = mapped;
      return mapped;
    } catch (_) {
      return _consultationCacheByKey[cacheKey] ?? const [];
    }
  }

  Future<void> saveDocumentScan(DocumentScan scan) async {
    if (!_isFirebaseAvailable) return;

    try {
      await _documentScansCollection.doc(scan.id).set(scan.toMap());
    } catch (error) {
      throw AppException(
        code: 'save-document-scan-failed',
        message: 'Unable to save document scan to cloud.',
        cause: error,
      );
    }
  }

  Stream<List<DocumentScan>> watchDocumentScans(String patientId) {
    if (!_isFirebaseAvailable) {
      return Stream.value(_documentScansCacheByPatient[patientId] ?? const []);
    }

    return _documentScansCollection
        .where('patientId', isEqualTo: patientId)
        .snapshots()
        .map(
          (snapshot) {
            final scans = snapshot.docs
              .map((doc) => DocumentScan.fromMap(doc.data()))
              .toList()
              ..sort((a, b) => b.dateScanned.compareTo(a.dateScanned));
            _documentScansCacheByPatient[patientId] = scans;
      return scans;
    });
  }
}
