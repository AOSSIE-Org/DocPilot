import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../domain/transcription_history_model.dart';

class LocalStorageService {
  static const String _key = "transcription_history_secure";
  
  // Encrypted storage instance
  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  /// Saves a history item securely by encrypting the JSON string
  Future<void> save(TranscriptionHistoryModel item) async {
    try {
      final List<TranscriptionHistoryModel> currentHistory = await getAll();
      currentHistory.add(item);
      
      final String encodedData = jsonEncode(
        currentHistory.map((e) => e.toJson()).toList(),
      );
      
      await _storage.write(key: _key, value: encodedData);
    } catch (e) {
      throw Exception("Failed to secure medical data: $e");
    }
  }

  /// Retrieves and decrypts all transcription history
  Future<List<TranscriptionHistoryModel>> getAll() async {
    try {
      final String? securedJson = await _storage.read(key: _key);
      
      if (securedJson == null || securedJson.isEmpty) {
        return [];
      }

      final List<dynamic> decodedList = jsonDecode(securedJson);
      
      return decodedList
          .map((item) => TranscriptionHistoryModel.fromJson(item))
          .toList()
          .reversed // Newest first
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Optional: Clear all history for privacy compliance
  Future<void> clearAll() async {
    await _storage.delete(key: _key);
  }
}
