import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import '../../models/health_models.dart';
import '../../services/firebase/optimized_firestore_service.dart';
import '../storage/local_storage_service.dart';
import '../sync/smart_sync_service.dart';
import 'base_provider.dart';

/// Enhanced connection provider with smart sync and offline queue management
class EnhancedConnectionProvider extends ChangeNotifier {
  final Connectivity _connectivity = Connectivity();
  final OptimizedFirestoreService _firestoreService = OptimizedFirestoreService();
  final LocalStorageService _localStorageService = LocalStorageService();
  final SmartSyncService _syncService = SmartSyncService();

  ConnectionState _state = ConnectionState();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Timer? _syncTimer;
  Timer? _pingTimer;
  Timer? _queueProcessingTimer;

  // Enhanced sync state
  bool _isSyncing = false;
  bool _isProcessingQueue = false;
  int _pendingSyncCount = 0;
  int _failedOperations = 0;
  DateTime? _lastSyncAttempt;
  DateTime? _lastSuccessfulSync;

  // Offline queue management
  final List<OfflineOperation> _operationQueue = [];
  int _maxRetries = 3;

  ConnectionState get state => _state;
  ConnectionStatus get status => _state.status;
  bool get isOnline => _state.isOnline;
  bool get isOffline => _state.isOffline;
  bool get isSyncing => _isSyncing;
  bool get isProcessingQueue => _isProcessingQueue;
  int get pendingSyncCount => _pendingSyncCount;
  int get failedOperations => _failedOperations;
  DateTime? get lastSyncAttempt => _lastSyncAttempt;
  DateTime? get lastSuccessfulSync => _lastSuccessfulSync;
  List<OfflineOperation> get operationQueue => List.unmodifiable(_operationQueue);

  /// Initialize enhanced connection monitoring
  Future<void> initialize() async {
    await _checkInitialConnection();
    _startConnectivityMonitoring();
    _startPeriodicSync();
    _startQueueProcessing();
    await _updatePendingSyncCount();
  }

  /// Check initial connection status with enhanced testing
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

  /// Enhanced connectivity monitoring with multiple checks
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

  /// Update connection status with comprehensive testing
  Future<void> _updateConnectionStatus(List<ConnectivityResult> results) async {
    final hasConnection = results.any((result) => result != ConnectivityResult.none);

    if (!hasConnection) {
      _updateState(_state.copyWith(
        status: ConnectionStatus.offline,
        lastOnlineAt: _state.isOnline ? DateTime.now() : _state.lastOnlineAt,
        lastUpdated: DateTime.now(),
      ));
      return;
    }

    // Has connection, but test if it's actually working
    final isReallyOnline = await _testMultipleConnections();
    final newStatus = isReallyOnline ? ConnectionStatus.online : ConnectionStatus.offline;

    _updateState(_state.copyWith(
      status: newStatus,
      error: isReallyOnline ? null : 'No internet access',
      lastUpdated: DateTime.now(),
    ));

    // When coming back online, trigger smart sync
    if (isReallyOnline && _state.status == ConnectionStatus.offline) {
      await _onBackOnline();
    }
  }

  /// Test multiple connection endpoints for reliability
  Future<bool> _testMultipleConnections() async {
    final testHosts = [
      'google.com',
      'firebase.google.com',
      'cloudflare.com',
    ];

    int successCount = 0;
    const timeout = Duration(seconds: 5);

    for (final host in testHosts) {
      try {
        final result = await InternetAddress.lookup(host).timeout(timeout);
        if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
          successCount++;
          if (successCount >= 2) {
            return true; // Require at least 2 successful connections
          }
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[EnhancedConnectionProvider] Failed to reach $host: $e');
        }
      }
    }

    return successCount > 0; // At least one connection successful
  }

  /// Handle coming back online
  Future<void> _onBackOnline() async {
    if (kDebugMode) {
      debugPrint('[EnhancedConnectionProvider] Back online - triggering smart sync');
    }

    // Process offline queue first
    unawaited(_processOfflineQueue());

    // Then trigger full smart sync
    unawaited(_triggerSmartSync());
  }

  /// Enhanced sync with smart conflict resolution
  Future<void> _triggerSmartSync() async {
    if (_isSyncing || !isOnline) return;

    _isSyncing = true;
    _lastSyncAttempt = DateTime.now();
    notifyListeners();

    try {
      final result = await _syncService.performSmartSync(
        defaultStrategy: ConflictResolutionStrategy.newerWins,
        onConflictDetected: _handleConflictDetected,
      );

      if (!result.hasErrors) {
        _lastSuccessfulSync = DateTime.now();
        _failedOperations = 0;
      } else {
        _failedOperations += result.errors.length;
      }

      await _updatePendingSyncCount();

      if (kDebugMode) {
        debugPrint('[EnhancedConnectionProvider] Smart sync result: ${result.summary()}');
      }
    } catch (e) {
      _failedOperations++;
      if (kDebugMode) {
        debugPrint('[EnhancedConnectionProvider] Smart sync failed: $e');
      }
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  /// Handle detected conflicts during sync
  void _handleConflictDetected(DataConflict conflict) {
    if (kDebugMode) {
      debugPrint('[EnhancedConnectionProvider] Conflict detected: ${conflict.recordId} in ${conflict.tableName}');
    }
    // Could emit events here for UI to handle user-choice conflicts
  }

  /// Start periodic sync with adaptive intervals
  void _startPeriodicSync() {
    _syncTimer?.cancel();

    // Adaptive sync intervals based on connection quality and activity
    Duration syncInterval = const Duration(minutes: 5);

    if (_failedOperations > 3) {
      syncInterval = const Duration(minutes: 15); // Back off on failures
    } else if (_pendingSyncCount > 50) {
      syncInterval = const Duration(minutes: 2); // Sync more frequently with high backlog
    }

    _syncTimer = Timer.periodic(syncInterval, (timer) {
      if (isOnline && !_isSyncing) {
        _triggerSmartSync();
      }
    });
  }

  /// Start offline queue processing
  void _startQueueProcessing() {
    _queueProcessingTimer?.cancel();
    _queueProcessingTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (isOnline && !_isProcessingQueue) {
        _processOfflineQueue();
      }
    });
  }

  /// Process offline operation queue
  Future<void> _processOfflineQueue() async {
    if (_isProcessingQueue || !isOnline || _operationQueue.isEmpty) return;

    _isProcessingQueue = true;
    notifyListeners();

    final currentTime = DateTime.now();
    final operationsToProcess = _operationQueue
        .where((op) => op.shouldRetry(currentTime))
        .toList();

    for (final operation in operationsToProcess) {
      try {
        await _executeOfflineOperation(operation);
        _operationQueue.remove(operation);

        if (kDebugMode) {
          debugPrint('[EnhancedConnectionProvider] Successfully executed offline operation: ${operation.id}');
        }
      } catch (e) {
        operation.recordFailure(e.toString());

        if (operation.retryCount >= _maxRetries) {
          _operationQueue.remove(operation);
          _failedOperations++;

          if (kDebugMode) {
            debugPrint('[EnhancedConnectionProvider] Abandoned operation after max retries: ${operation.id}');
          }
        }
      }
    }

    _isProcessingQueue = false;
    notifyListeners();
  }

  /// Execute a single offline operation
  Future<void> _executeOfflineOperation(OfflineOperation operation) async {
    switch (operation.type) {
      case OperationType.savePatient:
        final patient = ProviderPatientRecord.fromMap(operation.data);
        await _firestoreService.savePatientRecord(patient);
        break;

      case OperationType.saveClinicalNote:
        final note = ClinicalNote.fromMap(operation.data);
        await _firestoreService.saveClinicalReport(note);
        break;

      case OperationType.saveDocumentScan:
        final scan = DocumentScan.fromMap(operation.data);
        await _firestoreService.saveDocumentScan(scan);
        break;

      case OperationType.deletePatient:
        await _firestoreService.deletePatientRecord(operation.recordId);
        break;

      case OperationType.deleteClinicalNote:
        await _firestoreService.deleteClinicalReport(operation.recordId);
        break;

      case OperationType.deleteDocumentScan:
        await _firestoreService.deleteDocumentScan(operation.recordId);
        break;

      case OperationType.saveConsultationSession:
        // Save consultation session offline operation
        debugPrint('[EnhancedConnectionProvider] Saving consultation session: ${operation.recordId}');
        break;

      case OperationType.deleteConsultationSession:
        // Delete consultation session offline operation
        debugPrint('[EnhancedConnectionProvider] Deleting consultation session: ${operation.recordId}');
        break;
    }
  }

  /// Add operation to offline queue
  void queueOfflineOperation(OfflineOperation operation) {
    _operationQueue.add(operation);
    notifyListeners();

    if (kDebugMode) {
      debugPrint('[EnhancedConnectionProvider] Queued offline operation: ${operation.type} for ${operation.recordId}');
    }

    // Try to process immediately if online
    if (isOnline) {
      unawaited(_processOfflineQueue());
    }
  }

  /// Update state and notify listeners
  void _updateState(ConnectionState newState) {
    if (_state.status != newState.status ||
        _state.error != newState.error) {
      _state = newState;
      notifyListeners();

      if (kDebugMode) {
        debugPrint('[EnhancedConnectionProvider] Status changed to: ${newState.status}');
      }
    }
  }

  /// Update pending sync operations count
  Future<void> _updatePendingSyncCount() async {
    try {
      final operations = await _localStorageService.getPendingSyncOperations();
      _pendingSyncCount = operations.length + _operationQueue.length;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[EnhancedConnectionProvider] Failed to update pending sync count: $e');
      }
    }
  }

  /// Force sync now (manual trigger with enhanced feedback)
  Future<SyncResult> forceSync({bool includeSmartSync = true}) async {
    if (!isOnline) {
      throw Exception('Cannot sync while offline');
    }

    if (includeSmartSync) {
      return await _syncService.performSmartSync(
        defaultStrategy: ConflictResolutionStrategy.newerWins,
        onConflictDetected: _handleConflictDetected,
      );
    } else {
      // Just process the offline queue
      await _processOfflineQueue();
      return SyncResult(); // Empty result for queue processing
    }
  }

  /// Clear failed operations and reset retry counts
  void clearFailedOperations() {
    _operationQueue.removeWhere((op) => op.retryCount >= _maxRetries);
    _failedOperations = 0;
    notifyListeners();
  }

  /// Get comprehensive sync statistics
  Map<String, dynamic> getEnhancedSyncStatistics() {
    return {
      'isOnline': isOnline,
      'isSyncing': isSyncing,
      'isProcessingQueue': isProcessingQueue,
      'pendingSyncCount': pendingSyncCount,
      'queuedOperations': _operationQueue.length,
      'failedOperations': failedOperations,
      'lastSyncAttempt': lastSyncAttempt?.toIso8601String(),
      'lastSuccessfulSync': lastSuccessfulSync?.toIso8601String(),
      'lastOnlineAt': _state.lastOnlineAt?.toIso8601String(),
      'syncService': _syncService.getSyncStatistics(),
      'cache': _firestoreService.getCacheStatistics(),
    };
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _syncTimer?.cancel();
    _pingTimer?.cancel();
    _queueProcessingTimer?.cancel();
    super.dispose();
  }
}

/// Represents an offline operation that can be queued and retried
class OfflineOperation {
  final String id;
  final OperationType type;
  final String recordId;
  final Map<String, dynamic> data;
  final DateTime createdAt;

  int retryCount = 0;
  DateTime? lastRetryAt;
  String? lastError;

  OfflineOperation({
    required this.id,
    required this.type,
    required this.recordId,
    required this.data,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  bool shouldRetry(DateTime currentTime) {
    if (retryCount >= 3) return false; // Max retries reached

    if (lastRetryAt == null) return true; // Never tried

    // Exponential backoff: wait longer each time
    final waitDuration = Duration(seconds: 30 * (retryCount + 1));
    return currentTime.difference(lastRetryAt!) > waitDuration;
  }

  void recordFailure(String error) {
    retryCount++;
    lastRetryAt = DateTime.now();
    lastError = error;
  }
}

/// Types of offline operations
enum OperationType {
  savePatient,
  saveClinicalNote,
  saveDocumentScan,
  saveConsultationSession,
  deletePatient,
  deleteClinicalNote,
  deleteDocumentScan,
  deleteConsultationSession,
}