import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

import 'features/transcription/presentation/transcription_controller.dart';
import 'features/transcription/presentation/transcription_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized(); 
  
  bool isConfigLoaded = false;
  try {
    // Attempt to load environment variables
    await dotenv.load(fileName: ".env").timeout(const Duration(seconds: 2));
    isConfigLoaded = true;
  } catch (e) {
    debugPrint("Critical: Could not load .env file: $e");
    // We proceed to runApp so we can show a user-friendly error in the UI
  }
  
  runApp(MyApp(isConfigLoaded: isConfigLoaded));
}

class MyApp extends StatelessWidget {
  final bool isConfigLoaded;
  
  const MyApp({super.key, required this.isConfigLoaded});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      // Pass the config status to the controller so it can show an alert
      create: (_) => TranscriptionController()..checkConfigStatus(isConfigLoaded),
      child: MaterialApp(
        title: 'DocPilot',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          useMaterial3: true,
          fontFamily: 'Roboto',
        ),
        home: const TranscriptionScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
