// Reminder settings and the rules for when reminders go off. Kept free of
// plugin code so it can be unit tested (see test/reminders_test.dart).

import 'package:lucid/analytics.dart';
import 'package:lucid/hive_storage.dart';

const int MINUTES_PER_DAY = 24 * 60;

/// Choices offered in the Reminders screen.
const List<int> REMINDER_INTERVALS = [30, 60, 90, 120, 180]; // minutes
const List<int> REMINDER_GOALS = [0, 5, 10, 15, 20, 30, 45, 60]; // 0 = any
const int REMINDERS_MAX = 8;

class ReminderSettings {
  ReminderSettings({
    this.enabled = false,
    this.firstMinutes = 15 * 60,
    this.intervalMinutes = 60,
    this.count = 3,
    this.goalMinutes = 0,
  });

  bool enabled;

  /// Time of the first reminder, in minutes after midnight (15:00 = 900).
  int firstMinutes;

  /// Time between reminders.
  int intervalMinutes;

  /// Most reminders per day.
  int count;

  /// Reminders stop for the day once you have meditated this many minutes.
  /// 0: any session counts.
  int goalMinutes;

  /// Times of day (minutes after midnight) the reminders go off. Times that
  /// would fall after midnight are dropped.
  List<int> get times => [
    for (int i = 0; i < count; i++)
      if (firstMinutes + i * intervalMinutes < MINUTES_PER_DAY)
        firstMinutes + i * intervalMinutes,
  ];

  Map<String, Object> toMap() => {
    'enabled': enabled,
    'first': firstMinutes,
    'interval': intervalMinutes,
    'count': count,
    'goal': goalMinutes,
  };

  factory ReminderSettings.fromMap(Object? map) {
    ReminderSettings settings = ReminderSettings();
    if (map is Map) {
      int read(String key, int fallback) {
        Object? value = map[key];
        return value is int ? value : fallback;
      }

      settings.enabled = map['enabled'] == true;
      settings.firstMinutes = read(
        'first',
        settings.firstMinutes,
      ).clamp(0, MINUTES_PER_DAY - 1);
      settings.intervalMinutes = read(
        'interval',
        settings.intervalMinutes,
      ).clamp(1, MINUTES_PER_DAY);
      settings.count = read('count', settings.count).clamp(1, REMINDERS_MAX);
      settings.goalMinutes = read(
        'goal',
        settings.goalMinutes,
      ).clamp(0, MINUTES_PER_DAY);
    }
    return settings;
  }
}

/// Whether today's goal is reached: at least [goalMinutes] of meditation
/// today, or any session today when [goalMinutes] is 0.
bool goalReached(Iterable<Session> sessions, int goalMinutes, DateTime now) {
  DateTime today = dayOf(now);
  Iterable<Session> todays = sessions.where((s) => dayOf(s.start) == today);
  if (goalMinutes <= 0) {
    return todays.isNotEmpty;
  }
  double minutes = todays.fold(0.0, (total, s) => total + sessionMinutes(s));
  return minutes >= goalMinutes;
}

/// When each reminder first goes off (they then repeat daily at the same
/// time): today if that time is still ahead and the goal is not reached yet,
/// otherwise tomorrow.
List<DateTime> firstReminderDates(
  ReminderSettings settings,
  bool goalReachedToday,
  DateTime now,
) {
  return [
    for (int minutes in settings.times)
      () {
        DateTime today = DateTime(
          now.year,
          now.month,
          now.day,
          minutes ~/ 60,
          minutes % 60,
        );
        return goalReachedToday || !today.isAfter(now)
            ? DateTime(
                now.year,
                now.month,
                now.day + 1,
                minutes ~/ 60,
                minutes % 60,
              )
            : today;
      }(),
  ];
}
