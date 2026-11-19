import 'package:flutter/material.dart';

import 'package:lucid/common_widgets.dart';
import 'package:lucid/score_colors.dart';
import 'package:lucid/session_measure.dart';
import 'package:lucid/theme.dart';
import 'package:lucid/utils.dart';
import 'package:lucid/format.dart';
import 'package:lucid/l10n/generated/app_localizations.dart';

/// What the phone's sensors measured during a session, on the review screen:
/// the measured calm score, stillness, breaths, steps, room loudness and time
/// away, how well the movement fits the chosen [type], and the type it looks
/// like (with a button to use it).
class MeasuredCard extends StatelessWidget {
  const MeasuredCard({
    super.key,
    required this.measures,
    required this.type,
    this.onUseType,
  });

  final Map measures;
  final String? type;
  final ValueChanged<String>? onUseType;

  // These static variables are used with flutter tests
  static const String keyCalm = "Measured Calm", keyUseType = "Use Type";

  num? _read(String key) => measures[key] as num?;

  Widget _stat(BuildContext context, String label, String value, String unit) {
    ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2.0),
        MetricText(value: value, unit: unit),
      ],
    );
  }

  String _number(num value) =>
      value == value.roundToDouble() ? "${value.round()}" : "$value";

  @override
  Widget build(BuildContext context) {
    AppLocalizations l10n = AppLocalizations.of(context);
    ThemeData theme = Theme.of(context);
    ColorScheme colors = theme.colorScheme;
    TextStyle? note = theme.textTheme.bodySmall?.copyWith(
      color: colors.onSurfaceVariant,
    );

    int? calm = calmScore(measures, type);
    int? fit = typeFit(measures, type);
    String? suggested = suggestedType(measures);
    bool suggest =
        suggested != null &&
        suggested != type &&
        (fit == null || fit < 70) &&
        onUseType != null;

    num? stillness = _read(Measure.stillness),
        movements = _read(Measure.movements),
        steps = _read(Measure.steps),
        cadence = _read(Measure.cadence),
        pace = _read(Measure.paceSteady),
        breaths = _read(Measure.breaths),
        breathRate = _read(Measure.breathRate),
        confidence = _read(Measure.breathConfidence),
        guideRate = _read(Measure.guideRate),
        quiet = _read(Measure.quiet),
        noiseDb = _read(Measure.noiseDb),
        loudMoments = _read(Measure.loudMoments),
        interruptions = _read(Measure.interruptions),
        awaySeconds = _read(Measure.awaySeconds);
    bool walking = steps != null && (_read(Measure.walking) ?? 0) >= 0.5;

    List<Widget> stats = [
      if (stillness != null && !walking)
        _stat(context, l10n.stillness, "$stillness%", ""),
      if (movements != null && !walking)
        _stat(context, l10n.movements, "$movements", ""),
      if (steps != null)
        _stat(
          context,
          l10n.steps,
          "$steps",
          cadence == null ? "" : "${cadence.round()} ${l10n.perMinute}",
        ),
      if (pace != null) _stat(context, l10n.evenPace, "$pace", ""),
      if (breaths != null && breathRate != null)
        _stat(
          context,
          l10n.breathsMeasured,
          "~$breaths",
          "${_number(breathRate)} ${l10n.perMinute}",
        ),
      if (quiet != null)
        _stat(
          context,
          l10n.quiet,
          "$quiet",
          noiseDb == null ? "" : "${noiseDb.round()} dB",
        ),
      if (loudMoments != null && loudMoments > 0)
        _stat(context, l10n.loudMoments, "$loudMoments", ""),
      if (interruptions != null && interruptions > 0)
        _stat(
          context,
          l10n.leftApp,
          "$interruptions×",
          awaySeconds == null
              ? ""
              : getDurationString(Duration(seconds: awaySeconds.toInt())),
        ),
    ];

    // How the breaths were found, and the guide's pace to compare with
    String? breathNote;
    if (breaths != null) {
      String source = measures[Measure.breathSource] == Measure.sourceSound
          ? l10n.fromSound
          : l10n.fromMotion;
      String quality = (confidence ?? 0) >= 60
          ? l10n.goodEstimate
          : l10n.roughEstimate;
      breathNote = "${l10n.breathsMeasured} $source, $quality";
      if (guideRate != null) {
        breathNote +=
            " · ${l10n.guide} ${_number(guideRate)} ${l10n.perMinute}";
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.sensors_rounded, color: colors.primary),
                const SizedBox(width: 8.0),
                Expanded(
                  child: Text(
                    l10n.measured,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                if (calm != null) ...[
                  Text(l10n.measuredCalm, style: note),
                  const SizedBox(width: 8.0),
                  ScoreBadge(
                    key: const Key(MeasuredCard.keyCalm),
                    score: calm,
                    size: 44.0,
                  ),
                ],
              ],
            ),
            if (stats.isNotEmpty) ...[
              const SizedBox(height: 12.0),
              Wrap(spacing: 28.0, runSpacing: 12.0, children: stats),
            ],
            if (breathNote != null) ...[
              const SizedBox(height: 10.0),
              Text(breathNote, style: note),
            ],
            if (fit != null) ...[
              const SizedBox(height: 14.0),
              Row(
                children: [
                  Icon(
                    sessionTypeIcon(type),
                    size: 18.0,
                    color: colors.primary,
                  ),
                  const SizedBox(width: 8.0),
                  Expanded(
                    child: Text(
                      "${l10n.typeFit}: ${sessionTypeLabel(context, type!)}",
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  Text(
                    "$fit%",
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: scoreColor(fit),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6.0),
              // Fit bar, with the same thin edges as the charts
              Container(
                height: 8.0,
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(4.0),
                  border: lineBorder(context),
                ),
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: (fit / 100).clamp(0.0, 1.0),
                  heightFactor: 1.0,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: scoreColor(fit),
                      borderRadius: BorderRadius.circular(4.0),
                      border: edgeBorder(context, scoreColor(fit)),
                    ),
                  ),
                ),
              ),
            ],
            if (suggest) ...[
              const SizedBox(height: 8.0),
              Row(
                children: [
                  Icon(
                    sessionTypeIcon(suggested),
                    size: 18.0,
                    color: colors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8.0),
                  Expanded(
                    child: Text(
                      "${l10n.looksLike} ${sessionTypeLabel(context, suggested)}",
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                  TextButton(
                    key: const Key(MeasuredCard.keyUseType),
                    onPressed: () => onUseType!(suggested),
                    child: Text(l10n.use),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
