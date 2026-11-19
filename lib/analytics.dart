// Numbers behind the analytics screen. Kept free of UI code so it can be
// unit tested (see test/analytics_test.dart).

import 'package:lucid/constants.dart';
import 'package:lucid/hive_storage.dart';
import 'package:lucid/session_measure.dart';
import 'package:lucid/format.dart';

enum AnalyticsRange { last30Days, year, allTime }

const int ANALYTICS_RECENT_DAYS = 30;

/// Midnight at the start of [dateTime]'s day.
DateTime dayOf(DateTime dateTime) =>
    DateTime(dateTime.year, dateTime.month, dateTime.day);

/// First day of the "last 30 days" period ending today. Uses calendar days,
/// so it stays right across daylight saving time changes.
DateTime recentFirstDay(DateTime now) =>
    DateTime(now.year, now.month, now.day - (ANALYTICS_RECENT_DAYS - 1));

Duration sessionDuration(Session session) =>
    roundDuration(session.end.difference(session.start));

double sessionMinutes(Session session) =>
    sessionDuration(session).inSeconds / Duration.secondsPerMinute;

/// Average rating of the rated sessions, or null if none are rated.
double? averageRating(Iterable<Session> sessions) {
  int total = 0, count = 0;
  for (Session session in sessions) {
    int? rating = session.rating;
    if (rating != null) {
      total += rating;
      count++;
    }
  }
  return count == 0 ? null : total / count;
}

/// The sessions that fall in [range]. [year] is used for AnalyticsRange.year.
List<Session> sessionsInRange(
  Iterable<Session> sessions,
  AnalyticsRange range, {
  required DateTime now,
  int? year,
}) {
  switch (range) {
    case AnalyticsRange.last30Days:
      DateTime first = recentFirstDay(now);
      return sessions.where((s) => !s.start.isBefore(first)).toList();
    case AnalyticsRange.year:
      int y = year ?? now.year;
      return sessions.where((s) => s.start.year == y).toList();
    case AnalyticsRange.allTime:
      return sessions.toList();
  }
}

/// Totals and averages for one day of the year overview.
class DaySummary {
  int sessions = 0;
  double minutes = 0;
  int _ratingTotal = 0, _ratings = 0;

  double? get averageScore => _ratings == 0 ? null : _ratingTotal / _ratings;

  void add(Session session) {
    sessions++;
    minutes += sessionMinutes(session);
    int? rating = session.rating;
    if (rating != null) {
      _ratingTotal += rating;
      _ratings++;
    }
  }
}

/// Totals and averages for one session type.
class TypeSummary {
  TypeSummary(this.type);
  final String type;
  final List<Session> sessions = [];

  double get minutes =>
      sessions.fold(0.0, (total, s) => total + sessionMinutes(s));
  double? get averageScore => averageRating(sessions);
}

class Analytics {
  Analytics(List<Session> sessions)
    : sessions = List.of(sessions)..sort((a, b) => a.start.compareTo(b.start));

  /// Sessions in this period, oldest first.
  final List<Session> sessions;

  int get count => sessions.length;

  Duration get totalDuration =>
      sessions.fold(Duration.zero, (total, s) => total + sessionDuration(s));

  Duration get averageDuration =>
      count == 0 ? Duration.zero : totalDuration ~/ count;

  int get totalBreaths => sessions.fold(0, (total, s) => total + s.breaths);

  double? get averageScore => averageRating(sessions);

  /// Average over the sessions that have the value (null if none).
  double? _averageOf(num? Function(Session s) value) {
    double total = 0;
    int counted = 0;
    for (Session s in sessions) {
      num? v = value(s);
      if (v != null) {
        total += v;
        counted++;
      }
    }
    return counted == 0 ? null : total / counted;
  }

  /// Measured calm, stillness (sessions that aren't walking) and breath rate.
  double? get averageCalm =>
      _averageOf((s) => calmScore(s.measurements, s.sessionType));

  double? get averageStillness => _averageOf(
    (s) => s.sessionType == SESSION_TYPE_WALKING
        ? null
        : s.measurements?[Measure.stillness] as num?,
  );

  double? get averageBreathRate =>
      _averageOf((s) => s.measurements?[Measure.breathRate] as num?);

  /// Longest run of consecutive days with at least one session.
  int get bestStreak {
    List<DateTime> days = sessions.map((s) => dayOf(s.start)).toSet().toList()
      ..sort();
    int best = 0, current = 0;
    DateTime? previous;
    for (DateTime day in days) {
      bool consecutive =
          previous != null &&
          DateTime(previous.year, previous.month, previous.day + 1) == day;
      current = consecutive ? current + 1 : 1;
      if (current > best) best = current;
      previous = day;
    }
    return best;
  }

  /// Number of sessions started in each hour of the day (index 0-23).
  List<int> get sessionsByHour {
    List<int> hours = List.filled(24, 0);
    for (Session s in sessions) {
      hours[s.start.hour]++;
    }
    return hours;
  }

  /// Number of sessions on each day of the week, Monday first (index 0-6).
  List<int> get sessionsByWeekday {
    List<int> days = List.filled(7, 0);
    for (Session s in sessions) {
      days[s.start.weekday - DateTime.monday]++;
    }
    return days;
  }

  /// Minutes on each of the [days] days starting at [firstDay].
  List<double> minutesPerDay(DateTime firstDay, int days) {
    DateTime first = dayOf(firstDay);
    List<double> minutes = List.filled(days, 0.0);
    for (Session s in sessions) {
      DateTime day = dayOf(s.start);
      // Count calendar days, not 24h periods (safe across clock changes)
      int index = DateTime.utc(
        day.year,
        day.month,
        day.day,
      ).difference(DateTime.utc(first.year, first.month, first.day)).inDays;
      if (index >= 0 && index < days) {
        minutes[index] += sessionMinutes(s);
      }
    }
    return minutes;
  }

  /// Minutes in each month of [year] (index 0 = January).
  List<double> minutesPerMonth(int year) {
    List<double> minutes = List.filled(12, 0.0);
    for (Session s in sessions) {
      if (s.start.year == year) {
        minutes[s.start.month - 1] += sessionMinutes(s);
      }
    }
    return minutes;
  }

  /// Minutes in each year from [firstYear] to [lastYear].
  List<double> minutesPerYear(int firstYear, int lastYear) {
    List<double> minutes = List.filled(lastYear - firstYear + 1, 0.0);
    for (Session s in sessions) {
      int index = s.start.year - firstYear;
      if (index >= 0 && index < minutes.length) {
        minutes[index] += sessionMinutes(s);
      }
    }
    return minutes;
  }

  /// Per-day totals, keyed by midnight of each day.
  Map<DateTime, DaySummary> get byDay {
    Map<DateTime, DaySummary> days = {};
    for (Session s in sessions) {
      days.putIfAbsent(dayOf(s.start), () => DaySummary()).add(s);
    }
    return days;
  }

  /// Per-type totals for sessions that have a type, most used first.
  List<TypeSummary> get byType {
    Map<String, TypeSummary> types = {};
    for (Session s in sessions) {
      String? type = s.sessionType;
      if (type != null && type.isNotEmpty) {
        types.putIfAbsent(type, () => TypeSummary(type)).sessions.add(s);
      }
    }
    return types.values.toList()
      ..sort((a, b) => b.sessions.length.compareTo(a.sessions.length));
  }
}

/// Round axis values from 0 up to at least [maxValue], using a 1-2-5 step
/// (1, 2, 5, 10, 20, 50 ...) with at most [maxIntervals] steps.
/// For example 37 -> [0, 20, 40] and 130 -> [0, 50, 100, 150].
List<double> niceTicks(double maxValue, {int maxIntervals = 3}) {
  if (maxValue <= 0) return [0, 1];
  for (double base = 1; ; base *= 10) {
    for (int multiple in const [1, 2, 5]) {
      double step = multiple * base;
      int intervals = (maxValue / step).ceil();
      if (intervals <= maxIntervals) {
        return [for (int i = 0; i <= intervals; i++) i * step];
      }
    }
  }
}

/// Short axis label: "40", "1.5k", "2k".
String formatAxisValue(double value) {
  if (value >= 1000) {
    double thousands = value / 1000;
    String text = thousands == thousands.roundToDouble()
        ? thousands.toInt().toString()
        : thousands.toStringAsFixed(1);
    return "${text}k";
  }
  return value.round().toString();
}

/// "45m" or "3h 20m".
String formatMinutes(double minutes) {
  int total = minutes.round();
  int hours = total ~/ 60, rest = total % 60;
  if (hours == 0) return "${rest}m";
  if (rest == 0) return "${hours}h";
  return "${hours}h ${rest}m";
}
