import 'package:doc_pilot_new_app_gradel_fix/screens/prescription_screen.dart';
import 'package:doc_pilot_new_app_gradel_fix/screens/summary_screen.dart';
import 'package:doc_pilot_new_app_gradel_fix/screens/transcription_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'transcription_controller.dart';

class TranscriptionScreen extends StatelessWidget {
  const TranscriptionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Listen to changes in the controller
    final controller = context.watch<TranscriptionController>();

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
                const Text(
                  'DocPilot',
                  style: TextStyle(
                    fontSize: 28, 
                    fontWeight: FontWeight.bold, 
                    color: Colors.white
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _statusText(controller.state),
                  style: const TextStyle(fontSize: 16, color: Colors.white70),
                ),
                const SizedBox(height: 30),

                // Waveform Display
                SizedBox(
                  height: 100,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: List.generate(
                      controller.waveformValues.length,
                      (index) {
                        final value = controller.waveformValues[index];
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 100),
                          width: 4,
                          height: value * 80 + 5,
                          decoration: BoxDecoration(
                            color: controller.isRecording
                                ? HSLColor.fromAHSL(1.0, (280 + index * 2) % 360, 0.8, 0.7 + value * 0.2).toColor()
                                : Colors.white.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(5),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 40),

                // Mic button
                Center(
                  child: GestureDetector(
                    onTap: controller.isProcessing ? null : controller.toggleRecording,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: controller.isRecording ? Colors.red : Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: (controller.isRecording ? Colors.red : Colors.white).withOpacity(0.3),
                            spreadRadius: 8,
                            blurRadius: 20,
                          ),
                        ],
                      ),
                      child: Icon(
                        controller.isRecording ? Icons.stop : Icons.mic,
                        size: 50,
                        color: controller.isRecording ? Colors.white : Colors.deepPurple.shade800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Status indicator with Overflow Fix
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (controller.isRecording || controller.isProcessing)
                        Container(
                          width: 16,
                          height: 16,
                          margin: const EdgeInsets.only(right: 8.0),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: controller.isRecording
                                ? Colors.red
                                : controller.state == TranscriptionState.processing
                                    ? Colors.blue
                                    : Colors.amber,
                          ),
                        ),
                      // FIX: Wrapped in Expanded to prevent the 174px right overflow
                      Expanded(
                        child: Text(
                          _statusDetailText(controller),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 16, 
                            fontWeight: FontWeight.w500, 
                            color: Colors.white
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),

                // Navigation buttons with Compilation Fix
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildNavigationButton(
                        context, 'Transcription', Icons.record_voice_over,
                        controller.transcription.isNotEmpty,
                        () => Navigator.push(context, MaterialPageRoute(
                          builder: (_) => TranscriptionDetailScreen(transcription: controller.transcription),
                        )),
                      ),
                      const SizedBox(height: 16),
                      _buildNavigationButton(
                        context, 'Summary', Icons.summarize,
                        controller.summary.isNotEmpty,
                        () => Navigator.push(context, MaterialPageRoute(
                          builder: (_) => SummaryScreen(summary: controller.summary),
                        )),
                      ),
                      const SizedBox(height: 16),
                      // FIX: Using controller.medicines instead of controller.prescription
                      _buildNavigationButton(
                        context, 'Prescription', Icons.medication,
                        controller.medicines.isNotEmpty,
                        () => Navigator.push(context, MaterialPageRoute(
                          builder: (_) => PrescriptionScreen(
                            prescription: controller.medicines.join(", "),
                          ),
                        )),
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

  String _statusText(TranscriptionState state) {
    switch (state) {
      case TranscriptionState.recording:    return 'Recording your voice...';
      case TranscriptionState.transcribing: return 'Transcribing your voice...';
      case TranscriptionState.processing:   return 'Processing with Gemini...';
      case TranscriptionState.error:        return 'Something went wrong';
      default:                              return 'Tap the mic to begin';
    }
  }

  String _statusDetailText(TranscriptionController controller) {
    switch (controller.state) {
      case TranscriptionState.recording:    return 'Recording in progress';
      case TranscriptionState.transcribing: return 'Processing audio...';
      case TranscriptionState.processing:   return 'Generating content with Gemini...';
      case TranscriptionState.done:         return 'Ready to view results';
      case TranscriptionState.error:        return controller.errorMessage ?? 'Error occurred';
      default:                              return 'Press the microphone button to start';
    }
  }

  Widget _buildNavigationButton(
    BuildContext context,
    String title,
    IconData icon,
    bool isEnabled,
    VoidCallback onPressed,
  ) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        icon: Icon(icon, color: Colors.deepPurple),
        label: Text(title, style: const TextStyle(fontSize: 16, color: Colors.black87)),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          backgroundColor: isEnabled ? Colors.white : Colors.white24,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: isEnabled ? onPressed : null,
      ),
    );
  }
}
