import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:doc_pilot_new_app_gradel_fix/screens/prescription_screen.dart';
import 'package:doc_pilot_new_app_gradel_fix/screens/summary_screen.dart';
import 'package:doc_pilot_new_app_gradel_fix/screens/transcription_detail_screen.dart';

void main() {
  testWidgets('SummaryScreen shows fallback when summary is empty', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SummaryScreen(summary: ''),
      ),
    );

    expect(find.text('Conversation Summary'), findsOneWidget);
    expect(find.text('No summary available'), findsOneWidget);
  });

  testWidgets('PrescriptionScreen renders markdown content', (WidgetTester tester) async {
    const prescription = '# Prescription\n\n- Paracetamol 500mg';

    await tester.pumpWidget(
      const MaterialApp(
        home: PrescriptionScreen(prescription: prescription),
      ),
    );

    expect(find.text('Prescription'), findsWidgets);
    expect(find.text('Paracetamol 500mg'), findsOneWidget);
  });

  testWidgets('TranscriptionDetailScreen renders transcription text', (WidgetTester tester) async {
    const transcription = 'Doctor: How are you feeling today?';

    await tester.pumpWidget(
      const MaterialApp(
        home: TranscriptionDetailScreen(transcription: transcription),
      ),
    );

    expect(find.text('Doctor-Patient Conversation'), findsOneWidget);
    expect(find.text('Doctor: How are you feeling today?'), findsOneWidget);
  });
}
