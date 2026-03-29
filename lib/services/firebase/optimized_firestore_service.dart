import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../core/config/firebase_config.dart';
import '../../core/errors/app_exception.dart';
import '../../models/health_models.dart';
import 'firebase_bootstrap_service.dart';

/// Enhanced Firestore service with optimized queries, batch operations, and smart caching
class OptimizedFirestoreService {
  static final Map<String, List<ProviderPatientRecord>> _patientsCacheByDoctor = {};
  static final Map<String, List<ClinicalNote>> _clinicalCacheByPatient = {};
  static final Map<String, List<ConsultationSession>> _consultationCacheByKey = {};
  static final Map<String, List<DocumentScan>> _documentScansCacheByPatient = {};
  static final Map<String, DateTime> _cacheTimestamps = {};

  // Cache TTL configurations
  static const Duration _patientsCacheTTL = Duration(minutes: 30);
  static const Duration _clinicalNotesCacheTTL = Duration(minutes: 15);
  static const Duration _consultationsCacheTTL = Duration(minutes: 10);
  static const Duration _documentScansCacheTTL = Duration(minutes: 20);

  /// Clears all static caches and timestamps
  static void clearAllCaches() {
    _patientsCacheByDoctor.clear();
    _clinicalCacheByPatient.clear();
    _consultationCacheByKey.clear();
    _documentScansCacheByPatient.clear();
    _cacheTimestamps.clear();
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

  // Collection references with optimized settings
  CollectionReference<Map<String, dynamic>> get _clinicalReportsCollection =>
      _requireFirestore().collection('clinical_reports');

  CollectionReference<Map<String, dynamic>> get _patientsCollection =>
      _requireFirestore().collection('patients');

  CollectionReference<Map<String, dynamic>> get _consultationSessionsCollection =>
      _requireFirestore().collection('consultation_sessions');

  CollectionReference<Map<String, dynamic>> get _documentScansCollection =>
      _requireFirestore().collection('document_scans');

  /// Check if cache is still valid
  bool _isCacheValid(String key, Duration ttl) {
    final timestamp = _cacheTimestamps[key];
    if (timestamp == null) return false;
    return DateTime.now().difference(timestamp) < ttl;
  }

  /// Update cache timestamp
  void _updateCacheTimestamp(String key) {
    _cacheTimestamps[key] = DateTime.now();
  }

  /// Generate cache key for consultations
  String _consultationCacheKey(String doctorId, String? patientId) {
    final patientSegment = (patientId ?? '').trim();
    return '$doctorId::$patientSegment';
  }

  // OPTIMIZED BATCH OPERATIONS

  /// Batch save multiple patients
  Future<void> batchSavePatients(List<ProviderPatientRecord> patients) async {
    if (!_isFirebaseAvailable || patients.isEmpty) return;

    final firestore = _requireFirestore();
    final batch = firestore.batch();

    try {
      for (final patient in patients) {
        final docRef = _patientsCollection.doc(patient.id);
        batch.set(docRef, patient.toMap());
      }

      await batch.commit();

      // Update cache for each doctor
      for (final patient in patients) {
        final doctorPatients = _patientsCacheByDoctor[patient.doctorId] ?? [];
        final existingIndex = doctorPatients.indexWhere((p) => p.id == patient.id);

        if (existingIndex != -1) {
          doctorPatients[existingIndex] = patient;
        } else {
          doctorPatients.insert(0, patient);
        }

        _patientsCacheByDoctor[patient.doctorId] = doctorPatients;
        _updateCacheTimestamp('patients_${patient.doctorId}');
      }
    } catch (error) {
      throw AppException(
        code: 'batch-save-patients-failed',
        message: 'Unable to batch save patients to cloud.',
        cause: error,
      );
    }
  }

  /// Batch save multiple clinical notes
  Future<void> batchSaveClinicalNotes(List<ClinicalNote> notes) async {
    if (!_isFirebaseAvailable || notes.isEmpty) return;

    final firestore = _requireFirestore();
    final batch = firestore.batch();

    try {
      for (final note in notes) {
        final docRef = _clinicalReportsCollection.doc(note.id);
        batch.set(docRef, note.toMap());
      }

      await batch.commit();

      // Update cache for each patient
      for (final note in notes) {
        final patientNotes = _clinicalCacheByPatient[note.patientId] ?? [];
        final existingIndex = patientNotes.indexWhere((n) => n.id == note.id);

        if (existingIndex != -1) {
          patientNotes[existingIndex] = note;
        } else {
          patientNotes.insert(0, note);
        }

        patientNotes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        _clinicalCacheByPatient[note.patientId] = patientNotes;
        _updateCacheTimestamp('clinical_notes_${note.patientId}');
      }
    } catch (error) {
      throw AppException(
        code: 'batch-save-clinical-notes-failed',
        message: 'Unable to batch save clinical notes to cloud.',
        cause: error,
      );
    }
  }

  // OPTIMIZED QUERY METHODS with caching

  /// Get patients for doctor with optimized caching
  Future<List<ProviderPatientRecord>> getDoctorPatientsOptimized(
    String doctorId, {
    bool useCache = true,
    int? limit,
    DateTime? lastUpdatedAfter,
  }) async {
    final cacheKey = 'patients_$doctorId';

    // Check cache first if enabled
    if (useCache && _isCacheValid(cacheKey, _patientsCacheTTL)) {
      var cached = _patientsCacheByDoctor[doctorId] ?? [];
      if (limit != null) cached = cached.take(limit).toList();
      return cached;
    }

    if (!_isFirebaseAvailable) {
      return _patientsCacheByDoctor[doctorId] ?? const [];
    }

    try {
      Query<Map<String, dynamic>> query = _patientsCollection
          .where('doctorId', isEqualTo: doctorId);

      // Add date filter if provided
      if (lastUpdatedAfter != null) {
        query = query.where('updatedAt', isGreaterThan: lastUpdatedAfter.toIso8601String());
      }

      // Add limit and ordering
      query = query.orderBy('updatedAt', descending: true);
      if (limit != null) {
        query = query.limit(limit);
      }

      final snapshot = await query.get(const GetOptions(source: Source.serverAndCache));

      final patients = snapshot.docs
          .map((doc) => ProviderPatientRecord.fromMap(doc.data()))
          .toList();

      // Update cache
      _patientsCacheByDoctor[doctorId] = patients;
      _updateCacheTimestamp(cacheKey);

      return patients;
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[OptimizedFirestoreService] Failed to get patients: $error');
      }
      return _patientsCacheByDoctor[doctorId] ?? const [];
    }
  }

  /// Get clinical notes with pagination and caching
  Future<List<ClinicalNote>> getClinicalNotesOptimized(
    String patientId, {
    bool useCache = true,
    int limit = 20,
    DocumentSnapshot? startAfter,
    DateTime? dateFilter,
  }) async {
    final cacheKey = 'clinical_notes_$patientId';

    // Check cache for initial load
    if (useCache && startAfter == null && _isCacheValid(cacheKey, _clinicalNotesCacheTTL)) {
      var cached = _clinicalCacheByPatient[patientId] ?? [];
      if (dateFilter != null) {
        cached = cached.where((note) => note.createdAt.isAfter(dateFilter)).toList();
      }
      return cached.take(limit).toList();
    }

    if (!_isFirebaseAvailable) {
      return _clinicalCacheByPatient[patientId] ?? const [];
    }

    try {
      Query<Map<String, dynamic>> query = _clinicalReportsCollection
          .where('patientId', isEqualTo: patientId)
          .orderBy('createdAt', descending: true);

      // Add date filter
      if (dateFilter != null) {
        query = query.where('createdAt', isGreaterThan: dateFilter.toIso8601String());
      }

      // Add pagination
      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      query = query.limit(limit);

      final snapshot = await query.get(const GetOptions(source: Source.serverAndCache));

      final notes = snapshot.docs
          .map((doc) => ClinicalNote.fromMap(doc.data()))
          .toList();

      // Update cache only for initial load
      if (startAfter == null) {
        _clinicalCacheByPatient[patientId] = notes;
        _updateCacheTimestamp(cacheKey);
      }

      return notes;
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[OptimizedFirestoreService] Failed to get clinical notes: $error');
      }
      return _clinicalCacheByPatient[patientId] ?? const [];
    }
  }

  /// Optimized consultation history with smart caching
  Future<List<ConsultationSession>> getConsultationHistoryOptimized({
    required String doctorId,
    String? patientId,
    int limit = 20,
    bool useCache = true,
    DocumentSnapshot? startAfter,
  }) async {
    final cacheKey = _consultationCacheKey(doctorId, patientId);

    // Check cache for initial load
    if (useCache && startAfter == null && _isCacheValid(cacheKey, _consultationsCacheTTL)) {
      return _consultationCacheByKey[cacheKey] ?? const [];
    }

    if (!_isFirebaseAvailable) {
      return _consultationCacheByKey[cacheKey] ?? const [];
    }

    try {
      Query<Map<String, dynamic>> query = _consultationSessionsCollection
          .where('doctorId', isEqualTo: doctorId);

      if (patientId != null && patientId.isNotEmpty) {
        query = query.where('patientId', isEqualTo: patientId);
      }

      query = query.orderBy('createdAt', descending: true);

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      query = query.limit(limit);

      final snapshot = await query.get(const GetOptions(source: Source.serverAndCache));

      final sessions = snapshot.docs
          .map((doc) => ConsultationSession.fromMap(doc.data()))
          .toList();

      // Update cache only for initial load
      if (startAfter == null) {
        _consultationCacheByKey[cacheKey] = sessions;
        _updateCacheTimestamp(cacheKey);
      }

      return sessions;
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[OptimizedFirestoreService] Failed to get consultation history: $error');
      }
      return _consultationCacheByKey[cacheKey] ?? const [];
    }
  }

  // OPTIMIZED STREAM METHODS with better error handling

  /// Watch patients with connection resilience
  Stream<List<ProviderPatientRecord>> watchDoctorPatientsOptimized(String doctorId) {
    if (!_isFirebaseAvailable) {
      return Stream.value(_patientsCacheByDoctor[doctorId] ?? const []);
    }

    return _patientsCollection
        .where('doctorId', isEqualTo: doctorId)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .handleError((error) {
          if (kDebugMode) {
            debugPrint('[OptimizedFirestoreService] Error watching patients: $error');
          }
          // Return cached data on error
          return Stream.value(_patientsCacheByDoctor[doctorId] ?? const []);
        })
        .map((snapshot) {
          final patients = snapshot.docs
              .map((doc) => ProviderPatientRecord.fromMap(doc.data()))
              .toList();

          _patientsCacheByDoctor[doctorId] = patients;
          _updateCacheTimestamp('patients_$doctorId');
          return patients;
        });
  }

  /// Watch clinical notes with resilience
  Stream<List<ClinicalNote>> watchClinicalNotesOptimized(String patientId) {
    if (!_isFirebaseAvailable) {
      return Stream.value(_clinicalCacheByPatient[patientId] ?? const []);
    }

    return _clinicalReportsCollection
        .where('patientId', isEqualTo: patientId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .handleError((error) {
          if (kDebugMode) {
            debugPrint('[OptimizedFirestoreService] Error watching clinical notes: $error');
          }
        })
        .map((snapshot) {
          final notes = snapshot.docs
              .map((doc) => ClinicalNote.fromMap(doc.data()))
              .toList();

          _clinicalCacheByPatient[patientId] = notes;
          _updateCacheTimestamp('clinical_notes_$patientId');
          return notes;
        });
  }

  // ANALYTICS AND AGGREGATIONS

  /// Get patient statistics for dashboard
  Future<Map<String, dynamic>> getPatientStatistics(String doctorId) async {
    if (!_isFirebaseAvailable) return {};

    try {
      // Use aggregation queries for better performance
      final patientsQuery = _patientsCollection.where('doctorId', isEqualTo: doctorId);

      final totalPatientsSnapshot = await patientsQuery.count().get();
      final totalPatients = totalPatientsSnapshot.count;

      // Get recent patients (last 30 days)
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      final recentPatientsSnapshot = await patientsQuery
          .where('updatedAt', isGreaterThan: thirtyDaysAgo.toIso8601String())
          .count()
          .get();

      return {
        'totalPatients': totalPatients,
        'recentPatients': recentPatientsSnapshot.count,
        'lastUpdated': DateTime.now().toIso8601String(),
      };
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[OptimizedFirestoreService] Failed to get patient statistics: $error');
      }
      return {};
    }
  }

  /// Search patients with text search (requires Cloud Function or Algolia for full text search)
  Future<List<ProviderPatientRecord>> searchPatients({
    required String doctorId,
    required String searchTerm,
    int limit = 10,
  }) async {
    if (!_isFirebaseAvailable || searchTerm.isEmpty) return [];

    try {
      // Basic search using array-contains-any for limited text search
      // For production, implement full-text search using Cloud Functions + Algolia

      final searchTermLower = searchTerm.toLowerCase();

      // Search by email (exact match for now)
      final emailQuery = _patientsCollection
          .where('doctorId', isEqualTo: doctorId)
          .where('email', isGreaterThanOrEqualTo: searchTermLower)
          .where('email', isLessThan: '${searchTermLower}z')
          .limit(limit);

      final emailResults = await emailQuery.get();

      return emailResults.docs
          .map((doc) => ProviderPatientRecord.fromMap(doc.data()))
          .toList();

    } catch (error) {
      if (kDebugMode) {
        debugPrint('[OptimizedFirestoreService] Failed to search patients: $error');
      }
      return [];
    }
  }

  // MAINTENANCE AND MONITORING

  /// Get cache statistics
  Map<String, dynamic> getCacheStatistics() {
    return {
      'patientsCacheSize': _patientsCacheByDoctor.length,
      'clinicalCacheSize': _clinicalCacheByPatient.length,
      'consultationCacheSize': _consultationCacheByKey.length,
      'documentScansCacheSize': _documentScansCacheByPatient.length,
      'totalCachedItems': _patientsCacheByDoctor.values.fold(0, (sum, list) => sum + list.length) +
                         _clinicalCacheByPatient.values.fold(0, (sum, list) => sum + list.length) +
                         _consultationCacheByKey.values.fold(0, (sum, list) => sum + list.length) +
                         _documentScansCacheByPatient.values.fold(0, (sum, list) => sum + list.length),
      'cacheTimestamps': _cacheTimestamps.length,
    };
  }

  /// Clear expired caches
  void clearExpiredCaches() {
    final now = DateTime.now();
    final expiredKeys = <String>[];

    for (final entry in _cacheTimestamps.entries) {
      final key = entry.key;
      final timestamp = entry.value;

      Duration ttl;
      if (key.startsWith('patients_')) {
        ttl = _patientsCacheTTL;
      } else if (key.startsWith('clinical_notes_')) {
        ttl = _clinicalNotesCacheTTL;
      } else if (key.contains('::')) {
        ttl = _consultationsCacheTTL;
      } else {
        ttl = _documentScansCacheTTL;
      }

      if (now.difference(timestamp) > ttl) {
        expiredKeys.add(key);
      }
    }

    for (final key in expiredKeys) {
      _cacheTimestamps.remove(key);

      if (key.startsWith('patients_')) {
        final doctorId = key.substring(9);
        _patientsCacheByDoctor.remove(doctorId);
      } else if (key.startsWith('clinical_notes_')) {
        final patientId = key.substring(15);
        _clinicalCacheByPatient.remove(patientId);
      } else if (key.contains('::')) {
        _consultationCacheByKey.remove(key);
      }
    }

    if (kDebugMode && expiredKeys.isNotEmpty) {
      debugPrint('[OptimizedFirestoreService] Cleared ${expiredKeys.length} expired caches');
    }
  }

  // Delegate to original methods for backward compatibility
  Future<void> saveClinicalReport(ClinicalNote note) async {
    await batchSaveClinicalNotes([note]);
  }

  Future<void> savePatientRecord(ProviderPatientRecord record) async {
    await batchSavePatients([record]);
  }

  Future<void> saveDocumentScan(DocumentScan scan) async {
    if (!_isFirebaseAvailable) return;
    try {
      await _documentScansCollection.doc(scan.id).set(scan.toMap());
      _updateCacheTimestamp('document_scans_${scan.patientId}');
      _documentScansCacheByPatient.remove(scan.patientId);
    } catch (e) {
      debugPrint('[OptimizedFirestoreService] Error saving document scan: $e');
      rethrow;
    }
  }

  Future<void> deletePatientRecord(String patientId) async {
    if (!_isFirebaseAvailable) return;
    try {
      await _patientsCollection.doc(patientId).delete();
      for (final cacheList in _patientsCacheByDoctor.values) {
        cacheList.removeWhere((p) => p.id == patientId);
      }
    } catch (e) {
      debugPrint('[OptimizedFirestoreService] Error deleting patient: $e');
      rethrow;
    }
  }

  Future<void> deleteClinicalReport(String reportId) async {
    if (!_isFirebaseAvailable) return;
    try {
      await _clinicalReportsCollection.doc(reportId).delete();
      for (final cacheList in _clinicalCacheByPatient.values) {
        cacheList.removeWhere((n) => n.id == reportId);
      }
    } catch (e) {
      debugPrint('[OptimizedFirestoreService] Error deleting clinical report: $e');
      rethrow;
    }
  }

  Future<void> deleteDocumentScan(String scanId) async {
    if (!_isFirebaseAvailable) return;
    try {
      await _documentScansCollection.doc(scanId).delete();
      for (final cacheList in _documentScansCacheByPatient.values) {
        cacheList.removeWhere((s) => s.id == scanId);
      }
    } catch (e) {
      debugPrint('[OptimizedFirestoreService] Error deleting document scan: $e');
      rethrow;
    }
  }

  // Include all other methods from the original FirestoreService for compatibility
  // ... (keeping the same interface for existing methods)
}