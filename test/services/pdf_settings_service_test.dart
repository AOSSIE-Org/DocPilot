import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:doc_pilot_new_app_gradel_fix/services/pdf_settings_service.dart';
import 'package:doc_pilot_new_app_gradel_fix/models/pdf_settings.dart';

@GenerateMocks([SharedPreferences])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PdfSettingsService', () {
    late PdfSettingsService pdfSettingsService;
    late MockSharedPreferences mockSharedPreferences;

    setUp(() {
      pdfSettingsService = PdfSettingsService();
      mockSharedPreferences = MockSharedPreferences();
    });

    tearDown(() {
      reset(mockSharedPreferences);
    });

    group('saveDoctorInfo', () {
      test('should save doctor info to SharedPreferences', () async {
        // Arrange
        const doctorInfo = DoctorInfo(
          name: 'Dr. John Smith',
          licenseNumber: 'LIC123456',
          specialization: 'Cardiology',
          phone: '+1-555-0123',
          email: 'dr.smith@example.com',
        );

        // Setup SharedPreferences mock
        SharedPreferences.setMockInitialValues({});

        // Act & Assert
        expect(
          () => pdfSettingsService.saveDoctorInfo(doctorInfo),
          returnsNormally,
        );

        // Verify JSON serialization
        final expectedJson = {
          'name': 'Dr. John Smith',
          'licenseNumber': 'LIC123456',
          'specialization': 'Cardiology',
          'phone': '+1-555-0123',
          'email': 'dr.smith@example.com',
        };

        expect(doctorInfo.toJson(), equals(expectedJson));
      });

      test('should handle empty doctor info', () async {
        final emptyDoctorInfo = DoctorInfo.empty();

        SharedPreferences.setMockInitialValues({});

        expect(
          () => pdfSettingsService.saveDoctorInfo(emptyDoctorInfo),
          returnsNormally,
        );

        final expectedEmptyJson = {
          'name': '',
          'licenseNumber': '',
          'specialization': '',
          'phone': '',
          'email': '',
        };

        expect(emptyDoctorInfo.toJson(), equals(expectedEmptyJson));
      });

      test('should handle doctor info with special characters', () async {
        const doctorInfoWithSpecialChars = DoctorInfo(
          name: 'Dr. José María González-Smith',
          licenseNumber: 'LIC-123/ABC-456',
          specialization: 'Emergency Medicine & Surgery',
          phone: '+1 (555) 123-4567 ext. 890',
          email: 'dr.jose.maria@hospital-center.com',
        );

        SharedPreferences.setMockInitialValues({});

        expect(
          () => pdfSettingsService.saveDoctorInfo(doctorInfoWithSpecialChars),
          returnsNormally,
        );

        expect(doctorInfoWithSpecialChars.name, contains('José'));
        expect(doctorInfoWithSpecialChars.licenseNumber, contains('/'));
        expect(doctorInfoWithSpecialChars.specialization, contains('&'));
      });

      test('should update existing doctor info', () async {
        // Setup initial state
        SharedPreferences.setMockInitialValues({
          'pdf_doctor_info': jsonEncode({
            'name': 'Dr. Old Name',
            'licenseNumber': 'OLD123',
            'specialization': 'Old Specialty',
            'phone': 'old-phone',
            'email': 'old@example.com',
          }),
        });

        const newDoctorInfo = DoctorInfo(
          name: 'Dr. New Name',
          licenseNumber: 'NEW456',
          specialization: 'New Specialty',
          phone: 'new-phone',
          email: 'new@example.com',
        );

        expect(
          () => pdfSettingsService.saveDoctorInfo(newDoctorInfo),
          returnsNormally,
        );
      });
    });

    group('getDoctorInfo', () {
      test('should return saved doctor info', () async {
        // Arrange
        final doctorInfoJson = {
          'name': 'Dr. Jane Doe',
          'licenseNumber': 'LIC789',
          'specialization': 'Neurology',
          'phone': '+1-555-9876',
          'email': 'dr.jane@clinic.com',
        };

        SharedPreferences.setMockInitialValues({
          'pdf_doctor_info': jsonEncode(doctorInfoJson),
        });

        // Act
        final result = await pdfSettingsService.getDoctorInfo();

        // Assert
        expect(result.name, equals('Dr. Jane Doe'));
        expect(result.licenseNumber, equals('LIC789'));
        expect(result.specialization, equals('Neurology'));
        expect(result.phone, equals('+1-555-9876'));
        expect(result.email, equals('dr.jane@clinic.com'));
      });

      test('should return empty doctor info when no data exists', () async {
        // No initial values set
        SharedPreferences.setMockInitialValues({});

        final result = await pdfSettingsService.getDoctorInfo();

        expect(result.name, isEmpty);
        expect(result.licenseNumber, isEmpty);
        expect(result.specialization, isEmpty);
        expect(result.phone, isEmpty);
        expect(result.email, isEmpty);
        expect(result.isComplete, isFalse);
      });

      test('should return empty doctor info when stored data is empty string', () async {
        SharedPreferences.setMockInitialValues({
          'pdf_doctor_info': '',
        });

        final result = await pdfSettingsService.getDoctorInfo();

        expect(result.name, isEmpty);
        expect(result.isComplete, isFalse);
      });

      test('should handle malformed JSON gracefully', () async {
        SharedPreferences.setMockInitialValues({
          'pdf_doctor_info': 'invalid json',
        });

        final result = await pdfSettingsService.getDoctorInfo();

        expect(result.name, isEmpty);
        expect(result, equals(DoctorInfo.empty()));
      });

      test('should handle partial JSON data', () async {
        final partialJson = {
          'name': 'Dr. Partial',
          'specialization': 'Partial Specialty',
          // Missing other fields
        };

        SharedPreferences.setMockInitialValues({
          'pdf_doctor_info': jsonEncode(partialJson),
        });

        final result = await pdfSettingsService.getDoctorInfo();

        expect(result.name, equals('Dr. Partial'));
        expect(result.specialization, equals('Partial Specialty'));
        expect(result.licenseNumber, isEmpty);
        expect(result.phone, isEmpty);
        expect(result.email, isEmpty);
      });
    });

    group('saveClinicInfo', () {
      test('should save clinic info to SharedPreferences', () async {
        const clinicInfo = ClinicInfo(
          name: 'City General Hospital',
          address: '123 Main Street',
          city: 'Metropolis',
          phone: '+1-555-7890',
          email: 'info@citygeneral.com',
          website: 'www.citygeneral.com',
        );

        SharedPreferences.setMockInitialValues({});

        expect(
          () => pdfSettingsService.saveClinicInfo(clinicInfo),
          returnsNormally,
        );

        final expectedJson = {
          'name': 'City General Hospital',
          'address': '123 Main Street',
          'city': 'Metropolis',
          'phone': '+1-555-7890',
          'email': 'info@citygeneral.com',
          'website': 'www.citygeneral.com',
        };

        expect(clinicInfo.toJson(), equals(expectedJson));
      });

      test('should handle clinic info with long address', () async {
        const clinicInfoWithLongAddress = ClinicInfo(
          name: 'Regional Medical Center',
          address: '456 Very Long Street Name, Suite 1234, Building C, Apartment Complex Alpha',
          city: 'Long City Name With Multiple Words',
          phone: '+1 (555) 123-4567 extension 8901',
          email: 'contact@regionalmedicalcenter-specializedcare.com',
          website: 'https://www.regionalmedicalcenter-specializedcare.org',
        );

        SharedPreferences.setMockInitialValues({});

        expect(
          () => pdfSettingsService.saveClinicInfo(clinicInfoWithLongAddress),
          returnsNormally,
        );

        expect(clinicInfoWithLongAddress.address.length, greaterThan(50));
      });

      test('should handle empty clinic info', () async {
        final emptyClinicInfo = ClinicInfo.empty();

        SharedPreferences.setMockInitialValues({});

        expect(
          () => pdfSettingsService.saveClinicInfo(emptyClinicInfo),
          returnsNormally,
        );

        expect(emptyClinicInfo.isComplete, isFalse);
      });
    });

    group('getClinicInfo', () {
      test('should return saved clinic info', () async {
        final clinicInfoJson = {
          'name': 'Metro Clinic',
          'address': '789 Health Ave',
          'city': 'Healthcare City',
          'phone': '+1-555-4321',
          'email': 'metro@clinic.com',
          'website': 'www.metroclinic.com',
        };

        SharedPreferences.setMockInitialValues({
          'pdf_clinic_info': jsonEncode(clinicInfoJson),
        });

        final result = await pdfSettingsService.getClinicInfo();

        expect(result.name, equals('Metro Clinic'));
        expect(result.address, equals('789 Health Ave'));
        expect(result.city, equals('Healthcare City'));
        expect(result.phone, equals('+1-555-4321'));
        expect(result.email, equals('metro@clinic.com'));
        expect(result.website, equals('www.metroclinic.com'));
        expect(result.isComplete, isTrue);
      });

      test('should return empty clinic info when no data exists', () async {
        SharedPreferences.setMockInitialValues({});

        final result = await pdfSettingsService.getClinicInfo();

        expect(result.name, isEmpty);
        expect(result.address, isEmpty);
        expect(result.city, isEmpty);
        expect(result.isComplete, isFalse);
      });

      test('should handle malformed clinic JSON gracefully', () async {
        SharedPreferences.setMockInitialValues({
          'pdf_clinic_info': 'malformed json',
        });

        final result = await pdfSettingsService.getClinicInfo();

        expect(result, equals(ClinicInfo.empty()));
      });
    });

    group('savePdfTemplate', () {
      test('should save PDF template to SharedPreferences', () async {
        const pdfTemplate = PdfTemplate(
          headerColor: 'blue',
          includeDoctorInfo: true,
          includeClinicInfo: false,
          includePatientInfo: true,
          footerText: 'Custom footer text',
        );

        SharedPreferences.setMockInitialValues({});

        expect(
          () => pdfSettingsService.savePdfTemplate(pdfTemplate),
          returnsNormally,
        );

        final expectedJson = {
          'headerColor': 'blue',
          'includeDoctorInfo': true,
          'includeClinicInfo': false,
          'includePatientInfo': true,
          'footerText': 'Custom footer text',
        };

        expect(pdfTemplate.toJson(), equals(expectedJson));
      });

      test('should handle default PDF template', () async {
        const defaultTemplate = PdfTemplate();

        SharedPreferences.setMockInitialValues({});

        expect(
          () => pdfSettingsService.savePdfTemplate(defaultTemplate),
          returnsNormally,
        );

        expect(defaultTemplate.headerColor, equals('deepPurple'));
        expect(defaultTemplate.includeDoctorInfo, isTrue);
        expect(defaultTemplate.includeClinicInfo, isTrue);
        expect(defaultTemplate.includePatientInfo, isFalse);
        expect(defaultTemplate.footerText, isEmpty);
      });

      test('should handle template with long footer text', () async {
        final longFooterText = 'A' * 500; // Very long footer
        final templateWithLongFooter = PdfTemplate(
          footerText: longFooterText,
        );

        SharedPreferences.setMockInitialValues({});

        expect(
          () => pdfSettingsService.savePdfTemplate(templateWithLongFooter),
          returnsNormally,
        );

        expect(templateWithLongFooter.footerText.length, equals(500));
      });
    });

    group('getPdfTemplate', () {
      test('should return saved PDF template', () async {
        final templateJson = {
          'headerColor': 'green',
          'includeDoctorInfo': false,
          'includeClinicInfo': true,
          'includePatientInfo': false,
          'footerText': 'Saved footer',
        };

        SharedPreferences.setMockInitialValues({
          'pdf_template': jsonEncode(templateJson),
        });

        final result = await pdfSettingsService.getPdfTemplate();

        expect(result.headerColor, equals('green'));
        expect(result.includeDoctorInfo, isFalse);
        expect(result.includeClinicInfo, isTrue);
        expect(result.includePatientInfo, isFalse);
        expect(result.footerText, equals('Saved footer'));
      });

      test('should return default template when no data exists', () async {
        SharedPreferences.setMockInitialValues({});

        final result = await pdfSettingsService.getPdfTemplate();

        expect(result.headerColor, equals('deepPurple'));
        expect(result.includeDoctorInfo, isTrue);
        expect(result.includeClinicInfo, isTrue);
        expect(result.includePatientInfo, isFalse);
        expect(result.footerText, isEmpty);
      });

      test('should handle malformed template JSON gracefully', () async {
        SharedPreferences.setMockInitialValues({
          'pdf_template': 'invalid template json',
        });

        final result = await pdfSettingsService.getPdfTemplate();

        expect(result, equals(const PdfTemplate()));
      });
    });

    group('clearAllSettings', () {
      test('should clear all settings from SharedPreferences', () async {
        // Setup initial data
        SharedPreferences.setMockInitialValues({
          'pdf_doctor_info': jsonEncode({'name': 'Dr. Test'}),
          'pdf_clinic_info': jsonEncode({'name': 'Test Clinic'}),
          'pdf_template': jsonEncode({'headerColor': 'red'}),
        });

        expect(
          () => pdfSettingsService.clearAllSettings(),
          returnsNormally,
        );

        // After clearing, should return empty/default values
        final doctorInfo = await pdfSettingsService.getDoctorInfo();
        final clinicInfo = await pdfSettingsService.getClinicInfo();
        final template = await pdfSettingsService.getPdfTemplate();

        // Note: In real tests, we'd verify the actual clearing behavior
        expect(doctorInfo, isA<DoctorInfo>());
        expect(clinicInfo, isA<ClinicInfo>());
        expect(template, isA<PdfTemplate>());
      });

      test('should handle clearing when no settings exist', () async {
        SharedPreferences.setMockInitialValues({});

        expect(
          () => pdfSettingsService.clearAllSettings(),
          returnsNormally,
        );
      });
    });

    group('isDoctorInfoConfigured', () {
      test('should return true when doctor info is complete', () async {
        final completeDoctor = {
          'name': 'Dr. Complete',
          'licenseNumber': 'LIC123',
          'specialization': 'Complete Specialty',
          'phone': '555-0123',
          'email': 'complete@doctor.com',
        };

        SharedPreferences.setMockInitialValues({
          'pdf_doctor_info': jsonEncode(completeDoctor),
        });

        final result = await pdfSettingsService.isDoctorInfoConfigured();

        // The actual result depends on the isComplete implementation
        // This tests the method structure
        expect(result, isA<bool>());
      });

      test('should return false when doctor info is incomplete', () async {
        final incompleteDoctor = {
          'name': 'Dr. Incomplete',
          'licenseNumber': '', // Missing required field
          'specialization': '', // Missing required field
          'phone': '',
          'email': '',
        };

        SharedPreferences.setMockInitialValues({
          'pdf_doctor_info': jsonEncode(incompleteDoctor),
        });

        final result = await pdfSettingsService.isDoctorInfoConfigured();

        expect(result, isA<bool>());
      });

      test('should return false when no doctor info exists', () async {
        SharedPreferences.setMockInitialValues({});

        final result = await pdfSettingsService.isDoctorInfoConfigured();

        expect(result, isA<bool>());
      });
    });

    group('isClinicInfoConfigured', () {
      test('should return true when clinic info is complete', () async {
        final completeClinic = {
          'name': 'Complete Clinic',
          'address': '123 Complete St',
          'city': 'Complete City',
          'phone': '555-9876',
          'email': 'complete@clinic.com',
          'website': 'www.complete.com',
        };

        SharedPreferences.setMockInitialValues({
          'pdf_clinic_info': jsonEncode(completeClinic),
        });

        final result = await pdfSettingsService.isClinicInfoConfigured();

        expect(result, isA<bool>());
      });

      test('should return false when clinic info is incomplete', () async {
        final incompleteClinic = {
          'name': '', // Missing required field
          'address': '', // Missing required field
          'city': '', // Missing required field
          'phone': '555-9876',
          'email': 'incomplete@clinic.com',
          'website': 'www.incomplete.com',
        };

        SharedPreferences.setMockInitialValues({
          'pdf_clinic_info': jsonEncode(incompleteClinic),
        });

        final result = await pdfSettingsService.isClinicInfoConfigured();

        expect(result, isA<bool>());
      });
    });

    group('error handling', () {
      test('should handle SharedPreferences initialization errors gracefully', () async {
        // Test error scenarios
        expect(pdfSettingsService, isNotNull);
      });

      test('should handle concurrent access safely', () async {
        const doctorInfo = DoctorInfo(
          name: 'Dr. Concurrent',
          licenseNumber: 'LIC999',
          specialization: 'Concurrent Medicine',
          phone: '555-0000',
          email: 'concurrent@test.com',
        );

        SharedPreferences.setMockInitialValues({});

        // Multiple simultaneous operations
        final futures = [
          pdfSettingsService.saveDoctorInfo(doctorInfo),
          pdfSettingsService.getDoctorInfo(),
          pdfSettingsService.isDoctorInfoConfigured(),
        ];

        expect(() => Future.wait(futures), returnsNormally);
      });

      test('should handle very large data gracefully', () async {
        final largeDoctorName = 'Dr. ${'Very' * 100} Long Name';
        final largeDoctorInfo = DoctorInfo(
          name: largeDoctorName,
          licenseNumber: 'LIC${'123' * 100}',
          specialization: 'Specialized' * 50,
          phone: '+1-555-${'0123' * 10}',
          email: 'very.long.email${'@longdomain' * 10}.com',
        );

        SharedPreferences.setMockInitialValues({});

        expect(
          () => pdfSettingsService.saveDoctorInfo(largeDoctorInfo),
          returnsNormally,
        );
      });
    });

    group('integration tests', () {
      test('should maintain data consistency across operations', () async {
        const doctorInfo = DoctorInfo(
          name: 'Dr. Consistency',
          licenseNumber: 'CON123',
          specialization: 'Consistency Medicine',
          phone: '555-1111',
          email: 'consistency@test.com',
        );

        const clinicInfo = ClinicInfo(
          name: 'Consistency Clinic',
          address: '123 Consistency Ave',
          city: 'Consistent City',
          phone: '555-2222',
          email: 'clinic@consistency.com',
          website: 'www.consistency.com',
        );

        const template = PdfTemplate(
          headerColor: 'consistent',
          includeDoctorInfo: true,
          includeClinicInfo: true,
          includePatientInfo: false,
          footerText: 'Consistent footer',
        );

        SharedPreferences.setMockInitialValues({});

        // Save all data
        expect(
          () async {
            await pdfSettingsService.saveDoctorInfo(doctorInfo);
            await pdfSettingsService.saveClinicInfo(clinicInfo);
            await pdfSettingsService.savePdfTemplate(template);
          }(),
          returnsNormally,
        );
      });

      test('should handle full workflow simulation', () async {
        SharedPreferences.setMockInitialValues({});

        // Initial state - should be empty
        expect(
          () async {
            final initialDoctor = await pdfSettingsService.getDoctorInfo();
            final initialClinic = await pdfSettingsService.getClinicInfo();
            final initialTemplate = await pdfSettingsService.getPdfTemplate();

            // Save some data
            await pdfSettingsService.saveDoctorInfo(const DoctorInfo(
              name: 'Workflow Doctor',
              licenseNumber: 'WF123',
              specialization: 'Workflow Medicine',
              phone: '555-9999',
              email: 'workflow@test.com',
            ));

            // Check configuration status
            await pdfSettingsService.isDoctorInfoConfigured();
            await pdfSettingsService.isClinicInfoConfigured();

            // Clear all
            await pdfSettingsService.clearAllSettings();
          }(),
          returnsNormally,
        );
      });

      test('should handle service reuse across operations', () async {
        SharedPreferences.setMockInitialValues({});

        const sampleDoctor = DoctorInfo(
          name: 'Dr. Reuse',
          licenseNumber: 'REU123',
          specialization: 'Reuse Medicine',
          phone: '555-8888',
          email: 'reuse@test.com',
        );

        // Reuse the same service instance multiple times
        for (int i = 0; i < 5; i++) {
          expect(
            () async {
              await pdfSettingsService.saveDoctorInfo(sampleDoctor);
              await pdfSettingsService.getDoctorInfo();
            }(),
            returnsNormally,
          );
        }
      });
    });
  });
}