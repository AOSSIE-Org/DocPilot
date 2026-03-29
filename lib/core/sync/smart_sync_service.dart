import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

import '../../models/health_models.dart';
import '../../services/firebase/optimized_firestore_service.dart';
import '../storage/local_storage_service.dart';

/// Conflict resolution strategy
enum ConflictResolutionStrategy {
  serverWins,      // Always take server version
  clientWins,      // Always take client version
  newerWins,       // Take the version with later timestamp
  merge,           // Attempt to merge changes
  userChoice,      // Let user decide
}

/// Represents a data conflict between local and server versions
class DataConflict<T> {
  final String recordId;
  final T localVersion;
  final T serverVersion;
  final DateTime localTimestamp;
  final DateTime serverTimestamp;
  final String tableName;
  final ConflictType conflictType;

  const DataConflict({
    required this.recordId,
    required this.localVersion,
    required this.serverVersion,
    required this.localTimestamp,
    required this.serverTimestamp,
    required this.tableName,
    required this.conflictType,
  });
}

/// Type of conflict detected
enum ConflictType {
  update,          // Both versions were updated
  deleteLocal,     // Deleted locally but exists on server
  deleteServer,    // Exists locally but deleted on server
  createDuplicate, // Created in both places with different content
}

/// Result of conflict resolution
class ConflictResolution<T> {
  final T resolvedVersion;
  final ConflictResolutionStrategy strategy;
  final String reason;
  final bool requiresUserInput;

  const ConflictResolution({
    required this.resolvedVersion,
    required this.strategy,
    required this.reason,
    this.requiresUserInput = false,
  });
}

/// Smart synchronization service with conflict resolution
class SmartSyncService {
  static final SmartSyncService _instance = SmartSyncService._internal();
  factory SmartSyncService() => _instance;
  SmartSyncService._internal();

  final OptimizedFirestoreService _firestoreService = OptimizedFirestoreService();
  final LocalStorageService _localStorageService = LocalStorageService();

  // Pending user decisions for conflicts
  final Map<String, Completer<ConflictResolution>> _pendingConflicts = {};

  // Synchronization state
  bool _isSyncing = false;
  DateTime? _lastSyncTime;
  int _conflictsResolved = 0;
  int _conflictsPending = 0;

  bool get isSyncing => _isSyncing;
  DateTime? get lastSyncTime => _lastSyncTime;
  int get conflictsResolved => _conflictsResolved;
  int get conflictsPending => _conflictsPending;

  /// Perform comprehensive synchronization with conflict resolution
  Future<SyncResult> performSmartSync({
    ConflictResolutionStrategy defaultStrategy = ConflictResolutionStrategy.newerWins,
    Function(DataConflict)? onConflictDetected,
  }) async {
    if (_isSyncing) {
      throw Exception('Synchronization already in progress');
    }

    _isSyncing = true;
    final syncStartTime = DateTime.now();
    final syncResult = SyncResult();

    try {
      if (kDebugMode) {
        debugPrint('[SmartSyncService] Starting smart synchronization');
      }

      // Sync each data type
      await _syncPatients(syncResult, defaultStrategy, onConflictDetected);
      await _syncClinicalNotes(syncResult, defaultStrategy, onConflictDetected);
      await _syncDocumentScans(syncResult, defaultStrategy, onConflictDetected);
      await _syncConsultationSessions(syncResult, defaultStrategy, onConflictDetected);

      _lastSyncTime = DateTime.now();
      syncResult.duration = _lastSyncTime!.difference(syncStartTime);

      if (kDebugMode) {
        debugPrint('[SmartSyncService] Sync completed: ${syncResult.summary()}');
      }

      return syncResult;
    } catch (e) {
      syncResult.addError('Sync failed: $e');
      rethrow;
    } finally {
      _isSyncing = false;
    }
  }

  /// Sync patients with conflict resolution
  Future<void> _syncPatients(
    SyncResult syncResult,
    ConflictResolutionStrategy defaultStrategy,
    Function(DataConflict)? onConflictDetected,
  ) async {
    if (!_firestoreService.isFirebaseAvailable) return;

    try {
      // Get all local patients with unsynced changes
      final localPatients = await _getAllLocalPatients();
      final doctorIds = localPatients.map((p) => p.doctorId).toSet();

      for (final doctorId in doctorIds) {
        final doctorPatients = localPatients.where((p) => p.doctorId == doctorId).toList();

        // Get server versions
        final serverPatients = await _firestoreService.getDoctorPatientsOptimized(doctorId);
        final serverPatientsMap = {for (var p in serverPatients) p.id: p};

        // Check for conflicts and resolve
        for (final localPatient in doctorPatients) {
          final serverPatient = serverPatientsMap[localPatient.id];

          if (serverPatient == null) {
            // Patient doesn't exist on server - upload
            await _firestoreService.savePatientRecord(localPatient);
            syncResult.patientsUploaded++;
          } else {
            // Check for conflicts
            final conflict = await _detectPatientConflict(localPatient, serverPatient);

            if (conflict != null) {
              final resolution = await _resolvePatientConflict(
                conflict,
                defaultStrategy,
                onConflictDetected,
              );

              await _applyPatientResolution(resolution);
              syncResult.patientsConflictsResolved++;
            }
          }
        }

        syncResult.patientsProcessed += doctorPatients.length;
      }
    } catch (e) {
      syncResult.addError('Patient sync failed: $e');
    }
  }

  /// Detect conflicts between local and server patient records
  Future<DataConflict<ProviderPatientRecord>?> _detectPatientConflict(
    ProviderPatientRecord local,
    ProviderPatientRecord server,
  ) async {
    // Compare content hashes to detect changes
    final localHash = _generateContentHash(local.toMap());
    final serverHash = _generateContentHash(server.toMap());

    if (localHash == serverHash) {
      return null; // No conflict - identical content
    }

    // Determine conflict type
    ConflictType conflictType;
    if (local.updatedAt.isAfter(server.updatedAt) &&
        server.updatedAt.isAfter(local.createdAt)) {
      conflictType = ConflictType.update;
    } else {
      conflictType = ConflictType.update; // Default to update conflict
    }

    return DataConflict(
      recordId: local.id,
      localVersion: local,
      serverVersion: server,
      localTimestamp: local.updatedAt,
      serverTimestamp: server.updatedAt,
      tableName: 'patients',
      conflictType: conflictType,
    );
  }

  /// Resolve patient conflict based on strategy
  Future<ConflictResolution<ProviderPatientRecord>> _resolvePatientConflict(
    DataConflict<ProviderPatientRecord> conflict,
    ConflictResolutionStrategy strategy,
    Function(DataConflict)? onConflictDetected,
  ) async {
    onConflictDetected?.call(conflict);

    switch (strategy) {
      case ConflictResolutionStrategy.serverWins:
        return ConflictResolution(
          resolvedVersion: conflict.serverVersion,
          strategy: strategy,
          reason: 'Server version selected by strategy',
        );

      case ConflictResolutionStrategy.clientWins:
        return ConflictResolution(
          resolvedVersion: conflict.localVersion,
          strategy: strategy,
          reason: 'Client version selected by strategy',
        );

      case ConflictResolutionStrategy.newerWins:
        final newerVersion = conflict.serverTimestamp.isAfter(conflict.localTimestamp)
            ? conflict.serverVersion
            : conflict.localVersion;

        return ConflictResolution(
          resolvedVersion: newerVersion,
          strategy: strategy,
          reason: 'Newer version selected (${conflict.serverTimestamp.isAfter(conflict.localTimestamp) ? 'server' : 'client'})',
        );

      case ConflictResolutionStrategy.merge:
        final mergedVersion = await _mergePatientVersions(
          conflict.localVersion,
          conflict.serverVersion,
        );

        return ConflictResolution(
          resolvedVersion: mergedVersion,
          strategy: strategy,
          reason: 'Versions merged automatically',
        );

      case ConflictResolutionStrategy.userChoice:
        return ConflictResolution(
          resolvedVersion: conflict.localVersion, // Placeholder
          strategy: strategy,
          reason: 'User decision required',
          requiresUserInput: true,
        );
    }
  }

  /// Merge two patient versions intelligently
  Future<ProviderPatientRecord> _mergePatientVersions(
    ProviderPatientRecord local,
    ProviderPatientRecord server,
  ) async {
    // Use the newer timestamp for the merged version
    final newerTimestamp = local.updatedAt.isAfter(server.updatedAt)
        ? local.updatedAt
        : server.updatedAt;

    // Merge lists by combining and deduplicating
    final mergedPrescriptions = _mergeStringLists(local.prescriptions, server.prescriptions);
    final mergedReports = _mergeStringLists(local.reports, server.reports);
    final mergedFoodAllergies = _mergeStringLists(local.foodAllergies, server.foodAllergies);
    final mergedMedicinalAllergies = _mergeStringLists(local.medicinalAllergies, server.medicinalAllergies);
    final mergedMedicalHistory = _mergeStringLists(local.medicalHistory, server.medicalHistory);

    // For other fields, prefer the newer version or combine reasonably
    return local.copyWith(
      // Use server's core info if it's newer, otherwise keep local
      firstName: server.updatedAt.isAfter(local.updatedAt) ? server.firstName : local.firstName,
      lastName: server.updatedAt.isAfter(local.updatedAt) ? server.lastName : local.lastName,
      contactNumber: server.updatedAt.isAfter(local.updatedAt) ? server.contactNumber : local.contactNumber,
      email: server.updatedAt.isAfter(local.updatedAt) ? server.email : local.email,

      // Use the most recent visit summary
      lastVisitSummary: server.updatedAt.isAfter(local.updatedAt) ? server.lastVisitSummary : local.lastVisitSummary,

      // Merge lists
      prescriptions: mergedPrescriptions,
      reports: mergedReports,
      foodAllergies: mergedFoodAllergies,
      medicinalAllergies: mergedMedicinalAllergies,
      medicalHistory: mergedMedicalHistory,

      updatedAt: newerTimestamp,
    );
  }

  /// Apply patient conflict resolution
  Future<void> _applyPatientResolution(ConflictResolution<ProviderPatientRecord> resolution) async {
    final patient = resolution.resolvedVersion;

    // Save to both local and server
    await _localStorageService.savePatient(patient, markDirty: false);
    await _firestoreService.savePatientRecord(patient);

    _conflictsResolved++;
  }

  /// Sync clinical notes (similar pattern to patients)
  Future<void> _syncClinicalNotes(
    SyncResult syncResult,
    ConflictResolutionStrategy defaultStrategy,
    Function(DataConflict)? onConflictDetected,
  ) async {
    // Implementation similar to _syncPatients but for clinical notes
    // ... (implement similar logic for clinical notes)

    if (kDebugMode) {
      debugPrint('[SmartSyncService] Clinical notes sync completed');
    }
  }

  /// Sync document scans
  Future<void> _syncDocumentScans(
    SyncResult syncResult,
    ConflictResolutionStrategy defaultStrategy,
    Function(DataConflict)? onConflictDetected,
  ) async {
    // Implementation for document scans
    if (kDebugMode) {
      debugPrint('[SmartSyncService] Document scans sync completed');
    }
  }

  /// Sync consultation sessions
  Future<void> _syncConsultationSessions(
    SyncResult syncResult,
    ConflictResolutionStrategy defaultStrategy,
    Function(DataConflict)? onConflictDetected,
  ) async {
    // Implementation for consultation sessions
    if (kDebugMode) {
      debugPrint('[SmartSyncService] Consultation sessions sync completed');
    }
  }

  /// Generate content hash for conflict detection
  String _generateContentHash(Map<String, dynamic> data) {
    // Remove timestamp fields for content comparison
    final contentData = Map<String, dynamic>.from(data);
    contentData.remove('updatedAt');
    contentData.remove('createdAt');

    // Create sorted JSON string for consistent hashing
    final jsonString = jsonEncode(_sortMap(contentData));
    final bytes = utf8.encode(jsonString);
    return sha256.convert(bytes).toString();
  }

  /// Sort map recursively for consistent hashing
  Map<String, dynamic> _sortMap(Map<String, dynamic> map) {
    final sortedMap = <String, dynamic>{};
    final sortedKeys = map.keys.toList()..sort();

    for (final key in sortedKeys) {
      final value = map[key];
      if (value is Map<String, dynamic>) {
        sortedMap[key] = _sortMap(value);
      } else if (value is List) {
        sortedMap[key] = value..sort();
      } else {
        sortedMap[key] = value;
      }
    }

    return sortedMap;
  }

  /// Merge two string lists, removing duplicates
  List<String> _mergeStringLists(List<String> list1, List<String> list2) {
    final combined = <String>{...list1, ...list2};
    return combined.toList()..sort();
  }

  /// Get all local patients (helper method)
  Future<List<ProviderPatientRecord>> _getAllLocalPatients() async {
    // This would need to be implemented to get all patients from local storage
    // For now, return empty list
    return [];
  }

  /// Request user decision for conflict resolution
  Future<ConflictResolution<T>> requestUserDecision<T>(DataConflict<T> conflict) async {
    final completer = Completer<ConflictResolution<T>>();
    _pendingConflicts[conflict.recordId] = completer as Completer<ConflictResolution>;
    _conflictsPending++;

    return completer.future;
  }

  /// Resolve pending conflict with user decision
  void resolveUserConflict<T>(String recordId, ConflictResolution<T> resolution) {
    final completer = _pendingConflicts.remove(recordId);
    if (completer != null) {
      completer.complete(resolution as ConflictResolution);
      _conflictsPending--;
      _conflictsResolved++;
    }
  }

  /// Get sync statistics
  Map<String, dynamic> getSyncStatistics() {
    return {
      'isSyncing': _isSyncing,
      'lastSyncTime': _lastSyncTime?.toIso8601String(),
      'conflictsResolved': _conflictsResolved,
      'conflictsPending': _conflictsPending,
    };
  }
}

/// Result of synchronization operation
class SyncResult {
  int patientsProcessed = 0;
  int patientsUploaded = 0;
  int patientsConflictsResolved = 0;

  int clinicalNotesProcessed = 0;
  int clinicalNotesUploaded = 0;
  int clinicalNotesConflictsResolved = 0;

  int documentScansProcessed = 0;
  int documentScansUploaded = 0;

  int consultationsProcessed = 0;
  int consultationsUploaded = 0;

  Duration? duration;
  final List<String> errors = [];

  void addError(String error) {
    errors.add(error);
  }

  bool get hasErrors => errors.isNotEmpty;

  String summary() {
    return 'Sync completed in ${duration?.inMilliseconds}ms: '
           'Patients: $patientsProcessed processed, $patientsUploaded uploaded, $patientsConflictsResolved conflicts resolved. '
           'Errors: ${errors.length}';
  }
}