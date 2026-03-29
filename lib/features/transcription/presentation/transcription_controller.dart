import 'dart:developer' as developer;
import 'dart:math';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';

import '../data/deepgram_service.dart';
import '../data/gemini_service.dart';
import '../domain/transcription_model.dart';
import '../domain/medical_insights.dart';

enum TranscriptionState { idle, recording, transcribing, processing, done, error }

class TranscriptionController extends ChangeNotifier {
  final _audioRecorder = AudioRecorder();
  final _deepgramService = DeepgramService();
  final _geminiService = GeminiService();

  TranscriptionState state = TranscriptionState.idle;
  TranscriptionModel data = const TranscriptionModel();
  String? errorMessage;
  String _recordingPath = '';

  // Waveform
  final List<double> waveformValues = List.filled(40, 0.0);
  Timer? _waveformTimer;

  bool get isRecording => state == TranscriptionState.recording;

  bool get isProcessing =>
      state == TranscriptionState.transcribing ||
      state == TranscriptionState.processing;

  String get transcription => data.rawTranscript;

  // ✅ NEW STRUCTURED GETTERS
  String get summary => data.insights?.summary ?? '';
  List<String> get symptoms => data.insights?.symptoms ?? [];
  List<String> get medicines => data.insights?.medicines ?? [];

  Future<bool> requestPermissions() async {
    final status = await Permission.microphone.request();

    if (status.isGranted) return true;

    if (status.isPermanentlyDenied) {
      _setError('Microphone permission permanently denied. Please enable it in settings.');
      return false;
    }

    _setError('Microphone permission denied');
    return false;
  }

  Future<void> toggleRecording() async {
    if (isRecording) {
      await _stopRecording();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    try {
      if (!await _audioRecorder.hasPermission()) {
        final granted = await requestPermissions();
        if (!granted) return;
      }

      final directory = await getTemporaryDirectory();
      _recordingPath =
          '${directory.path}/recording_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _audioRecorder.start(
        RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: _recordingPath,
      );

      data = const TranscriptionModel();
      state = TranscriptionState.recording;
      _startWaveformAnimation();
      notifyListeners();

      developer.log('Started recording to: $_recordingPath');
    } catch (e) {
      _setError('Error starting recording: $e');
    }
  }

  Future<void> _stopRecording() async {
    try {
      _waveformTimer?.cancel();
      _resetWaveform();

      await _audioRecorder.stop();
      state = TranscriptionState.transcribing;
      notifyListeners();

      developer.log('Recording stopped, transcribing...');
      await _transcribe();
    } catch (e) {
      _setError('Error stopping recording: $e');
    }
  }

  Future<void> _transcribe() async {
    try {
      final transcript = await _deepgramService.transcribe(_recordingPath);

      data = data.copyWith(rawTranscript: transcript);
      state = TranscriptionState.processing;
      notifyListeners();

      if (transcript.isNotEmpty && transcript != 'No speech detected') {
        await _processWithGemini(transcript);
      } else {
        state = TranscriptionState.done;
        notifyListeners();
      }
    } catch (e) {
      _setError('Transcription error: $e');
    }
  }

  // ✅ UPDATED: Structured AI Processing
  Future<void> _processWithGemini(String transcript) async {
    try {
      final MedicalInsights insights =
          await _geminiService.generateInsights(transcript);

      data = data.copyWith(insights: insights);
      state = TranscriptionState.done;
      notifyListeners();

      developer.log('Gemini structured insights generated');
    } catch (e) {
      _setError('Gemini error: $e');
    }
  }

  void _startWaveformAnimation() {
    _waveformTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      for (int i = 0; i < waveformValues.length; i++) {
        waveformValues[i] = Random().nextDouble();
      }
      notifyListeners();
    });
  }

  void _resetWaveform() {
    for (int i = 0; i < waveformValues.length; i++) {
      waveformValues[i] = 0.0;
    }
  }

  void _setError(String message) {
    errorMessage = message;
    state = TranscriptionState.error;
    notifyListeners();
    developer.log(message);
  }

  @override
  void dispose() {
    _waveformTimer?.cancel();
    _audioRecorder.dispose();
    super.dispose();
  }
}