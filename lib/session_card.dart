import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:collection/collection.dart';

import 'package:lucid/analytics.dart';
import 'package:lucid/hive_storage.dart';
import 'package:lucid/score_colors.dart';
import 'package:lucid/theme.dart';
import 'package:lucid/session_measure.dart';
import 'package:lucid/utils.dart';
import 'package:lucid/format.dart';
import 'package:lucid/l10n/generated/app_localizations.dart';

/// A session in a list: colored stripe on the left (its score color), the
/// type as the title, preset and comment underneath, and a row of numbers.
class SessionCard extends StatelessWidget {
  const SessionCard({
    super.key,
    required this.session,
    this.onTap,
    this.margin,
  });

  final Session session;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? margin;

  static const double _stripeWidth = 6.0;

  Widget _getStat(BuildContext context, String label, Widget value) {
    ThemeData theme = Theme.of(context);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2.0),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: value,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    AppLocalizations l10n = AppLocalizations.of(context);
    ThemeData theme = Theme.of(context);
    ColorScheme colors = theme.colorScheme;
    TextStyle? valueStyle = theme.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w600,
    );

    String? type = session.sessionType;
    bool hasType = type != null && type.isNotEmpty;
    String preset = session.description ?? "";
    String comment = session.comment ?? "";
    int? rating = session.rating;
    Duration duration = sessionDuration(session);
    int heartrate = session.heartrates?.average.toInt() ?? 0;
    int? calm = calmScore(session.measurements, type);

    // Title: the type, else the preset name, else "Session"
    String title = hasType
        ? sessionTypeLabel(context, type)
        : (preset.isNotEmpty ? preset : l10n.session);
    String subtitle = hasType ? preset : "";

    return Card(
      margin: margin,
      child: InkWell(
        onTap: () {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          VoidCallback? tap = onTap;
          if (tap != null) {
            tap();
          }
        },
        onLongPress: () {
          debugPrint("session: ${session.toString()}");
        },
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                _stripeWidth + 14.0,
                14.0,
                16.0,
                14.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        sessionTypeIcon(type),
                        size: 20.0,
                        color: colors.primary,
                      ),
                      const SizedBox(width: 8.0),
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (onTap != null && !session.isReviewed)
                        Icon(
                          Icons.rate_review_outlined,
                          size: 18.0,
                          color: colors.onSurfaceVariant,
                        ),
                    ],
                  ),
                  if (subtitle.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        subtitle,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  if (comment.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        comment,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  const SizedBox(height: 10.0),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _getStat(
                        context,
                        l10n.start,
                        Text(
                          DateFormat.jm().format(session.start),
                          style: valueStyle,
                        ),
                      ),
                      _getStat(
                        context,
                        l10n.duration,
                        Text(getDurationString(duration), style: valueStyle),
                      ),
                      _getStat(
                        context,
                        l10n.breaths,
                        Text("${session.breaths}", style: valueStyle),
                      ),
                      if (heartrate > 0)
                        _getStat(
                          context,
                          l10n.heartrate,
                          Text("$heartrate", style: valueStyle),
                        ),
                      if (calm != null)
                        _getStat(
                          context,
                          l10n.measuredCalm,
                          Text(
                            "$calm",
                            style: valueStyle?.copyWith(
                              color: scoreColor(calm),
                            ),
                          ),
                        ),
                      _getStat(
                        context,
                        l10n.rating,
                        Text(
                          rating == null ? "–" : "$rating",
                          style: valueStyle?.copyWith(
                            color: rating == null ? null : scoreColor(rating),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Score stripe (the soft accent when not rated)
            Positioned(
              left: 0.0,
              top: 0.0,
              bottom: 0.0,
              width: _stripeWidth,
              child: Builder(
                builder: (context) {
                  Color stripe = rating == null
                      ? unratedColor(context)
                      : scoreColor(rating);
                  return DecoratedBox(
                    decoration: BoxDecoration(
                      color: stripe,
                      border: Border(
                        right: BorderSide(
                          color: edgeColor(context, stripe),
                          width: EDGE_WIDTH,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
