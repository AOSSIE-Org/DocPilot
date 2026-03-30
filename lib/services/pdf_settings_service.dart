import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:doc_pilot_new_app_gradel_fix/models/pdf_settings.dart';

/// Service for managing PDF customization settings
///
/// Handles persistence of doctor info, clinic info, and PDF template preferences
/// using SharedPreferences for local storage.
class PdfSettingsService {
  static const String _keyDoctorInfo = 'pdf_doctor_info';
  static const String _keyClinicInfo = 'pdf_clinic_info';
  static const String _keyPdfTemplate = 'pdf_template';

  /// Saves doctor information to local storage
  Future<void> saveDoctorInfo(DoctorInfo doctorInfo) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(doctorInfo.toJson());
    await prefs.setString(_keyDoctorInfo, jsonString);
  }

  /// Retrieves doctor information from local storage
  Future<DoctorInfo> getDoctorInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_keyDoctorInfo);

    if (jsonString == null || jsonString.isEmpty) {
      return DoctorInfo.empty();
    }

    try {
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return DoctorInfo.fromJson(json);
    } catch (e) {
      return DoctorInfo.empty();
    }
  }

  /// Saves clinic information to local storage
  Future<void> saveClinicInfo(ClinicInfo clinicInfo) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(clinicInfo.toJson());
    await prefs.setString(_keyClinicInfo, jsonString);
  }

  /// Retrieves clinic information from local storage
  Future<ClinicInfo> getClinicInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_keyClinicInfo);

    if (jsonString == null || jsonString.isEmpty) {
      return ClinicInfo.empty();
    }

    try {
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return ClinicInfo.fromJson(json);
    } catch (e) {
      return ClinicInfo.empty();
    }
  }

  /// Saves PDF template preferences to local storage
  Future<void> savePdfTemplate(PdfTemplate template) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(template.toJson());
    await prefs.setString(_keyPdfTemplate, jsonString);
  }

  /// Retrieves PDF template preferences from local storage
  Future<PdfTemplate> getPdfTemplate() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_keyPdfTemplate);

    if (jsonString == null || jsonString.isEmpty) {
      return const PdfTemplate();
    }

    try {
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return PdfTemplate.fromJson(json);
    } catch (e) {
      return const PdfTemplate();
    }
  }

  /// Clears all PDF settings from local storage
  Future<void> clearAllSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyDoctorInfo);
    await prefs.remove(_keyClinicInfo);
    await prefs.remove(_keyPdfTemplate);
  }

  /// Checks if doctor information is configured
  Future<bool> isDoctorInfoConfigured() async {
    final doctorInfo = await getDoctorInfo();
    return doctorInfo.isComplete;
  }

  /// Checks if clinic information is configured
  Future<bool> isClinicInfoConfigured() async {
    final clinicInfo = await getClinicInfo();
    return clinicInfo.isComplete;
  }
}
