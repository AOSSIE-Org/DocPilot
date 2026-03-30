import 'package:flutter_test/flutter_test.dart';
import 'package:doc_pilot_new_app_gradel_fix/models/pdf_settings.dart';

void main() {
  group('DoctorInfo', () {
    group('constructor', () {
      test('should create DoctorInfo with all required fields', () {
        const doctorInfo = DoctorInfo(
          name: 'Dr. John Smith',
          licenseNumber: 'LIC123456',
          specialization: 'Cardiology',
          phone: '+1-555-0123',
          email: 'dr.smith@example.com',
        );

        expect(doctorInfo.name, equals('Dr. John Smith'));
        expect(doctorInfo.licenseNumber, equals('LIC123456'));
        expect(doctorInfo.specialization, equals('Cardiology'));
        expect(doctorInfo.phone, equals('+1-555-0123'));
        expect(doctorInfo.email, equals('dr.smith@example.com'));
      });

      test('should create DoctorInfo with empty strings', () {
        const doctorInfo = DoctorInfo(
          name: '',
          licenseNumber: '',
          specialization: '',
          phone: '',
          email: '',
        );

        expect(doctorInfo.name, isEmpty);
        expect(doctorInfo.licenseNumber, isEmpty);
        expect(doctorInfo.specialization, isEmpty);
        expect(doctorInfo.phone, isEmpty);
        expect(doctorInfo.email, isEmpty);
      });
    });

    group('fromJson', () {
      test('should create DoctorInfo from valid JSON', () {
        final json = {
          'name': 'Dr. Jane Doe',
          'licenseNumber': 'LIC789012',
          'specialization': 'Neurology',
          'phone': '+1-555-9876',
          'email': 'dr.jane@clinic.com',
        };

        final doctorInfo = DoctorInfo.fromJson(json);

        expect(doctorInfo.name, equals('Dr. Jane Doe'));
        expect(doctorInfo.licenseNumber, equals('LIC789012'));
        expect(doctorInfo.specialization, equals('Neurology'));
        expect(doctorInfo.phone, equals('+1-555-9876'));
        expect(doctorInfo.email, equals('dr.jane@clinic.com'));
      });

      test('should handle missing fields in JSON', () {
        final json = {
          'name': 'Dr. Partial',
          'specialization': 'Partial Specialty',
          // Missing licenseNumber, phone, email
        };

        final doctorInfo = DoctorInfo.fromJson(json);

        expect(doctorInfo.name, equals('Dr. Partial'));
        expect(doctorInfo.licenseNumber, isEmpty);
        expect(doctorInfo.specialization, equals('Partial Specialty'));
        expect(doctorInfo.phone, isEmpty);
        expect(doctorInfo.email, isEmpty);
      });

      test('should handle null values in JSON', () {
        final json = {
          'name': null,
          'licenseNumber': 'LIC123',
          'specialization': null,
          'phone': '+1-555-0000',
          'email': null,
        };

        final doctorInfo = DoctorInfo.fromJson(json);

        expect(doctorInfo.name, isEmpty);
        expect(doctorInfo.licenseNumber, equals('LIC123'));
        expect(doctorInfo.specialization, isEmpty);
        expect(doctorInfo.phone, equals('+1-555-0000'));
        expect(doctorInfo.email, isEmpty);
      });

      test('should handle invalid JSON values gracefully', () {
        // Test handling of empty JSON
        final json = <String, dynamic>{};

        final doctorInfo = DoctorInfo.fromJson(json);

        expect(doctorInfo.name, isEmpty);
        expect(doctorInfo.licenseNumber, isEmpty);
        expect(doctorInfo.specialization, isEmpty);
        expect(doctorInfo.phone, isEmpty);
        expect(doctorInfo.email, isEmpty);
      });

      test('should handle empty JSON', () {
        final json = <String, dynamic>{};

        final doctorInfo = DoctorInfo.fromJson(json);

        expect(doctorInfo.name, isEmpty);
        expect(doctorInfo.licenseNumber, isEmpty);
        expect(doctorInfo.specialization, isEmpty);
        expect(doctorInfo.phone, isEmpty);
        expect(doctorInfo.email, isEmpty);
      });
    });

    group('toJson', () {
      test('should convert DoctorInfo to JSON', () {
        const doctorInfo = DoctorInfo(
          name: 'Dr. Convert',
          licenseNumber: 'LIC999',
          specialization: 'Conversion Medicine',
          phone: '+1-555-1111',
          email: 'convert@test.com',
        );

        final json = doctorInfo.toJson();

        expect(json, isA<Map<String, dynamic>>());
        expect(json['name'], equals('Dr. Convert'));
        expect(json['licenseNumber'], equals('LIC999'));
        expect(json['specialization'], equals('Conversion Medicine'));
        expect(json['phone'], equals('+1-555-1111'));
        expect(json['email'], equals('convert@test.com'));
      });

      test('should convert empty DoctorInfo to JSON', () {
        const doctorInfo = DoctorInfo(
          name: '',
          licenseNumber: '',
          specialization: '',
          phone: '',
          email: '',
        );

        final json = doctorInfo.toJson();

        expect(json['name'], isEmpty);
        expect(json['licenseNumber'], isEmpty);
        expect(json['specialization'], isEmpty);
        expect(json['phone'], isEmpty);
        expect(json['email'], isEmpty);
      });
    });

    group('empty factory', () {
      test('should create empty DoctorInfo', () {
        final emptyDoctor = DoctorInfo.empty();

        expect(emptyDoctor.name, isEmpty);
        expect(emptyDoctor.licenseNumber, isEmpty);
        expect(emptyDoctor.specialization, isEmpty);
        expect(emptyDoctor.phone, isEmpty);
        expect(emptyDoctor.email, isEmpty);
        expect(emptyDoctor.isComplete, isFalse);
      });
    });

    group('isComplete', () {
      test('should return true when all required fields are filled', () {
        const completeDoctor = DoctorInfo(
          name: 'Dr. Complete',
          licenseNumber: 'LIC123',
          specialization: 'Complete Medicine',
          phone: '+1-555-0000',
          email: 'complete@test.com',
        );

        expect(completeDoctor.isComplete, isTrue);
      });

      test('should return false when name is missing', () {
        const incompleteDoctor = DoctorInfo(
          name: '',
          licenseNumber: 'LIC123',
          specialization: 'Complete Medicine',
          phone: '+1-555-0000',
          email: 'complete@test.com',
        );

        expect(incompleteDoctor.isComplete, isFalse);
      });

      test('should return false when license number is missing', () {
        const incompleteDoctor = DoctorInfo(
          name: 'Dr. Incomplete',
          licenseNumber: '',
          specialization: 'Complete Medicine',
          phone: '+1-555-0000',
          email: 'complete@test.com',
        );

        expect(incompleteDoctor.isComplete, isFalse);
      });

      test('should return false when specialization is missing', () {
        const incompleteDoctor = DoctorInfo(
          name: 'Dr. Incomplete',
          licenseNumber: 'LIC123',
          specialization: '',
          phone: '+1-555-0000',
          email: 'complete@test.com',
        );

        expect(incompleteDoctor.isComplete, isFalse);
      });

      test('should return true even when phone and email are missing', () {
        const doctorWithoutContact = DoctorInfo(
          name: 'Dr. No Contact',
          licenseNumber: 'LIC123',
          specialization: 'Medicine',
          phone: '',
          email: '',
        );

        // isComplete only requires name, license, and specialization
        expect(doctorWithoutContact.isComplete, isTrue);
      });
    });

    group('copyWith', () {
      test('should copy DoctorInfo with updated fields', () {
        const original = DoctorInfo(
          name: 'Dr. Original',
          licenseNumber: 'LIC123',
          specialization: 'Original Medicine',
          phone: '+1-555-0000',
          email: 'original@test.com',
        );

        final updated = original.copyWith(
          name: 'Dr. Updated',
          email: 'updated@test.com',
        );

        expect(updated.name, equals('Dr. Updated'));
        expect(updated.licenseNumber, equals('LIC123'));  // Unchanged
        expect(updated.specialization, equals('Original Medicine'));  // Unchanged
        expect(updated.phone, equals('+1-555-0000'));  // Unchanged
        expect(updated.email, equals('updated@test.com'));
      });

      test('should copy DoctorInfo with all fields updated', () {
        const original = DoctorInfo(
          name: 'Dr. Original',
          licenseNumber: 'LIC123',
          specialization: 'Original Medicine',
          phone: '+1-555-0000',
          email: 'original@test.com',
        );

        final updated = original.copyWith(
          name: 'Dr. New',
          licenseNumber: 'LIC999',
          specialization: 'New Medicine',
          phone: '+1-555-9999',
          email: 'new@test.com',
        );

        expect(updated.name, equals('Dr. New'));
        expect(updated.licenseNumber, equals('LIC999'));
        expect(updated.specialization, equals('New Medicine'));
        expect(updated.phone, equals('+1-555-9999'));
        expect(updated.email, equals('new@test.com'));
      });

      test('should copy DoctorInfo with no changes when no parameters provided', () {
        const original = DoctorInfo(
          name: 'Dr. Same',
          licenseNumber: 'LIC123',
          specialization: 'Same Medicine',
          phone: '+1-555-0000',
          email: 'same@test.com',
        );

        final copied = original.copyWith();

        expect(copied.name, equals(original.name));
        expect(copied.licenseNumber, equals(original.licenseNumber));
        expect(copied.specialization, equals(original.specialization));
        expect(copied.phone, equals(original.phone));
        expect(copied.email, equals(original.email));
      });

      test('should create new instance, not modify original', () {
        const original = DoctorInfo(
          name: 'Dr. Original',
          licenseNumber: 'LIC123',
          specialization: 'Original Medicine',
          phone: '+1-555-0000',
          email: 'original@test.com',
        );

        final updated = original.copyWith(name: 'Dr. Updated');

        expect(original.name, equals('Dr. Original'));
        expect(updated.name, equals('Dr. Updated'));
        expect(identical(original, updated), isFalse);
      });
    });

    group('JSON roundtrip', () {
      test('should maintain data integrity through JSON conversion', () {
        const originalDoctor = DoctorInfo(
          name: 'Dr. Roundtrip',
          licenseNumber: 'LIC-RT-123',
          specialization: 'Roundtrip Medicine',
          phone: '+1 (555) 123-4567',
          email: 'roundtrip@test.com',
        );

        final json = originalDoctor.toJson();
        final reconstructedDoctor = DoctorInfo.fromJson(json);

        expect(reconstructedDoctor.name, equals(originalDoctor.name));
        expect(reconstructedDoctor.licenseNumber, equals(originalDoctor.licenseNumber));
        expect(reconstructedDoctor.specialization, equals(originalDoctor.specialization));
        expect(reconstructedDoctor.phone, equals(originalDoctor.phone));
        expect(reconstructedDoctor.email, equals(originalDoctor.email));
        expect(reconstructedDoctor.isComplete, equals(originalDoctor.isComplete));
      });

      test('should handle special characters through JSON conversion', () {
        const doctorWithSpecialChars = DoctorInfo(
          name: 'Dr. José María González-Smith',
          licenseNumber: 'LIC/123-ABC#456',
          specialization: 'Emergency Medicine & Surgery',
          phone: '+1 (555) 123-4567 ext. 890',
          email: 'jose.maria@hospital.org',
        );

        final json = doctorWithSpecialChars.toJson();
        final reconstructed = DoctorInfo.fromJson(json);

        expect(reconstructed.name, equals(doctorWithSpecialChars.name));
        expect(reconstructed.licenseNumber, equals(doctorWithSpecialChars.licenseNumber));
        expect(reconstructed.specialization, equals(doctorWithSpecialChars.specialization));
        expect(reconstructed.phone, equals(doctorWithSpecialChars.phone));
        expect(reconstructed.email, equals(doctorWithSpecialChars.email));
      });
    });
  });

  group('ClinicInfo', () {
    group('constructor', () {
      test('should create ClinicInfo with all required fields', () {
        const clinicInfo = ClinicInfo(
          name: 'City General Hospital',
          address: '123 Main Street',
          city: 'Metropolis',
          phone: '+1-555-7890',
          email: 'info@citygeneral.com',
          website: 'www.citygeneral.com',
        );

        expect(clinicInfo.name, equals('City General Hospital'));
        expect(clinicInfo.address, equals('123 Main Street'));
        expect(clinicInfo.city, equals('Metropolis'));
        expect(clinicInfo.phone, equals('+1-555-7890'));
        expect(clinicInfo.email, equals('info@citygeneral.com'));
        expect(clinicInfo.website, equals('www.citygeneral.com'));
      });
    });

    group('fromJson', () {
      test('should create ClinicInfo from valid JSON', () {
        final json = {
          'name': 'Metro Clinic',
          'address': '789 Health Ave',
          'city': 'Healthcare City',
          'phone': '+1-555-4321',
          'email': 'metro@clinic.com',
          'website': 'www.metroclinic.com',
        };

        final clinicInfo = ClinicInfo.fromJson(json);

        expect(clinicInfo.name, equals('Metro Clinic'));
        expect(clinicInfo.address, equals('789 Health Ave'));
        expect(clinicInfo.city, equals('Healthcare City'));
        expect(clinicInfo.phone, equals('+1-555-4321'));
        expect(clinicInfo.email, equals('metro@clinic.com'));
        expect(clinicInfo.website, equals('www.metroclinic.com'));
      });

      test('should handle missing fields in JSON', () {
        final json = {
          'name': 'Partial Clinic',
          'city': 'Partial City',
          // Missing address, phone, email, website
        };

        final clinicInfo = ClinicInfo.fromJson(json);

        expect(clinicInfo.name, equals('Partial Clinic'));
        expect(clinicInfo.address, isEmpty);
        expect(clinicInfo.city, equals('Partial City'));
        expect(clinicInfo.phone, isEmpty);
        expect(clinicInfo.email, isEmpty);
        expect(clinicInfo.website, isEmpty);
      });
    });

    group('empty factory', () {
      test('should create empty ClinicInfo', () {
        final emptyClinic = ClinicInfo.empty();

        expect(emptyClinic.name, isEmpty);
        expect(emptyClinic.address, isEmpty);
        expect(emptyClinic.city, isEmpty);
        expect(emptyClinic.phone, isEmpty);
        expect(emptyClinic.email, isEmpty);
        expect(emptyClinic.website, isEmpty);
        expect(emptyClinic.isComplete, isFalse);
      });
    });

    group('isComplete', () {
      test('should return true when all required fields are filled', () {
        const completeClinic = ClinicInfo(
          name: 'Complete Clinic',
          address: '123 Complete St',
          city: 'Complete City',
          phone: '+1-555-0000',
          email: 'complete@clinic.com',
          website: 'www.complete.com',
        );

        expect(completeClinic.isComplete, isTrue);
      });

      test('should return false when name is missing', () {
        const incompleteClinic = ClinicInfo(
          name: '',
          address: '123 Complete St',
          city: 'Complete City',
          phone: '+1-555-0000',
          email: 'complete@clinic.com',
          website: 'www.complete.com',
        );

        expect(incompleteClinic.isComplete, isFalse);
      });

      test('should return false when address is missing', () {
        const incompleteClinic = ClinicInfo(
          name: 'Complete Clinic',
          address: '',
          city: 'Complete City',
          phone: '+1-555-0000',
          email: 'complete@clinic.com',
          website: 'www.complete.com',
        );

        expect(incompleteClinic.isComplete, isFalse);
      });

      test('should return false when city is missing', () {
        const incompleteClinic = ClinicInfo(
          name: 'Complete Clinic',
          address: '123 Complete St',
          city: '',
          phone: '+1-555-0000',
          email: 'complete@clinic.com',
          website: 'www.complete.com',
        );

        expect(incompleteClinic.isComplete, isFalse);
      });

      test('should return true even when phone, email, and website are missing', () {
        const clinicWithoutContact = ClinicInfo(
          name: 'No Contact Clinic',
          address: '123 No Contact St',
          city: 'No Contact City',
          phone: '',
          email: '',
          website: '',
        );

        // isComplete only requires name, address, and city
        expect(clinicWithoutContact.isComplete, isTrue);
      });
    });

    group('copyWith', () {
      test('should copy ClinicInfo with updated fields', () {
        const original = ClinicInfo(
          name: 'Original Clinic',
          address: '123 Original St',
          city: 'Original City',
          phone: '+1-555-0000',
          email: 'original@clinic.com',
          website: 'www.original.com',
        );

        final updated = original.copyWith(
          name: 'Updated Clinic',
          email: 'updated@clinic.com',
        );

        expect(updated.name, equals('Updated Clinic'));
        expect(updated.address, equals('123 Original St'));  // Unchanged
        expect(updated.city, equals('Original City'));  // Unchanged
        expect(updated.phone, equals('+1-555-0000'));  // Unchanged
        expect(updated.email, equals('updated@clinic.com'));
        expect(updated.website, equals('www.original.com'));  // Unchanged
      });
    });
  });

  group('PdfTemplate', () {
    group('constructor', () {
      test('should create PdfTemplate with default values', () {
        const template = PdfTemplate();

        expect(template.headerColor, equals('deepPurple'));
        expect(template.includeDoctorInfo, isTrue);
        expect(template.includeClinicInfo, isTrue);
        expect(template.includePatientInfo, isFalse);
        expect(template.footerText, isEmpty);
      });

      test('should create PdfTemplate with custom values', () {
        const template = PdfTemplate(
          headerColor: 'blue',
          includeDoctorInfo: false,
          includeClinicInfo: false,
          includePatientInfo: true,
          footerText: 'Custom footer',
        );

        expect(template.headerColor, equals('blue'));
        expect(template.includeDoctorInfo, isFalse);
        expect(template.includeClinicInfo, isFalse);
        expect(template.includePatientInfo, isTrue);
        expect(template.footerText, equals('Custom footer'));
      });
    });

    group('fromJson', () {
      test('should create PdfTemplate from valid JSON', () {
        final json = {
          'headerColor': 'green',
          'includeDoctorInfo': false,
          'includeClinicInfo': true,
          'includePatientInfo': false,
          'footerText': 'JSON footer',
        };

        final template = PdfTemplate.fromJson(json);

        expect(template.headerColor, equals('green'));
        expect(template.includeDoctorInfo, isFalse);
        expect(template.includeClinicInfo, isTrue);
        expect(template.includePatientInfo, isFalse);
        expect(template.footerText, equals('JSON footer'));
      });

      test('should use defaults for missing fields in JSON', () {
        final json = {
          'headerColor': 'red',
          // Missing other fields
        };

        final template = PdfTemplate.fromJson(json);

        expect(template.headerColor, equals('red'));
        expect(template.includeDoctorInfo, isTrue);  // Default
        expect(template.includeClinicInfo, isTrue);  // Default
        expect(template.includePatientInfo, isFalse);  // Default
        expect(template.footerText, isEmpty);  // Default
      });
    });

    group('copyWith', () {
      test('should copy PdfTemplate with updated fields', () {
        const original = PdfTemplate(
          headerColor: 'original',
          includeDoctorInfo: true,
          includeClinicInfo: false,
          includePatientInfo: true,
          footerText: 'Original footer',
        );

        final updated = original.copyWith(
          headerColor: 'updated',
          includePatientInfo: false,
        );

        expect(updated.headerColor, equals('updated'));
        expect(updated.includeDoctorInfo, isTrue);  // Unchanged
        expect(updated.includeClinicInfo, isFalse);  // Unchanged
        expect(updated.includePatientInfo, isFalse);
        expect(updated.footerText, equals('Original footer'));  // Unchanged
      });
    });

    group('JSON roundtrip', () {
      test('should maintain data integrity through JSON conversion', () {
        const originalTemplate = PdfTemplate(
          headerColor: 'purple',
          includeDoctorInfo: false,
          includeClinicInfo: true,
          includePatientInfo: true,
          footerText: 'Roundtrip footer text',
        );

        final json = originalTemplate.toJson();
        final reconstructed = PdfTemplate.fromJson(json);

        expect(reconstructed.headerColor, equals(originalTemplate.headerColor));
        expect(reconstructed.includeDoctorInfo, equals(originalTemplate.includeDoctorInfo));
        expect(reconstructed.includeClinicInfo, equals(originalTemplate.includeClinicInfo));
        expect(reconstructed.includePatientInfo, equals(originalTemplate.includePatientInfo));
        expect(reconstructed.footerText, equals(originalTemplate.footerText));
      });
    });
  });
}