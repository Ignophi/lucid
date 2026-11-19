import 'package:flutter/material.dart';
import 'package:hive_ce/hive.dart';

import 'package:lucid/achievements_widget.dart';
import 'package:lucid/analytics_widget.dart';
import 'package:lucid/backup_widget.dart';
import 'package:lucid/constants.dart';
import 'package:lucid/hive_storage.dart';
import 'package:lucid/home_widget.dart';
import 'package:lucid/preferences_widget.dart';
import 'package:lucid/measure_settings.dart';
import 'package:lucid/measurements_widget.dart';
import 'package:lucid/reminder_settings.dart';
import 'package:lucid/reminders.dart';
import 'package:lucid/reminders_widget.dart';
import 'package:lucid/session_files.dart';
import 'package:lucid/session_review_widget.dart';
import 'package:lucid/sessions_calendar_widget.dart';
import 'package:lucid/sessions_widget.dart';
import 'package:lucid/l10n/generated/app_localizations.dart';

/// The main sections, switched from the side menu.
enum AppSection { calendar, sessions, analytics, achievements }

/// The app's root: shows one section at a time (Calendar first) with the side
/// menu on each, and runs the Meditate flow.
class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.appName,
    required this.version,
    required this.preferences,
    required this.sessions,
    required this.settings,
  });

  final String appName, version;
  final Box preferences, sessions;
  final Box settings; // app settings, e.g. reminders

  // These static variables are used with flutter tests
  static const String keyCalendar = "Calendar",
      keySessions = "Sessions",
      keyAnalytics = "Analytics",
      keyAchievements = "Achievements",
      keyPreferences = "Preferences",
      keyReminders = "Reminders",
      keyMeasurements = "Measurements",
      keyBackup = "Backup";

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  AppSection _section = AppSection.calendar;
  // Bumped to rebuild the section from the stored sessions after changes
  int _refresh = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Reminders need the translated texts, available after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateReminders();
      Backup.auto(widget.settings, widget.sessions); // at most once a day
      initAchievementsSeen(widget.settings, widget.sessions);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Back in the app: maybe a new day, or sessions changed
    if (state == AppLifecycleState.resumed) {
      _updateReminders();
    }
  }

  /// Reschedules the daily reminders (e.g. none today once the goal is met).
  Future<void> _updateReminders() async {
    if (!mounted) return;
    AppLocalizations l10n = AppLocalizations.of(context);
    ReminderSettings reminders = Reminders.load(widget.settings);
    await Reminders.update(
      settings: reminders,
      sessions: widget.sessions.values.cast<Session>(),
      title: l10n.reminderTitle,
      body: reminders.goalMinutes > 0
          ? l10n.reminderBodyGoal
          : l10n.reminderBody,
      channelName: l10n.reminderChannel,
    );
  }

  /// Meditate button: run a session, then open its review.
  Future<void> _meditate() async {
    MeasureSettings measure = MeasureSettings.load(widget.settings);
    Session? session = await Navigator.push<Session>(
      context,
      MaterialPageRoute(
        builder: (context) => HomeWidget(
          preferences: widget.preferences,
          sessions: widget.sessions,
          measureMotion: measure.motion,
          measureSound: measure.sound,
        ),
      ),
    );
    if (session != null && mounted) {
      await openSessionReview(context, session);
    }
    if (session != null && mounted) {
      // A cute card for any badge this session earned
      await celebrateNewAchievements(context, widget.settings, widget.sessions);
    }
    if (session != null) {
      Backup.auto(widget.settings, widget.sessions, always: true);
    }
    if (mounted) {
      setState(() {
        _refresh++; // show the new session
      });
      _updateReminders();
    }
  }

  void _select(BuildContext context, AppSection section) {
    Navigator.of(context).pop(); // close the menu
    if (section != _section) {
      setState(() {
        _section = section;
      });
      _updateReminders(); // sessions may have been imported or removed
    }
  }

  void _showWebDialog(String title, String url) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(AppLocalizations.of(context).openBrowser),
              const SizedBox(height: 10),
              SelectionArea(child: Text(url)),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  Widget _getDrawer(BuildContext context) {
    AppLocalizations l10n = AppLocalizations.of(context);
    ThemeData theme = Theme.of(context);
    return NavigationDrawer(
      selectedIndex: _section.index,
      onDestinationSelected: (int index) {
        _select(context, AppSection.values[index]);
      },
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(28.0, 20.0, 16.0, 16.0),
          child: Row(
            children: [
              Image.asset("images/launcher.png", width: 40.0, height: 40.0),
              const SizedBox(width: 12.0),
              Text(
                widget.appName,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        // Same order as AppSection
        NavigationDrawerDestination(
          key: const Key(AppShell.keyCalendar),
          icon: const Icon(Icons.calendar_month_outlined),
          selectedIcon: const Icon(Icons.calendar_month),
          label: Text(l10n.calendar),
        ),
        NavigationDrawerDestination(
          key: const Key(AppShell.keySessions),
          icon: const Icon(Icons.view_agenda_outlined),
          selectedIcon: const Icon(Icons.view_agenda),
          label: Text(l10n.sessions),
        ),
        NavigationDrawerDestination(
          key: const Key(AppShell.keyAnalytics),
          icon: const Icon(Icons.insights_outlined),
          selectedIcon: const Icon(Icons.insights),
          label: Text(l10n.analytics),
        ),
        NavigationDrawerDestination(
          key: const Key(AppShell.keyAchievements),
          icon: const Icon(Icons.emoji_events_outlined),
          selectedIcon: const Icon(Icons.emoji_events),
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.achievements),
              const SizedBox(width: 8.0),
              const BetaChip(),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 28.0),
          child: Divider(),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          child: ListTile(
            key: const Key(AppShell.keyPreferences),
            leading: const Icon(Icons.settings_outlined),
            title: Text(l10n.preferences),
            onTap: () async {
              Navigator.of(context).pop(); // close the menu
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PreferencesWidget(
                    preferences: widget.preferences,
                    settings: widget.settings,
                    callback: () {},
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          child: ListTile(
            key: const Key(AppShell.keyReminders),
            leading: const Icon(Icons.notifications_outlined),
            title: Text(l10n.reminders),
            onTap: () async {
              Navigator.of(context).pop(); // close the menu
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => RemindersWidget(
                    settings: widget.settings,
                    onChanged: _updateReminders,
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          child: ListTile(
            key: const Key(AppShell.keyMeasurements),
            leading: const Icon(Icons.sensors_rounded),
            title: Text(l10n.measurements),
            onTap: () async {
              Navigator.of(context).pop(); // close the menu
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      MeasurementsWidget(settings: widget.settings),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          child: ListTile(
            key: const Key(AppShell.keyBackup),
            leading: const Icon(Icons.backup_outlined),
            title: Text(l10n.backup),
            onTap: () async {
              Navigator.of(context).pop(); // close the menu
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BackupWidget(
                    settings: widget.settings,
                    sessions: widget.sessions,
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          child: SafeArea(
            top: false,
            child: AboutListTile(
              icon: const Icon(Icons.info_outline),
              applicationIcon: Image.asset(
                'images/launcher.png',
                width: 64.0,
                height: 64.0,
              ),
              applicationName: widget.appName,
              applicationVersion: widget.version,
              applicationLegalese: LICENSE_TEXT,
              aboutBoxChildren: [
                const SizedBox(height: 8.0),
                ListTile(
                  title: Text(l10n.help),
                  leading: const Icon(Icons.help_outline),
                  onTap: () {
                    _showWebDialog(l10n.help, REPO_URL);
                  },
                ),
                ListTile(
                  title: Text(l10n.reportIssue),
                  leading: const Icon(Icons.bug_report_outlined),
                  onTap: () {
                    _showWebDialog(l10n.reportIssue, BUGS_URL);
                  },
                ),
                ListTile(
                  title: const Text(BASED_ON_TEXT),
                  leading: const Icon(Icons.fork_right_rounded),
                  onTap: () {
                    _showWebDialog(BASED_ON_TEXT, BASED_ON_URL);
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _getSection(BuildContext context) {
    Widget drawer = _getDrawer(context);
    switch (_section) {
      case AppSection.calendar:
        return SessionsCalendarWidget(
          sessions: widget.sessions,
          drawer: drawer,
          onMeditate: _meditate,
        );
      case AppSection.sessions:
        return SessionsWidget(
          sessions: widget.sessions,
          drawer: drawer,
          onMeditate: _meditate,
        );
      case AppSection.analytics:
        return AnalyticsWidget(sessions: widget.sessions, drawer: drawer);
      case AppSection.achievements:
        return AchievementsWidget(sessions: widget.sessions, drawer: drawer);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Back from another section returns to the calendar
      canPop: _section == AppSection.calendar,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) {
          setState(() {
            _section = AppSection.calendar;
          });
        }
      },
      child: KeyedSubtree(
        key: ValueKey("${_section.name}-$_refresh"),
        child: _getSection(context),
      ),
    );
  }
}
