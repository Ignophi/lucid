// The charts on the analytics screen: a bar chart with thin axes, and the
// year overview (one square per day, colored by score).

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import 'package:lucid/analytics.dart';
import 'package:lucid/constants.dart';
import 'package:lucid/score_colors.dart';
import 'package:lucid/theme.dart';
import 'package:lucid/l10n/generated/app_localizations.dart';

/// Simple vertical bar chart with thin x and y axes, round y-axis values and
/// faint grid lines. The tallest bar is drawn in full color; each bar has a
/// thin edge. Tap a bar to see its exact value.
class BarChart extends StatelessWidget {
  const BarChart({
    super.key,
    required this.values,
    required this.labels,
    required this.tooltips,
    this.color,
    this.height = 120.0,
  });

  final List<double> values;
  final List<String> labels, tooltips;
  final Color? color;
  final double height;

  static const double _axisThickness = 1.0, _gridThickness = 0.5;

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    Color barColor = color ?? theme.colorScheme.primary;
    Color axisColor = lineColor(context);
    Color gridColor = axisColor.withValues(alpha: 0.5);
    double maxValue = values.fold(0.0, math.max);
    List<double> ticks = niceTicks(maxValue);
    double top = ticks.last;
    double gap = values.length > 20 ? 1.5 : 6.0;
    TextStyle labelStyle = (theme.textTheme.labelSmall ?? const TextStyle())
        .copyWith(color: theme.colorScheme.onSurfaceVariant);

    // Width of the y-axis labels, from the widest one
    TextScaler textScaler = MediaQuery.textScalerOf(context);
    double axisWidth = 0.0;
    for (double tick in ticks) {
      TextPainter painter = TextPainter(
        text: TextSpan(text: formatAxisValue(tick), style: labelStyle),
        textDirection: TextDirection.ltr,
        textScaler: textScaler,
      )..layout();
      axisWidth = math.max(axisWidth, painter.width);
      painter.dispose();
    }
    axisWidth += 6.0; // space between labels and the axis line
    double labelHeight =
        textScaler.scale(labelStyle.fontSize ?? 11.0) *
        (labelStyle.height ?? 1.4);

    return Padding(
      padding: EdgeInsets.only(top: labelHeight / 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: height,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // y-axis values, centered on their grid line
                SizedBox(
                  width: axisWidth,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      for (double tick in ticks)
                        Positioned(
                          right: 6.0,
                          bottom: height * tick / top - labelHeight / 2,
                          child: Text(formatAxisValue(tick), style: labelStyle),
                        ),
                    ],
                  ),
                ),
                Container(width: _axisThickness, color: axisColor),
                Expanded(
                  child: Stack(
                    children: [
                      for (double tick in ticks.skip(1))
                        Positioned(
                          left: 0.0,
                          right: 0.0,
                          bottom: height * tick / top - _gridThickness / 2,
                          child: Container(
                            height: _gridThickness,
                            color: gridColor,
                          ),
                        ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (int i = 0; i < values.length; i++)
                            Expanded(
                              child: Tooltip(
                                message: tooltips[i],
                                triggerMode: TooltipTriggerMode.tap,
                                child: Container(
                                  // transparent color makes the whole
                                  // column tappable
                                  color: Colors.transparent,
                                  alignment: Alignment.bottomCenter,
                                  padding: EdgeInsets.symmetric(
                                    horizontal: gap / 2,
                                  ),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 400),
                                    curve: Curves.easeOutCubic,
                                    width: double.infinity,
                                    height: values[i] <= 0
                                        ? 0.0
                                        : math.max(
                                            height * values[i] / top,
                                            3.0,
                                          ),
                                    decoration: BoxDecoration(
                                      color:
                                          values[i] == maxValue && maxValue > 0
                                          ? barColor
                                          : barColor.withValues(alpha: 0.45),
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(6.0),
                                      ),
                                      border: values[i] <= 0
                                          ? null
                                          : edgeBorder(context, barColor),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // x-axis
          Row(
            children: [
              SizedBox(width: axisWidth),
              Expanded(
                child: Container(height: _axisThickness, color: axisColor),
              ),
            ],
          ),
          const SizedBox(height: 4.0),
          Row(
            children: [
              SizedBox(width: axisWidth + _axisThickness),
              for (int i = 0; i < labels.length; i++)
                Expanded(
                  child: Text(
                    labels[i],
                    textAlign: TextAlign.center,
                    softWrap: false,
                    overflow: TextOverflow.visible,
                    style: labelStyle,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A year as 12 small month grids ("year in pixels"). Each day is colored
/// by its average score; tap a day for details.
class YearOverview extends StatelessWidget {
  const YearOverview({super.key, required this.year, required this.days});

  final int year;
  final Map<DateTime, DaySummary> days;

  Widget _getDay(BuildContext context, int month, int day, double cell) {
    int daysInMonth = DateTime(year, month + 1, 0).day;
    if (day < 1 || day > daysInMonth) {
      return SizedBox(width: cell, height: cell);
    }
    AppLocalizations l10n = AppLocalizations.of(context);
    ColorScheme colors = Theme.of(context).colorScheme;
    DateTime date = DateTime(year, month, day);
    DaySummary? summary = days[date];
    double? average = summary?.averageScore;
    Color color;
    if (summary == null) {
      color = colors.surfaceContainerHighest;
    } else if (average != null) {
      color = scoreColor(average);
    } else {
      color = unratedColor(context);
    }

    Widget square = Container(
      width: cell,
      height: cell,
      padding: EdgeInsets.all(cell * 0.12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(cell * 0.3),
          // Days without a session get a fainter edge
          border: summary == null
              ? lineBorder(context)
              : edgeBorder(context, color),
        ),
      ),
    );
    if (summary == null) {
      return square;
    }
    String details =
        "${DateFormat('EEE MMM d').format(date)}\n"
        "${l10n.sessions}: ${summary.sessions} · ${formatMinutes(summary.minutes)}";
    if (average != null) {
      details += " · ${l10n.rating}: ${average.round()}";
    }
    return Tooltip(
      message: details,
      triggerMode: TooltipTriggerMode.tap,
      child: square,
    );
  }

  Widget _getMonth(BuildContext context, int month, double cell) {
    DateTime first = DateTime(year, month, 1);
    int offset = first.weekday - DateTime.monday; // weeks start on Monday
    int daysInMonth = DateTime(year, month + 1, 0).day;
    int rows = ((offset + daysInMonth) / 7).ceil();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          DateFormat('MMM').format(first),
          style: Theme.of(context).textTheme.labelMedium,
        ),
        const SizedBox(height: 4.0),
        for (int r = 0; r < rows; r++)
          Row(
            children: [
              for (int c = 0; c < 7; c++)
                _getDay(context, month, r * 7 + c - offset + 1, cell),
            ],
          ),
      ],
    );
  }

  Widget _getLegend(BuildContext context) {
    AppLocalizations l10n = AppLocalizations.of(context);
    ThemeData theme = Theme.of(context);
    TextStyle? style = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    Widget swatch(Color color, Border border) => Container(
      width: 12.0,
      height: 12.0,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3.0),
        border: border,
      ),
    );
    return Wrap(
      spacing: 16.0,
      runSpacing: 6.0,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            swatch(
              theme.colorScheme.surfaceContainerHighest,
              lineBorder(context),
            ),
            const SizedBox(width: 4.0),
            Text(l10n.noSession, style: style),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            swatch(
              unratedColor(context),
              edgeBorder(context, unratedColor(context)),
            ),
            const SizedBox(width: 4.0),
            Text(l10n.notRated, style: style),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("$RATING_MIN", style: style),
            const SizedBox(width: 4.0),
            Container(
              width: 64.0,
              height: 10.0,
              decoration: BoxDecoration(
                gradient: SCORE_GRADIENT,
                borderRadius: BorderRadius.circular(5.0),
                border: Border.all(
                  color: edgeColorFor(
                    theme.colorScheme.outline,
                    theme.brightness,
                  ),
                  width: EDGE_WIDTH,
                ),
              ),
            ),
            const SizedBox(width: 4.0),
            Text("$RATING_MAX", style: style),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            const int perRow = 3;
            const double spacing = 12.0;
            double monthWidth =
                ((constraints.maxWidth - spacing * (perRow - 1)) / perRow)
                    .floorToDouble();
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                for (int m = 1; m <= 12; m++)
                  SizedBox(
                    width: monthWidth,
                    child: _getMonth(
                      context,
                      m,
                      (monthWidth / 7).floorToDouble(),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 12.0),
        _getLegend(context),
      ],
    );
  }
}
