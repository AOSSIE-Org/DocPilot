import 'package:doc_pilot_new_app_gradel_fix/screens/summary_screen.dart';
import 'package:doc_pilot_new_app_gradel_fix/screens/transcription_detail_screen.dart';
import 'package:doc_pilot_new_app_gradel_fix/screens/medical_insights_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'transcription_controller.dart';

class TranscriptionScreen extends StatelessWidget {
  const TranscriptionScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),

                Text(
                  _statusText(controller.state),
                  style: const TextStyle(fontSize: 16, color: Colors.white70),
                ),

                const SizedBox(height: 30),

                //  Waveform
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
                                ? HSLColor.fromAHSL(
                                    1.0,
                                    (280 + index * 2) % 360,
                                    0.8,
                                    0.7 + value * 0.2,
                                  ).toColor()
                                : Colors.white.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(5),
                          ),
                        );
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                //  Mic Button
                Center(
                  child: GestureDetector(
                    onTap: controller.isProcessing ? null : controller.toggleRecording,
                    child: AnimatedScale(
                      scale: controller.isRecording ? 1.2 : 1.0,
                      duration: const Duration(milliseconds: 200),
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: controller.isRecording ? Colors.red : Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: (controller.isRecording ? Colors.red : Colors.white)
                                  .withOpacity(0.3),
                              spreadRadius: 8,
                              blurRadius: 20,
                            ),
                          ],
                        ),
                        child: Icon(
                          controller.isRecording ? Icons.stop : Icons.mic,
                          size: 50,
                          color: controller.isRecording
                              ? Colors.white
                              : Colors.deepPurple.shade800,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                //  Status Row (FIXED)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (controller.isRecording || controller.isProcessing)
                        Container(
                          width: 16,
                          height: 16,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: controller.isRecording
                                ? Colors.red
                                : controller.state == TranscriptionState.processing
                                    ? Colors.blue
                                    : Colors.amber,
                          ),
                        ),
                      Expanded(
                        child: Text(
                          _statusDetailText(controller),
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // 🧠 Empty State
                if (controller.state == TranscriptionState.done &&
                    controller.transcription.isEmpty)
                  const Center(
                    child: Text(
                      "No speech detected. Try again.",
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),

                const SizedBox(height: 20),

                // 🚀 Navigation Buttons
Expanded(
  child: ListView(
    children: [
      // 1. Summary Button
      _buildNavigationButton(
        context,
        'Summary',
        Icons.description,
        controller.summary.isNotEmpty && !controller.isProcessing,
        () => Navigator.push(
          context, 
          MaterialPageRoute(builder: (_) => SummaryScreen(summary: controller.summary))
        ),
      ),
      
      const SizedBox(height: 12),

      // 2. Prescription Button (Legacy Adapter)
      _buildNavigationButton(
        context,
        'Prescription',
        Icons.medication,
        controller.prescription.isNotEmpty && !controller.isProcessing,
        () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PrescriptionScreen(prescription: controller.prescription)),
        ),
      ),

      const SizedBox(height: 12),

      // 3. Medical Insights Button (FIXED LOGIC)
      _buildNavigationButton(
        context,
        'Medical Insights',
        Icons.medical_services,
        // ✅ Enable if EITHER symptoms or medicines are found
        (controller.symptoms.isNotEmpty || controller.medicines.isNotEmpty) && !controller.isProcessing,
        () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MedicalInsightsScreen(
              symptoms: controller.symptoms,
              medicines: controller.medicines,
            ),
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

  String _statusText(TranscriptionState state) {
    switch (state) {
      case TranscriptionState.recording:
        return 'Recording your voice...';
      case TranscriptionState.transcribing:
        return 'Transcribing your voice...';
      case TranscriptionState.processing:
        return 'Processing with AI...';
      case TranscriptionState.error:
        return 'Something went wrong';
      default:
        return 'Tap the mic to begin';
    }
  }

  String _statusDetailText(TranscriptionController controller) {
    switch (controller.state) {
      case TranscriptionState.recording:
        return 'Recording in progress';
      case TranscriptionState.transcribing:
        return 'Processing audio...';
      case TranscriptionState.processing:
        return 'Generating insights...';
      case TranscriptionState.done:
        return 'Ready to view results';
      case TranscriptionState.error:
        return controller.errorMessage ?? 'Error occurred';
      default:
        return 'Press the microphone button to start';
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
        label: Text(
          title,
          style: const TextStyle(fontSize: 16, color: Colors.black87),
        ),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          backgroundColor: isEnabled ? Colors.white : Colors.white24,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        onPressed: isEnabled ? onPressed : null,
      ),
    );
  }
}