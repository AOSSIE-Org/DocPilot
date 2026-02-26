import 'dart:convert';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class DeepgramService {
  final String _apiKey = dotenv.env['DEEPGRAM_API_KEY'] ?? '';

  Future<String> transcribe(String recordingPath) async {
    final uri = Uri.parse('https://api.deepgram.com/v1/listen?model=nova-2');

    final file = File(recordingPath);
    if (!await file.exists()) {
      throw Exception('Recording file not found');
    }

    final bytes = await file.readAsBytes();
    final response = await http.post(
      uri,
      headers: {
        'Authorization': 'Token $_apiKey',
        'Content-Type': 'audio/m4a',
      },
      body: bytes,
    );

    if (response.statusCode == 200) {
      final decodedResponse = json.decode(response.body);
      final result = decodedResponse['results']['channels'][0]['alternatives'][0]['transcript'];
      return result.isNotEmpty ? result : 'No speech detected';
    } else {
      throw Exception('Deepgram failed: ${response.statusCode}');
    }
  }
}