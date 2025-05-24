import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'dart:developer' as developer;
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'services/chatbot_service.dart';
import 'screens/transcription_detail_screen.dart';
import 'screens/summary_screen.dart';
import 'screens/prescription_screen.dart';

Future<void> main() async {
  await dotenv.load();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DocPilot',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const TranscriptionScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class TranscriptionScreen extends StatefulWidget {
  const TranscriptionScreen({super.key});

  @override
  State<TranscriptionScreen> createState() => _TranscriptionScreenState();
}

class _TranscriptionScreenState extends State<TranscriptionScreen> with SingleTickerProviderStateMixin {
  final _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  String _transcription = '';
  String _recordingPath = '';
  bool _isTranscribing = false;
  bool _isProcessing = false;

  // Data for screens
  String _formattedTranscription = '';
  String _summaryContent = '';
  String _prescriptionContent = '';

  // Chatbot service
  final ChatbotService _chatbotService = ChatbotService();

  // For waveform animation
  late AnimationController _animationController;
  final List<double> _waveformValues = List.filled(40, 0.0);
  Timer? _waveformTimer;

  @override
  void initState() {
    super.initState();
    _requestPermissions();

    // Initialize animation controller for waveform animation
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
  }

  Future<void> _requestPermissions() async {
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Microphone permission is required'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      await _stopRecording();
    } else {
      await _startRecording();
    }
  }

  void _startWaveformAnimation() {
    // Create a timer that updates the waveform values periodically
    _waveformTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (mounted) {
        setState(() {
          // Update waveform values with random heights to simulate audio levels
          for (int i = 0; i < _waveformValues.length; i++) {
            // When recording, show dynamic waveform
            _waveformValues[i] = _isRecording ? Random().nextDouble() : 0.0;
          }
        });
      }
    });
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final directory = await getTemporaryDirectory();
        _recordingPath = '${directory.path}/recording_${DateTime.now().millisecondsSinceEpoch}.m4a';

        await _audioRecorder.start(
          RecordConfig(
            encoder: AudioEncoder.aacLc,
            bitRate: 128000,
            sampleRate: 44100,
          ),
          path: _recordingPath,
        );

        setState(() {
          _isRecording = true;
          _transcription = 'Recording...';

          // Reset previous content
          _formattedTranscription = '';
          _summaryContent = '';
          _prescriptionContent = '';
        });

        // Start waveform animation
        _startWaveformAnimation();

        developer.log('Started recording to: $_recordingPath');
      } else {
        await _requestPermissions();
      }
    } catch (e) {
      setState(() {
        _transcription = 'Error starting recording: $e';
      });
      developer.log('Error starting recording: $e', error: e);
    }
  }

  Future<void> _stopRecording() async {
    try {
      // Stop waveform animation
      _waveformTimer?.cancel();

      await _audioRecorder.stop();
      setState(() {
        _isRecording = false;
        _isTranscribing = true;
        _transcription = 'Processing audio...';

        // Reset waveform heights
        for (int i = 0; i < _waveformValues.length; i++) {
          _waveformValues[i] = 0.0;
        }
      });

      developer.log('Recording stopped, transcribing audio...');
      await _transcribeAudio();
    } catch (e) {
      setState(() {
        _isRecording = false;
        _transcription = 'Error stopping recording: $e';
      });
      developer.log('Error stopping recording: $e', error: e);
    }
  }

  Future<void> _transcribeAudio() async {
    try {
      final apiKey = dotenv.env['DEEPGRAM_API_KEY'] ?? '';
      final uri = Uri.parse('https://api.deepgram.com/v1/listen?model=nova-2');

      final file = File(_recordingPath);
      if (!await file.exists()) {
        setState(() {
          _isTranscribing = false;
          _transcription = 'Recording file not found';
        });
        return;
      }

      final bytes = await file.readAsBytes();
      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Token $apiKey',
          'Content-Type': 'audio/m4a',
        },
        body: bytes,
      );

      if (response.statusCode == 200) {
        final decodedResponse = json.decode(response.body);
        final result = decodedResponse['results']['channels'][0]['alternatives'][0]['transcript'];

        setState(() {
          _isTranscribing = false;
          _transcription = result.isNotEmpty ? result : 'No speech detected';
          _formattedTranscription = _transcription; // Store raw transcription directly
          _isProcessing = true;
        });

        // Print the transcription to console
        print('\n============ TRANSCRIPTION RESULT ============');
        print(_transcription);
        print('=============================================');

        // Send to Gemini for processing if we have a valid transcription
        if (_transcription.isNotEmpty && _transcription != 'No speech detected') {
          await _processWithGemini(_transcription);
        } else {
          setState(() {
            _isProcessing = false;
          });
        }
      } else {
        setState(() {
          _isTranscribing = false;
          _transcription = 'Transcription failed';
          _isProcessing = false;
        });
      }
    } catch (e) {
      setState(() {
        _isTranscribing = false;
        _transcription = 'Error during transcription';
        _isProcessing = false;
      });
      print('Error: $e');
    }
  }

  // Process the transcription with Gemini
  Future<void> _processWithGemini(String transcription) async {
    try {
      // Process with the three specific prompts

      // Prompt 1: Format as conversation
      // final formattedTranscription = await _chatbotService.getGeminiResponse(
      //     "Provide a proper conversation between a doctor and a patient in the format: Doctor: [said this] Patient: [said that] based on this transcription and make sure no additional things should be added on point conversation just detect this messages spoken by Dr and this message is spoken by patient: $transcription"
      // );

      // Prompt 2: Generate summary
      final summary = await _chatbotService.getGeminiResponse(
          "Generate a summary of the conversation based on this transcription: $transcription"
      );

      // Prompt 3: Generate prescription
      final prescription = await _chatbotService.getGeminiResponse(
          "Generate a prescription based on the conversation in this transcription: $transcription"
      );

      setState(() {
        // _formattedTranscription = formattedTranscription;
        _summaryContent = summary;
        _prescriptionContent = prescription;
        _isProcessing = false;
      });

      print('\n============ GEMINI PROCESSING COMPLETE ============');

    } catch (e) {
      setState(() {
        _isProcessing = false;
      });
      print('Error processing with Gemini: $e');
    }
  }

  @override
  void dispose() {
    _waveformTimer?.cancel();
    _animationController.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.deepPurple.shade800,
              Colors.deepPurple.shade500,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // App header
                const Text(
                  'DocPilot',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _isRecording
                      ? 'Recording your voice...'
                      : _isTranscribing
                      ? 'Transcribing your voice...'
                      : _isProcessing
                      ? 'Processing with Gemini...'
                      : 'Tap the mic to begin',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 30),

                // Waveform visualization
                Container(
                  height: 100,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: AnimatedBuilder(
                    animation: _animationController,
                    builder: (context, child) {
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: List.generate(
                          _waveformValues.length,
                              (index) {
                            final value = _waveformValues[index];
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 100),
                              width: 4,
                              height: value * 80 + 5, // Minimum height of 5
                              decoration: BoxDecoration(
                                color: _isRecording
                                    ? HSLColor.fromAHSL(
                                    1.0,
                                    (280 + index * 2) % 360,
                                    0.8,
                                    0.7 + value * 0.2
                                ).toColor()
                                    : Colors.white.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(5),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 40),

                // Microphone button
                Center(
                  child: GestureDetector(
                    onTap: (_isTranscribing || _isProcessing) ? null : _toggleRecording,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isRecording ? Colors.red : Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: (_isRecording ? Colors.red : Colors.white).withOpacity(0.3),
                            spreadRadius: 8,
                            blurRadius: 20,
                          ),
                        ],
                      ),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          _isRecording ? Icons.stop : Icons.mic,
                          size: 50,
                          color: _isRecording ? Colors.white : Colors.deepPurple.shade800,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Status indicator
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_isRecording || _isTranscribing || _isProcessing)
                        Container(
                          width: 16,
                          height: 16,
                          margin: const EdgeInsets.only(right: 8.0),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _isRecording
                                ? Colors.red
                                : _isProcessing
                                ? Colors.blue
                                : Colors.amber,
                          ),
                        ),
                      Text(
                        _isRecording
                            ? 'Recording in progress'
                            : _isTranscribing
                            ? 'Processing audio...'
                            : _isProcessing
                            ? 'Generating content with Gemini...'
                            : _transcription.isEmpty
                            ? 'Press the microphone button to start'
                            : 'Ready to view results',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),

                // Vertical navigation buttons
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildNavigationButton(
                        context,
                        'Transcription',
                        Icons.record_voice_over,
                        _formattedTranscription.isNotEmpty,
                            () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => TranscriptionDetailScreen(transcription: _formattedTranscription),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildNavigationButton(
                        context,
                        'Summary',
                        Icons.summarize,
                        _summaryContent.isNotEmpty,
                            () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SummaryScreen(summary: _summaryContent),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildNavigationButton(
                        context,
                        'Prescription',
                        Icons.medication,
                        _prescriptionContent.isNotEmpty,
                            () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PrescriptionScreen(prescription: _prescriptionContent),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Helper method to build navigation buttons
  Widget _buildNavigationButton(
      BuildContext context,
      String title,
      IconData icon,
      bool isEnabled,
      VoidCallback onPressed,
      ) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isEnabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          backgroundColor: Colors.white,
          foregroundColor: Colors.deepPurple,
          disabledBackgroundColor: Colors.white.withOpacity(0.3),
          disabledForegroundColor: Colors.white.withOpacity(0.5),
          elevation: isEnabled ? 4 : 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 24),
            const SizedBox(width: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}