// How achievements look: a round badge with an icon in the group's color,
// a ring in the level's color (bronze, silver, gold and beyond) and the level
// as a Roman numeral. Plus their names, descriptions, icons and colors.

import 'package:flutter/material.dart';

import 'package:lucid/achievements.dart';
import 'package:lucid/theme.dart';
import 'package:lucid/l10n/generated/app_localizations.dart';

IconData achievementIcon(String id) => switch (id) {
  A_SESSIONS => Icons.self_improvement_rounded,
  A_HOURS => Icons.hourglass_bottom_rounded,
  A_LONG => Icons.scuba_diving_rounded,
  A_STREAK => Icons.local_fire_department_rounded,
  A_DAYS => Icons.event_available_rounded,
  A_WEEKS => Icons.calendar_view_week_rounded,
  A_DAILY_SESSIONS => Icons.auto_awesome_rounded,
  A_DAILY_MINUTES => Icons.wb_sunny_rounded,
  A_EARLY => Icons.wb_twilight_rounded,
  A_NIGHT => Icons.bedtime_rounded,
  A_EXPLORER => Icons.explore_rounded,
  A_WALKER => Icons.hiking_rounded,
  A_REVIEWS => Icons.rate_review_rounded,
  A_JOURNAL => Icons.edit_note_rounded,
  A_TOP_SCORE => Icons.emoji_events_rounded,
  A_CALM => Icons.spa_rounded,
  A_STILL => Icons.landscape_rounded,
  A_QUIET => Icons.volume_mute_rounded,
  _ => Icons.star_rounded,
};

Color groupColor(AchievementGroup group) => switch (group) {
  AchievementGroup.milestones => const Color(0xFF5B8FC9), // sky blue
  AchievementGroup.consistency => const Color(0xFFE0A43B), // amber
  AchievementGroup.moments => const Color(0xFFA394D6), // lavender
  AchievementGroup.practice => const Color(0xFF6FB59A), // sage green
  AchievementGroup.mindfulness => const Color(0xFF4FA3A5), // teal
};

/// Ring color for each level: bronze, silver, gold, then gem colors.
const List<Color> LEVEL_COLORS = [
  Color(0xFFC78C5A), // bronze
  Color(0xFFA9B3C0), // silver
  Color(0xFFE1B84E), // gold
  Color(0xFF7FCBC8), // platinum
  Color(0xFF8FA6F0), // sapphire
  Color(0xFFB794E8), // amethyst
  Color(0xFF6FD3E8), // diamond
];

Color levelColor(int level) =>
    LEVEL_COLORS[(level - 1).clamp(0, LEVEL_COLORS.length - 1)];

String roman(int number) => const [
  "",
  "I",
  "II",
  "III",
  "IV",
  "V",
  "VI",
  "VII",
  "VIII",
  "IX",
  "X",
][number.clamp(0, 10)];

String groupName(AppLocalizations l10n, AchievementGroup group) =>
    switch (group) {
      AchievementGroup.milestones => l10n.milestones,
      AchievementGroup.consistency => l10n.consistency,
      AchievementGroup.moments => l10n.moments,
      AchievementGroup.practice => l10n.practice,
      AchievementGroup.mindfulness => l10n.mindfulness,
    };

String achievementName(AppLocalizations l10n, String id) => switch (id) {
  A_SESSIONS => l10n.achSessions,
  A_HOURS => l10n.achHours,
  A_LONG => l10n.achLong,
  A_STREAK => l10n.achStreak,
  A_DAYS => l10n.achDays,
  A_WEEKS => l10n.achWeeks,
  A_DAILY_SESSIONS => l10n.achDailySessions,
  A_DAILY_MINUTES => l10n.achDailyMinutes,
  A_EARLY => l10n.achEarly,
  A_NIGHT => l10n.achNight,
  A_EXPLORER => l10n.achExplorer,
  A_WALKER => l10n.achWalker,
  A_REVIEWS => l10n.achReviews,
  A_JOURNAL => l10n.achJournal,
  A_TOP_SCORE => l10n.achTopScore,
  A_CALM => l10n.achCalm,
  A_STILL => l10n.achStill,
  A_QUIET => l10n.achQuiet,
  _ => id,
};

/// What is counted, e.g. "Days in a row".
String achievementWhat(AppLocalizations l10n, String id) => switch (id) {
  A_SESSIONS => l10n.achSessionsWhat,
  A_HOURS => l10n.achHoursWhat,
  A_LONG => l10n.achLongWhat,
  A_STREAK => l10n.achStreakWhat,
  A_DAYS => l10n.achDaysWhat,
  A_WEEKS => l10n.achWeeksWhat,
  A_DAILY_SESSIONS => l10n.achDailySessionsWhat,
  A_DAILY_MINUTES => l10n.achDailyMinutesWhat,
  A_EARLY => l10n.achEarlyWhat,
  A_NIGHT => l10n.achNightWhat,
  A_EXPLORER => l10n.achExplorerWhat,
  A_WALKER => l10n.achWalkerWhat,
  A_REVIEWS => l10n.achReviewsWhat,
  A_JOURNAL => l10n.achJournalWhat,
  A_TOP_SCORE => l10n.achTopScoreWhat,
  A_CALM => l10n.achCalmWhat,
  A_STILL => l10n.achStillWhat,
  A_QUIET => l10n.achQuietWhat,
  _ => "",
};

/// The unit of the counted value, e.g. "days".
String achievementUnit(AppLocalizations l10n, String id) => switch (id) {
  A_HOURS => l10n.hoursUnit,
  A_LONG || A_DAILY_MINUTES => l10n.minutesShort,
  A_STREAK || A_DAYS => l10n.daysUnit,
  A_WEEKS => l10n.weeksUnit,
  A_EXPLORER => l10n.typesUnit,
  _ => l10n.sessionsUnit,
};

/// The badge of [achievement] at [level] (0: not earned yet).
class AchievementBadge extends StatelessWidget {
  const AchievementBadge({
    super.key,
    required this.achievement,
    required this.level,
    this.size = 64.0,
  });

  final Achievement achievement;
  final int level;
  final double size;

  @override
  Widget build(BuildContext context) {
    ColorScheme colors = Theme.of(context).colorScheme;
    bool locked = level <= 0;
    bool complete = level >= achievement.tiers.length;
    Color group = groupColor(achievement.group);
    Color metal = locked ? colors.surfaceContainerHighest : levelColor(level);
    Color light(Color c, double t) => Color.lerp(c, Colors.white, t)!;
    Color dark(Color c, double t) => Color.lerp(c, Colors.black, t)!;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // The ring, in the level's color
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: locked ? metal : null,
                gradient: locked
                    ? null
                    : LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [light(metal, 0.45), metal, dark(metal, 0.18)],
                      ),
                border: locked
                    ? lineBorder(context)
                    : edgeBorder(context, metal),
                boxShadow: locked
                    ? null
                    : [
                        BoxShadow(
                          color: group.withValues(alpha: 0.25),
                          blurRadius: size * 0.12,
                        ),
                      ],
              ),
            ),
          ),
          // The face, in the group's color, with the icon
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.all(size * 0.09),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: locked ? colors.surfaceContainerLow : null,
                  gradient: locked
                      ? null
                      : RadialGradient(
                          center: const Alignment(-0.3, -0.4),
                          colors: [
                            light(group, 0.35),
                            group,
                            dark(group, 0.12),
                          ],
                        ),
                  border: locked
                      ? lineBorder(context)
                      : edgeBorder(context, group),
                ),
                child: Icon(
                  achievementIcon(achievement.id),
                  size: size * 0.44,
                  color: locked
                      ? colors.onSurfaceVariant.withValues(alpha: 0.45)
                      : Colors.white,
                ),
              ),
            ),
          ),
          // The level, as a Roman numeral
          if (!locked)
            Positioned(
              left: 0,
              right: 0,
              bottom: -size * 0.06,
              child: Center(
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: size * 0.08,
                    vertical: size * 0.01,
                  ),
                  decoration: BoxDecoration(
                    color: metal,
                    borderRadius: BorderRadius.circular(size * 0.12),
                    border: edgeBorder(context, metal),
                  ),
                  child: Text(
                    roman(level),
                    style: TextStyle(
                      fontSize: size * 0.15,
                      fontWeight: FontWeight.w800,
                      color: dark(metal, 0.6),
                      height: 1.2,
                    ),
                  ),
                ),
              ),
            ),
          // A sparkle when every level is reached
          if (complete)
            Positioned(
              top: -size * 0.04,
              right: -size * 0.04,
              child: Icon(
                Icons.auto_awesome,
                size: size * 0.3,
                color: dark(metal, 0.1),
              ),
            ),
          // A small lock while not earned yet
          if (locked)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                padding: EdgeInsets.all(size * 0.04),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.surfaceContainerHighest,
                  border: lineBorder(context),
                ),
                child: Icon(
                  Icons.lock_rounded,
                  size: size * 0.16,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
