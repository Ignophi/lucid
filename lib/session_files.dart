// Sessions as files: Import, Export and the automatic backup to
// Download/Lucid. The CSV format itself is in session_csv.dart.

import 'dart:convert';
import 'dart:typed_data';

import 'package:hive_ce/hive.dart';
import 'package:intl/intl.dart' show DateFormat;

import 'package:lucid/android_system.dart';
import 'package:lucid/constants.dart';
import 'package:lucid/hive_storage.dart';
import 'package:lucid/session_csv.dart';

/// What an import changed.
class ImportSummary {
  const ImportSummary(this.added, this.updated, this.skipped);
  final int added, updated, skipped;
}

/// All stored sessions.
List<Session> storedSessions(Box sessions) =>
    sessions.values.whereType<Session>().toList();

/// Adds the sessions in CSV [text] to [sessions], and fills in details that
/// stored sessions are missing. Throws a FormatException if the text is not
/// a sessions file.
Future<ImportSummary> importSessions(Box sessions, String text) async {
  CsvImport result = parseSessionsCsv(text);
  List<Session> stored = storedSessions(sessions);
  ImportPlan plan = planImport(stored, result.sessions);
  if (plan.toAdd.isNotEmpty) {
    // Store all sessions again, oldest first, as the rest of the app expects
    List<Session> all = [...stored, ...plan.toAdd]
      ..sort((a, b) => a.start.compareTo(b.start));
    await sessions.clear();
    await sessions.addAll(all);
  } else {
    for (Session session in plan.toUpdate) {
      await session.save();
    }
  }
  return ImportSummary(plan.toAdd.length, plan.toUpdate.length, result.skipped);
}

/// CSV file contents for all [sessions].
Uint8List sessionsFile(Iterable<Session> sessions) =>
    Uint8List.fromList(utf8.encode(sessionsToCsv(sessions)));

/// File name for an export made on [day].
String exportFileName(DateTime day) =>
    "${APP_NAME.toLowerCase()}-sessions-${DateFormat('yyyy-MM-dd').format(day)}.csv";

// --- automatic backup ------------------------------------------------------

/// The automatic backup: after each session (and when the app opens, at most
/// once a day), all sessions are saved to Download/Lucid. There is one file
/// per month, so older months stay as earlier copies.
class Backup {
  Backup._();

  static const String folder = APP_NAME;
  static const String _settingsKey = "backup";

  /// Backup file name for [day]'s month, e.g. lucid-sessions-2026-11.csv.
  static String fileName(DateTime day) =>
      "${APP_NAME.toLowerCase()}-sessions-${DateFormat('yyyy-MM').format(day)}.csv";

  static Map _stored(Box settings) {
    Object? map = settings.get(_settingsKey);
    return map is Map ? map : const {};
  }

  /// On unless turned off in the Backup screen.
  static bool isEnabled(Box settings) => _stored(settings)['enabled'] != false;

  static Future<void> setEnabled(Box settings, bool enabled) =>
      settings.put(_settingsKey, {..._stored(settings), 'enabled': enabled});

  /// When the last backup was made, and where it went.
  static DateTime? lastTime(Box settings) {
    Object? millis = _stored(settings)['last'];
    return millis is int ? DateTime.fromMillisecondsSinceEpoch(millis) : null;
  }

  static String? lastPath(Box settings) => _stored(settings)['path'] as String?;

  /// Saves the backup now. Skipped when there are no sessions, so an empty
  /// app never replaces a good backup. Returns where it was saved, or null.
  static Future<String?> save(Box settings, Box sessions) async {
    List<Session> all = storedSessions(sessions);
    if (all.isEmpty) return null;
    DateTime now = DateTime.now();
    String? path = await AndroidSystem.saveToDownloads(
      folder,
      fileName(now),
      sessionsFile(all),
    );
    if (path != null) {
      await settings.put(_settingsKey, {
        ..._stored(settings),
        'last': now.millisecondsSinceEpoch,
        'path': path,
      });
    }
    return path;
  }

  /// Backs up if turned on and [always] (after a session) or if the last
  /// backup was on an earlier day (when the app opens).
  static Future<void> auto(
    Box settings,
    Box sessions, {
    bool always = false,
  }) async {
    if (!isEnabled(settings)) return;
    DateTime? last = lastTime(settings);
    DateTime now = DateTime.now();
    bool today =
        last != null &&
        last.year == now.year &&
        last.month == now.month &&
        last.day == now.day;
    if (always || !today) {
      await save(settings, sessions);
    }
  }
}
