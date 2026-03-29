import 'package:flutter/material.dart';

import '../../models/health_models.dart';
import '../../screens/auth/auth_gate_screen.dart';
import '../../screens/auth/sign_in_screen.dart';
import '../../screens/clinical_notes_screen.dart';
import '../../screens/document_scanner_screen.dart';
import '../../screens/doctor_patients_screen.dart';
import '../../screens/doctor_profile_screen.dart';
import '../../screens/medication_safety_screen.dart';
import '../../screens/patient_profile_screen.dart';
import '../../screens/shift_handoff_screen.dart';
import '../../screens/transcription_detail_screen.dart';
import '../../screens/voice_assistant_screen.dart';
import '../../screens/emergency_triage_screen.dart';
import '../../screens/ward_rounds_screen.dart';
import '../../screens/ai_briefing_screen.dart';

class AppRouter {
  static const String home = '/';
  static const String signIn = '/sign-in';
  static const String patientProfile = '/patient-profile';
  static const String doctorPatients = '/doctor-patients';
  static const String doctorProfile = '/doctor-profile';
  static const String voiceAssistant = '/voice-assistant';
  static const String documentScanner = '/document-scanner';
  static const String clinicalNotes = '/clinical-notes';
  static const String transcription = '/transcription';
  static const String medicationSafety = '/medication-safety';
  static const String shiftHandoff = '/shift-handoff';
  static const String emergencyTriage = '/emergency-triage';
  static const String wardRounds = '/ward-rounds';
  static const String aiBriefing = '/ai-briefing';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case home:
        return MaterialPageRoute(builder: (_) => const AuthGateScreen());
      case signIn:
        return MaterialPageRoute(builder: (_) => const SignInScreen());
      case patientProfile:
        String? patientId;
        PatientProfile? initialProfile;

        final args = settings.arguments;
        if (args is String) {
          patientId = args;
        } else if (args is Map<String, dynamic>) {
          patientId = args['patientId'] as String?;
          initialProfile = args['profile'] as PatientProfile?;
        } else if (args is PatientProfile) {
          initialProfile = args;
        }

        return MaterialPageRoute(
          builder: (_) => PatientProfileScreen(
            patientId: patientId,
            initialProfile: initialProfile,
          ),
        );
      case doctorPatients:
        return MaterialPageRoute(builder: (_) => const DoctorPatientsScreen());
      case doctorProfile:
        // Safe type check to prevent crash with wrong argument type
        final profile = settings.arguments is DoctorProfile
            ? settings.arguments as DoctorProfile
            : null;
        return MaterialPageRoute(
          builder: (_) => DoctorProfileScreen(initialProfile: profile),
        );
      case voiceAssistant:
        String patientId = 'no-patient';
        String? initialPrompt;

        final args = settings.arguments;
        if (args is String) {
          patientId = args;
        } else if (args is Map<String, dynamic>) {
          patientId = (args['patientId'] as String?) ?? patientId;
          initialPrompt = args['initialPrompt'] as String?;
        }

        return MaterialPageRoute(
          builder: (_) => InteractiveVoiceAssistantScreen(
            patientId: patientId,
            initialPrompt: initialPrompt,
          ),
        );
      case documentScanner:
        final patientId = settings.arguments is String
            ? settings.arguments as String
            : 'no-patient';
        return MaterialPageRoute(
          builder: (_) => DocumentScannerScreen(patientId: patientId),
        );
      case clinicalNotes:
        final patientId = settings.arguments is String
            ? settings.arguments as String
            : 'no-patient';
        return MaterialPageRoute(
          builder: (_) => ClinicalNotesScreen(patientId: patientId),
        );
      case transcription:
        final transcription = settings.arguments is String
            ? settings.arguments as String
            : '';
        return MaterialPageRoute(
          builder: (_) => TranscriptionDetailScreen(transcription: transcription),
        );
      case medicationSafety:
        final patientId = settings.arguments is String
            ? settings.arguments as String
            : null;
        return MaterialPageRoute(
          builder: (_) => MedicationSafetyScreen(patientId: patientId),
        );
      case shiftHandoff:
        final patientId = settings.arguments is String
            ? settings.arguments as String
            : null;
        return MaterialPageRoute(
          builder: (_) => ShiftHandoffScreen(patientId: patientId),
        );
      case emergencyTriage:
        final patientId = settings.arguments is String
            ? settings.arguments as String
            : (settings.arguments is Map<String, dynamic>
                ? (settings.arguments as Map<String, dynamic>)['patientId'] as String? ?? 'no-patient'
                : 'no-patient');
        return MaterialPageRoute(
          builder: (_) => EmergencyTriageScreen(patientId: patientId),
        );
      case wardRounds:
        final patientId = settings.arguments is String
            ? settings.arguments as String
            : (settings.arguments is Map<String, dynamic>
                ? (settings.arguments as Map<String, dynamic>)['patientId'] as String? ?? 'no-patient'
                : 'no-patient');
        return MaterialPageRoute(
          builder: (_) => WardRoundsScreen(patientId: patientId),
        );
      case aiBriefing:
        String patientId = 'no-patient';
        String? initialPrompt;
        final args = settings.arguments;
        if (args is String) {
          patientId = args;
        } else if (args is Map<String, dynamic>) {
          patientId = (args['patientId'] as String?) ?? patientId;
          initialPrompt = args['initialPrompt'] as String?;
        }
        return MaterialPageRoute(
          builder: (_) => AIBriefingScreen(
            patientId: patientId,
            initialPrompt: initialPrompt,
          ),
        );
      default:
        return MaterialPageRoute(
          builder: (_) => const Scaffold(
            body: Center(child: Text('Page not found')),
          ),
        );
    }
  }
}
