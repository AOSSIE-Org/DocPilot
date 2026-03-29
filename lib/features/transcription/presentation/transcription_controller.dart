import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';

import '../data/deepgram_service.dart';
import '../data/gemini_service.dart';
import '../data/local_storage_service.dart';
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

  // FIXED: Declared missing waveform fields
  final List<double> waveformValues = List.filled(40, 0.0);
  Timer? _waveformTimer;

  bool get isRecording => state == TranscriptionState.recording;

  // UI Helper Getters
  String get transcription => data.rawTranscript;
  String get summary => data.insights?.summary ?? '';
  List<String> get symptoms => data.insights?.symptoms ?? [];
  List<String> get medicines => data.insights?.medicines ?? [];

  Future<void> toggleRecording() async {
    isRecording ? await _stopRecording() : await _startRecording();
  }

  Future<void> _startRecording() async {
    try {
      if (!await _audioRecorder.hasPermission()) {
        // FIXED: Provide user feedback instead of failing silently
        _setError("Microphone permission is required to record audio.");
        return;
      }
      final dir = await getTemporaryDirectory();
      _recordingPath = '${dir.path}/rec_${DateTime.now().millisecondsSinceEpoch}.m4a';
      
      await _audioRecorder.start(const RecordConfig(), path: _recordingPath);
      state = TranscriptionState.recording;
      data = const TranscriptionModel(); 
      notifyListeners();
    } catch (e) { _setError("Record start failed: $e"); }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _audioRecorder.stop();
      if (path == null) {
        state = TranscriptionState.idle;
        notifyListeners();
        return;
      }
      
      state = TranscriptionState.transcribing;
      notifyListeners();
      
      final transcript = await _deepgramService.transcribe(path);
      await _processWithGemini(transcript);
    } catch (e) { _setError("Transcription failed: $e"); }
  }

  Future<void> _processWithGemini(String transcript) async {
    if (transcript.isEmpty || transcript == "No speech detected") {
      state = TranscriptionState.idle;
      notifyListeners();
      return;
    }

    state = TranscriptionState.processing;
    notifyListeners();

    try {
      final insights = await _geminiService.generateInsights(transcript);
      
      data = data.copyWith(
        rawTranscript: transcript,
        insights: insights,
        summary: insights.summary,
      );

      final history = TranscriptionHistoryModel(
        transcript: transcript,
        summary: insights.summary,
        symptoms: insights.symptoms,
        medicines: insights.medicines,
        createdAt: DateTime.now(),
      );

      await _localStorageService.save(history);
      state = TranscriptionState.done;
    } catch (e) {
      _setError("AI Processing failed: $e");
    } finally {
      notifyListeners();
    }
  }

  void _setError(String msg) {
    errorMessage = msg;
    state = TranscriptionState.error;
    notifyListeners();
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
