import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import '../../services/firebase/firestore_service.dart';
import '../../models/health_models.dart';
import '../storage/local_storage_service.dart';
import 'base_provider.dart';

class ConnectionProvider extends ChangeNotifier {
  final Connectivity _connectivity = Connectivity();
  final FirestoreService _firestoreService = FirestoreService();
  final LocalStorageService _localStorageService = LocalStorageService();

  ConnectionState _state = ConnectionState();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Timer? _syncTimer;

  bool _isSyncing = false;
  int _pendingSyncCount = 0;
  DateTime? _lastSyncAttempt;

  ConnectionState get state => _state;
  ConnectionStatus get status => _state.status;
  bool get isOnline => _state.isOnline;
  bool get isOffline => _state.isOffline;
  bool get isSyncing => _isSyncing;
  int get pendingSyncCount => _pendingSyncCount;
  DateTime? get lastSyncAttempt => _lastSyncAttempt;

  /// Initialize connection monitoring
  Future<void> initialize() async {
    await _checkInitialConnection();
    _startConnectivityMonitoring();
    _startPeriodicSync();
    _updatePendingSyncCount();
  }

  /// Check initial connection status
  Future<void> _checkInitialConnection() async {
    try {
      final connectivityResults = await _connectivity.checkConnectivity();
      await _updateConnectionStatus(connectivityResults);
    } catch (e) {
      _updateState(_state.copyWith(
        status: ConnectionStatus.unknown,
        error: 'Failed to check initial connection: $e',
      ));
    }
  }

  /// Start monitoring connectivity changes
  void _startConnectivityMonitoring() {
    _connectivitySubscription?.cancel();
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      _updateConnectionStatus,
      onError: (error) {
        _updateState(_state.copyWith(
          error: 'Connectivity monitoring error: $error',
        ));
      },
    );
  }

  /// Update connection status based on connectivity result
  Future<void> _updateConnectionStatus(List<ConnectivityResult> results) async {
    final hasConnection = results.any((result) => result != ConnectivityResult.none);

    if (hasConnection) {
      // Test actual internet connectivity with a ping
      final isReallyOnline = await _testInternetConnection();
      if (isReallyOnline) {
        _updateState(_state.copyWith(
          status: ConnectionStatus.online,
          error: null,
          lastUpdated: DateTime.now(),
        ));

        // Trigger immediate sync when coming back online
        if (_state.status == ConnectionStatus.offline) {
          _triggerSync();
        }
      } else {
        _updateState(_state.copyWith(
          status: ConnectionStatus.offline,
          lastUpdated: DateTime.now(),
        ));
      }
    } else {
      _updateState(_state.copyWith(
        status: ConnectionStatus.offline,
        lastOnlineAt: _state.isOnline ? DateTime.now() : _state.lastOnlineAt,
        lastUpdated: DateTime.now(),
      ));
    }
  }

  /// Test actual internet connection with a ping
  Future<bool> _testInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Update state and notify listeners
  void _updateState(ConnectionState newState) {
    if (_state.status != newState.status ||
        _state.error != newState.error) {

      _state = newState;
      notifyListeners();

      if (kDebugMode) {
        debugPrint('[ConnectionProvider] Status changed to: ${newState.status}');
      }
    }
  }

  /// Start periodic sync when online
  void _startPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      if (isOnline && !_isSyncing) {
        _triggerSync();
      }
    });
  }

  /// Trigger data synchronization
  Future<void> _triggerSync() async {
    if (_isSyncing || !isOnline) return;

    _isSyncing = true;
    _lastSyncAttempt = DateTime.now();
    notifyListeners();

    try {
      await _performSync();

      // Update pending count after sync
      await _updatePendingSyncCount();

      if (kDebugMode) {
        debugPrint('[ConnectionProvider] Sync completed successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ConnectionProvider] Sync failed: $e');
      }
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  /// Perform the actual data synchronization
  Future<void> _performSync() async {
    if (!_firestoreService.isFirebaseAvailable) return;

    final pendingOperations = await _localStorageService.getPendingSyncOperations();

    for (final operation in pendingOperations) {
      try {
        await _processSyncOperation(operation);
        await _localStorageService.markSyncCompleted(operation['id']);
      } catch (e) {
        await _localStorageService.updateSyncRetry(operation['id'], e.toString());

        // Skip operations that failed too many times
        if ((operation['retry_count'] as int) >= 3) {
          if (kDebugMode) {
            debugPrint('[ConnectionProvider] Skipping operation after 3 retries: ${operation['id']}');
          }
          await _localStorageService.markSyncCompleted(operation['id']);
        }

        rethrow;
      }
    }
  }

  /// Process individual sync operation
  Future<void> _processSyncOperation(Map<String, dynamic> operation) async {
    final operationType = operation['operation_type'] as String;
    final tableName = operation['table_name'] as String;
    final recordId = operation['record_id'] as String;
    final operationData = Map<String, dynamic>.from(
      operation['operation_data'] is String
        ? {} // Handle JSON parsing if needed
        : operation['operation_data']
    );

    switch (tableName) {
      case 'patients':
        await _syncPatientOperation(operationType, recordId, operationData);
        break;
      case 'clinical_notes':
        await _syncClinicalNoteOperation(operationType, recordId, operationData);
        break;
      case 'document_scans':
        await _syncDocumentScanOperation(operationType, recordId, operationData);
        break;
      case 'consultation_sessions':
        await _syncConsultationOperation(operationType, recordId, operationData);
        break;
      default:
        if (kDebugMode) {
          debugPrint('[ConnectionProvider] Unknown table name: $tableName');
        }
    }

    // Mark the record as synced in local database
    await _localStorageService.markRecordSynced(tableName, recordId);
  }

  /// Sync patient operations
  Future<void> _syncPatientOperation(String operationType, String recordId, Map<String, dynamic> data) async {
    switch (operationType) {
      case 'INSERT':
      case 'UPDATE':
        final patient = ProviderPatientRecord.fromMap(data);
        await _firestoreService.savePatientRecord(patient);
        break;
      case 'DELETE':
        await _firestoreService.deletePatientRecord(recordId);
        break;
    }
  }

  /// Sync clinical note operations
  Future<void> _syncClinicalNoteOperation(String operationType, String recordId, Map<String, dynamic> data) async {
    switch (operationType) {
      case 'INSERT':
      case 'UPDATE':
        final note = ClinicalNote.fromMap(data);
        await _firestoreService.saveClinicalReport(note);
        break;
      case 'DELETE':
        await _firestoreService.deleteClinicalReport(recordId);
        break;
    }
  }

  /// Sync document scan operations
  Future<void> _syncDocumentScanOperation(String operationType, String recordId, Map<String, dynamic> data) async {
    switch (operationType) {
      case 'INSERT':
      case 'UPDATE':
        final scan = DocumentScan.fromMap(data);
        await _firestoreService.saveDocumentScan(scan);
        break;
      case 'DELETE':
        await _firestoreService.deleteDocumentScan(recordId);
        break;
    }
  }

  /// Sync consultation session operations
  Future<void> _syncConsultationOperation(String operationType, String recordId, Map<String, dynamic> data) async {
    switch (operationType) {
      case 'INSERT':
      case 'UPDATE':
        final session = ConsultationSession.fromMap(data);
        await _firestoreService.saveConsultationSession(session);
        break;
      case 'DELETE':
        await _firestoreService.deleteConsultationSession(recordId);
        break;
    }
  }

  /// Update pending sync operations count
  Future<void> _updatePendingSyncCount() async {
    try {
      final operations = await _localStorageService.getPendingSyncOperations();
      _pendingSyncCount = operations.length;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ConnectionProvider] Failed to update pending sync count: $e');
      }
    }
  }

  /// Force sync now (manual trigger)
  Future<void> forceSync() async {
    if (!isOnline) {
      throw Exception('Cannot sync while offline');
    }

    await _triggerSync();
  }

  /// Get sync statistics
  Map<String, dynamic> getSyncStatistics() {
    return {
      'isOnline': isOnline,
      'isSyncing': isSyncing,
      'pendingSyncCount': pendingSyncCount,
      'lastSyncAttempt': lastSyncAttempt?.toIso8601String(),
      'lastOnlineAt': _state.lastOnlineAt?.toIso8601String(),
    };
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _syncTimer?.cancel();
    super.dispose();
  }
}
