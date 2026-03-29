import 'dart:async';
import 'package:flutter/foundation.dart';

import '../../models/health_models.dart';
import '../../services/firebase/firestore_service.dart';
import '../storage/local_storage_service.dart';
import 'base_provider.dart';

class PatientProvider extends BasePaginatedProvider<ProviderPatientRecord> {
  final FirestoreService _firestoreService = FirestoreService();
  final LocalStorageService _localStorageService = LocalStorageService();

  String? _currentDoctorId;
  StreamSubscription<List<ProviderPatientRecord>>? _dataSubscription;

  String? get currentDoctorId => _currentDoctorId;

  /// Load patients for a specific doctor
  Future<void> loadPatientsForDoctor(String doctorId) async {
    _currentDoctorId = doctorId;
    await loadData();
  }

  @override
  Future<void> loadData() async {
    if (_currentDoctorId == null) return;

    setLoading();

    try {
      // Try local storage first for immediate results
      final localPatients = await _localStorageService.getPatients(_currentDoctorId!);
      if (localPatients.isNotEmpty) {
        setSuccess(
          items: localPatients,
          hasMore: false, // Local data doesn't paginate
        );
      }

      // Then sync with Firebase if available
      if (_firestoreService.isFirebaseAvailable) {
        final firebasePatients = await _firestoreService.getDoctorPatients(_currentDoctorId!);
        setSuccess(
          items: firebasePatients,
          hasMore: false,
        );

        // Update local storage with latest data
        for (final patient in firebasePatients) {
          await _localStorageService.savePatient(patient, markDirty: false);
        }
      }
    } catch (e) {
      setError(e.toString());
    }
  }

  @override
  Future<void> loadMore() async {
    // For now, we don't paginate patients
    // This could be implemented if needed for large datasets
  }

  @override
  Future<void> refresh() async {
    await loadData();
  }

  /// Add a new patient
  Future<void> addPatient(ProviderPatientRecord patient) async {
    try {
      // Save locally first for immediate UI update
      await _localStorageService.savePatient(patient);
      prependItem(patient);

      // Sync to Firebase if available
      if (_firestoreService.isFirebaseAvailable) {
        await _firestoreService.savePatientRecord(patient);
      }
    } catch (e) {
      setError('Failed to add patient: $e');
      rethrow;
    }
  }

  /// Update existing patient
  Future<void> updatePatient(ProviderPatientRecord patient) async {
    try {
      // Update locally first
      await _localStorageService.savePatient(patient);
      updateItem(patient, (p) => p.id == patient.id);

      // Sync to Firebase if available
      if (_firestoreService.isFirebaseAvailable) {
        await _firestoreService.savePatientRecord(patient);
      }
    } catch (e) {
      setError('Failed to update patient: $e');
      rethrow;
    }
  }

  /// Delete a patient
  Future<void> deletePatient(String patientId) async {
    try {
      // Remove from local storage
      await _localStorageService.deletePatient(patientId);
      removeItem((p) => p.id == patientId);

      // Delete from Firebase if available
      if (_firestoreService.isFirebaseAvailable) {
        await _firestoreService.deletePatientRecord(patientId);
      }
    } catch (e) {
      setError('Failed to delete patient: $e');
      rethrow;
    }
  }

  /// Get a specific patient by ID
  ProviderPatientRecord? getPatientById(String patientId) {
    try {
      return items.firstWhere((patient) => patient.id == patientId);
    } catch (e) {
      return null;
    }
  }

  /// Search patients by name
  List<ProviderPatientRecord> searchPatients(String query) {
    if (query.isEmpty) return items;

    final lowerQuery = query.toLowerCase();
    return items.where((patient) {
      return patient.firstName.toLowerCase().contains(lowerQuery) ||
             patient.lastName.toLowerCase().contains(lowerQuery) ||
             patient.fullName.toLowerCase().contains(lowerQuery) ||
             patient.email.toLowerCase().contains(lowerQuery);
    }).toList();
  }

  /// Watch real-time updates from Firebase
  void watchPatientsForDoctor(String doctorId) {
    _currentDoctorId = doctorId;

    if (!_firestoreService.isFirebaseAvailable) {
      loadData();
      return;
    }

    _dataSubscription?.cancel();
    _dataSubscription = _firestoreService.watchDoctorPatients(doctorId).listen(
      (patients) {
        setSuccess(
          items: patients,
          hasMore: false,
        );

        // Update local storage in background
        _updateLocalStorage(patients);
      },
      onError: (error) {
        setError(error.toString());
        // Fallback to local data
        loadData();
      },
    );
  }

  /// Update local storage in background
  Future<void> _updateLocalStorage(List<ProviderPatientRecord> patients) async {
    try {
      for (final patient in patients) {
        await _localStorageService.savePatient(patient, markDirty: false);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[PatientProvider] Failed to update local storage: $e');
      }
    }
  }

  /// Get patients count by status
  Map<String, int> getPatientStatistics() {
    return {
      'total': items.length,
      'withRecentVisits': items.where((p) =>
        p.lastVisitSummary.isNotEmpty &&
        p.lastVisitSummary != 'No summary available.'
      ).length,
      'withAllergies': items.where((p) =>
        p.foodAllergies.isNotEmpty || p.medicinalAllergies.isNotEmpty
      ).length,
      'withMedicalHistory': items.where((p) =>
        p.medicalHistory.isNotEmpty
      ).length,
    };
  }
}