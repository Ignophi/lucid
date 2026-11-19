import 'package:flutter/material.dart';
import 'package:hive_ce/hive.dart';
import 'package:intl/intl.dart' show DateFormat;

import 'package:lucid/achievement_badge.dart';
import 'package:lucid/achievements.dart';
import 'package:lucid/breath_colors.dart';
import 'package:lucid/session_files.dart';
import 'package:lucid/theme.dart';
import 'package:lucid/l10n/generated/app_localizations.dart';

/// The Achievements page (beta): how many badges are earned, the latest
/// ones, and every achievement by group with its level and progress. Tap one
/// for its levels and when each was reached.
class AchievementsWidget extends StatelessWidget {
  const AchievementsWidget({super.key, required this.sessions, this.drawer});

  final Box sessions;
  final Widget? drawer; // the side menu, when shown as a main section

  @override
  Widget build(BuildContext context) {
    AppLocalizations l10n = AppLocalizations.of(context);
    ThemeData theme = Theme.of(context);
    List<AchievementStatus> statuses = computeAchievements(
      storedSessions(sessions),
    );
    List<EarnedLevel> levels = earnedLevels(statuses);
    int total = ACHIEVEMENTS.fold(0, (sum, a) => sum + a.tiers.length);

    return Scaffold(
      drawer: drawer,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.achievements),
            const SizedBox(width: 10.0),
            const BetaChip(),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 24.0),
        children: [
          _summary(context, levels.length, total),
          if (levels.isNotEmpty) _recent(context, levels.take(10).toList()),
          for (AchievementGroup group in AchievementGroup.values) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(4.0, 18.0, 4.0, 8.0),
              child: Text(
                groupName(l10n, group),
                style: theme.textTheme.titleMedium,
              ),
            ),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisExtent: 156.0,
                crossAxisSpacing: 8.0,
                mainAxisSpacing: 8.0,
              ),
              itemCount: statuses
                  .where((s) => s.achievement.group == group)
                  .length,
              itemBuilder: (context, i) => _AchievementTile(
                status: statuses
                    .where((s) => s.achievement.group == group)
                    .elementAt(i),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _summary(BuildContext context, int earned, int total) {
    AppLocalizations l10n = AppLocalizations.of(context);
    ThemeData theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            SizedBox(
              width: 68.0,
              height: 68.0,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: total == 0 ? 0 : earned / total,
                    strokeWidth: 6.0,
                    strokeCap: StrokeCap.round,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  ),
                  Center(
                    child: Icon(
                      Icons.emoji_events_rounded,
                      size: 30.0,
                      color: levelColor(3),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16.0),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "$earned / $total ${l10n.badgesUnit}",
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4.0),
                  Text(
                    earned == 0 ? l10n.firstBadgeHint : l10n.achievementsBeta,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _recent(BuildContext context, List<EarnedLevel> levels) {
    AppLocalizations l10n = AppLocalizations.of(context);
    ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 12.0),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16.0, 14.0, 0.0, 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.recentlyEarned, style: theme.textTheme.titleMedium),
              const SizedBox(height: 12.0),
              SizedBox(
                height: 118.0,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: levels.length,
                  separatorBuilder: (context, i) => const SizedBox(width: 14.0),
                  itemBuilder: (context, i) {
                    EarnedLevel level = levels[i];
                    return SizedBox(
                      width: 76.0,
                      child: Column(
                        children: [
                          AchievementBadge(
                            achievement: level.achievement,
                            level: level.level,
                            size: 56.0,
                          ),
                          const SizedBox(height: 10.0),
                          Text(
                            achievementName(l10n, level.achievement.id),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.labelMedium,
                          ),
                          Text(
                            DateFormat.MMMd().format(level.date),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A small "Beta" label.
class BetaChip extends StatelessWidget {
  const BetaChip({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
      decoration: BoxDecoration(
        color: tintColor(context, HOLD_IN_COLOR, 0.35),
        borderRadius: BorderRadius.circular(10.0),
        border: edgeBorder(context, HOLD_IN_COLOR),
      ),
      child: Text(
        AppLocalizations.of(context).beta,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: tintTextColor(context, HOLD_IN_COLOR),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// One achievement in the grid: badge, name and progress to the next level.
class _AchievementTile extends StatelessWidget {
  const _AchievementTile({required this.status});

  final AchievementStatus status;

  @override
  Widget build(BuildContext context) {
    AppLocalizations l10n = AppLocalizations.of(context);
    ThemeData theme = Theme.of(context);
    Achievement achievement = status.achievement;
    bool recent =
        status.earned.isNotEmpty &&
        DateTime.now().difference(status.earned.last).inDays < 7;
    Color color = groupColor(achievement.group);

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: Key("achievement-${achievement.id}"),
        onTap: () => showAchievementDetails(context, status),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8.0, 12.0, 8.0, 10.0),
          child: Column(
            children: [
              AchievementBadge(achievement: achievement, level: status.level),
              const SizedBox(height: 10.0),
              Text(
                achievementName(l10n, achievement.id),
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge?.copyWith(height: 1.15),
              ),
              const Spacer(),
              if (recent)
                Text(
                  l10n.newBadge,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                )
              else
                Text(
                  status.complete
                      ? l10n.complete
                      : "${status.value} / ${status.next}",
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              const SizedBox(height: 4.0),
              _ProgressBar(value: status.progress, color: color),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.value, required this.color});

  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 5.0,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(3.0),
        border: lineBorder(context),
      ),
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: value.clamp(0.0, 1.0),
        heightFactor: 1.0,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3.0),
            border: edgeBorder(context, color),
          ),
        ),
      ),
    );
  }
}

/// An achievement's levels: the value needed for each, and when it was
/// reached.
Future<void> showAchievementDetails(
  BuildContext context,
  AchievementStatus status,
) {
  AppLocalizations l10n = AppLocalizations.of(context);
  ThemeData theme = Theme.of(context);
  Achievement achievement = status.achievement;
  String unit = achievementUnit(l10n, achievement.id);
  return showModalBottomSheet(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24.0, 0.0, 24.0, 24.0),
        child: Column(
          children: [
            AchievementBadge(
              achievement: achievement,
              level: status.level,
              size: 96.0,
            ),
            const SizedBox(height: 16.0),
            Text(
              achievementName(l10n, achievement.id),
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 4.0),
            Text(
              achievementWhat(l10n, achievement.id),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6.0),
            Text(
              "${l10n.soFar}: ${status.value} $unit",
              style: theme.textTheme.labelLarge,
            ),
            const Divider(height: 28.0),
            for (int i = 0; i < achievement.tiers.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5.0),
                child: Row(
                  children: [
                    Container(
                      width: 30.0,
                      height: 30.0,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i < status.level
                            ? levelColor(i + 1)
                            : theme.colorScheme.surfaceContainerHighest,
                        border: i < status.level
                            ? edgeBorder(context, levelColor(i + 1))
                            : lineBorder(context),
                      ),
                      child: Text(
                        roman(i + 1),
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: i < status.level
                              ? Color.lerp(levelColor(i + 1), Colors.black, 0.6)
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14.0),
                    Expanded(
                      child: Text(
                        "${achievement.tiers[i]} $unit",
                        style: theme.textTheme.bodyLarge,
                      ),
                    ),
                    Text(
                      i < status.level
                          ? DateFormat.yMMMd().format(status.earned[i])
                          : l10n.notYet,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

// --- celebrating new badges ------------------------------------------------

const String _seenKey = "achievementsSeen";

List<EarnedLevel> _currentLevels(Box sessions) =>
    earnedLevels(computeAchievements(storedSessions(sessions)));

/// The first time: counts every badge already earned from the history as
/// seen, so only new ones are celebrated.
Future<void> initAchievementsSeen(Box settings, Box sessions) async {
  if (settings.get(_seenKey) is List) return;
  await settings.put(_seenKey, [
    for (EarnedLevel level in _currentLevels(sessions)) level.id,
  ]);
}

/// After a session: shows the badges it earned, if any.
Future<void> celebrateNewAchievements(
  BuildContext context,
  Box settings,
  Box sessions,
) async {
  List<EarnedLevel> levels = _currentLevels(sessions);
  Object? seen = settings.get(_seenKey);
  // Saved in the background (the value is available right away)
  settings.put(_seenKey, [for (EarnedLevel level in levels) level.id]);
  if (seen is! List) return;
  List<EarnedLevel> fresh = newLevels(levels, seen.whereType<String>());
  if (fresh.isEmpty || !context.mounted) return;
  await showDialog(
    context: context,
    builder: (context) => _Celebration(levels: fresh),
  );
}

class _Celebration extends StatelessWidget {
  const _Celebration({required this.levels});

  final List<EarnedLevel> levels;

  @override
  Widget build(BuildContext context) {
    AppLocalizations l10n = AppLocalizations.of(context);
    ThemeData theme = Theme.of(context);
    List<EarnedLevel> shown = levels.take(3).toList();
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24.0, 28.0, 24.0, 16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              levels.length == 1 ? l10n.newAchievement : l10n.newAchievements,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 22.0),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 18.0,
              runSpacing: 18.0,
              children: [
                for (int i = 0; i < shown.length; i++)
                  // Each badge pops in, one after the other
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: Duration(milliseconds: 700 + 200 * i),
                    curve: Curves.elasticOut,
                    builder: (context, t, child) =>
                        Transform.scale(scale: 0.3 + 0.7 * t, child: child),
                    child: SizedBox(
                      width: 92.0,
                      child: Column(
                        children: [
                          AchievementBadge(
                            achievement: shown[i].achievement,
                            level: shown[i].level,
                            size: shown.length == 1 ? 96.0 : 72.0,
                          ),
                          const SizedBox(height: 12.0),
                          Text(
                            achievementName(l10n, shown[i].achievement.id),
                            textAlign: TextAlign.center,
                            style: theme.textTheme.labelLarge,
                          ),
                          Text(
                            "${shown[i].achievement.tiers[shown[i].level - 1]} "
                            "${achievementUnit(l10n, shown[i].achievement.id)}",
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            if (levels.length > shown.length) ...[
              const SizedBox(height: 12.0),
              Text(
                "+${levels.length - shown.length}",
                style: theme.textTheme.labelLarge,
              ),
            ],
            const SizedBox(height: 20.0),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.nice),
            ),
          ],
        ),
      ),
    );
  }
}
