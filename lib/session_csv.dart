// Sessions as CSV: the format used by Backup, Restore, Export and Import.
//
// Every session is one row, oldest first, with these columns:
//   start, end    when it started and ended (e.g. 2026-11-18 07:30:00.000)
//   breaths       number of breaths
//   heartrate     average heart rate from a watch (0.0 if none)
//   description   preset name, if one was used
//   rating        your score, 0-100 (empty if not rated)
//   type          session type: sitting, lying, walking, body_scan or other
//                 (empty if not set)
//   comment       your comment
//   duration      length as h:mm:ss (for reading; ignored on import)
//   heartrates    every heart rate reading, separated by ";"
//   calm          measured calm score, 0-100 (for reading; ignored on import)
//   fit           how well the measured movement fits the type, 0-100 (for
//                 reading; ignored on import)
//   measurements  what the sensors measured, as name=value pairs separated
//                 by ";" (e.g. stillness=96; breathRate=6.2)
//
// The first five columns match the original Brethap app, so files exported
// from Brethap can be imported here (and these files can be imported there).
// On import, columns are found by name, in any order; only start and end are
// required, so files edited in a spreadsheet still work.

import 'package:csv/csv.dart';

import 'package:lucid/constants.dart';
import 'package:lucid/hive_storage.dart';
import 'package:lucid/session_measure.dart';
import 'package:lucid/format.dart';

const String CSV_START = "start",
    CSV_END = "end",
    CSV_BREATHS = "breaths",
    CSV_HEARTRATE = "heartrate",
    CSV_DESCRIPTION = "description",
    CSV_RATING = "rating",
    CSV_TYPE = "type",
    CSV_COMMENT = "comment",
    CSV_DURATION = "duration",
    CSV_HEARTRATES = "heartrates",
    CSV_CALM = "calm",
    CSV_FIT = "fit",
    CSV_MEASUREMENTS = "measurements";

const List<String> CSV_COLUMNS = [
  CSV_START,
  CSV_END,
  CSV_BREATHS,
  CSV_HEARTRATE,
  CSV_DESCRIPTION,
  CSV_RATING,
  CSV_TYPE,
  CSV_COMMENT,
  CSV_DURATION,
  CSV_HEARTRATES,
  CSV_CALM,
  CSV_FIT,
  CSV_MEASUREMENTS,
];

String _number(double value) =>
    value == value.roundToDouble() ? value.toInt().toString() : "$value";

/// Measurements as "name=value; name=value".
String measurementsToText(Map? measures) {
  if (measures == null) return "";
  return [
    for (MapEntry entry in measures.entries)
      if (entry.value != null) "${entry.key}=${entry.value}",
  ].join("; ");
}

/// Reads [measurementsToText] back (numbers as int or double). Null if empty.
Map<String, dynamic>? measurementsFromText(String text) {
  Map<String, dynamic> measures = {};
  for (String part in text.split(";")) {
    int equals = part.indexOf("=");
    if (equals <= 0) continue;
    String key = part.substring(0, equals).trim();
    String value = part.substring(equals + 1).trim();
    if (key.isEmpty || value.isEmpty) continue;
    measures[key] = int.tryParse(value) ?? double.tryParse(value) ?? value;
  }
  return measures.isEmpty ? null : measures;
}

/// All [sessions] as CSV text, oldest first. Starts with a byte order mark so
/// spreadsheet apps read accents and other special characters correctly.
String sessionsToCsv(Iterable<Session> sessions) {
  List<Session> sorted = sessions.toList()
    ..sort((a, b) => a.start.compareTo(b.start));
  List<List<dynamic>> rows = [CSV_COLUMNS];
  for (Session s in sorted) {
    List<double> heartrates = s.heartrates ?? const [];
    double average = heartrates.isEmpty
        ? 0.0
        : heartrates.reduce((a, b) => a + b) / heartrates.length;
    rows.add([
      s.start.toString(),
      s.end.toString(),
      s.breaths,
      average.toStringAsFixed(1),
      s.description ?? "",
      s.rating ?? "",
      s.sessionType ?? "",
      s.comment ?? "",
      getDurationString(roundDuration(s.end.difference(s.start))),
      heartrates.map(_number).join(";"),
      calmScore(s.measurements, s.sessionType) ?? "",
      typeFit(s.measurements, s.sessionType) ?? "",
      measurementsToText(s.measurements),
    ]);
  }
  return CsvCodec(addBom: true).encode(rows);
}

/// Sessions read from a CSV file (not stored yet).
class CsvImport {
  CsvImport(this.sessions, this.skipped);

  final List<Session> sessions;

  /// Rows that could not be read (e.g. a date a spreadsheet reformatted).
  final int skipped;
}

int? _toInt(String text) =>
    int.tryParse(text) ?? double.tryParse(text)?.round();

/// Reads sessions from CSV [text]. Throws a [FormatException] if the text has
/// no "start" and "end" columns, i.e. it is not a sessions file.
CsvImport parseSessionsCsv(String text) {
  if (text.startsWith('﻿')) {
    text = text.substring(1);
  }
  List<List<dynamic>> rows = csv.decode(text);
  if (rows.isEmpty) {
    throw const FormatException("The file is empty");
  }
  List<String> header = [
    for (dynamic cell in rows.first) cell.toString().trim().toLowerCase(),
  ];
  int column(String name) => header.indexOf(name);
  int start = column(CSV_START), end = column(CSV_END);
  if (start < 0 || end < 0) {
    throw const FormatException("No start and end columns");
  }
  int breaths = column(CSV_BREATHS),
      heartrate = column(CSV_HEARTRATE),
      heartrates = column(CSV_HEARTRATES),
      description = column(CSV_DESCRIPTION),
      rating = column(CSV_RATING),
      type = column(CSV_TYPE),
      comment = column(CSV_COMMENT),
      measurements = column(CSV_MEASUREMENTS);

  List<Session> sessions = [];
  int skipped = 0;
  for (List<dynamic> row in rows.skip(1)) {
    String cell(int index) =>
        index >= 0 && index < row.length ? row[index].toString().trim() : "";
    String? optional(int index) {
      String value = cell(index);
      return value.isEmpty ? null : value;
    }

    DateTime? startTime = DateTime.tryParse(cell(start)),
        endTime = DateTime.tryParse(cell(end));
    if (startTime == null || endTime == null || endTime.isBefore(startTime)) {
      skipped++;
      continue;
    }
    Session session = Session(start: startTime);
    session.end = endTime;
    session.breaths = _toInt(cell(breaths)) ?? 0;

    List<double> readings = [
      for (String part in cell(heartrates).split(RegExp(r'[;\s]+')))
        if (double.tryParse(part) != null) double.parse(part),
    ];
    if (readings.isEmpty) {
      double average = double.tryParse(cell(heartrate)) ?? 0.0;
      if (average > 0) readings = [average];
    }
    session.heartrates = readings.isEmpty ? null : readings;

    session.description = optional(description);
    session.rating = _toInt(cell(rating))?.clamp(RATING_MIN, RATING_MAX);
    session.sessionType = currentSessionType(optional(type));
    session.comment = optional(comment);
    session.measurements = measurementsFromText(cell(measurements));
    sessions.add(session);
  }
  return CsvImport(sessions, skipped);
}

/// What importing will change: sessions to add, and stored sessions that got
/// missing details filled in (they need saving).
class ImportPlan {
  final List<Session> toAdd = [];
  final List<Session> toUpdate = [];
  int unchanged = 0;
}

/// Matches [imported] sessions to [existing] ones by start time. New sessions
/// are added; for ones already stored, details they are missing (rating,
/// type, comment, preset, heart rates, measurements) are filled in. Stored
/// values are never overwritten. Updates the matching existing sessions in
/// place.
ImportPlan planImport(Iterable<Session> existing, Iterable<Session> imported) {
  ImportPlan plan = ImportPlan();
  Map<int, Session> byStart = {
    for (Session s in existing) s.start.millisecondsSinceEpoch: s,
  };
  for (Session s in imported) {
    int key = s.start.millisecondsSinceEpoch;
    Session? match = byStart[key];
    if (match == null) {
      plan.toAdd.add(s);
      byStart[key] = s; // ignore duplicates within the file
      continue;
    }
    bool changed = false;
    if (match.rating == null && s.rating != null) {
      match.rating = s.rating;
      changed = true;
    }
    if ((match.sessionType ?? "").isEmpty && s.sessionType != null) {
      match.sessionType = s.sessionType;
      changed = true;
    }
    if ((match.comment ?? "").isEmpty && s.comment != null) {
      match.comment = s.comment;
      changed = true;
    }
    if ((match.description ?? "").isEmpty && s.description != null) {
      match.description = s.description;
      changed = true;
    }
    if ((match.heartrates ?? const []).isEmpty && s.heartrates != null) {
      match.heartrates = s.heartrates;
      changed = true;
    }
    if ((match.measurements ?? const {}).isEmpty && s.measurements != null) {
      match.measurements = s.measurements;
      changed = true;
    }
    if (changed) {
      if (!plan.toUpdate.contains(match) && !plan.toAdd.contains(match)) {
        plan.toUpdate.add(match);
      }
    } else {
      plan.unchanged++;
    }
  }
  return plan;
}
