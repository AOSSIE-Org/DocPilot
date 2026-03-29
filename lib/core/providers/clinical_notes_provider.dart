import 'dart:async';
import 'package:flutter/foundation.dart';

import '../../models/health_models.dart';
import '../../services/firebase/firestore_service.dart';
import '../storage/local_storage_service.dart';
import 'base_provider.dart';

class ClinicalNotesProvider extends BasePaginatedProvider<ClinicalNote> {
  final FirestoreService _firestoreService = FirestoreService();
  final LocalStorageService _localStorageService = LocalStorageService();

  String? _currentPatientId;
  StreamSubscription<List<ClinicalNote>>? _dataSubscription;

  String? get currentPatientId => _currentPatientId;

  /// Load clinical notes for a specific patient
  Future<void> loadNotesForPatient(String patientId) async {
    _currentPatientId = patientId;
    await loadData();
  }

  @override
  Future<void> loadData() async {
    if (_currentPatientId == null) return;

    setLoading();

    try {
      // Load from local storage first
      final localNotes = await _localStorageService.getClinicalNotes(_currentPatientId!);
      if (localNotes.isNotEmpty) {
        setSuccess(
          items: localNotes,
          hasMore: false,
        );
      }

      // Sync with Firebase if available
      if (_firestoreService.isFirebaseAvailable) {
        final firebaseNotes = await _firestoreService.getClinicalReports(_currentPatientId!);
        setSuccess(
          items: firebaseNotes,
          hasMore: false,
        );

        // Update local storage
        for (final note in firebaseNotes) {
          await _localStorageService.saveClinicalNote(note, markDirty: false);
        }
      }
    } catch (e) {
      setError(e.toString());
    }
  }

  @override
  Future<void> loadMore() async {
    // Clinical notes don't paginate for now
  }

  @override
  Future<void> refresh() async {
    await loadData();
  }

  /// Add a new clinical note
  Future<void> addNote(ClinicalNote note) async {
    try {
      // Save locally first
      await _localStorageService.saveClinicalNote(note);
      prependItem(note);

      // Sync to Firebase if available
      if (_firestoreService.isFirebaseAvailable) {
        await _firestoreService.saveClinicalReport(note);
      }
    } catch (e) {
      setError('Failed to add clinical note: $e');
      rethrow;
    }
  }

  /// Delete a clinical note
  Future<void> deleteNote(String noteId) async {
    try {
      // Remove from UI first for immediate feedback
      removeItem((note) => note.id == noteId);

      // Delete from Firebase if available
      if (_firestoreService.isFirebaseAvailable) {
        await _firestoreService.deleteClinicalReport(noteId);
      }
    } catch (e) {
      setError('Failed to delete clinical note: $e');
      // Refresh to restore state on error
      refresh();
      rethrow;
    }
  }

  /// Get note by ID
  ClinicalNote? getNoteById(String noteId) {
    try {
      return items.firstWhere((note) => note.id == noteId);
    } catch (e) {
      return null;
    }
  }

  /// Search notes by content
  List<ClinicalNote> searchNotes(String query) {
    if (query.isEmpty) return items;

    final lowerQuery = query.toLowerCase();
    return items.where((note) {
      return note.title.toLowerCase().contains(lowerQuery) ||
             note.content.toLowerCase().contains(lowerQuery) ||
             (note.diagnosis?.toLowerCase().contains(lowerQuery) ?? false) ||
             note.createdBy.toLowerCase().contains(lowerQuery);
    }).toList();
  }

  /// Filter notes by date range
  List<ClinicalNote> getNotesInDateRange(DateTime start, DateTime end) {
    return items.where((note) {
      return note.createdAt.isAfter(start) && note.createdAt.isBefore(end);
    }).toList();
  }

  /// Watch real-time updates from Firebase
  void watchNotesForPatient(String patientId) {
    _currentPatientId = patientId;

    if (!_firestoreService.isFirebaseAvailable) {
      loadData();
      return;
    }

    _dataSubscription?.cancel();
    _dataSubscription = _firestoreService.watchClinicalReports(patientId).listen(
      (notes) {
        setSuccess(
          items: notes,
          hasMore: false,
        );

        // Update local storage in background
        _updateLocalStorage(notes);
      },
      onError: (error) {
        setError(error.toString());
        // Fallback to local data
        loadData();
      },
    );
  }

  /// Update local storage in background
  Future<void> _updateLocalStorage(List<ClinicalNote> notes) async {
    try {
      for (final note in notes) {
        await _localStorageService.saveClinicalNote(note, markDirty: false);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ClinicalNotesProvider] Failed to update local storage: $e');
      }
    }
  }

  /// Get notes statistics
  Map<String, dynamic> getNotesStatistics() {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final weekStart = todayStart.subtract(const Duration(days: 7));
    final monthStart = DateTime(now.year, now.month, 1);

    return {
      'total': items.length,
      'today': items.where((note) => note.createdAt.isAfter(todayStart)).length,
      'thisWeek': items.where((note) => note.createdAt.isAfter(weekStart)).length,
      'thisMonth': items.where((note) => note.createdAt.isAfter(monthStart)).length,
      'withDiagnosis': items.where((note) => note.diagnosis?.isNotEmpty ?? false).length,
      'withTreatments': items.where((note) => note.treatments.isNotEmpty).length,
      'withFollowUp': items.where((note) => note.followUpItems.isNotEmpty).length,
    };
  }

  /// Get recent notes (last 5)
  List<ClinicalNote> getRecentNotes([int limit = 5]) {
    return items.take(limit).toList();
  }

  /// Group notes by date
  Map<String, List<ClinicalNote>> groupNotesByDate() {
    final grouped = <String, List<ClinicalNote>>{};

    for (final note in items) {
      final dateKey = '${note.createdAt.year}-${note.createdAt.month.toString().padLeft(2, '0')}-${note.createdAt.day.toString().padLeft(2, '0')}';
      grouped.putIfAbsent(dateKey, () => []).add(note);
    }

    return grouped;
  }
}