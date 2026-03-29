import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../cache/cache_manager.dart';
import '../../models/health_models.dart';

/// Local storage service for offline data persistence using SQLite
class LocalStorageService {
  static final LocalStorageService _instance = LocalStorageService._internal();
  factory LocalStorageService() => _instance;
  LocalStorageService._internal();

  Database? _database;
  bool _initialized = false;
  final CacheManager _cacheManager = CacheManager();

  /// Database version for migrations
  static const int _databaseVersion = 1;
  static const String _databaseName = 'docpilot_local.db';

  /// Initialize the local storage service
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      await _cacheManager.initialize();
      await _initializeDatabase();
      _initialized = true;

      if (kDebugMode) {
        debugPrint('[LocalStorageService] Initialized successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[LocalStorageService] Failed to initialize: $e');
      }
    }
  }

  /// Get the database instance
  Future<Database> get database async {
    if (_database != null) return _database!;
    await _initializeDatabase();
    return _database!;
  }

  /// Initialize the SQLite database
  Future<void> _initializeDatabase() async {
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, _databaseName);

    _database = await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _createTables,
      onUpgrade: _upgradeDatabase,
    );
  }

  /// Create database tables
  Future<void> _createTables(Database db, int version) async {
    // Patients table
    await db.execute('''
      CREATE TABLE patients (
        id TEXT PRIMARY KEY,
        doctor_id TEXT NOT NULL,
        first_name TEXT NOT NULL,
        last_name TEXT NOT NULL,
        date_of_birth TEXT NOT NULL,
        gender TEXT NOT NULL,
        blood_type TEXT NOT NULL,
        contact_number TEXT NOT NULL,
        email TEXT NOT NULL,
        last_visit_summary TEXT NOT NULL,
        prescriptions TEXT NOT NULL,
        reports TEXT NOT NULL,
        food_allergies TEXT NOT NULL,
        medicinal_allergies TEXT NOT NULL,
        medical_history TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        sync_status INTEGER DEFAULT 0,
        is_dirty INTEGER DEFAULT 0
      )
    ''');

    // Clinical notes table
    await db.execute('''
      CREATE TABLE clinical_notes (
        id TEXT PRIMARY KEY,
        patient_id TEXT NOT NULL,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        diagnosis TEXT,
        treatments TEXT NOT NULL,
        follow_up_items TEXT NOT NULL,
        created_at TEXT NOT NULL,
        created_by TEXT NOT NULL,
        attachment_path TEXT,
        sync_status INTEGER DEFAULT 0,
        is_dirty INTEGER DEFAULT 0
      )
    ''');

    // Document scans table
    await db.execute('''
      CREATE TABLE document_scans (
        id TEXT PRIMARY KEY,
        patient_id TEXT NOT NULL,
        image_path TEXT NOT NULL,
        document_type TEXT NOT NULL,
        extracted_text TEXT,
        analysis TEXT,
        date_scanned TEXT NOT NULL,
        is_processed INTEGER DEFAULT 0,
        sync_status INTEGER DEFAULT 0,
        is_dirty INTEGER DEFAULT 0
      )
    ''');

    // Consultation sessions table
    await db.execute('''
      CREATE TABLE consultation_sessions (
        id TEXT PRIMARY KEY,
        doctor_id TEXT NOT NULL,
        patient_id TEXT NOT NULL,
        patient_name TEXT NOT NULL,
        transcript TEXT NOT NULL,
        summary TEXT NOT NULL,
        prescription TEXT NOT NULL,
        source TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        sync_status INTEGER DEFAULT 0,
        is_dirty INTEGER DEFAULT 0
      )
    ''');

    // Doctor profiles table
    await db.execute('''
      CREATE TABLE doctor_profiles (
        id TEXT PRIMARY KEY,
        first_name TEXT NOT NULL,
        last_name TEXT NOT NULL,
        license_number TEXT NOT NULL,
        specialty TEXT NOT NULL,
        hospital_name TEXT NOT NULL,
        contact_number TEXT NOT NULL,
        email TEXT NOT NULL,
        department_name TEXT,
        degree TEXT,
        sync_status INTEGER DEFAULT 0,
        is_dirty INTEGER DEFAULT 0
      )
    ''');

    // Sync queue table for offline operations
    await db.execute('''
      CREATE TABLE sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        operation_type TEXT NOT NULL,
        table_name TEXT NOT NULL,
        record_id TEXT NOT NULL,
        operation_data TEXT NOT NULL,
        created_at TEXT NOT NULL,
        retry_count INTEGER DEFAULT 0,
        last_error TEXT
      )
    ''');

    // Create indexes for better query performance
    await db.execute('CREATE INDEX idx_patients_doctor_id ON patients(doctor_id)');
    await db.execute('CREATE INDEX idx_clinical_notes_patient_id ON clinical_notes(patient_id)');
    await db.execute('CREATE INDEX idx_document_scans_patient_id ON document_scans(patient_id)');
    await db.execute('CREATE INDEX idx_consultation_sessions_doctor_id ON consultation_sessions(doctor_id)');
    await db.execute('CREATE INDEX idx_consultation_sessions_patient_id ON consultation_sessions(patient_id)');
    await db.execute('CREATE INDEX idx_sync_queue_created_at ON sync_queue(created_at)');
  }

  /// Handle database upgrades
  Future<void> _upgradeDatabase(Database db, int oldVersion, int newVersion) async {
    // Handle future schema migrations
    if (kDebugMode) {
      debugPrint('[LocalStorageService] Upgrading database from $oldVersion to $newVersion');
    }
  }

  // PATIENT OPERATIONS

  /// Save patient record locally
  Future<void> savePatient(ProviderPatientRecord patient, {bool markDirty = true}) async {
    final db = await database;

    await db.insert(
      'patients',
      {
        ...patient.toMap(),
        'prescriptions': jsonEncode(patient.prescriptions),
        'reports': jsonEncode(patient.reports),
        'food_allergies': jsonEncode(patient.foodAllergies),
        'medicinal_allergies': jsonEncode(patient.medicinalAllergies),
        'medical_history': jsonEncode(patient.medicalHistory),
        'sync_status': 0, // 0=pending, 1=synced
        'is_dirty': markDirty ? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // Update cache
    await _cacheManager.set('patient_${patient.id}', patient);

    if (markDirty) {
      await _addToSyncQueue('INSERT', 'patients', patient.id, patient.toMap());
    }
  }

  /// Get patient records for a doctor
  Future<List<ProviderPatientRecord>> getPatients(String doctorId) async {
    // Try cache first
    final cacheKey = 'patients_$doctorId';
    final cached = _cacheManager.get<List<ProviderPatientRecord>>(cacheKey);
    if (cached != null) return cached;

    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'patients',
      where: 'doctor_id = ?',
      whereArgs: [doctorId],
      orderBy: 'updated_at DESC',
    );

    final patients = maps.map((map) {
      // Parse JSON arrays back to lists
      final patientMap = Map<String, dynamic>.from(map);
      patientMap['prescriptions'] = jsonDecode(map['prescriptions'] ?? '[]');
      patientMap['reports'] = jsonDecode(map['reports'] ?? '[]');
      patientMap['foodAllergies'] = jsonDecode(map['food_allergies'] ?? '[]');
      patientMap['medicinalAllergies'] = jsonDecode(map['medicinal_allergies'] ?? '[]');
      patientMap['medicalHistory'] = jsonDecode(map['medical_history'] ?? '[]');

      return ProviderPatientRecord.fromMap(patientMap);
    }).toList();

    // Cache results
    await _cacheManager.set(cacheKey, patients, expiration: const Duration(minutes: 30));

    return patients;
  }

  /// Delete patient record
  Future<void> deletePatient(String patientId) async {
    final db = await database;

    await db.delete('patients', where: 'id = ?', whereArgs: [patientId]);

    // Remove from cache
    _cacheManager.remove('patient_$patientId');

    // Add to sync queue
    await _addToSyncQueue('DELETE', 'patients', patientId, {'id': patientId});
  }

  // CLINICAL NOTES OPERATIONS

  /// Save clinical note locally
  Future<void> saveClinicalNote(ClinicalNote note, {bool markDirty = true}) async {
    final db = await database;

    final noteMap = note.toMap();
    await db.insert(
      'clinical_notes',
      {
        ...noteMap,
        'treatments': jsonEncode(note.treatments),
        'follow_up_items': jsonEncode(note.followUpItems),
        'sync_status': 0,
        'is_dirty': markDirty ? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // Update cache
    await _cacheManager.set('clinical_note_${note.id}', note);

    // Invalidate patient notes cache
    _cacheManager.remove('clinical_notes_${note.patientId}');

    if (markDirty) {
      await _addToSyncQueue('INSERT', 'clinical_notes', note.id, noteMap);
    }
  }

  /// Get clinical notes for a patient
  Future<List<ClinicalNote>> getClinicalNotes(String patientId) async {
    final cacheKey = 'clinical_notes_$patientId';
    final cached = _cacheManager.get<List<ClinicalNote>>(cacheKey);
    if (cached != null) return cached;

    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'clinical_notes',
      where: 'patient_id = ?',
      whereArgs: [patientId],
      orderBy: 'created_at DESC',
    );

    final notes = maps.map((map) {
      final noteMap = Map<String, dynamic>.from(map);
      noteMap['treatments'] = jsonDecode(map['treatments'] ?? '[]');
      noteMap['followUpItems'] = jsonDecode(map['follow_up_items'] ?? '[]');

      return ClinicalNote.fromMap(noteMap);
    }).toList();

    await _cacheManager.set(cacheKey, notes, expiration: const Duration(minutes: 15));
    return notes;
  }

  // DOCUMENT SCANS OPERATIONS

  /// Save document scan locally
  Future<void> saveDocumentScan(DocumentScan scan, {bool markDirty = true}) async {
    final db = await database;

    final scanMap = scan.toMap();
    await db.insert(
      'document_scans',
      {
        ...scanMap,
        'sync_status': 0,
        'is_dirty': markDirty ? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    await _cacheManager.set('document_scan_${scan.id}', scan);
    _cacheManager.remove('document_scans_${scan.patientId}');

    if (markDirty) {
      await _addToSyncQueue('INSERT', 'document_scans', scan.id, scanMap);
    }
  }

  /// Get document scans for a patient
  Future<List<DocumentScan>> getDocumentScans(String patientId) async {
    final cacheKey = 'document_scans_$patientId';
    final cached = _cacheManager.get<List<DocumentScan>>(cacheKey);
    if (cached != null) return cached;

    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'document_scans',
      where: 'patient_id = ?',
      whereArgs: [patientId],
      orderBy: 'date_scanned DESC',
    );

    final scans = maps.map((map) => DocumentScan.fromMap(map)).toList();

    await _cacheManager.set(cacheKey, scans, expiration: const Duration(minutes: 15));
    return scans;
  }

  // CONSULTATION SESSIONS OPERATIONS

  /// Save consultation session locally
  Future<void> saveConsultationSession(ConsultationSession session, {bool markDirty = true}) async {
    final db = await database;

    final sessionMap = session.toMap();
    await db.insert(
      'consultation_sessions',
      {
        ...sessionMap,
        'sync_status': 0,
        'is_dirty': markDirty ? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    await _cacheManager.set('consultation_session_${session.id}', session);
    _cacheManager.remove('consultation_sessions_${session.doctorId}');

    if (markDirty) {
      await _addToSyncQueue('INSERT', 'consultation_sessions', session.id, sessionMap);
    }
  }

  /// Get consultation sessions
  Future<List<ConsultationSession>> getConsultationSessions({
    required String doctorId,
    String? patientId,
    int limit = 20,
  }) async {
    final cacheKey = 'consultation_sessions_${doctorId}_${patientId ?? 'all'}';
    final cached = _cacheManager.get<List<ConsultationSession>>(cacheKey);
    if (cached != null) return cached;

    final db = await database;
    String where = 'doctor_id = ?';
    List<dynamic> whereArgs = [doctorId];

    if (patientId != null) {
      where += ' AND patient_id = ?';
      whereArgs.add(patientId);
    }

    final List<Map<String, dynamic>> maps = await db.query(
      'consultation_sessions',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'created_at DESC',
      limit: limit,
    );

    final sessions = maps.map((map) => ConsultationSession.fromMap(map)).toList();

    await _cacheManager.set(cacheKey, sessions, expiration: const Duration(minutes: 10));
    return sessions;
  }

  // DOCTOR PROFILE OPERATIONS

  /// Save doctor profile locally
  Future<void> saveDoctorProfile(DoctorProfile profile, {bool markDirty = true}) async {
    final db = await database;

    final profileMap = profile.toMap();
    await db.insert(
      'doctor_profiles',
      {
        ...profileMap,
        'sync_status': 0,
        'is_dirty': markDirty ? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    await _cacheManager.set('doctor_profile_${profile.id}', profile);

    if (markDirty) {
      await _addToSyncQueue('INSERT', 'doctor_profiles', profile.id, profileMap);
    }
  }

  /// Get doctor profile
  Future<DoctorProfile?> getDoctorProfile(String doctorId) async {
    final cacheKey = 'doctor_profile_$doctorId';
    final cached = _cacheManager.get<DoctorProfile>(cacheKey);
    if (cached != null) return cached;

    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'doctor_profiles',
      where: 'id = ?',
      whereArgs: [doctorId],
      limit: 1,
    );

    if (maps.isEmpty) return null;

    final profile = DoctorProfile.fromMap(maps.first);
    await _cacheManager.set(cacheKey, profile, expiration: const Duration(hours: 1));
    return profile;
  }

  // SYNC OPERATIONS

  /// Add operation to sync queue
  Future<void> _addToSyncQueue(String operationType, String tableName, String recordId, Map<String, dynamic> data) async {
    final db = await database;

    await db.insert('sync_queue', {
      'operation_type': operationType,
      'table_name': tableName,
      'record_id': recordId,
      'operation_data': jsonEncode(data),
      'created_at': DateTime.now().toIso8601String(),
      'retry_count': 0,
    });
  }

  /// Get pending sync operations
  Future<List<Map<String, dynamic>>> getPendingSyncOperations([int limit = 50]) async {
    final db = await database;

    return await db.query(
      'sync_queue',
      orderBy: 'created_at ASC',
      limit: limit,
    );
  }

  /// Mark sync operation as completed
  Future<void> markSyncCompleted(int syncId) async {
    final db = await database;
    await db.delete('sync_queue', where: 'id = ?', whereArgs: [syncId]);
  }

  /// Update sync operation retry count
  Future<void> updateSyncRetry(int syncId, String error) async {
    final db = await database;
    await db.rawUpdate(
      'UPDATE sync_queue SET retry_count = retry_count + 1, last_error = ? WHERE id = ?',
      [error, syncId],
    );
  }

  /// Mark record as synced
  Future<void> markRecordSynced(String tableName, String recordId) async {
    final db = await database;
    await db.update(
      tableName,
      {'sync_status': 1, 'is_dirty': 0},
      where: 'id = ?',
      whereArgs: [recordId],
    );
  }

  /// Get unsynced records count
  Future<Map<String, int>> getUnsyncedCounts() async {
    final db = await database;
    final tables = ['patients', 'clinical_notes', 'document_scans', 'consultation_sessions'];
    final counts = <String, int>{};

    for (final table in tables) {
      final result = await db.rawQuery('SELECT COUNT(*) as count FROM $table WHERE sync_status = 0');
      counts[table] = result.first['count'] as int;
    }

    return counts;
  }

  /// Clear all local data (use with caution)
  Future<void> clearAllData() async {
    final db = await database;

    await db.delete('patients');
    await db.delete('clinical_notes');
    await db.delete('document_scans');
    await db.delete('consultation_sessions');
    await db.delete('doctor_profiles');
    await db.delete('sync_queue');

    await _cacheManager.clear();
  }

  /// Get database statistics
  Future<Map<String, dynamic>> getDatabaseStats() async {
    final db = await database;
    final stats = <String, dynamic>{};

    final tables = ['patients', 'clinical_notes', 'document_scans', 'consultation_sessions', 'doctor_profiles'];

    for (final table in tables) {
      final result = await db.rawQuery('SELECT COUNT(*) as count FROM $table');
      stats[table] = result.first['count'];
    }

    // Add sync queue stats
    final syncResult = await db.rawQuery('SELECT COUNT(*) as count FROM sync_queue');
    stats['sync_queue'] = syncResult.first['count'];

    // Add cache stats
    stats['cache'] = _cacheManager.getStats();

    return stats;
  }

  /// Dispose resources
  void dispose() {
    _database?.close();
    _cacheManager.dispose();
    _initialized = false;
  }
}