/// Application-wide constants
class AppConstants {
  // Prevent instantiation
  AppConstants._();

  // Firebase/Cloud Config
  static const String firebaseEnabledKey = 'FIREBASE_ENABLED';
  static const String firebaseUseEmulatorKey = 'FIREBASE_USE_EMULATOR';
  static const String firestoreEmulatorHostKey = 'FIRESTORE_EMULATOR_HOST';
  static const String firestoreEmulatorPortKey = 'FIRESTORE_EMULATOR_PORT';
  static const String authEmulatorHostKey = 'AUTH_EMULATOR_HOST';
  static const String authEmulatorPortKey = 'AUTH_EMULATOR_PORT';
  static const String fcmEnabledKey = 'FCM_ENABLED';

  // Firebase Collections and Documents
  static const String apiKeysCollection = 'app_runtime';
  static const String apiKeysDocument = 'api_keys';
  static const String patientsCollection = 'patients';
  static const String clinicalReportsCollection = 'clinical_reports';
  static const String consultationSessionsCollection = 'consultation_sessions';
  static const String documentScansCollection = 'document_scans';

  // Default values
  static const String defaultDateOfBirth = '1990-01-01';
  static const String defaultGender = 'Unknown';
  static const String defaultBloodType = 'Unknown';
  static const String defaultNoSummary = 'No summary available.';
  static const String defaultDoctor = 'Doctor';
  static const String defaultClinicianName = 'Clinician';

  // Connection timeouts
  static const Duration connectionTimeout = Duration(seconds: 5);
  static const Duration syncTimeout = Duration(seconds: 30);

  // Pagination and limits
  static const int defaultPageSize = 20;
  static const int maxRetryAttempts = 3;
  static const Duration retryDelay = Duration(seconds: 30);

  // Device defaults
  static const Duration portraitDefaultDuration = Duration(milliseconds: 300);
  static const double largeIconSize = 64.0;
  static const double mediumIconSize = 32.0;
  static const double smallIconSize = 16.0;

  // Error messages
  static const String errorGeneric = 'Something went wrong. Please try again.';
  static const String errorNoInternet = 'No internet connection. Working offline.';
  static const String errorFirebaseNotConfigured = 'Firebase is not configured. Please check your setup.';
  static const String errorApiKeyNotFound = 'API key not configured.';
  static const String errorEmptyInput = 'Please enter all required fields.';
  static const String errorPatientNotFound = 'Patient not found.';
  static const String errorFailedToLoad = 'Failed to load data.';
  static const String errorFailedToSave = 'Failed to save data.';
  static const String errorFailedToDelete = 'Failed to delete data.';

  // Success messages
  static const String successSaved = 'Saved successfully';
  static const String successDeleted = 'Deleted successfully';
  static const String successUpdated = 'Updated successfully';

  // UI Labels
  static const String labelTitle = 'Title';
  static const String labelDiagnosis = 'Diagnosis / Assessment';
  static const String labelClinicalNotes = 'Clinical Notes';
  static const String labelPatient = 'Patient';
  static const String labelAge = 'Age';
  static const String labelGender = 'Gender';
  static const String labelAllergies = 'Allergies';
  static const String labelMedicalHistory = 'Medical History';
  static const String labelClear = 'Clear';
  static const String labelSave = 'Save';
  static const String labelCancel = 'Cancel';
  static const String labelDelete = 'Delete';
  static const String labelEdit = 'Edit';
  static const String labelRefresh = 'Refresh';
  static const String labelLoading = 'Loading...';
  static const String labelSaving = 'Saving...';
  static const String labelRetry = 'Retry';

  // Network hosts for connectivity testing
  static const List<String> connectivityTestHosts = [
    'google.com',
    'firebase.google.com',
    'cloudflare.com',
  ];

  // Feature flags
  static const bool enableOfflineMode = true;
  static const bool enableDebugLogging = true;
  static const bool enableAnalytics = false; // TODO: Enable for production

  // Regex patterns for validation
  static const String emailPattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$';
  static const String phonePattern = r'^[0-9]{10,}$'; // Min 10 digits
  static const String datePattern = r'^\d{4}-\d{2}-\d{2}$'; // YYYY-MM-DD
}
