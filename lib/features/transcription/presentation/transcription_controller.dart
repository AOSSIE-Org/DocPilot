import 'dart:developer' as developer;
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';

import '../data/deepgram_service.dart';
import '../data/local_storage_service.dart';
import '../data/gemini_service.dart';
import '../domain/transcription_model.dart';
import '../domain/medical_insights.dart';
import '../domain/transcription_history_model.dart';

enum TranscriptionState { idle, recording, transcribing, processing, done, error }

class TranscriptionController extends ChangeNotifier {
  final _audioRecorder = AudioRecorder();
  final _deepgramService = DeepgramService();
  final _geminiService = GeminiService();
  
  final _localStorageService = LocalStorageService();

  TranscriptionState state = TranscriptionState.idle;
  TranscriptionModel data = const TranscriptionModel();

  String? errorMessage;
  String _recordingPath = '';
  final List<double> waveformValues = List.filled(40, 0.0);
  Timer? _waveformTimer;

  bool get isRecording => state == TranscriptionState.recording;
  bool get isProcessing =>
      state == TranscriptionState.transcribing ||
      state == TranscriptionState.processing;

  String get transcription => data.rawTranscript;
  String get summary => data.insights?.summary ?? '';
  String get prescription => data.prescription ?? ''; // FIXED: Return actual prescription
  
  List<String> get symptoms => List.unmodifiable(data.insights?.symptoms ?? []);
  List<String> get medicines => List.unmodifiable(data.insights?.medicines ?? []);

  bool get hasInsights => symptoms.isNotEmpty || medicines.isNotEmpty || summary.isNotEmpty;

  Future<bool> requestPermissions() async {
    final status = await Permission.microphone.request();
    if (status.isGranted) return true;
    
    _setError(status.isPermanentlyDenied 
        ? 'Microphone permission permanently denied. Please enable it in settings.' 
        : 'Microphone permission denied');
    return false;
  }

  Future<void> _processWithGemini(String transcript) async {
    // 1. Handle Empty Input Early
    if (transcript.trim().isEmpty || transcript == "No speech detected") {
      state = TranscriptionState.idle;
      notifyListeners();
      return;
    }

    try {
      state = TranscriptionState.processing;
      notifyListeners();

      // Parallelize AI calls for better performance
      final results = await Future.wait([
        _geminiService.generateSummary(transcript),
        _geminiService.generatePrescription(transcript),
        _geminiService.generateInsights(transcript),
      ]);

      final String summaryText = results[0] as String;
      final String prescriptionText = results[1] as String;
      final MedicalInsights insights = results[2] as MedicalInsights;

      data = data.copyWith(
        insights: insights,
        summary: summaryText,
        prescription: prescriptionText,
      );

      // 2. Mark UI Done BEFORE persistence to ensure responsiveness
      state = TranscriptionState.done;
      notifyListeners();

      // 3. Isolated Persistence (Doesn't break UI on failure)
      _persistHistory(transcript, insights);

    } catch (e) {
      _setError('Gemini error: $e');
    }
  }

  Future<void> _persistHistory(String transcript, MedicalInsights insights) async {
    try {
      final historyItem = TranscriptionHistoryModel(
        transcript: transcript,
        summary: insights.summary,
        symptoms: insights.symptoms,
        medicines: insights.medicines,
        createdAt: DateTime.now(),
      );
      await _localStorageService.save(historyItem);
      developer.log('History persisted successfully');
    } catch (e) {
      developer.log('Persistence failed: $e', level: 1000);
    }
  }

  void _setError(String message) {
    errorMessage = message;
    state = TranscriptionState.error;
    notifyListeners();
    developer.log(message, name: 'TranscriptionController', error: message);
  }

  void checkConfigStatus(bool isLoaded) {
  if (!isLoaded) {
    _setError('Configuration Error: API keys could not be loaded. Please check your .env file.');
  }
  }
  
  @override
  void dispose() {
    _waveformTimer?.cancel();
    _audioRecorder.dispose();
    super.dispose();
  }
}


