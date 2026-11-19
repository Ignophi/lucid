import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hive_ce/hive.dart';
import 'package:intl/intl.dart' show DateFormat;

import 'package:lucid/analytics.dart';
import 'package:lucid/charts.dart';
import 'package:lucid/hive_storage.dart';
import 'package:lucid/score_colors.dart';
import 'package:lucid/theme.dart';
import 'package:lucid/utils.dart';
import 'package:lucid/l10n/generated/app_localizations.dart';

/// Opens the analytics screen, optionally on a given period.
Future<void> openAnalytics(
  BuildContext context,
  Box sessions, {
  AnalyticsRange range = AnalyticsRange.last30Days,
  int? year,
}) async {
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => AnalyticsWidget(
        sessions: sessions,
        initialRange: range,
        initialYear: year,
      ),
    ),
  );
}

/// Charts and totals: when (hour, weekday) and how much you meditate,
/// a year overview colored by score, and stats per session type.
class AnalyticsWidget extends StatefulWidget {
  const AnalyticsWidget({
    super.key,
    required this.sessions,
    this.initialRange = AnalyticsRange.last30Days,
    this.initialYear,
    this.drawer,
  });
  final Box sessions;
  final Widget? drawer; // the side menu, when shown as a main section
  final AnalyticsRange initialRange;
  final int? initialYear;

  // These static variables are used with flutter tests
  static const String keyRecent = "Analytics Recent",
      keyYear = "Analytics Year",
      keyAllTime = "Analytics All Time",
      keySessionCount = "Analytics Sessions";

  @override
  State<AnalyticsWidget> createState() => _AnalyticsWidgetState();
}

class _ChartData {
  _ChartData(this.values, this.labels, this.tooltips);
  final List<double> values;
  final List<String> labels, tooltips;
}

class _AnalyticsWidgetState extends State<AnalyticsWidget> {
  late final List<Session> _all;
  late final DateTime _now;
  late final int _firstYear, _lastYear;
  late AnalyticsRange _range;
  late int _year;

  @override
  void initState() {
    super.initState();
    _all = widget.sessions.values.toList().cast<Session>();
    _now = DateTime.now();
    Iterable<int> years = _all.map((s) => s.start.year);
    _firstYear = years.isEmpty ? _now.year : years.reduce(math.min);
    _lastYear = math.max(_now.year, years.isEmpty ? 0 : years.reduce(math.max));
    _range = widget.initialRange;
    _year = (widget.initialYear ?? _now.year).clamp(_firstYear, _lastYear);
  }

  String _activityTitle(AppLocalizations l10n) {
    switch (_range) {
      case AnalyticsRange.last30Days:
        return l10n.minutesPerDay;
      case AnalyticsRange.year:
        return l10n.minutesPerMonth;
      case AnalyticsRange.allTime:
        return l10n.minutesPerYear;
    }
  }

  _ChartData _activityData(Analytics stats) {
    switch (_range) {
      case AnalyticsRange.last30Days:
        DateTime first = recentFirstDay(_now);
        List<double> values = stats.minutesPerDay(first, ANALYTICS_RECENT_DAYS);
        List<DateTime> days = [
          for (int i = 0; i < ANALYTICS_RECENT_DAYS; i++)
            DateTime(first.year, first.month, first.day + i),
        ];
        return _ChartData(
          values,
          [
            // label every 7th day, ending on today
            for (int i = 0; i < days.length; i++)
              (days.length - 1 - i) % 7 == 0 ? "${days[i].day}" : "",
          ],
          [
            for (int i = 0; i < days.length; i++)
              "${DateFormat('EEE MMM d').format(days[i])} · ${formatMinutes(values[i])}",
          ],
        );
      case AnalyticsRange.year:
        List<double> values = stats.minutesPerMonth(_year);
        return _ChartData(
          values,
          [
            for (int m = 1; m <= 12; m++)
              DateFormat('MMMMM').format(DateTime(_year, m)),
          ],
          [
            for (int m = 1; m <= 12; m++)
              "${DateFormat('MMMM').format(DateTime(_year, m))} · ${formatMinutes(values[m - 1])}",
          ],
        );
      case AnalyticsRange.allTime:
        List<double> values = stats.minutesPerYear(_firstYear, _lastYear);
        bool short = values.length > 6;
        return _ChartData(
          values,
          [
            for (int y = _firstYear; y <= _lastYear; y++)
              short ? "'${(y % 100).toString().padLeft(2, '0')}" : "$y",
          ],
          [
            for (int y = _firstYear; y <= _lastYear; y++)
              "$y · ${formatMinutes(values[y - _firstYear])}",
          ],
        );
    }
  }

  Widget _getSummary(BuildContext context, Analytics stats) {
    AppLocalizations l10n = AppLocalizations.of(context);
    double? score = stats.averageScore;
    double? calm = stats.averageCalm,
        stillness = stats.averageStillness,
        breathRate = stats.averageBreathRate;
    List<Widget> tiles = [
      _StatTile(
        label: l10n.sessions,
        value: "${stats.count}",
        valueKey: const Key(AnalyticsWidget.keySessionCount),
      ),
      _StatTile(
        label: l10n.totalTime,
        value: formatMinutes(stats.totalDuration.inSeconds / 60),
      ),
      _StatTile(
        label: l10n.averageSession,
        value: formatMinutes(stats.averageDuration.inSeconds / 60),
      ),
      _StatTile(
        label: l10n.averageScore,
        value: score == null ? "–" : "${score.round()}",
        valueColor: score == null ? null : scoreColor(score),
      ),
      _StatTile(label: l10n.bestStreakDays, value: "${stats.bestStreak}"),
      _StatTile(label: l10n.breaths, value: "${stats.totalBreaths}"),
      // From the sensor measurements, when there are any
      if (calm != null)
        _StatTile(
          label: l10n.averageCalm,
          value: "${calm.round()}",
          valueColor: scoreColor(calm),
        ),
      if (stillness != null)
        _StatTile(label: l10n.stillness, value: "${stillness.round()}%"),
      if (breathRate != null)
        _StatTile(
          label: l10n.breathRate,
          value: "${breathRate.toStringAsFixed(1)} ${l10n.perMinute}",
        ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        const double spacing = 8.0;
        double width = ((constraints.maxWidth - 2 * spacing) / 3)
            .floorToDouble();
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (Widget tile in tiles) SizedBox(width: width, child: tile),
          ],
        );
      },
    );
  }

  Widget _getHourChart(BuildContext context, Analytics stats) {
    AppLocalizations l10n = AppLocalizations.of(context);
    List<int> hours = stats.sessionsByHour;
    return BarChart(
      color: Theme.of(context).colorScheme.secondary,
      values: [for (int count in hours) count.toDouble()],
      labels: [for (int h = 0; h < 24; h++) h % 6 == 0 ? "$h" : ""],
      tooltips: [
        for (int h = 0; h < 24; h++)
          "${h.toString().padLeft(2, '0')}:00 · ${l10n.sessions}: ${hours[h]}",
      ],
    );
  }

  Widget _getWeekdayChart(BuildContext context, Analytics stats) {
    AppLocalizations l10n = AppLocalizations.of(context);
    List<int> weekdays = stats.sessionsByWeekday;
    // 1 Jan 2024 was a Monday
    List<DateTime> days = [
      for (int i = 0; i < 7; i++) DateTime(2024, 1, 1 + i),
    ];
    return BarChart(
      values: [for (int count in weekdays) count.toDouble()],
      labels: [for (DateTime d in days) DateFormat('E').format(d)],
      tooltips: [
        for (int i = 0; i < 7; i++)
          "${DateFormat('EEEE').format(days[i])} · ${l10n.sessions}: ${weekdays[i]}",
      ],
    );
  }

  Widget _getTypeList(BuildContext context, List<TypeSummary> types) {
    AppLocalizations l10n = AppLocalizations.of(context);
    return Column(
      children: [
        for (TypeSummary t in types)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              sessionTypeIcon(t.type),
              color: Theme.of(context).colorScheme.primary,
            ),
            title: Text(sessionTypeLabel(context, t.type)),
            subtitle: Text(
              "${l10n.sessions}: ${t.sessions.length} · ${formatMinutes(t.minutes)}",
            ),
            trailing: ScoreBadge(score: t.averageScore, size: 36.0),
          ),
      ],
    );
  }

  Widget _getYearPicker(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded),
            onPressed: _year > _firstYear
                ? () => setState(() {
                    _year--;
                  })
                : null,
          ),
          Text("$_year", style: Theme.of(context).textTheme.titleLarge),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded),
            onPressed: _year < _lastYear
                ? () => setState(() {
                    _year++;
                  })
                : null,
          ),
        ],
      ),
    );
  }

  List<Widget> _getSections(BuildContext context, Analytics stats) {
    AppLocalizations l10n = AppLocalizations.of(context);
    _ChartData activity = _activityData(stats);
    List<TypeSummary> types = stats.byType;
    return [
      _getSummary(context, stats),
      _Section(
        title: _activityTitle(l10n),
        child: BarChart(
          values: activity.values,
          labels: activity.labels,
          tooltips: activity.tooltips,
        ),
      ),
      if (_range == AnalyticsRange.year)
        _Section(
          title: l10n.yearOverview,
          child: YearOverview(year: _year, days: stats.byDay),
        ),
      _Section(
        title: l10n.timeOfDay,
        subtitle: l10n.numberOfSessions,
        child: _getHourChart(context, stats),
      ),
      _Section(
        title: l10n.dayOfWeek,
        subtitle: l10n.numberOfSessions,
        child: _getWeekdayChart(context, stats),
      ),
      if (types.isNotEmpty)
        _Section(title: l10n.byType, child: _getTypeList(context, types)),
    ];
  }

  @override
  Widget build(BuildContext context) {
    AppLocalizations l10n = AppLocalizations.of(context);
    ThemeData theme = Theme.of(context);
    Analytics stats = Analytics(
      sessionsInRange(_all, _range, now: _now, year: _year),
    );

    return Scaffold(
      drawer: widget.drawer,
      appBar: AppBar(title: Text(l10n.analytics)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 24.0),
        children: [
          SegmentedButton<AnalyticsRange>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment<AnalyticsRange>(
                value: AnalyticsRange.last30Days,
                label: Text(
                  l10n.last30Days,
                  key: const Key(AnalyticsWidget.keyRecent),
                ),
              ),
              ButtonSegment<AnalyticsRange>(
                value: AnalyticsRange.year,
                label: Text(l10n.year, key: const Key(AnalyticsWidget.keyYear)),
              ),
              ButtonSegment<AnalyticsRange>(
                value: AnalyticsRange.allTime,
                label: Text(
                  l10n.allTime,
                  key: const Key(AnalyticsWidget.keyAllTime),
                ),
              ),
            ],
            selected: {_range},
            onSelectionChanged: (Set<AnalyticsRange> selection) {
              setState(() {
                _range = selection.first;
              });
            },
          ),
          if (_range == AnalyticsRange.year) _getYearPicker(context),
          const SizedBox(height: 16.0),
          if (stats.count == 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48.0),
              child: Center(
                child: Text(
                  l10n.noSessions,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            )
          else
            ..._getSections(context, stats),
        ],
      ),
    );
  }
}

/// A rounded card with a title, used for each chart.
class _Section extends StatelessWidget {
  const _Section({required this.title, this.subtitle, required this.child});

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    String? sub = subtitle;
    return Card(
      margin: const EdgeInsets.only(top: 16.0),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16.0, 14.0, 16.0, 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            if (sub != null)
              Text(
                sub,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            const SizedBox(height: 12.0),
            child,
          ],
        ),
      ),
    );
  }
}

/// One number with a label under it, for the summary at the top.
class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    this.valueKey,
    this.valueColor,
  });

  final String label, value;
  final Key? valueKey;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: lineColor(context), width: OUTLINE_WIDTH),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              key: valueKey,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: valueColor,
              ),
            ),
          ),
          const SizedBox(height: 2.0),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
