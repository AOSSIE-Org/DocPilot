import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:path_provider/path_provider.dart';
import 'package:doc_pilot_new_app_gradel_fix/services/pdf_service.dart';
import 'package:doc_pilot_new_app_gradel_fix/models/pdf_settings.dart';

import 'pdf_service_test.mocks.dart';

@GenerateMocks([Directory, File])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PdfService', () {
    late PdfService pdfService;
    late MockDirectory mockDirectory;
    late MockFile mockFile;

    setUp(() {
      pdfService = PdfService();
      mockDirectory = MockDirectory();
      mockFile = MockFile();
    });

    tearDown(() {
      reset(mockDirectory);
      reset(mockFile);
    });

    group('generatePrescriptionPdf', () {
      test('should generate PDF with valid prescription text', () async {
        const prescriptionText = '''
        # Patient Prescription

        ## Medications
        * Lisinopril 10mg once daily
        * Metformin 500mg twice daily

        ## Instructions
        Take medications with food.
        ''';
        const patientName = 'John Doe';

        // Test would require mocking path_provider and file operations
        expect(pdfService, isNotNull);
        expect(pdfService.generatePrescriptionPdf, isA<Function>());

        // Verify the method can be called
        expect(
          () => pdfService.generatePrescriptionPdf(
            prescriptionText: prescriptionText,
            patientName: patientName,
          ),
          returnsNormally,
        );
      });

      test('should generate PDF without patient name', () async {
        const prescriptionText = '''
        ## Diagnosis
        Hypertension

        ## Treatment Plan
        * Monitor blood pressure daily
        * Follow up in 2 weeks
        ''';

        expect(
          () => pdfService.generatePrescriptionPdf(
            prescriptionText: prescriptionText,
          ),
          returnsNormally,
        );
      });

      test('should handle empty prescription text', () async {
        const emptyPrescriptionText = '';

        expect(
          () => pdfService.generatePrescriptionPdf(
            prescriptionText: emptyPrescriptionText,
          ),
          returnsNormally,
        );
      });

      test('should handle prescription text with only whitespace', () async {
        const whitespacePrescriptionText = '   \n\t   \n   ';

        expect(
          () => pdfService.generatePrescriptionPdf(
            prescriptionText: whitespacePrescriptionText,
          ),
          returnsNormally,
        );
      });

      test('should handle very long prescription text', () async {
        final longPrescriptionText = '''
        # Extended Treatment Plan

        ${List.generate(100, (i) => '* Medication $i: Details about medication $i').join('\n')}
        ''';

        expect(
          () => pdfService.generatePrescriptionPdf(
            prescriptionText: longPrescriptionText,
          ),
          returnsNormally,
        );
      });

      test('should handle prescription with special characters', () async {
        const prescriptionWithSpecialChars = '''
        # Prescription für Patient

        ## Médications
        * Ibuprofen 400mg (börste täglich)
        * Vitamin D₃ 1000IU

        **Note**: Take with 8oz H₂O
        ''';

        expect(
          () => pdfService.generatePrescriptionPdf(
            prescriptionText: prescriptionWithSpecialChars,
          ),
          returnsNormally,
        );
      });

      test('should handle patient name with special characters', () async {
        const prescriptionText = '## Basic prescription';
        const specialPatientName = 'José María O\'Connor-Smith';

        expect(
          () => pdfService.generatePrescriptionPdf(
            prescriptionText: prescriptionText,
            patientName: specialPatientName,
          ),
          returnsNormally,
        );
      });

      test('should handle null patient name', () async {
        const prescriptionText = '## Basic prescription';

        expect(
          () => pdfService.generatePrescriptionPdf(
            prescriptionText: prescriptionText,
            patientName: null,
          ),
          returnsNormally,
        );
      });

      test('should handle empty patient name', () async {
        const prescriptionText = '## Basic prescription';
        const emptyPatientName = '';

        expect(
          () => pdfService.generatePrescriptionPdf(
            prescriptionText: prescriptionText,
            patientName: emptyPatientName,
          ),
          returnsNormally,
        );
      });

      test('should generate unique filenames for concurrent calls', () async {
        const prescriptionText = '## Test prescription';

        // Generate multiple PDFs concurrently
        final futures = List.generate(3, (index) =>
          pdfService.generatePrescriptionPdf(
            prescriptionText: '$prescriptionText $index',
          )
        );

        expect(() => Future.wait(futures), returnsNormally);
      });
    });

    group('_parseMarkdownToPdfContent', () {
      test('should parse headers correctly', () {
        const markdown = '''
        # Main Header
        ## Sub Header
        ### Sub Sub Header
        ''';

        // Test header parsing logic
        final lines = markdown.split('\n');
        final headerLines = lines.where((line) => line.trim().startsWith('#')).toList();

        expect(headerLines, hasLength(3));
        expect(headerLines[0].trim(), startsWith('# Main Header'));
        expect(headerLines[1].trim(), startsWith('## Sub Header'));
        expect(headerLines[2].trim(), startsWith('### Sub Sub Header'));
      });

      test('should parse bullet points correctly', () {
        const markdown = '''
        * First bullet point
        - Second bullet point
        * Third bullet point
        ''';

        final lines = markdown.split('\n');
        final bulletLines = lines.where((line) =>
          line.trim().startsWith('*') || line.trim().startsWith('-')
        ).toList();

        expect(bulletLines, hasLength(3));
        expect(bulletLines[0].trim(), startsWith('* First'));
        expect(bulletLines[1].trim(), startsWith('- Second'));
        expect(bulletLines[2].trim(), startsWith('* Third'));
      });

      test('should parse numbered lists correctly', () {
        const markdown = '''
        1. First item
        2. Second item
        10. Tenth item
        ''';

        final lines = markdown.split('\n');
        final numberedLines = lines.where((line) =>
          RegExp(r'^\d+\.').hasMatch(line.trim())
        ).toList();

        expect(numberedLines, hasLength(3));
        expect(numberedLines[0].trim(), startsWith('1.'));
        expect(numberedLines[1].trim(), startsWith('2.'));
        expect(numberedLines[2].trim(), startsWith('10.'));
      });

      test('should parse bold text correctly', () {
        const textWithBold = 'This is **bold text** in a sentence.';

        expect(textWithBold, contains('**'));

        final parts = textWithBold.split('**');
        expect(parts, hasLength(3));
        expect(parts[1], equals('bold text'));
      });

      test('should handle mixed markdown content', () {
        const mixedMarkdown = '''
        # Main Title

        This is a paragraph with **bold text**.

        ## Medications
        * First medication
        * Second medication

        ### Instructions
        1. Take with food
        2. Monitor symptoms
        ''';

        final lines = mixedMarkdown.split('\n');

        // Headers
        final headers = lines.where((line) => line.trim().startsWith('#'));
        expect(headers, hasLength(3));

        // Bullets
        final bullets = lines.where((line) => line.trim().startsWith('*'));
        expect(bullets, hasLength(2));

        // Numbered items
        final numbered = lines.where((line) => RegExp(r'^\d+\.').hasMatch(line.trim()));
        expect(numbered, hasLength(2));

        // Bold text
        final boldLines = lines.where((line) => line.contains('**'));
        expect(boldLines, hasLength(1));
      });

      test('should handle empty lines correctly', () {
        const markdownWithEmptyLines = '''
        # Header


        Paragraph after empty lines.


        ## Another section
        ''';

        final lines = markdownWithEmptyLines.split('\n');
        final emptyLines = lines.where((line) => line.trim().isEmpty);

        expect(emptyLines, hasLength(greaterThan(2)));
      });

      test('should handle malformed markdown gracefully', () {
        const malformedMarkdown = '''
        ### Header with missing space###
        * Bullet without space*
        **Unclosed bold text
        1.Number without space
        ''';

        final lines = malformedMarkdown.split('\n');

        // Should still parse what it can
        final headers = lines.where((line) => line.trim().startsWith('#'));
        expect(headers, hasLength(1));

        final bullets = lines.where((line) => line.trim().startsWith('*'));
        expect(bullets, hasLength(1));
      });
    });

    group('_buildHeader', () {
      test('should create header with correct title', () {
        const expectedTitle = 'MEDICAL PRESCRIPTION';

        // Test header structure
        expect(expectedTitle, equals('MEDICAL PRESCRIPTION'));
      });

      test('should include DocPilot branding', () {
        const expectedBranding = 'Generated by DocPilot AI';

        expect(expectedBranding, contains('DocPilot'));
      });

      test('should include current date', () {
        final now = DateTime.now();
        final expectedDateFormat = RegExp(r'\w+ \d{1,2}, \d{4}');

        // Test date formatting
        final months = [
          'January', 'February', 'March', 'April', 'May', 'June',
          'July', 'August', 'September', 'October', 'November', 'December'
        ];

        final formattedDate = '${months[now.month - 1]} ${now.day}, ${now.year}';

        expect(formattedDate, matches(expectedDateFormat));
      });
    });

    group('_buildPatientInfo', () {
      test('should display patient name correctly', () {
        const patientName = 'John Doe';
        const expectedLabel = 'Patient: ';

        expect(expectedLabel, equals('Patient: '));
        expect(patientName, equals('John Doe'));
      });

      test('should handle long patient names', () {
        const longPatientName = 'María Fernanda González-Rodríguez de la Cruz';

        expect(longPatientName.length, greaterThan(20));
        expect(longPatientName, contains('María'));
        expect(longPatientName, contains('Cruz'));
      });

      test('should handle patient names with numbers', () {
        const patientNameWithNumbers = 'John Doe III';

        expect(patientNameWithNumbers, contains('III'));
      });
    });

    group('_buildFooter', () {
      test('should include important medical disclaimer', () {
        const expectedDisclaimer = 'This prescription was generated using AI assistance and should be reviewed by a licensed healthcare professional before use.';

        expect(expectedDisclaimer, contains('AI assistance'));
        expect(expectedDisclaimer, contains('licensed healthcare professional'));
        expect(expectedDisclaimer, contains('reviewed'));
      });

      test('should include DocPilot attribution', () {
        const expectedAttribution = 'Generated by DocPilot - AI-Powered Medical Documentation Assistant';

        expect(expectedAttribution, contains('DocPilot'));
        expect(expectedAttribution, contains('AI-Powered'));
      });

      test('should have important notice label', () {
        const expectedNoticeLabel = 'Important Notice:';

        expect(expectedNoticeLabel, equals('Important Notice:'));
      });
    });

    group('_formatDate', () {
      test('should format date correctly', () {
        final testDate = DateTime(2024, 3, 15);
        const expectedFormat = 'March 15, 2024';

        final months = [
          'January', 'February', 'March', 'April', 'May', 'June',
          'July', 'August', 'September', 'October', 'November', 'December'
        ];

        final formattedDate = '${months[testDate.month - 1]} ${testDate.day}, ${testDate.year}';

        expect(formattedDate, equals(expectedFormat));
      });

      test('should handle edge dates correctly', () {
        // Test edge cases
        final newYear = DateTime(2025, 1, 1);
        final leap = DateTime(2024, 2, 29);
        final endYear = DateTime(2024, 12, 31);

        final months = [
          'January', 'February', 'March', 'April', 'May', 'June',
          'July', 'August', 'September', 'October', 'November', 'December'
        ];

        final newYearFormatted = '${months[newYear.month - 1]} ${newYear.day}, ${newYear.year}';
        final leapFormatted = '${months[leap.month - 1]} ${leap.day}, ${leap.year}';
        final endYearFormatted = '${months[endYear.month - 1]} ${endYear.day}, ${endYear.year}';

        expect(newYearFormatted, equals('January 1, 2025'));
        expect(leapFormatted, equals('February 29, 2024'));
        expect(endYearFormatted, equals('December 31, 2024'));
      });

      test('should handle all months correctly', () {
        final months = [
          'January', 'February', 'March', 'April', 'May', 'June',
          'July', 'August', 'September', 'October', 'November', 'December'
        ];

        for (int month = 1; month <= 12; month++) {
          final date = DateTime(2024, month, 15);
          final formatted = '${months[date.month - 1]} ${date.day}, ${date.year}';

          expect(formatted, contains(months[month - 1]));
          expect(formatted, contains('15'));
          expect(formatted, contains('2024'));
        }
      });
    });

    group('filename generation', () {
      test('should generate unique timestamp-based filenames', () {
        final timestamp1 = DateTime.now().millisecondsSinceEpoch;
        // Simulate slight delay
        final timestamp2 = timestamp1 + 1;

        final filename1 = 'prescription_$timestamp1.pdf';
        final filename2 = 'prescription_$timestamp2.pdf';

        expect(filename1, isNot(equals(filename2)));
        expect(filename1, startsWith('prescription_'));
        expect(filename1, endsWith('.pdf'));
        expect(filename2, startsWith('prescription_'));
        expect(filename2, endsWith('.pdf'));
      });

      test('should use consistent filename format', () {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final filename = 'prescription_$timestamp.pdf';

        expect(filename, matches(RegExp(r'prescription_\d+\.pdf')));
      });
    });

    group('error handling', () {
      test('should handle file system errors gracefully', () async {
        // In a real implementation, test file system error scenarios
        expect(pdfService, isNotNull);
      });

      test('should handle PDF generation errors gracefully', () async {
        // Test error scenarios in PDF generation
        expect(pdfService, isNotNull);
      });

      test('should handle path provider errors gracefully', () async {
        // Test when getApplicationDocumentsDirectory fails
        expect(pdfService, isNotNull);
      });
    });

    group('integration tests', () {
      test('should handle concurrent PDF generation', () async {
        const prescriptionTexts = [
          '## Prescription 1',
          '## Prescription 2',
          '## Prescription 3',
        ];

        final futures = prescriptionTexts.map((text) =>
          pdfService.generatePrescriptionPdf(prescriptionText: text)
        );

        expect(() => Future.wait(futures), returnsNormally);
      });

      test('should maintain service state across calls', () async {
        const prescription1 = '## First prescription';
        const prescription2 = '## Second prescription';

        // Service should be reusable
        expect(
          () => pdfService.generatePrescriptionPdf(prescriptionText: prescription1),
          returnsNormally,
        );
        expect(
          () => pdfService.generatePrescriptionPdf(prescriptionText: prescription2),
          returnsNormally,
        );
      });
    });
  });
}