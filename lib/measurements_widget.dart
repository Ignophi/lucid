import 'package:flutter/material.dart';
import 'package:hive_ce/hive.dart';

import 'package:lucid/measure_settings.dart';
import 'package:lucid/session_recorder.dart';
import 'package:lucid/l10n/generated/app_localizations.dart';

/// Settings for the session measurements: motion (on by default) and sound
/// (off by default, asks for microphone access when turned on), with a note
/// on privacy and where to put the phone.
class MeasurementsWidget extends StatefulWidget {
  const MeasurementsWidget({super.key, required this.settings});

  final Box settings;

  // These static variables are used with flutter tests
  static const String keyMotion = "Measure Motion", keySound = "Measure Sound";

  @override
  State<MeasurementsWidget> createState() => _MeasurementsWidgetState();
}

class _MeasurementsWidgetState extends State<MeasurementsWidget> {
  late final MeasureSettings _measure;

  @override
  void initState() {
    super.initState();
    _measure = MeasureSettings.load(widget.settings);
  }

  Future<void> _change(void Function() change) async {
    setState(change);
    await _measure.save(widget.settings);
  }

  Future<void> _setSound(bool enabled) async {
    if (enabled && SessionRecorder.supported) {
      AppLocalizations l10n = AppLocalizations.of(context);
      ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
      bool allowed = await SessionRecorder.requestMicrophone();
      if (!allowed) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.microphoneBlocked)));
        return;
      }
    }
    await _change(() => _measure.sound = enabled);
  }

  Widget _tip(BuildContext context, IconData icon, String text) {
    ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20.0, color: theme.colorScheme.primary),
          const SizedBox(width: 12.0),
          Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    AppLocalizations l10n = AppLocalizations.of(context);
    ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.measurements)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(4.0, 8.0, 4.0, 24.0),
        children: [
          if (!SessionRecorder.supported)
            Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 4.0, 16.0, 8.0),
              child: Text(
                l10n.measureUnsupported,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  key: const Key(MeasurementsWidget.keyMotion),
                  secondary: const Icon(Icons.vibration_rounded),
                  title: Text(l10n.measureMotion),
                  subtitle: Text(l10n.measureMotionHint),
                  value: _measure.motion,
                  onChanged: (bool value) =>
                      _change(() => _measure.motion = value),
                ),
                SwitchListTile(
                  key: const Key(MeasurementsWidget.keySound),
                  secondary: Icon(
                    _measure.sound ? Icons.mic_rounded : Icons.mic_off_outlined,
                  ),
                  title: Text(l10n.measureSound),
                  subtitle: Text(l10n.measureSoundHint),
                  value: _measure.sound,
                  onChanged: _setSound,
                ),
              ],
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.lock_outline_rounded),
              title: Text(l10n.measurePrivacy),
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 14.0, 16.0, 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.phonePlacement, style: theme.textTheme.titleMedium),
                  _tip(
                    context,
                    Icons.airline_seat_flat_outlined,
                    l10n.placementLying,
                  ),
                  _tip(
                    context,
                    Icons.self_improvement_rounded,
                    l10n.placementSitting,
                  ),
                  _tip(
                    context,
                    Icons.directions_walk_rounded,
                    l10n.placementWalking,
                  ),
                ],
              ),
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 14.0, 16.0, 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.measuredCalm, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 6.0),
                  Text(l10n.calmExplained, style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 6.0),
                  Text(
                    l10n.typeFitExplained,
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
