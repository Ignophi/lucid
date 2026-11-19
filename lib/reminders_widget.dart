import 'package:flutter/material.dart';
import 'package:hive_ce/hive.dart';

import 'package:lucid/analytics.dart';
import 'package:lucid/reminder_settings.dart';
import 'package:lucid/reminders.dart';
import 'package:lucid/l10n/generated/app_localizations.dart';

/// Settings for the daily meditation reminders: when the first one comes,
/// how often and how many, and the daily goal after which they stop.
class RemindersWidget extends StatefulWidget {
  const RemindersWidget({
    super.key,
    required this.settings,
    required this.onChanged,
  });

  final Box settings;

  /// Called after every change, to reschedule the reminders.
  final Future<void> Function() onChanged;

  // These static variables are used with flutter tests
  static const String keyEnabled = "Reminders Enabled";

  @override
  State<RemindersWidget> createState() => _RemindersWidgetState();
}

class _RemindersWidgetState extends State<RemindersWidget> {
  late final ReminderSettings _reminders;

  @override
  void initState() {
    super.initState();
    _reminders = Reminders.load(widget.settings);
  }

  Future<void> _change(void Function() change) async {
    setState(change);
    await Reminders.save(widget.settings, _reminders);
    await widget.onChanged();
  }

  Future<void> _setEnabled(bool enabled) async {
    AppLocalizations l10n = AppLocalizations.of(context);
    ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    if (enabled && Reminders.supported) {
      bool allowed = await Reminders.requestPermission();
      if (!allowed) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.notificationsBlocked)),
        );
      }
    }
    await _change(() => _reminders.enabled = enabled);
  }

  String _time(int minutes) {
    return MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );
  }

  Future<void> _pickFirstTime() async {
    TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: _reminders.firstMinutes ~/ 60,
        minute: _reminders.firstMinutes % 60,
      ),
    );
    if (picked != null) {
      await _change(
        () => _reminders.firstMinutes = picked.hour * 60 + picked.minute,
      );
    }
  }

  String _summary(AppLocalizations l10n) {
    List<int> times = _reminders.times;
    String goal = _reminders.goalMinutes > 0
        ? " ${formatMinutes(_reminders.goalMinutes.toDouble())}"
        : "";
    return "${l10n.remindersAt} ${times.map(_time).join(", ")}.\n"
        "${l10n.stopsOnceMeditated}$goal.";
  }

  @override
  Widget build(BuildContext context) {
    AppLocalizations l10n = AppLocalizations.of(context);
    ThemeData theme = Theme.of(context);
    bool on = _reminders.enabled;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.reminders)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(4.0, 8.0, 4.0, 24.0),
        children: [
          Card(
            child: SwitchListTile(
              key: const Key(RemindersWidget.keyEnabled),
              secondary: const Icon(Icons.notifications_outlined),
              title: Text(l10n.dailyReminders),
              subtitle: Text(l10n.remindersHint),
              value: on,
              onChanged: _setEnabled,
            ),
          ),
          Card(
            child: Column(
              children: [
                ListTile(
                  enabled: on,
                  leading: const Icon(Icons.schedule),
                  title: Text(l10n.firstReminder),
                  trailing: Text(
                    _time(_reminders.firstMinutes),
                    style: theme.textTheme.titleMedium,
                  ),
                  onTap: _pickFirstTime,
                ),
                ListTile(
                  enabled: on,
                  leading: const Icon(Icons.repeat),
                  title: Text(l10n.remindEvery),
                  trailing: DropdownButton<int>(
                    value:
                        REMINDER_INTERVALS.contains(_reminders.intervalMinutes)
                        ? _reminders.intervalMinutes
                        : null,
                    underline: const SizedBox.shrink(),
                    items: [
                      for (int minutes in REMINDER_INTERVALS)
                        DropdownMenuItem<int>(
                          value: minutes,
                          child: Text(formatMinutes(minutes.toDouble())),
                        ),
                    ],
                    onChanged: on
                        ? (int? value) {
                            if (value != null) {
                              _change(() => _reminders.intervalMinutes = value);
                            }
                          }
                        : null,
                  ),
                ),
                ListTile(
                  enabled: on,
                  leading: const Icon(Icons.notifications_active_outlined),
                  title: Text(l10n.remindersPerDay),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_rounded),
                        onPressed: on && _reminders.count > 1
                            ? () => _change(() => _reminders.count--)
                            : null,
                      ),
                      Text(
                        "${_reminders.count}",
                        style: theme.textTheme.titleMedium,
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_rounded),
                        onPressed: on && _reminders.count < REMINDERS_MAX
                            ? () => _change(() => _reminders.count++)
                            : null,
                      ),
                    ],
                  ),
                ),
                ListTile(
                  enabled: on,
                  leading: const Icon(Icons.flag_outlined),
                  title: Text(l10n.dailyGoal),
                  subtitle: Text(l10n.dailyGoalHint),
                  trailing: DropdownButton<int>(
                    value: REMINDER_GOALS.contains(_reminders.goalMinutes)
                        ? _reminders.goalMinutes
                        : null,
                    underline: const SizedBox.shrink(),
                    items: [
                      for (int minutes in REMINDER_GOALS)
                        DropdownMenuItem<int>(
                          value: minutes,
                          child: Text(
                            minutes == 0
                                ? l10n.anySession
                                : formatMinutes(minutes.toDouble()),
                          ),
                        ),
                    ],
                    onChanged: on
                        ? (int? value) {
                            if (value != null) {
                              _change(() => _reminders.goalMinutes = value);
                            }
                          }
                        : null,
                  ),
                ),
              ],
            ),
          ),
          if (on)
            Padding(
              padding: const EdgeInsets.fromLTRB(20.0, 12.0, 20.0, 4.0),
              child: Text(
                _summary(l10n),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 0.0),
            child: OutlinedButton.icon(
              icon: const Icon(Icons.notifications_outlined),
              label: Text(l10n.sendTestReminder),
              onPressed: () async {
                // Android 13+ needs permission before any notification shows
                await Reminders.requestPermission();
                await Reminders.showTest(
                  title: l10n.reminderTitle,
                  body: l10n.reminderBody,
                  channelName: l10n.reminderChannel,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
