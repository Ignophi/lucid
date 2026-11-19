import 'package:flutter_test/flutter_test.dart';

import 'package:lucid/achievements.dart';
import 'package:lucid/constants.dart';
import 'package:lucid/hive_storage.dart';
import 'package:lucid/session_measure.dart';

Session session(
  DateTime start, {
  int minutes = 10,
  int seconds = 0,
  String? type,
  int? rating,
  String? comment,
  Map<String, dynamic>? measurements,
}) {
  Session s = Session(start: start);
  s.end = start.add(Duration(minutes: minutes, seconds: seconds));
  s.breaths = 0;
  s.sessionType = type;
  s.rating = rating;
  s.comment = comment;
  s.measurements = measurements;
  return s;
}

AchievementStatus find(List<AchievementStatus> all, String id) =>
    all.firstWhere((s) => s.achievement.id == id);

void main() {
  group('Achievements', () {
    test('first session, and very short ones do not count', () {
      List<AchievementStatus> all = computeAchievements([
        session(DateTime(2026, 11, 1, 9), minutes: 0, seconds: 5),
        session(DateTime(2026, 11, 2, 9)),
      ]);
      AchievementStatus sessions = find(all, A_SESSIONS);
      expect(sessions.value, 1);
      expect(sessions.level, 1);
      expect(sessions.earned.first, DateTime(2026, 11, 2, 9));
      expect(sessions.next, 10);
    });

    test('days in a row, and a gap starts again', () {
      List<AchievementStatus> all = computeAchievements([
        session(DateTime(2026, 3, 27, 8)),
        session(DateTime(2026, 3, 28, 8)),
        session(DateTime(2026, 3, 29, 8)), // a clock change in Europe
        session(DateTime(2026, 3, 29, 20)), // same day
        session(DateTime(2026, 4, 2, 8)), // gap
      ]);
      AchievementStatus streak = find(all, A_STREAK);
      expect(streak.value, 3); // the best streak
      expect(streak.level, 1);
      expect(streak.earned.first, DateTime(2026, 3, 29, 8));
      expect(find(all, A_DAYS).value, 4);
    });

    test('a busy day, time and the longest session', () {
      List<AchievementStatus> all = computeAchievements([
        session(DateTime(2026, 5, 4, 6, 30), minutes: 20), // early
        session(DateTime(2026, 5, 4, 13)),
        session(DateTime(2026, 5, 4, 23), minutes: 31), // night
        session(DateTime(2026, 5, 5, 2)), // still night
      ]);
      expect(find(all, A_DAILY_SESSIONS).level, 2); // 2 and 3 in a day
      expect(find(all, A_DAILY_MINUTES).value, 61);
      expect(find(all, A_DAILY_MINUTES).level, 2);
      expect(find(all, A_HOURS).value, 1);
      expect(find(all, A_LONG).value, 31);
      expect(find(all, A_LONG).level, 3); // 10, 20 and 30 min
      expect(find(all, A_EARLY).value, 1);
      expect(find(all, A_NIGHT).value, 2);
    });

    test('a steady week: sessions on five days', () {
      List<AchievementStatus> all = computeAchievements([
        for (int day = 9; day <= 13; day++) session(DateTime(2026, 11, day, 7)),
      ]);
      expect(find(all, A_WEEKS).value, 1);
      expect(find(all, A_WEEKS).earned.first, DateTime(2026, 11, 13, 7));
    });

    test('types, reviews, comments and measurements', () {
      Map<String, dynamic> calmAndStill = {
        Measure.stillness: 97,
        Measure.breathSteady: 85,
        Measure.quiet: 82,
      };
      List<AchievementStatus> all = computeAchievements([
        session(DateTime(2026, 1, 1, 9), type: SESSION_TYPE_SITTING),
        session(DateTime(2026, 1, 2, 9), type: SESSION_TYPE_LYING, rating: 92),
        session(
          DateTime(2026, 1, 3, 9),
          type: "walking_breathing", // an older type name
          rating: 70,
          comment: "Windy",
        ),
        session(
          DateTime(2026, 1, 4, 9),
          type: SESSION_TYPE_SITTING,
          measurements: calmAndStill,
        ),
      ]);
      expect(find(all, A_EXPLORER).value, 3);
      expect(find(all, A_EXPLORER).level, 2);
      expect(find(all, A_WALKER).value, 1);
      expect(find(all, A_REVIEWS).value, 2);
      expect(find(all, A_TOP_SCORE).value, 1);
      expect(find(all, A_JOURNAL).value, 1);
      expect(find(all, A_CALM).value, 1);
      expect(find(all, A_STILL).value, 1);
      expect(find(all, A_QUIET).value, 1);
    });

    test('progress, earned levels and what is new', () {
      List<AchievementStatus> all = computeAchievements([
        for (int i = 0; i < 12; i++) session(DateTime(2026, 2, 1 + i, 9)),
      ]);
      AchievementStatus sessions = find(all, A_SESSIONS);
      expect(sessions.level, 2);
      expect(sessions.progress, closeTo(2 / 40, 1e-9)); // 12 of 10..50

      List<EarnedLevel> levels = earnedLevels(all);
      expect(levels.first.date.isAfter(levels.last.date), isTrue);
      List<EarnedLevel> fresh = newLevels(levels, [
        for (EarnedLevel l in levels)
          if (l.id != "$A_SESSIONS:2") l.id,
      ]);
      expect(fresh.length, 1);
      expect(fresh.first.id, "$A_SESSIONS:2");
    });
  });
}
