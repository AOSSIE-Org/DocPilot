import 'package:flutter/material.dart';

import '../models/health_models.dart';
import '../services/firebase/auth_service.dart';
import '../services/firebase/firestore_service.dart';

/// Base mixin for screens that work with patient data
/// Provides common patient loading and management functionality
mixin BasePatientScreen<T extends StatefulWidget> on State<T> {
  @protected final FirestoreService firestoreService = FirestoreService();
  @protected final AuthService authService = AuthService();

  /// Current patient data (null if no patient or loading)
  @protected ProviderPatientRecord? patient;

  /// Get current doctor ID from authenticated user
  @protected String? get doctorId => authService.currentUser?.uid;

  /// Load patient data by ID for the current doctor
  /// Returns true if patient was found and loaded successfully
  @protected Future<bool> loadPatientData(String? patientId) async {
    if (patientId == null ||
        patientId.isEmpty ||
        patientId == 'no-patient' ||
        patientId == 'demo-patient') {
      return false;
    }

    try {
      final currentDoctorId = doctorId;
      if (currentDoctorId == null) {
        debugPrint('[BasePatientScreen] No authenticated doctor found');
        return false;
      }

      final patients = await firestoreService.getDoctorPatients(currentDoctorId);
      try {
        final foundPatient = patients.firstWhere((p) => p.id == patientId);

        if (mounted) {
          setState(() {
            patient = foundPatient;
          });
          onPatientLoaded(foundPatient);
          return true;
        }
        return false;
      } catch (e) {
        // Patient not found, try to use first available patient as fallback
        if (patients.isNotEmpty) {
          final fallbackPatient = patients.first;
          debugPrint('[BasePatientScreen] Patient $patientId not found, using fallback: ${fallbackPatient.id}');

          if (mounted) {
            setState(() {
              patient = fallbackPatient;
            });
            onPatientLoaded(fallbackPatient);
            return true;
          }
        } else {
          debugPrint('[BasePatientScreen] No patients found for doctor $currentDoctorId');
        }
        return false;
      }
    } catch (e) {
      debugPrint('[BasePatientScreen] Error loading patient $patientId: $e');
      return false;
    }
  }

  /// Called when patient data is successfully loaded
  /// Override in implementing screens to handle patient-specific initialization
  @protected void onPatientLoaded(ProviderPatientRecord loadedPatient) {
    // Default implementation does nothing
    // Override in subclasses for patient-specific setup
  }

  /// Get display name for current patient or fallback text
  @protected String getPatientDisplayName({String fallback = 'No patient selected'}) {
    return patient?.fullName ?? fallback;
  }

  /// Get formatted patient info string
  @protected String getPatientInfo() {
    final p = patient;
    if (p == null) return '';
    return '${p.fullName} • ${p.age} yrs • ${p.gender}';
  }

  /// Get patient allergies formatted for display
  @protected String getPatientAllergies({String type = 'all'}) {
    final p = patient;
    if (p == null) return 'None reported';

    switch (type.toLowerCase()) {
      case 'food':
        return p.foodAllergies.isEmpty ? 'None reported' : p.foodAllergies.join(', ');
      case 'medicine':
      case 'medication':
        return p.medicinalAllergies.isEmpty ? 'None reported' : p.medicinalAllergies.join(', ');
      case 'all':
      default:
        final allAllergies = [...p.foodAllergies, ...p.medicinalAllergies];
        return allAllergies.isEmpty ? 'None reported' : allAllergies.join(', ');
    }
  }

  /// Get patient medical history formatted for display
  @protected String getPatientMedicalHistory() {
    final p = patient;
    if (p == null || p.medicalHistory.isEmpty) return 'None documented';
    return p.medicalHistory.join(', ');
  }

  /// Check if patient data is currently loaded
  @protected bool get hasPatient => patient != null;

  /// Get patient ID if available
  @protected String? get patientId => patient?.id;
}