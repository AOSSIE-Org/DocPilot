import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../domain/transcription_history_model.dart';

class LocalStorageService {
  static const String _key = "transcription_history_secure";
  final _storage = const FlutterSecureStorage();

  // Internal helper to get RAW list without reversing (prevents corruption)
  Future<List<TranscriptionHistoryModel>> _getRawList() async {
    try {
      final jsonStr = await _storage.read(key: _key);
      if (jsonStr == null) return [];
      final List<dynamic> decoded = jsonDecode(jsonStr);
      return decoded.map((item) => TranscriptionHistoryModel.fromJson(item)).toList();
    } catch (_) { return []; }
  }

  Future<void> save(TranscriptionHistoryModel item) async {
    final list = await _getRawList(); // Get chronological order
    list.add(item);
    await _storage.write(key: _key, value: jsonEncode(list.map((e) => e.toJson()).toList()));
  }

  Future<List<TranscriptionHistoryModel>> getAll() async {
    final list = await _getRawList();
    return list.reversed.toList(); // Reverse ONLY for UI display
  }
}
