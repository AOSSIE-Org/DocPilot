import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/transcription_history_model.dart';

class LocalStorageService {
  static const String key = "transcription_history";

  Future<void> save(TranscriptionHistoryModel item) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(key) ?? [];

    list.add(jsonEncode(item.toJson()));
    await prefs.setStringList(key, list);
  }

  Future<List<TranscriptionHistoryModel>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(key) ?? [];

    return list
        .map((e) => TranscriptionHistoryModel.fromJson(jsonDecode(e)))
        .toList()
        .reversed
        .toList();
  }
}