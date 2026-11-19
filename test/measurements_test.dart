import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import 'package:lucid/constants.dart';
import 'package:lucid/hive_storage.dart';
import 'package:lucid/measure_settings.dart';
import 'package:lucid/measured_card.dart';
import 'package:lucid/measurements_widget.dart';
import 'package:lucid/session_measure.dart';
import 'package:lucid/session_review_widget.dart';
import 'package:lucid/utils.dart';
import 'package:lucid/l10n/generated/app_localizations.dart';
import 'test_utils.dart';

Widget wrap(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: child,
);

Session measuredSession() {
  Session session = Session(start: DateTime(2026, 11, 18, 7));
  session.end = DateTime(2026, 11, 18, 7, 10);
  session.breaths = 60;
  // Lying still with the phone on the belly
  session.measurements = {
    Measure.version: 1,
    Measure.seconds: 600,
    Measure.interruptions: 0,
    Measure.stillness: 97,
    Measure.movements: 1,
    Measure.flat: 0.95,
    Measure.upright: 0.02,
    Measure.walking: 0.0,
    Measure.breaths: 61,
    Measure.breathRate: 6.1,
    Measure.breathSource: Measure.sourceMotion,
    Measure.breathConfidence: 88,
    Measure.breathSteady: 85,
    Measure.guideRate: 6.0,
  };
  return session;
}

Future<void> main() async {
  late HiveData hiveData;
  setUpAll(() async {
    hiveData = await setupHive();
  });

  test('measurement settings: motion on, sound off by default', () async {
    MeasureSettings defaults = MeasureSettings.load(hiveData.settings);
    expect(defaults.motion, isTrue);
    expect(defaults.sound, isFalse);

    await MeasureSettings(motion: false, sound: true).save(hiveData.settings);
    MeasureSettings loaded = MeasureSettings.load(hiveData.settings);
    expect(loaded.motion, isFalse);
    expect(loaded.sound, isTrue);
    await MeasureSettings().save(hiveData.settings);
  });

  test('measurements are stored with the session', () async {
    Box box = await Hive.openBox('measured_sessions');
    await box.add(measuredSession());
    await box.close();
    box = await Hive.openBox('measured_sessions');
    Session stored = box.getAt(0);
    expect(stored.measurements?[Measure.stillness], 97);
    expect(stored.measurements?[Measure.breathRate], 6.1);
    expect(stored.measurements?[Measure.breathSource], Measure.sourceMotion);
    await box.close();
  });

  test('session types from earlier versions are converted', () async {
    Box box = await Hive.openBox('typed_sessions');
    for (String? type in [
      'sitting_meditation',
      'sitting_breathing',
      'lying_breathing',
      'walking_breathing',
      'body_scan',
      null,
    ]) {
      await box.add(measuredSession()..sessionType = type);
    }
    expect(await updateSessionTypes(box), 4);
    expect(
      [for (Session s in box.values) s.sessionType],
      ['sitting', 'sitting', 'lying', 'walking', 'body_scan', null],
    );
    expect(await updateSessionTypes(box), 0); // nothing left to convert
    await box.close();
  });

  testWidgets('Measurements screen', (WidgetTester tester) async {
    await tester.pumpWidget(
      wrap(MeasurementsWidget(settings: hiveData.settings)),
    );
    await tester.pumpAndSettle();

    SwitchListTile motion = tester.widget(
      find.byKey(const Key(MeasurementsWidget.keyMotion)),
    );
    SwitchListTile sound = tester.widget(
      find.byKey(const Key(MeasurementsWidget.keySound)),
    );
    expect(motion.value, isTrue);
    expect(sound.value, isFalse);

    await tester.tap(find.byKey(const Key(MeasurementsWidget.keyMotion)));
    await tester.pumpAndSettle();
    expect(MeasureSettings.load(hiveData.settings).motion, isFalse);

    await tester.tap(find.byKey(const Key(MeasurementsWidget.keyMotion)));
    await tester.pumpAndSettle();
    expect(MeasureSettings.load(hiveData.settings).motion, isTrue);
  });

  testWidgets('Review shows what was measured and suggests the type', (
    WidgetTester tester,
  ) async {
    Session session = measuredSession();
    await tester.pumpWidget(wrap(SessionReviewWidget(session: session)));
    await tester.pumpAndSettle();

    expect(find.byType(MeasuredCard), findsOneWidget);
    expect(find.byKey(const Key(MeasuredCard.keyCalm)), findsOneWidget);
    expect(find.textContaining("97%"), findsOneWidget); // stillness

    // No type yet: it looks like lying down breathing
    expect(find.byKey(const Key(MeasuredCard.keyUseType)), findsOneWidget);
    await tester.tap(find.byKey(const Key(MeasuredCard.keyUseType)));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key(MeasuredCard.keyUseType)), findsNothing);
    expect(typeFit(session.measurements, SESSION_TYPE_LYING)! >= 90, isTrue);
    expect(find.textContaining("96%"), findsOneWidget); // fit, now shown
  });

  testWidgets('Review without measurements has no measured card', (
    WidgetTester tester,
  ) async {
    Session session = measuredSession()..measurements = null;
    await tester.pumpWidget(wrap(SessionReviewWidget(session: session)));
    await tester.pumpAndSettle();
    expect(find.byType(MeasuredCard), findsNothing);
  });
}
