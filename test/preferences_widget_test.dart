import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lucid/constants.dart';
import 'package:lucid/preferences_widget.dart';
import 'package:lucid/programs.dart';
import 'package:lucid/format.dart';
import 'package:lucid/l10n/generated/app_localizations.dart';
import 'test_utils.dart';

const Duration wait = Duration(milliseconds: 500);

Future<void> tapMenu(WidgetTester tester) async {
  Finder menu = find.byKey(Key(PreferencesWidget.keyMenu));
  expect(menu, findsOneWidget);
  await tester.tap(menu);
  await tester.pumpAndSettle();
}

Future<void> testSwitch(WidgetTester tester, String key, bool value) async {
  Finder tile = find.byKey(Key(key));
  await tester.ensureVisible(tile);
  await tester.pumpAndSettle();
  expect((tester.widget(tile) as SwitchListTile).value, value);
  await tester.tap(tile);
  await tester.pumpAndSettle();
  expect((tester.widget(tile) as SwitchListTile).value, !value);
}

/// Taps the middle of a slider (sets it to half way).
Future<void> tapSlider(WidgetTester tester, String key) async {
  Finder slider = find.byKey(Key(key));
  await tester.ensureVisible(slider);
  await tester.pumpAndSettle();
  await tester.tap(slider);
  await tester.pumpAndSettle();
}

Future<void> testAudio(WidgetTester tester, String key, [String? audio]) async {
  audio ??= AUDIO_TONE1;

  Finder finder = find.byKey(Key(key), skipOffstage: false);
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
  expect(find.textContaining(AUDIO_NONE), findsWidgets);
  expect(find.textContaining(AUDIO_TONE1), findsWidgets);
  expect(find.textContaining(AUDIO_TONE2), findsWidgets);
  expect(find.textContaining(AUDIO_TONE3), findsWidgets);
  expect(find.textContaining(AUDIO_TONE4), findsWidgets);
  finder = find.text(audio).last;
  await tester.tap(finder);
  await tester.pumpAndSettle();
  expect(find.textContaining(audio), findsWidgets);
  await tester.pumpAndSettle();
}

/// Taps the card of the program with [key].
Future<void> tapProgram(WidgetTester tester, String key) async {
  Finder card = find.byKey(Key(key));
  expect(card, findsOneWidget);
  await tester.ensureVisible(card);
  await tester.pumpAndSettle();
  await tester.tap(card);
  await tester.pumpAndSettle();
}

/// The text in the name field.
String nameText(WidgetTester tester) =>
    (tester.widget(find.byKey(Key(PreferencesWidget.keyPreferenceName)))
            as TextFormField)
        .controller!
        .text;

Future<void> changeColors(WidgetTester tester) async {
  await tester.pump(wait);
}

Future<void> testPreferencesWidget(WidgetTester tester) async {
  // Name
  Finder preferenceName = find.byKey(Key(PreferencesWidget.keyPreferenceName));
  expect(preferenceName, findsOneWidget);

  // Duration: minutes, then seconds
  expect(
    find.text(getDurationString(const Duration(seconds: DURATION))),
    findsOneWidget,
  );
  await tapSlider(tester, DURATION_MINUTES_TEXT);
  expect(
    find.text(
      getDurationString(
        Duration(minutes: PreferencesWidget.maxDurationMinutes ~/ 2),
      ),
    ),
    findsOneWidget,
  );
  await tapSlider(tester, DURATION_SECONDS_TEXT);
  expect(
    find.text(
      getDurationString(
        Duration(
          minutes: PreferencesWidget.maxDurationMinutes ~/ 2,
          seconds: PreferencesWidget.maxDurationSeconds ~/ 2,
        ),
      ),
    ),
    findsOneWidget,
  );

  // Breathing
  expect(
    find.text("${INHALE / Duration.millisecondsPerSecond} s"),
    findsWidgets,
  );
  await tapSlider(tester, INHALE_TEXT);
  expect(
    find.text(
      "${((PreferencesWidget.maxInhale + PreferencesWidget.minBreath) / 10 / 2).toStringAsFixed(1)} s",
    ),
    findsOneWidget,
  );
  await tapSlider(tester, INHALE_HOLD_TEXT);
  await tapSlider(tester, INHALE_LAST_TEXT);
  expect(
    find.text("${PreferencesWidget.maxHold / 10 / 2} s"),
    findsNWidgets(2),
  );
  await tapSlider(tester, EXHALE_TEXT);
  expect(
    find.text(
      "${((PreferencesWidget.maxExhale + PreferencesWidget.minBreath) / 10 / 2).toStringAsFixed(1)} s",
    ),
    findsOneWidget,
  );
  await tapSlider(tester, EXHALE_HOLD_TEXT);
  await tapSlider(tester, EXHALE_LAST_TEXT);
  expect(
    find.text("${PreferencesWidget.maxHold / 10 / 2} s"),
    findsNWidgets(4),
  );

  // Sounds
  await testAudio(tester, INHALE_AUDIO_TEXT, AUDIO_TONE1);
  await testAudio(tester, INHALE_HOLD_AUDIO_TEXT, AUDIO_TONE3);
  await testAudio(tester, EXHALE_AUDIO_TEXT, AUDIO_TONE2);
  await testAudio(tester, EXHALE_HOLD_AUDIO_TEXT, AUDIO_TONE4);

  // Vibration
  int half = PreferencesWidget.maxVibration * 10 ~/ 2;
  expect(find.text("$VIBRATE_DURATION ms"), findsOneWidget);
  await tapSlider(tester, DURATION_VIBRATE_TEXT);
  expect(find.text("$half ms"), findsOneWidget);
  expect(find.text("$VIBRATE_BREATH ms"), findsOneWidget);
  await tapSlider(tester, BREATH_VIBRATE_TEXT);
  expect(find.text("$half ms"), findsNWidgets(2));

  // Voice
  await testSwitch(tester, DURATION_TTS_TEXT, false);
  await testSwitch(tester, BREATH_TTS_TEXT, false);

  // Save the current settings as your own program, then delete it
  await tester.ensureVisible(preferenceName);
  await tester.pumpAndSettle();
  await tester.enterText(preferenceName, "Evening");
  await tester.pumpAndSettle();
  Finder add = find.byKey(Key(PreferencesWidget.keySaveProgram));
  await tester.ensureVisible(add);
  await tester.pumpAndSettle();
  await tester.tap(add);
  await tester.pumpAndSettle();
  expect(find.byKey(Key(PreferencesWidget.keyProgramName)), findsOneWidget);
  await tester.tap(find.byKey(Key(PreferencesWidget.keySaveProgramConfirm)));
  await tester.pumpAndSettle();
  Finder mine = find.byWidgetPredicate(
    (widget) => widget is ProgramCard && widget.program.isCustom,
  );
  expect(mine, findsOneWidget);
  expect(
    find.descendant(
      of: mine,
      matching: find.byIcon(Icons.check_circle_rounded),
    ),
    findsOneWidget,
  );
  await tester.ensureVisible(mine);
  await tester.pumpAndSettle();
  await tester.longPress(mine);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key(CONTINUE_TEXT)));
  await tester.pumpAndSettle();
  expect(mine, findsNothing);

  // Reset all
  await tapMenu(tester);
  await tester.tap(find.byKey(const Key(RESET_ALL_TEXT)));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key(CONTINUE_TEXT)));
  await tester.pumpAndSettle();
  expect(find.textContaining("Preferences reset"), findsOneWidget);

  // Programs: each sets the pattern, the duration and the name
  for (var (key, name, duration) in const [
    (PRESET_478_TEXT, "4-7-8 breathing", DURATION_478),
    (BOX_TEXT, "Box breathing", DURATION_BOX),
    (PHYS_SIGH_TEXT, "Physiological sigh", DURATION_PS),
    (COHERENT_TEXT, "Coherent breathing", 300),
    (LONG_EXHALE_TEXT, "Long exhale", 180),
    (DEFAULT_TEXT, "Equal breathing", DURATION),
  ]) {
    await tapProgram(tester, key);
    expect(nameText(tester), name);
    expect(
      find.text(getDurationString(Duration(seconds: duration))),
      findsOneWidget,
    );
    // The chosen program is marked
    expect(
      find.descendant(
        of: find.byKey(Key(key)),
        matching: find.byIcon(Icons.check_circle_rounded),
      ),
      findsOneWidget,
    );
  }

  // Quick duration choice
  Finder tenMinutes = find.byKey(const Key("$DURATION_MINUTES_TEXT 10"));
  await tester.ensureVisible(tenMinutes);
  await tester.pumpAndSettle();
  await tester.tap(tenMinutes);
  await tester.pumpAndSettle();
  expect(
    find.text(getDurationString(const Duration(minutes: 10))),
    findsOneWidget,
  );
}

Future<void> main() async {
  late HiveData hiveData;
  setUpAll((() async {
    hiveData = await setupHive();
    AudioCache.instance = AudioCache(prefix: "audio/");
  }));

  tearDownAll((() async {}));

  testWidgets('PreferencesWidget', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: PreferencesWidget(
          preferences: hiveData.preferences,
          settings: hiveData.settings,
          callback: () {
            debugPrint("testWidget callback executed");
          },
        ),
      ),
    );

    await tester.pumpAndSettle();

    await testPreferencesWidget(tester);
  });
}
