import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Local storage service for audio files
/// Uses device storage instead of Firebase Storage (works with free plan)
class StorageService {
  /// Get the local audio storage directory
  Future<Directory> _getAudioDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final audioDir = Directory('${appDir.path}/consultations');
    if (!await audioDir.exists()) {
      await audioDir.create(recursive: true);
    }
    return audioDir;
  }

  /// Save audio file to local storage
  /// Returns the local file path of the saved audio
  Future<String?> uploadAudioFile({
    required String filePath,
    required String doctorId,
    required String sessionId,
  }) async {
    try {
      final sourceFile = File(filePath);
      if (!await sourceFile.exists()) {
        return null;
      }

      final audioDir = await _getAudioDirectory();
      final fileName = 'consultation_${sessionId}.m4a';
      final destinationPath = '${audioDir.path}/$fileName';

      // Copy file to permanent storage
      await sourceFile.copy(destinationPath);

      return destinationPath;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[StorageService] Failed to upload audio file: $e');
      }
      return null;
    }
  }

  /// Delete audio file from local storage
  Future<void> deleteAudioFile(String audioPath) async {
    if (audioPath.isEmpty) return;

    try {
      final file = File(audioPath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[StorageService] Failed to delete audio file at $audioPath: $e');
      }
    }
  }

  /// Get all stored audio files size (for storage management)
  Future<int> getStorageUsedBytes() async {
    try {
      final audioDir = await _getAudioDirectory();
      if (!await audioDir.exists()) return 0;

      int totalSize = 0;
      await for (final entity in audioDir.list()) {
        if (entity is File) {
          totalSize += await entity.length();
        }
      }
      return totalSize;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[StorageService] Failed to calculate storage used: $e');
      }
      return 0;
    }
  }

  /// Clear all stored audio files
  Future<void> clearAllAudio() async {
    try {
      final audioDir = await _getAudioDirectory();
      if (await audioDir.exists()) {
        await for (final entity in audioDir.list()) {
          if (entity is File) {
            await entity.delete();
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[StorageService] Failed to clear all audio files: $e');
      }
    }
  }
}
