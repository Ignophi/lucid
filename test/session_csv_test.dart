import 'package:flutter_test/flutter_test.dart';

import 'package:lucid/hive_storage.dart';
import 'package:lucid/session_csv.dart';
import 'package:lucid/session_measure.dart';

Session makeSession(
  DateTime start, {
  int minutes = 10,
  int breaths = 60,
  int? rating,
  String? type,
  String? comment,
  String? description,
  List<double>? heartrates,
}) {
  Session session = Session(start: start);
  session.end = start.add(Duration(minutes: minutes));
  session.breaths = breaths;
  session.rating = rating;
  session.sessionType = type;
  session.comment = comment;
  session.description = description;
  session.heartrates = heartrates;
  return session;
}

void main() {
  group('Session CSV', () {
    test('export then import keeps every detail', () {
      List<Session> sessions = [
        makeSession(
          DateTime(2026, 11, 18, 7, 30, 0, 123),
          rating: 85,
          type: 'sitting',
          comment: 'Calm, "deep" breaths\nthen a café',
          description: '4-7-8 Breathing',
          heartrates: [70, 68.5, 66],
        ),
        makeSession(DateTime(2026, 11, 17, 21, 5), minutes: 5, breaths: 30),
      ];
      sessions[0].measurements = {
        Measure.version: 1,
        Measure.stillness: 96,
        Measure.flat: 0.12,
        Measure.upright: 0.84,
        Measure.breathRate: 6.2,
        Measure.breathSource: Measure.sourceMotion,
        Measure.quiet: 71,
        Measure.interruptions: 0,
      };

      String text = sessionsToCsv(sessions);
      expect(text.startsWith('﻿'), isTrue);
      CsvImport result = parseSessionsCsv(text);

      expect(result.skipped, 0);
      expect(result.sessions.length, 2);
      // Written oldest first
      Session plain = result.sessions[0], full = result.sessions[1];
      expect(plain.start, DateTime(2026, 11, 17, 21, 5));
      expect(plain.rating, isNull);
      expect(plain.sessionType, isNull);
      expect(plain.comment, isNull);
      expect(plain.heartrates, isNull);

      expect(full.start, DateTime(2026, 11, 18, 7, 30, 0, 123));
      expect(full.end, DateTime(2026, 11, 18, 7, 40, 0, 123));
      expect(full.breaths, 60);
      expect(full.rating, 85);
      expect(full.sessionType, 'sitting');
      expect(full.comment, 'Calm, "deep" breaths\nthen a café');
      expect(full.description, '4-7-8 Breathing');
      expect(full.heartrates, [70.0, 68.5, 66.0]);
      expect(plain.measurements, isNull);
      expect(full.measurements, sessions[0].measurements);
      // Calm and fit are written for reading
      expect(text.contains(',calm,fit,measurements'), isTrue);
      expect(text.contains('stillness=96; flat=0.12'), isTrue);
    });

    test('reads files exported by the original Brethap app', () {
      String brethap =
          'start,end,breaths,heartrate,description\r\n'
          '2025-03-01 08:00:00.000,2025-03-01 08:02:00.000,12,0.0,\r\n'
          '2025-03-02 08:00:00.000,2025-03-02 08:01:16.000,4,65.5,4-7-8 Breathing\r\n';
      CsvImport result = parseSessionsCsv(brethap);

      expect(result.skipped, 0);
      expect(result.sessions.length, 2);
      expect(result.sessions[0].breaths, 12);
      expect(result.sessions[0].heartrates, isNull);
      expect(result.sessions[0].description, isNull);
      expect(result.sessions[1].heartrates, [65.5]);
      expect(result.sessions[1].description, '4-7-8 Breathing');
      expect(result.sessions[1].rating, isNull);
    });

    test('converts session types from earlier versions', () {
      String text =
          'start,end,type\n'
          '2026-11-01 07:00:00,2026-11-01 07:10:00,sitting_breathing\n'
          '2026-11-02 07:00:00,2026-11-02 07:10:00,lying_breathing\n'
          '2026-11-03 07:00:00,2026-11-03 07:10:00,walking_meditation\n'
          '2026-11-04 07:00:00,2026-11-04 07:10:00,body_scan\n';
      List<String?> types = [
        for (Session s in parseSessionsCsv(text).sessions) s.sessionType,
      ];
      expect(types, ['sitting', 'lying', 'walking', 'body_scan']);
    });

    test('reads spreadsheet-edited files', () {
      // Byte order mark, ";" separators, columns moved, an extra column
      String excel =
          '﻿Comment;Start;End;Notes;Rating;Breaths\r\n'
          'Good one;2026-01-05 07:00:00;2026-01-05 07:20:00;x;90;100\r\n'
          ';2026-01-06T07:00:00;2026-01-06T07:10:00;;150;50.0\r\n';
      CsvImport result = parseSessionsCsv(excel);

      expect(result.sessions.length, 2);
      expect(result.sessions[0].comment, 'Good one');
      expect(result.sessions[0].rating, 90);
      expect(result.sessions[0].breaths, 100);
      expect(result.sessions[1].comment, isNull);
      expect(result.sessions[1].rating, 100); // clamped to the 0-100 scale
      expect(result.sessions[1].breaths, 50);
    });

    test('skips rows it cannot read', () {
      String text =
          'start,end,breaths\n'
          '18/11/2026 7:30,18/11/2026 7:40,10\n' // not an ISO date
          '2026-11-18 08:00:00,2026-11-18 07:00:00,10\n' // ends before start
          '2026-11-18 09:00:00,2026-11-18 09:10:00,10\n';
      CsvImport result = parseSessionsCsv(text);
      expect(result.sessions.length, 1);
      expect(result.skipped, 2);
    });

    test('rejects files that are not session exports', () {
      bool rejected = false;
      try {
        parseSessionsCsv('name,amount\nrent,1200\n');
      } on FormatException {
        rejected = true;
      }
      expect(rejected, isTrue);
    });

    test('import adds new sessions and only fills in missing details', () {
      Session stored = makeSession(DateTime(2026, 1, 1, 7), rating: 70);
      Session storedPlain = makeSession(DateTime(2026, 1, 2, 7));
      List<Session> imported = [
        makeSession(
          DateTime(2026, 1, 1, 7),
          rating: 10,
          comment: 'from backup',
        ), // keeps 70, gains comment
        makeSession(DateTime(2026, 1, 2, 7)), // nothing new
        makeSession(DateTime(2026, 1, 4, 7)), // measurements filled in below
        makeSession(DateTime(2026, 1, 3, 7), rating: 55), // new
        makeSession(DateTime(2026, 1, 3, 7), rating: 99), // duplicate row
      ];

      Session storedNoMeasures = makeSession(DateTime(2026, 1, 4, 7));
      imported[2].measurements = {Measure.stillness: 80};

      ImportPlan plan = planImport([
        stored,
        storedPlain,
        storedNoMeasures,
      ], imported);

      expect(plan.toAdd.length, 1);
      expect(plan.toAdd.first.rating, 55);
      expect(plan.toUpdate.length, 2);
      expect(stored.rating, 70);
      expect(stored.comment, 'from backup');
      expect(storedNoMeasures.measurements, {Measure.stillness: 80});
      expect(plan.unchanged, 2);
    });
  });
}
