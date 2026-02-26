import 'dart:async';
import 'package:doc_pilot_new_app_gradel_fix/features/transcription/presentation/transcription_controller.dart';
import 'package:doc_pilot_new_app_gradel_fix/features/transcription/presentation/transcription_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

Future<void> main() async {
  await dotenv.load();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => TranscriptionController(),
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
