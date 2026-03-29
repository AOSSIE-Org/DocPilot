// Basic smoke test for DocPilot app.
//
// Verifies that the app renders its core UI elements without crashing.
// This replaces the default Flutter counter test which was invalid for DocPilot.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:doc_pilot_new_app_gradel_fix/main.dart';

void main() {
  testWidgets('DocPilot app renders without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    // Verify the app title is displayed
    expect(find.text('DocPilot'), findsWidgets);
  });

  testWidgets('DocPilot app shows microphone button', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    // Verify the microphone icon is present on the main screen
    expect(find.byIcon(Icons.mic), findsOneWidget);
  });

  testWidgets('DocPilot app shows navigation buttons', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    // Verify the three navigation buttons exist
    expect(find.text('Transcription'), findsOneWidget);
    expect(find.text('Summary'), findsOneWidget);
    expect(find.text('Prescription'), findsOneWidget);
  });
}
