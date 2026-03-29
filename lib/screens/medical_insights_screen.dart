import 'package:flutter/material.dart';

class MedicalInsightsScreen extends StatelessWidget {
  final List<String> symptoms;
  final List<String> medicines;

  const MedicalInsightsScreen({
    super.key,
    required this.symptoms,
    required this.medicines,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Medical Insights")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            const Text(
              "Symptoms",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            if (symptoms.isEmpty)
              const Text("No symptoms detected")
            else
              ...symptoms.map(
                (e) => ListTile(
                  leading: const Icon(Icons.warning, color: Colors.orange),
                  title: Text(e),
                ),
              ),

            const SizedBox(height: 20),

            const Text(
              "Medicines",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            if (medicines.isEmpty)
              const Text("No medicines suggested")
            else
              ...medicines.map(
                (e) => ListTile(
                  leading: const Icon(Icons.medication, color: Colors.blue),
                  title: Text(e),
                ),
              ),
          ],
        ),
      ),
    );
  }
}