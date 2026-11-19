import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lucid/analytics.dart';
import 'package:lucid/hive_storage.dart';
import 'package:lucid/score_colors.dart';

Session makeSession(DateTime start, {int minutes = 10, int? rating}) {
  Session session = Session(start: start);
  session.end = start.add(Duration(minutes: minutes));
  session.breaths = minutes * 6;
  session.rating = rating;
  return session;
}

void main() {
  group('Analytics', () {
    // Mon 6 Jan 2025 to Thu 9 Jan, then Sat 11 Jan
    List<Session> sessions = [
      makeSession(DateTime(2025, 1, 6, 7, 30), rating: 80),
      makeSession(DateTime(2025, 1, 6, 21, 0), minutes: 20, rating: 60),
      makeSession(DateTime(2025, 1, 7, 7, 15)),
      makeSession(DateTime(2025, 1, 8, 7, 45), rating: 100),
      makeSession(DateTime(2025, 1, 9, 22, 10), minutes: 5),
      makeSession(DateTime(2025, 1, 11, 7, 0), minutes: 15, rating: 40),
    ];
    Analytics stats = Analytics(sessions);

    test('totals', () {
      expect(stats.count, 6);
      expect(stats.totalDuration, const Duration(minutes: 70));
      expect(stats.averageDuration.inSeconds, 700);
      expect(stats.averageScore, 70.0); // (80 + 60 + 100 + 40) / 4
    });

    test('best streak counts consecutive days', () {
      expect(stats.bestStreak, 4); // 6, 7, 8, 9 January
    });

    test('sessions by hour and weekday', () {
      List<int> hours = stats.sessionsByHour;
      expect(hours[7], 4);
      expect(hours[21], 1);
      expect(hours[22], 1);
      expect(hours.reduce((a, b) => a + b), 6);

      List<int> weekdays = stats.sessionsByWeekday; // Monday first
      expect(weekdays, [2, 1, 1, 1, 0, 1, 0]);
    });

    test('minutes per day, month and year', () {
      List<double> days = stats.minutesPerDay(DateTime(2025, 1, 5), 7);
      expect(days, [0, 30, 10, 10, 5, 0, 15]);
      expect(stats.minutesPerMonth(2025)[0], 70);
      expect(stats.minutesPerYear(2024, 2025), [0, 70]);
    });

    test('per day summary and types', () {
      DaySummary? monday = stats.byDay[DateTime(2025, 1, 6)];
      expect(monday?.sessions, 2);
      expect(monday?.minutes, 30);
      expect(monday?.averageScore, 70);

      sessions[0].sessionType = 'sitting';
      sessions[1].sessionType = 'sitting';
      sessions[2].sessionType = 'walking';
      List<TypeSummary> types = Analytics(sessions).byType;
      expect(types.first.type, 'sitting');
      expect(types.first.sessions.length, 2);
      expect(types.first.averageScore, 70);
      expect(types.last.averageScore, isNull);
    });

    test('range filter', () {
      DateTime now = DateTime(2025, 2, 9, 12); // 30 days back = 11 Jan
      expect(
        sessionsInRange(sessions, AnalyticsRange.last30Days, now: now).length,
        1, // only 11 January is within the last 30 days
      );
      expect(
        sessionsInRange(
          sessions,
          AnalyticsRange.year,
          now: now,
          year: 2024,
        ).length,
        0,
      );
      expect(
        sessionsInRange(sessions, AnalyticsRange.allTime, now: now).length,
        6,
      );
    });

    test('formatMinutes', () {
      expect(formatMinutes(45), '45m');
      expect(formatMinutes(60), '1h');
      expect(formatMinutes(200), '3h 20m');
    });

    test('y-axis ticks are round numbers covering the data', () {
      expect(niceTicks(0), [0, 1]);
      expect(niceTicks(1), [0, 1]);
      expect(niceTicks(3), [0, 1, 2, 3]);
      expect(niceTicks(4), [0, 2, 4]);
      expect(niceTicks(7), [0, 5, 10]);
      expect(niceTicks(37), [0, 20, 40]);
      expect(niceTicks(40), [0, 20, 40]);
      expect(niceTicks(130), [0, 50, 100, 150]);
      expect(niceTicks(2300), [0, 1000, 2000, 3000]);
    });

    test('y-axis labels', () {
      expect(formatAxisValue(0), '0');
      expect(formatAxisValue(40), '40');
      expect(formatAxisValue(1500), '1.5k');
      expect(formatAxisValue(2000), '2k');
    });
  });

  group('Score colors', () {
    test('ends and middle of the scale', () {
      expect(scoreColor(0), SCORE_COLOR_LOW);
      expect(scoreColor(50), SCORE_COLOR_MID);
      expect(scoreColor(100), SCORE_COLOR_HIGH);
      expect(scoreColor(-10), SCORE_COLOR_LOW);
      expect(scoreColor(150), SCORE_COLOR_HIGH);
    });

    test('readable text color', () {
      expect(onColor(Colors.black), Colors.white);
      expect(onColor(Colors.white), Colors.black87);
    });
  });
}
