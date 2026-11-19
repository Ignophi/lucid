// Small bridge to Lucid's own Android code (MainActivity.kt, SessionService.kt):
// keeping a session running with the screen off, checking whether the screen
// is on, and saving backups to the Download folder. Does nothing elsewhere
// (e.g. in tests).

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class AndroidSystem {
  AndroidSystem._();

  static const MethodChannel _channel = MethodChannel("lucid/system");

  static bool get supported => !kIsWeb && Platform.isAndroid;

  /// Keeps the session going while the screen is off or another app is open:
  /// a foreground service (with an ongoing notification counting down to
  /// [endsAt], if given) that keeps the phone awake. [microphone] lets sound
  /// measurements continue in the background too. Called again to update
  /// the notification (e.g. when paused).
  static Future<void> startSession({
    required String title,
    required String text,
    DateTime? endsAt,
    bool microphone = false,
  }) async {
    if (!supported) return;
    try {
      await _channel.invokeMethod("startSession", {
        "title": title,
        "text": text,
        "endsAt": endsAt?.millisecondsSinceEpoch ?? 0,
        "microphone": microphone,
      });
    } catch (e) {
      debugPrint("startSession: $e");
    }
  }

  static Future<void> stopSession() async {
    if (!supported) return;
    try {
      await _channel.invokeMethod("stopSession");
    } catch (e) {
      debugPrint("stopSession: $e");
    }
  }

  /// Whether the screen is on (true where this can't be checked).
  static Future<bool> isScreenOn() async {
    if (!supported) return true;
    try {
      return await _channel.invokeMethod<bool>("isScreenOn") ?? true;
    } catch (e) {
      debugPrint("isScreenOn: $e");
      return true;
    }
  }

  /// Saves [bytes] as Download/[folder]/[name], replacing an earlier file of
  /// the same name saved by Lucid. Returns where it was saved, or null.
  static Future<String?> saveToDownloads(
    String folder,
    String name,
    Uint8List bytes,
  ) async {
    if (!supported) return null;
    try {
      return await _channel.invokeMethod<String>("saveToDownloads", {
        "folder": folder,
        "name": name,
        "bytes": bytes,
      });
    } catch (e) {
      debugPrint("saveToDownloads: $e");
      return null;
    }
  }
}
