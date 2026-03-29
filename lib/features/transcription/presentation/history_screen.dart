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

  @override
  void initState() {
    super.initState();
    loadHistory();
  }

  Future<void> loadHistory() async {
    history = await LocalStorageService().getAll();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("History")),
      body: history.isEmpty
          ? const Center(child: Text("No history yet"))
          : ListView.builder(
              itemCount: history.length,
              itemBuilder: (context, index) {
                final item = history[index];

                return ListTile(
                  title: Text(
                    item.summary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(item.createdAt.toString()),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MedicalInsightsScreen(
                          symptoms: item.symptoms,
                          medicines: item.medicines,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}