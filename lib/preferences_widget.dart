import 'package:flutter/material.dart';
import 'package:hive_ce/hive.dart';
import 'package:audioplayers/audioplayers.dart';

import 'package:lucid/breath_colors.dart';
import 'package:lucid/breath_wave.dart';
import 'package:lucid/breathing.dart';
import 'package:lucid/constants.dart';
import 'package:lucid/format.dart';
import 'package:lucid/hive_storage.dart';
import 'package:lucid/programs.dart';
import 'package:lucid/theme.dart';
import 'package:lucid/utils.dart';
import 'package:lucid/l10n/generated/app_localizations.dart';

/// The session settings, in cards like the rest of the app: breathing
/// programs to choose from (and your own, saved with the + card), your
/// session (name and its breathing wave), duration, breathing, sounds,
/// vibration and voice. Every change is saved right away.
class PreferencesWidget extends StatefulWidget {
  const PreferencesWidget({
    super.key,
    required this.preferences,
    required this.settings,
    required this.callback,
  });

  final Box preferences, settings;
  final dynamic callback;

  // These static variables are used with flutter tests
  static int maxDurationMinutes = 120,
      maxDurationSeconds = 59,
      maxVibration = 100,
      minBreath = 5,
      maxInhale = 150,
      maxExhale = 300,
      maxHold = 100;
  static String keyMenu = "Menu",
      keyPreferenceName = "Preference Name",
      keySaveProgram = "Save Program",
      keyProgramName = "Program Name",
      keySaveProgramConfirm = "Save Program Confirm";

  @override
  State<PreferencesWidget> createState() => _PreferencesWidgetState();
}

class _PreferencesWidgetState extends State<PreferencesWidget> {
  late double _durationMinutes = 0.0,
      _durationSeconds = 0.0,
      _vibrateDurationD = 0.0,
      _vibrateBreathD = 0.0;
  late bool _durationTts = false, _breathTts = false;
  List<Program> _myPrograms = [];
  final TextEditingController _textEditingController = TextEditingController();

  late final AudioPlayer _player = AudioPlayer();

  @override
  initState() {
    debugPrint("$widget.initState");
    _init();
    super.initState();
  }

  @override
  void dispose() {
    debugPrint("$widget.dispose");
    _player.dispose();
    _textEditingController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    // Create default preference
    if (widget.preferences.isEmpty) {
      await createDefaultPref(widget.preferences);
    }
    Preference preference = widget.preferences.getAt(0);

    setState(() {
      _myPrograms = MyPrograms.load(widget.settings);
      Duration duration = Duration(seconds: preference.duration);
      _durationMinutes = duration.inMinutes.toDouble();
      _durationSeconds = (duration.inSeconds % Duration.secondsPerMinute)
          .toDouble();
      _vibrateDurationD = preference.vibrateDuration.toDouble() / 10;
      _vibrateBreathD = preference.vibrateBreath.toDouble() / 10;
      _durationTts = preference.durationTts;
      _breathTts = preference.breathTts;
      _textEditingController.text = preference.name;
    });
  }

  /// Uses [program]: its breathing pattern, duration and name. Sounds,
  /// vibration and voice stay as they are.
  void _useProgram(Program program) {
    Preference preference = widget.preferences.getAt(0);
    preference.inhale = List.of(program.inhale);
    preference.exhale = List.of(program.exhale);
    preference.duration = program.duration;
    preference.name = program.name(AppLocalizations.of(context));
    preference.save();
    widget.callback();
    _init();
  }

  /// Back to the default settings, without your own programs.
  Future<void> _resetAll() async {
    Preference preference = widget.preferences.getAt(0);
    preference.copy(Preference.getDefaultPref());
    await preference.save();
    await MyPrograms.clear(widget.settings);
    widget.callback();
    _init();
  }

  /// "+" card: saves the current pattern, duration and name as a program.
  Future<void> _saveAsProgram() async {
    AppLocalizations l10n = AppLocalizations.of(context);
    Preference preference = widget.preferences.getAt(0);
    TextEditingController name = TextEditingController(text: preference.name);
    String? chosen = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.saveAsProgram),
        content: TextField(
          key: Key(PreferencesWidget.keyProgramName),
          controller: name,
          autofocus: true,
          maxLength: 32,
          decoration: InputDecoration(labelText: l10n.programName),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            key: Key(PreferencesWidget.keySaveProgramConfirm),
            onPressed: () => Navigator.of(context).pop(name.text.trim()),
            child: Text(l10n.save),
          ),
        ],
      ),
    );
    name.dispose();
    if (chosen == null || !mounted) return;
    if (chosen.isEmpty) {
      chosen = "${l10n.program} ${_myPrograms.length + 1}";
    }
    preference.name = chosen;
    await preference.save();
    await MyPrograms.add(
      widget.settings,
      name: chosen,
      inhale: preference.inhale,
      exhale: preference.exhale,
      duration: preference.duration,
    );
    widget.callback();
    await _init();
    if (mounted) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(l10n.programSaved)));
    }
  }

  /// Long press on one of your own programs: delete it (after asking).
  void _confirmDelete(Program program) {
    AppLocalizations l10n = AppLocalizations.of(context);
    showAlertDialog(context, l10n.deleteProgram, program.name(l10n), () async {
      Navigator.of(context).pop();
      await MyPrograms.remove(widget.settings, program.key);
      await _init();
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(content: Text(l10n.programDeleted)));
      }
    });
  }

  void _confirmResetAll() {
    AppLocalizations l10n = AppLocalizations.of(context);
    showAlertDialog(context, l10n.resetAll, l10n.resetAllPreferences, () {
      _resetAll();
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(l10n.preferencesReset)));
    });
  }

  // --- building blocks -----------------------------------------------------

  /// A card with an icon and title, like the other settings screens.
  Widget _section({
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    ThemeData theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16.0, 14.0, 16.0, 10.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, size: 20.0, color: theme.colorScheme.primary),
                const SizedBox(width: 10.0),
                Text(title, style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 4.0),
            ...children,
          ],
        ),
      ),
    );
  }

  /// A small sub-heading inside a card (e.g. Inhale, Exhale).
  Widget _subheading(String text) {
    ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 10.0, bottom: 2.0),
      child: Text(
        text.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          letterSpacing: 1.0,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  /// The value of a setting, in a small pill with a thin edge.
  Widget _valuePill(String text) {
    ColorScheme colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 3.0),
      decoration: BoxDecoration(
        color: colors.secondaryContainer,
        borderRadius: BorderRadius.circular(12.0),
        border: edgeBorder(context, colors.secondaryContainer),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: colors.onSecondaryContainer,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  /// A small dot in a part's color, next to its label.
  Widget _dot(Color color) => Container(
    width: 10.0,
    height: 10.0,
    margin: const EdgeInsets.only(right: 8.0),
    decoration: BoxDecoration(
      color: color,
      shape: BoxShape.circle,
      border: edgeBorder(context, color),
    ),
  );

  /// A label with its value on the right, and a slider under them.
  Widget _sliderRow(String label, String value, Widget slider, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (color != null) _dot(color),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
              _valuePill(value),
            ],
          ),
          slider,
        ],
      ),
    );
  }

  /// One part of a breath (e.g. inhale hold): a slider in tenths of a
  /// second (stored in milliseconds in [lengths]).
  Widget _breathSetting(
    Preference preference,
    String keyText,
    String label,
    BreathPhase phase,
    int min,
    int max,
  ) {
    List<int> lengths = phase.index < 3 ? preference.inhale : preference.exhale;
    int index = phase.index % 3;
    int tenths(double value) => value.round() * 100;
    // The drag range of the inhale and exhale sliders starts at [min]
    int divisions = min > 0 ? max - min + 1 : max + 1;
    // Each part's slider in its color, as in the breathing wave
    Color color = phaseColor(phase);
    return _sliderRow(
      label,
      "${lengths[index] / Duration.millisecondsPerSecond} s",
      color: color,
      SliderTheme(
        data: SliderTheme.of(context).copyWith(
          activeTrackColor: color,
          thumbColor: color,
          inactiveTrackColor: color.withValues(alpha: 0.22),
          overlayColor: color.withValues(alpha: 0.12),
        ),
        child: Slider(
          key: Key(keyText),
          value: (lengths[index] / 100).clamp(min, max).toDouble(),
          min: min.toDouble(),
          max: max.toDouble(),
          divisions: divisions,
          onChanged: (double value) {
            setState(() {
              lengths[index] = tenths(value);
            });
          },
          onChangeEnd: (double value) {
            setState(() {
              lengths[index] = tenths(value);
              preference.save();
            });
          },
        ),
      ),
    );
  }

  /// The sound played at the start of a part of a breath.
  Widget _audioSetting(
    Preference preference,
    String keyText,
    String label,
    int index,
    BreathPhase phase,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          _dot(phaseColor(phase)),
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyLarge),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(12.0, 6.0, 6.0, 6.0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14.0),
              border: Border.all(
                color: lineColor(context),
                width: OUTLINE_WIDTH,
              ),
            ),
            child: DropdownButton<String>(
              key: Key(keyText),
              value: preference.audio[index],
              underline: const SizedBox.shrink(),
              isDense: true,
              borderRadius: BorderRadius.circular(14.0),
              icon: const Icon(Icons.expand_more_rounded),
              onChanged: (String? value) {
                if (value == null) return;
                setState(() {
                  preference.audio[index] = value;
                  preference.save();
                });
                play(_player, value);
              },
              items: [
                for (String audio in const [
                  AUDIO_NONE,
                  AUDIO_TONE1,
                  AUDIO_TONE2,
                  AUDIO_TONE3,
                  AUDIO_TONE4,
                ])
                  DropdownMenuItem<String>(value: audio, child: Text(audio)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// The last card in the programs grid: save the current settings as a
  /// program of your own.
  Widget _addProgramCard() {
    AppLocalizations l10n = AppLocalizations.of(context);
    ColorScheme colors = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18.0),
        side: BorderSide(color: lineColor(context), width: OUTLINE_WIDTH * 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: Key(PreferencesWidget.keySaveProgram),
        onTap: _saveAsProgram,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 44.0,
                height: 44.0,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.secondaryContainer,
                  border: edgeBorder(context, colors.secondaryContainer),
                ),
                child: Icon(
                  Icons.add_rounded,
                  color: colors.onSecondaryContainer,
                ),
              ),
              const SizedBox(height: 10.0),
              Text(
                l10n.saveAsProgram,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 4.0),
              Text(
                l10n.saveAsProgramHint,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- the screen ----------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    AppLocalizations l10n = AppLocalizations.of(context);
    ThemeData theme = Theme.of(context);
    Preference preference = widget.preferences.getAt(0);
    BreathPattern pattern = BreathPattern(preference.inhale, preference.exhale);
    double? perMinute = pattern.breathsPerMinute;
    List<Program> programs = [...PROGRAMS, ..._myPrograms];
    Program? program = programOf(preference, _myPrograms);

    void setDuration({bool save = false}) {
      preference.duration = Duration(
        minutes: _durationMinutes.toInt(),
        seconds: _durationSeconds.toInt(),
      ).inSeconds;
      if (save) {
        preference.save();
        widget.callback();
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.preferences),
        actions: <Widget>[
          PopupMenuButton<String>(
            key: Key(PreferencesWidget.keyMenu),
            onSelected: (value) {
              if (value == RESET_ALL_TEXT) _confirmResetAll();
            },
            itemBuilder: (BuildContext context) => [
              PopupMenuItem<String>(
                key: const Key(RESET_ALL_TEXT),
                value: RESET_ALL_TEXT,
                child: Text(l10n.resetAll),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(0.0, 8.0, 0.0, 32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Programs to choose from
            _section(
              icon: Icons.self_improvement_rounded,
              title: l10n.programs,
              children: [
                Text(
                  l10n.programsHint,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12.0),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  itemCount: programs.length + 1,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisExtent: 178.0,
                    crossAxisSpacing: 10.0,
                    mainAxisSpacing: 10.0,
                  ),
                  itemBuilder: (context, i) => i == programs.length
                      ? _addProgramCard()
                      : ProgramCard(
                          program: programs[i],
                          selected: programs[i] == program,
                          onTap: () => _useProgram(programs[i]),
                          onLongPress: programs[i].isCustom
                              ? () => _confirmDelete(programs[i])
                              : null,
                        ),
                ),
                const SizedBox(height: 6.0),
              ],
            ),

            // Your session: name, and its breathing wave
            _section(
              icon: Icons.tune_rounded,
              title: l10n.yourSession,
              children: [
                const SizedBox(height: 10.0),
                TextFormField(
                  key: Key(PreferencesWidget.keyPreferenceName),
                  controller: _textEditingController,
                  maxLength: 32,
                  decoration: InputDecoration(
                    labelText: l10n.name,
                    hintText: l10n.enterAName,
                    prefixIcon: const Icon(Icons.edit_outlined),
                  ),
                  onChanged: (value) {
                    setState(() {
                      preference.name = value;
                      preference.save();
                      widget.callback();
                    });
                  },
                ),
                if (program != null) ...[
                  Text(
                    program.description(l10n),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12.0),
                ],
                BreathWave(pattern: pattern, height: 96.0),
                const SizedBox(height: 10.0),
                Row(
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 4.0,
                        runSpacing: 4.0,
                        children: phasePills(pattern),
                      ),
                    ),
                    if (perMinute != null)
                      Text(
                        "${perMinute.toStringAsFixed(1)} "
                        "${l10n.breathsUnit}${l10n.perMinute}",
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6.0),
              ],
            ),

            // Duration
            _section(
              icon: Icons.timer_outlined,
              title: l10n.duration,
              children: [
                const SizedBox(height: 8.0),
                Wrap(
                  spacing: 8.0,
                  runSpacing: 4.0,
                  children: [
                    for (int minutes in const [2, 5, 10, 15, 20, 30])
                      ChoiceChip(
                        key: Key("$DURATION_MINUTES_TEXT $minutes"),
                        label: Text("$minutes ${l10n.minutesShort}"),
                        selected: preference.duration == minutes * 60,
                        onSelected: (_) {
                          setState(() {
                            _durationMinutes = minutes.toDouble();
                            _durationSeconds = 0;
                            setDuration(save: true);
                          });
                        },
                      ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.minutes,
                          style: theme.textTheme.bodyLarge,
                        ),
                      ),
                      _valuePill(
                        getDurationString(
                          Duration(seconds: preference.duration),
                        ),
                      ),
                    ],
                  ),
                ),
                Slider(
                  key: const Key(DURATION_MINUTES_TEXT),
                  value: _durationMinutes,
                  min: 0,
                  max: PreferencesWidget.maxDurationMinutes.toDouble(),
                  divisions: PreferencesWidget.maxDurationMinutes + 1,
                  onChanged: (double value) {
                    setState(() {
                      _durationMinutes = value;
                      setDuration();
                    });
                  },
                  onChangeEnd: (double value) {
                    setState(() => setDuration(save: true));
                  },
                ),
                Text(l10n.seconds, style: theme.textTheme.bodyLarge),
                Slider(
                  key: const Key(DURATION_SECONDS_TEXT),
                  value: _durationSeconds,
                  min: 0,
                  max: PreferencesWidget.maxDurationSeconds.toDouble(),
                  divisions: PreferencesWidget.maxDurationSeconds + 1,
                  onChanged: (double value) {
                    setState(() {
                      _durationSeconds = value;
                      setDuration();
                    });
                  },
                  onChangeEnd: (double value) {
                    setState(() => setDuration(save: true));
                  },
                ),
              ],
            ),

            // Breathing
            _section(
              icon: Icons.air_rounded,
              title: l10n.breathing,
              children: [
                _subheading(l10n.inhale),
                _breathSetting(
                  preference,
                  INHALE_TEXT,
                  l10n.inhale,
                  BreathPhase.inhale,
                  PreferencesWidget.minBreath,
                  PreferencesWidget.maxInhale,
                ),
                _breathSetting(
                  preference,
                  INHALE_HOLD_TEXT,
                  l10n.inhaleHold,
                  BreathPhase.inhaleHold,
                  0,
                  PreferencesWidget.maxHold,
                ),
                _breathSetting(
                  preference,
                  INHALE_LAST_TEXT,
                  l10n.inhaleLast,
                  BreathPhase.inhaleLast,
                  0,
                  PreferencesWidget.maxHold,
                ),
                const Divider(),
                _subheading(l10n.exhale),
                _breathSetting(
                  preference,
                  EXHALE_TEXT,
                  l10n.exhale,
                  BreathPhase.exhale,
                  PreferencesWidget.minBreath,
                  PreferencesWidget.maxExhale,
                ),
                _breathSetting(
                  preference,
                  EXHALE_HOLD_TEXT,
                  l10n.exhaleHold,
                  BreathPhase.exhaleHold,
                  0,
                  PreferencesWidget.maxHold,
                ),
                _breathSetting(
                  preference,
                  EXHALE_LAST_TEXT,
                  l10n.exhaleLast,
                  BreathPhase.exhaleLast,
                  0,
                  PreferencesWidget.maxHold,
                ),
              ],
            ),

            // Sounds
            _section(
              icon: Icons.music_note_outlined,
              title: l10n.sounds,
              children: [
                _audioSetting(
                  preference,
                  INHALE_AUDIO_TEXT,
                  l10n.inhaleAudio,
                  0,
                  BreathPhase.inhale,
                ),
                _audioSetting(
                  preference,
                  INHALE_HOLD_AUDIO_TEXT,
                  l10n.inhaleHoldAudio,
                  2,
                  BreathPhase.inhaleHold,
                ),
                _audioSetting(
                  preference,
                  EXHALE_AUDIO_TEXT,
                  l10n.exhaleAudio,
                  1,
                  BreathPhase.exhale,
                ),
                _audioSetting(
                  preference,
                  EXHALE_HOLD_AUDIO_TEXT,
                  l10n.exhaleHoldAudio,
                  3,
                  BreathPhase.exhaleHold,
                ),
              ],
            ),

            // Vibration
            if (!isWeb())
              _section(
                icon: Icons.vibration_rounded,
                title: l10n.vibration,
                children: [
                  _sliderRow(
                    l10n.breathVibrate,
                    "${preference.vibrateBreath} ms",
                    Slider(
                      key: const Key(BREATH_VIBRATE_TEXT),
                      value: _vibrateBreathD,
                      min: 0,
                      max: PreferencesWidget.maxVibration.toDouble(),
                      divisions: PreferencesWidget.maxVibration + 1,
                      onChanged: (double value) {
                        setState(() {
                          _vibrateBreathD = value;
                          preference.vibrateBreath = value.round() * 10;
                        });
                      },
                      onChangeEnd: (double value) {
                        setState(() {
                          preference.vibrateBreath = value.round() * 10;
                          preference.save();
                        });
                      },
                    ),
                  ),
                  _sliderRow(
                    l10n.durationVibrate,
                    "${preference.vibrateDuration} ms",
                    Slider(
                      key: const Key(DURATION_VIBRATE_TEXT),
                      value: _vibrateDurationD,
                      min: 0,
                      max: PreferencesWidget.maxVibration.toDouble(),
                      divisions: PreferencesWidget.maxVibration + 1,
                      onChanged: (double value) {
                        setState(() {
                          _vibrateDurationD = value;
                          preference.vibrateDuration = value.round() * 10;
                        });
                      },
                      onChangeEnd: (double value) {
                        setState(() {
                          preference.vibrateDuration = value.round() * 10;
                          preference.save();
                        });
                      },
                    ),
                  ),
                ],
              ),

            // Voice
            _section(
              icon: Icons.record_voice_over_outlined,
              title: l10n.voice,
              children: [
                SwitchListTile(
                  key: const Key(BREATH_TTS_TEXT),
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.breathTts),
                  value: _breathTts,
                  onChanged: (value) {
                    setState(() {
                      _breathTts = value;
                      preference.breathTts = value;
                      preference.save();
                    });
                  },
                ),
                SwitchListTile(
                  key: const Key(DURATION_TTS_TEXT),
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.durationTts),
                  value: _durationTts,
                  onChanged: (value) {
                    setState(() {
                      _durationTts = value;
                      preference.durationTts = value;
                      preference.save();
                    });
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
