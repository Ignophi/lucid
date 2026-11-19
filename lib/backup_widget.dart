import 'package:flutter/material.dart';
import 'package:hive_ce/hive.dart';
import 'package:intl/intl.dart' show DateFormat;

import 'package:lucid/session_files.dart';
import 'package:lucid/l10n/generated/app_localizations.dart';

/// The automatic backup: on/off, when the last one was made, and a button to
/// back up now. Backups go to Download/Lucid, one file per month; restore
/// one with Import in Sessions.
class BackupWidget extends StatefulWidget {
  const BackupWidget({
    super.key,
    required this.settings,
    required this.sessions,
  });

  final Box settings, sessions;

  // These static variables are used with flutter tests
  static const String keyEnabled = "Backup Enabled", keyNow = "Backup Now";

  @override
  State<BackupWidget> createState() => _BackupWidgetState();
}

class _BackupWidgetState extends State<BackupWidget> {
  bool _saving = false;

  Future<void> _setEnabled(bool enabled) async {
    await Backup.setEnabled(widget.settings, enabled);
    setState(() {});
    if (enabled) {
      await Backup.auto(widget.settings, widget.sessions);
      if (mounted) setState(() {});
    }
  }

  Future<void> _backUpNow() async {
    AppLocalizations l10n = AppLocalizations.of(context);
    ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    String? path = await Backup.save(widget.settings, widget.sessions);
    if (!mounted) return;
    setState(() => _saving = false);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          path != null
              ? "${l10n.backedUpTo}: $path"
              : storedSessions(widget.sessions).isEmpty
              ? l10n.noSessionsYet
              : l10n.backupFailed,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    AppLocalizations l10n = AppLocalizations.of(context);
    ThemeData theme = Theme.of(context);
    bool enabled = Backup.isEnabled(widget.settings);
    DateTime? last = Backup.lastTime(widget.settings);
    String? path = Backup.lastPath(widget.settings);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.backup)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(4.0, 8.0, 4.0, 24.0),
        children: [
          Card(
            child: SwitchListTile(
              key: const Key(BackupWidget.keyEnabled),
              secondary: const Icon(Icons.backup_outlined),
              title: Text(l10n.automaticBackup),
              subtitle: Text(l10n.automaticBackupHint),
              value: enabled,
              onChanged: _setEnabled,
            ),
          ),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.history_rounded),
                  title: Text(l10n.lastBackup),
                  subtitle: path == null ? null : Text(path),
                  trailing: Text(
                    last == null
                        ? l10n.never
                        : DateFormat.MMMd().add_jm().format(last),
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 16.0),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonalIcon(
                      key: const Key(BackupWidget.keyNow),
                      onPressed: _saving ? null : _backUpNow,
                      icon: const Icon(Icons.save_alt_rounded),
                      label: Text(l10n.backUpNow),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.restore_rounded),
              title: Text(l10n.restoreHint),
            ),
          ),
        ],
      ),
    );
  }
}
