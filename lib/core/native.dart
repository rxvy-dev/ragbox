import 'dart:io';

import 'package:flutter/services.dart';

/// Thin bridge to the Android side (MainActivity.kt). Everything here is
/// local to the device: file locations, sound playback through SoundPool,
/// and the system file picker for backups. There is no networking.
class Native {
  static const MethodChannel _ch = MethodChannel('dev.rxvy.ragbox/native');

  static Future<String> filesDir() async {
    try {
      final d = await _ch.invokeMethod<String>('filesDir');
      if (d != null && d.isNotEmpty) return d;
    } catch (_) {}
    final fallback = Directory('${Directory.systemTemp.path}/ragbox');
    if (!fallback.existsSync()) fallback.createSync(recursive: true);
    return fallback.path;
  }

  static Future<int> loadSound(String path) async {
    try {
      return await _ch.invokeMethod<int>('loadSound', {'path': path}) ?? -1;
    } catch (_) {
      return -1;
    }
  }

  static void playSound(int id, double volume, double rate) {
    if (id < 0) return;
    _ch.invokeMethod('playSound', {'id': id, 'volume': volume, 'rate': rate}).catchError((_) => null);
  }

  /// Opens the system "save as" dialog and writes [content] to the chosen file.
  static Future<bool> exportText(String fileName, String content) async {
    try {
      return await _ch.invokeMethod<bool>('exportText', {'name': fileName, 'content': content}) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Opens the system file picker and returns the chosen file's text.
  static Future<String?> importText() async {
    try {
      return await _ch.invokeMethod<String>('importText');
    } catch (_) {
      return null;
    }
  }
}
