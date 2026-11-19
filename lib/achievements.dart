// Achievements (beta): badges with levels, worked out from the session
// history every time (nothing is stored but which ones you have already
// seen), so they can be fine-tuned and recalculated at any point. Plain Dart
// so it can be unit tested (see test/achievements_test.dart).

import 'package:lucid/constants.dart';
import 'package:lucid/hive_storage.dart';
import 'package:lucid/session_measure.dart';

enum AchievementGroup {
  milestones,
  consistency,
  moments,
  practice,
  mindfulness,
}

/// An achievement and the values needed for each of its levels.
class Achievement {
  const Achievement(this.id, this.group, this.tiers);

  final String id;
  final AchievementGroup group;
  final List<int> tiers;
}

// Ids
const String A_SESSIONS = "sessions",
    A_HOURS = "hours",
    A_LONG = "long",
    A_STREAK = "streak",
    A_DAYS = "days",
    A_WEEKS = "weeks",
    A_DAILY_SESSIONS = "dailySessions",
    A_DAILY_MINUTES = "dailyMinutes",
    A_EARLY = "earlyBird",
    A_NIGHT = "nightOwl",
    A_EXPLORER = "explorer",
    A_WALKER = "walker",
    A_REVIEWS = "reviews",
    A_JOURNAL = "journal",
    A_TOP_SCORE = "topScore",
    A_CALM = "calm",
    A_STILL = "still",
    A_QUIET = "quiet";

const List<Achievement> ACHIEVEMENTS = [
  // Milestones
  Achievement(A_SESSIONS, AchievementGroup.milestones, [
    1,
    10,
    50,
    100,
    250,
    500,
    1000,
  ]),
  Achievement(A_HOURS, AchievementGroup.milestones, [1, 5, 10, 25, 50, 100]),
  Achievement(A_LONG, AchievementGroup.milestones, [10, 20, 30, 45, 60]),
  // Consistency
  Achievement(A_STREAK, AchievementGroup.consistency, [
    3,
    7,
    14,
    30,
    60,
    100,
    365,
  ]),
  Achievement(A_DAYS, AchievementGroup.consistency, [7, 30, 100, 200, 365]),
  Achievement(A_WEEKS, AchievementGroup.consistency, [1, 4, 12, 26, 52]),
  // Moments
  Achievement(A_DAILY_SESSIONS, AchievementGroup.moments, [2, 3, 5]),
  Achievement(A_DAILY_MINUTES, AchievementGroup.moments, [30, 60, 120]),
  Achievement(A_EARLY, AchievementGroup.moments, [1, 10, 50]),
  Achievement(A_NIGHT, AchievementGroup.moments, [1, 10, 50]),
  // Practice
  Achievement(A_EXPLORER, AchievementGroup.practice, [2, 3, 4]),
  Achievement(A_WALKER, AchievementGroup.practice, [1, 10, 50]),
  Achievement(A_REVIEWS, AchievementGroup.practice, [1, 10, 50, 100]),
  Achievement(A_JOURNAL, AchievementGroup.practice, [1, 10, 50]),
  // Mindfulness
  Achievement(A_TOP_SCORE, AchievementGroup.mindfulness, [1, 10, 25]),
  Achievement(A_CALM, AchievementGroup.mindfulness, [1, 10, 50]),
  Achievement(A_STILL, AchievementGroup.mindfulness, [1, 10, 25]),
  Achievement(A_QUIET, AchievementGroup.mindfulness, [1, 10, 25]),
];

/// Sessions shorter than this (e.g. started by accident) don't count.
const Duration MIN_SESSION = Duration(seconds: 10);

/// Thresholds used by some achievements.
const int EARLY_BEFORE_HOUR =
        7, // early bird: 4:00 to 6:59
    NIGHT_FROM_HOUR =
        22, // night owl: 22:00 to 3:59
    STEADY_WEEK_DAYS = 5,
    TOP_SCORE = 90,
    CALM_SCORE = 80,
    STILLNESS = 95,
    QUIET_SCORE = 80;

/// Where you are with one achievement.
class AchievementStatus {
  AchievementStatus(this.achievement);

  final Achievement achievement;

  /// The value so far (e.g. sessions done, best streak).
  int value = 0;

  /// When each level was reached, in order (its length is the level).
  final List<DateTime> earned = [];

  int get level => earned.length;
  bool get complete => level >= achievement.tiers.length;

  /// The value needed for the next level (null when complete).
  int? get next => complete ? null : achievement.tiers[level];

  /// How far towards the next level (1 when complete).
  double get progress {
    int? goal = next;
    if (goal == null) return 1.0;
    int from = level == 0 ? 0 : achievement.tiers[level - 1];
    return goal <= from
        ? 0.0
        : ((value - from) / (goal - from)).clamp(0.0, 1.0);
  }
}

/// One level of one achievement, and when it was reached.
class EarnedLevel {
  const EarnedLevel(this.achievement, this.level, this.date);

  final Achievement achievement;

  /// 1 for the first level.
  final int level;
  final DateTime date;

  /// Identifies it, e.g. "streak:3".
  String get id => "${achievement.id}:$level";
}

DateTime _day(DateTime time) => DateTime(time.year, time.month, time.day);

/// Works out every achievement from [sessions] (in any order).
List<AchievementStatus> computeAchievements(Iterable<Session> sessions) {
  Map<String, AchievementStatus> status = {
    for (Achievement a in ACHIEVEMENTS) a.id: AchievementStatus(a),
  };
  List<Session> ordered =
      sessions.where((s) => s.end.difference(s.start) >= MIN_SESSION).toList()
        ..sort((a, b) => a.start.compareTo(b.start));

  int totalSeconds = 0;
  Map<DateTime, int> dayCount = {}, daySeconds = {};
  Map<DateTime, Set<DateTime>> weekDays = {};
  Set<String> types = {};
  DateTime? lastDay;
  int streak = 0, steadyWeeks = 0;
  Map<String, int> counts = {};
  void count(String id) => counts[id] = (counts[id] ?? 0) + 1;

  for (Session s in ordered) {
    int seconds = s.end.difference(s.start).inSeconds;
    DateTime day = _day(s.start);
    String? type = currentSessionType(s.sessionType);
    Map? m = s.measurements;

    totalSeconds += seconds;
    dayCount[day] = (dayCount[day] ?? 0) + 1;
    daySeconds[day] = (daySeconds[day] ?? 0) + seconds;

    // Days in a row
    if (lastDay == null || day != lastDay) {
      DateTime? previous = lastDay;
      bool nextDay =
          previous != null &&
          DateTime(previous.year, previous.month, previous.day + 1) == day;
      streak = nextDay ? streak + 1 : 1;
      lastDay = day;
    }

    // Weeks (starting on Monday) with sessions on 5 days or more
    DateTime week = DateTime(day.year, day.month, day.day - (day.weekday - 1));
    Set<DateTime> days = weekDays.putIfAbsent(week, () => {});
    if (days.add(day) && days.length == STEADY_WEEK_DAYS) steadyWeeks++;

    int hour = s.start.hour;
    if (hour >= 4 && hour < EARLY_BEFORE_HOUR) count(A_EARLY);
    if (hour >= NIGHT_FROM_HOUR || hour < 4) count(A_NIGHT);
    if (type != null && type != SESSION_TYPE_OTHER) types.add(type);
    if (type == SESSION_TYPE_WALKING) count(A_WALKER);
    if (s.rating != null) count(A_REVIEWS);
    if ((s.comment ?? "").trim().isNotEmpty) count(A_JOURNAL);
    if ((s.rating ?? 0) >= TOP_SCORE) count(A_TOP_SCORE);
    if ((calmScore(m, type) ?? 0) >= CALM_SCORE) count(A_CALM);
    num? stillness = m?[Measure.stillness] as num?;
    if (type != SESSION_TYPE_WALKING && (stillness ?? 0) >= STILLNESS) {
      count(A_STILL);
    }
    if (((m?[Measure.quiet] as num?) ?? 0) >= QUIET_SCORE) count(A_QUIET);

    int best(String id, int value) =>
        value > status[id]!.value ? value : status[id]!.value;
    Map<String, int> values = {
      A_SESSIONS: status[A_SESSIONS]!.value + 1,
      A_HOURS: totalSeconds ~/ 3600,
      A_LONG: best(A_LONG, seconds ~/ 60),
      A_STREAK: best(A_STREAK, streak),
      A_DAYS: dayCount.length,
      A_WEEKS: steadyWeeks,
      A_DAILY_SESSIONS: best(A_DAILY_SESSIONS, dayCount[day]!),
      A_DAILY_MINUTES: best(A_DAILY_MINUTES, daySeconds[day]! ~/ 60),
      A_EXPLORER: types.length,
      for (String id in counts.keys) id: counts[id]!,
    };

    // New levels reached with this session
    for (MapEntry<String, int> entry in values.entries) {
      AchievementStatus a = status[entry.key]!;
      a.value = entry.value;
      while (!a.complete && a.value >= a.next!) {
        a.earned.add(s.start);
      }
    }
  }
  return [for (Achievement a in ACHIEVEMENTS) status[a.id]!];
}

/// Every level reached, the most recent first.
List<EarnedLevel> earnedLevels(List<AchievementStatus> statuses) {
  List<EarnedLevel> levels = [
    for (AchievementStatus s in statuses)
      for (int i = 0; i < s.earned.length; i++)
        EarnedLevel(s.achievement, i + 1, s.earned[i]),
  ];
  levels.sort((a, b) => b.date.compareTo(a.date));
  return levels;
}

/// Levels in [levels] whose ids are not in [seen] (to celebrate them).
List<EarnedLevel> newLevels(List<EarnedLevel> levels, Iterable<String> seen) {
  Set<String> known = seen.toSet();
  return [
    for (EarnedLevel level in levels)
      if (!known.contains(level.id)) level,
  ];
}
