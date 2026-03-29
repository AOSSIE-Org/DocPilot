import 'package:flutter/material.dart';
import '../data/local_storage_service.dart';
import '../domain/transcription_history_model.dart';
import 'package:doc_pilot_new_app_gradel_fix/screens/medical_insights_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<TranscriptionHistoryModel> history = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadHistory();
  }

  Future<void> loadHistory() async {
    final results = await LocalStorageService().getAll();
    
    // FIXED: Guard against calling setState if the widget is no longer in the tree
    if (!mounted) return;

    setState(() {
      history = results;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Transcription History")),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (history.isEmpty) {
      return const Center(child: Text("No history found"));
    }

    return ListView.builder(
      itemCount: history.length,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemBuilder: (context, index) {
        final item = history[index];

        return ListTile(
          leading: const Icon(Icons.history_medical, color: Colors.blue),
          title: Text(
            item.summary.isNotEmpty ? item.summary : "No Summary Available",
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            _formatDate(item.createdAt),
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            // FIXED: Passing full data so the insights screen isn't incomplete
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MedicalInsightsScreen(
                  symptoms: item.symptoms,
                  medicines: item.medicines,
                  summary: item.summary, // Added summary
                  transcript: item.transcript, // Added transcript if supported
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    return "${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}";
  }
}
