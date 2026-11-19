import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import 'package:lucid/constants.dart';
import 'package:lucid/hive_storage.dart';
import 'package:lucid/programs.dart';
import 'package:lucid/utils.dart';
import 'test_utils.dart';

void main() {
  setUpAll(() async {
    await setupHive();
  });

  test('saved slots become your own programs, once', () async {
    Box preferences = await Hive.openBox('slot_preferences');
    Box settings = await Hive.openBox('slot_settings');
    await preferences.add(Preference.getDefaultPref()); // the current one
    await preferences.add(Preference.getDefaultPref()); // never really used
    await preferences.add(Preference.get478Pref()); // same as a built-in one
    Preference evening = Preference.getDefaultPref()
      ..name = "Evening"
      ..inhale = [4000, 2000, 0]
      ..exhale = [7000, 0, 0]
      ..duration = 600;
    await preferences.add(evening);

    await moveSlotsToPrograms(preferences, settings);
    List<Program> mine = MyPrograms.load(settings);
    expect(mine.length, 1);
    expect(mine.first.customName, "Evening");
    expect(mine.first.inhale, [4000, 2000, 0]);
    expect(mine.first.duration, 600);
    expect(preferences.length, 1);

    // Saving, finding and deleting your own programs
    Program morning = await MyPrograms.add(
      settings,
      name: "Morning",
      inhale: [5000, 0, 0],
      exhale: [5000, 0, 0],
      duration: 300,
    );
    Preference current = preferences.getAt(0)
      ..name = "Morning"
      ..inhale = [5000, 0, 0]
      ..exhale = [5000, 0, 0]
      ..duration = 300;
    expect(programOf(current, MyPrograms.load(settings))?.key, morning.key);
    await MyPrograms.remove(settings, morning.key);
    expect(MyPrograms.load(settings).length, 1);
    // 5-5 is no built-in pattern (coherent breathing is 5.5-5.5)
    expect(programOf(current), isNull);
  });

  test('old hold tones become silent, once', () async {
    Box preferences = await Hive.openBox('hold_preferences');
    Box settings = await Hive.openBox('hold_settings');
    Preference old = Preference.getDefaultPref()
      ..audio = [AUDIO_TONE1, AUDIO_TONE2, AUDIO_TONE3, AUDIO_TONE4];
    await preferences.add(old);
    await silenceHoldSounds(preferences, settings);
    Preference updated = preferences.getAt(0);
    expect(updated.audio, [AUDIO_TONE1, AUDIO_TONE2, AUDIO_NONE, AUDIO_NONE]);

    // Chosen again later: left alone
    updated.audio[2] = AUDIO_TONE3;
    await updated.save();
    await silenceHoldSounds(preferences, settings);
    expect((preferences.getAt(0) as Preference).audio[2], AUDIO_TONE3);
  });
}
