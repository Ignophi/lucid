import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show NumberFormat;

import 'package:lucid/analytics.dart';
import 'package:lucid/score_colors.dart';
import 'package:lucid/theme.dart';
import 'package:lucid/utils.dart';
import 'package:lucid/l10n/generated/app_localizations.dart';

/// The bottom-right button on Calendar and Sessions: starts a session.
/// Just the meditation icon (the label shows on long press).
class MeditateButton extends StatelessWidget {
  const MeditateButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  // Used with flutter tests
  static const String keyMeditate = "Meditate";

  static const double _size = 64.0, _iconSize = 34.0; // icon ~140% of normal

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(
        floatingActionButtonTheme: theme.floatingActionButtonTheme.copyWith(
          sizeConstraints: const BoxConstraints.tightFor(
            width: _size,
            height: _size,
          ),
        ),
      ),
      child: FloatingActionButton(
        key: const Key(keyMeditate),
        onPressed: onPressed,
        tooltip: AppLocalizations.of(context).meditate,
        child: const Icon(Icons.self_improvement, size: _iconSize),
      ),
    );
  }
}

/// A number in bold followed by a small grey unit, e.g. "42 sessions".
class MetricText extends StatelessWidget {
  const MetricText({
    super.key,
    required this.value,
    required this.unit,
    this.color,
  });

  final String value, unit;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          TextSpan(
            text: " $unit",
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// Totals for a period in two columns: sessions and total time on the left,
/// breaths and average score (in its color) on the right.
class PeriodSummary extends StatelessWidget {
  const PeriodSummary({super.key, required this.stats});

  final Analytics stats;

  @override
  Widget build(BuildContext context) {
    AppLocalizations l10n = AppLocalizations.of(context);
    NumberFormat number = NumberFormat.decimalPattern();
    double? score = stats.averageScore;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MetricText(
                value: number.format(stats.count),
                unit: l10n.sessionsUnit,
              ),
              const SizedBox(height: 4.0),
              MetricText(
                value: formatMinutes(stats.totalDuration.inSeconds / 60),
                unit: l10n.totalUnit,
              ),
            ],
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MetricText(
                value: number.format(stats.totalBreaths),
                unit: l10n.breathsUnit,
              ),
              const SizedBox(height: 4.0),
              MetricText(
                value: score == null ? "–" : "${score.round()}",
                unit: l10n.avgScoreUnit,
                color: score == null ? null : scoreColor(score),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Small rounded pill with the icons of the session types in a period,
/// most used first.
class TypePill extends StatelessWidget {
  const TypePill({super.key, required this.types});

  final List<TypeSummary> types;

  @override
  Widget build(BuildContext context) {
    ColorScheme colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20.0),
        border: lineBorder(context),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (TypeSummary t in types.take(5))
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2.0),
              child: Icon(
                sessionTypeIcon(t.type),
                size: 16.0,
                color: colors.primary,
              ),
            ),
        ],
      ),
    );
  }
}
