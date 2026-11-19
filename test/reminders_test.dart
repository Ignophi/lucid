import 'package:flutter_test/flutter_test.dart';

import 'package:lucid/hive_storage.dart';
import 'package:lucid/reminder_settings.dart';

Session makeSession(DateTime start, int minutes) {
  Session session = Session(start: start);
  session.end = start.add(Duration(minutes: minutes));
  session.breaths = minutes * 6;
  return session;
}

void main() {
  group('Reminders', () {
    test('reminder times, none after midnight', () {
      ReminderSettings settings = ReminderSettings(
        firstMinutes: 15 * 60,
        intervalMinutes: 60,
        count: 3,
      );
      expect(settings.times, [900, 960, 1020]); // 15:00, 16:00, 17:00

      settings.firstMinutes = 22 * 60 + 30;
      expect(settings.times, [1350, 1410]); // 22:30, 23:30 (00:30 dropped)
    });

    test('daily goal', () {
      DateTime now = DateTime(2026, 11, 18, 16, 0);
      List<Session> none = [makeSession(DateTime(2026, 11, 17, 8, 0), 20)];
      List<Session> short = [makeSession(DateTime(2026, 11, 18, 7, 0), 5)];
      List<Session> enough = [
        makeSession(DateTime(2026, 11, 18, 7, 0), 5),
        makeSession(DateTime(2026, 11, 18, 12, 0), 7),
      ];

      // Any session counts when the goal is 0
      expect(goalReached(none, 0, now), isFalse); // yesterday doesn't count
      expect(goalReached(short, 0, now), isTrue);
      // A 10 minute goal
      expect(goalReached(short, 10, now), isFalse);
      expect(goalReached(enough, 10, now), isTrue);
    });

    test('reminders start today, or tomorrow once the goal is met', () {
      ReminderSettings settings = ReminderSettings(
        firstMinutes: 15 * 60,
        intervalMinutes: 60,
        count: 3,
      );

      expect(
        firstReminderDates(settings, false, DateTime(2026, 11, 18, 14, 0)),
        [
          DateTime(2026, 11, 18, 15, 0),
          DateTime(2026, 11, 18, 16, 0),
          DateTime(2026, 11, 18, 17, 0),
        ],
      );
      // 15:30: the 15:00 one is past, so it next comes tomorrow
      expect(
        firstReminderDates(settings, false, DateTime(2026, 11, 18, 15, 30)),
        [
          DateTime(2026, 11, 19, 15, 0),
          DateTime(2026, 11, 18, 16, 0),
          DateTime(2026, 11, 18, 17, 0),
        ],
      );
      // Goal met: nothing more today
      expect(firstReminderDates(settings, true, DateTime(2026, 11, 18, 9, 0)), [
        DateTime(2026, 11, 19, 15, 0),
        DateTime(2026, 11, 19, 16, 0),
        DateTime(2026, 11, 19, 17, 0),
      ]);
      // End of a month
      expect(
        firstReminderDates(settings, true, DateTime(2026, 1, 31, 20, 0)).first,
        DateTime(2026, 2, 1, 15, 0),
      );
    });

    test('settings are saved and loaded', () {
      ReminderSettings settings = ReminderSettings(
        enabled: true,
        firstMinutes: 16 * 60 + 30,
        intervalMinutes: 90,
        count: 4,
        goalMinutes: 10,
      );
      ReminderSettings loaded = ReminderSettings.fromMap(settings.toMap());
      expect(loaded.enabled, isTrue);
      expect(loaded.firstMinutes, 990);
      expect(loaded.intervalMinutes, 90);
      expect(loaded.count, 4);
      expect(loaded.goalMinutes, 10);

      // Nothing saved yet: off, 3 reminders an hour apart from 15:00
      ReminderSettings defaults = ReminderSettings.fromMap(null);
      expect(defaults.enabled, isFalse);
      expect(defaults.times, [900, 960, 1020]);

      // Out-of-range values are corrected
      ReminderSettings fixed = ReminderSettings.fromMap({
        'enabled': true,
        'count': 99,
        'first': -5,
      });
      expect(fixed.count, REMINDERS_MAX);
      expect(fixed.firstMinutes, 0);
    });
  });
}
