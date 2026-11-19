import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lucid/analytics_widget.dart';
import 'package:lucid/app_shell.dart';
import 'package:lucid/common_widgets.dart';
import 'package:lucid/constants.dart';
import 'package:lucid/home_widget.dart';
import 'package:lucid/main.dart';
import 'package:lucid/session_review_widget.dart';
import 'package:lucid/sessions_calendar_widget.dart';
import 'package:lucid/sessions_widget.dart';
import 'package:lucid/utils.dart';
import 'test_utils.dart';

const String APP_VERSION = "1.0.0";

Future<void> openDrawer(WidgetTester tester) async {
  tester.firstState<ScaffoldState>(find.byType(Scaffold)).openDrawer();
  await tester.pumpAndSettle();
}

Future<void> closeDrawer(WidgetTester tester) async {
  tester.firstState<ScaffoldState>(find.byType(Scaffold)).closeDrawer();
  await tester.pumpAndSettle();
}

/// From Calendar or Sessions: Meditate starts a session right away; it can be
/// paused and resumed; Stop saves it and opens its review; going back returns
/// to where we were.
Future<void> testHomeWidget(WidgetTester tester) async {
  const Duration shortWait = Duration(milliseconds: 500);

  await tester.tap(find.byKey(const Key(MeditateButton.keyMeditate)));
  await tester.pump();
  await tester.pump(shortWait);
  expect(find.byType(HomeWidget), findsOneWidget);
  expect(find.text(INHALE_TEXT), findsOneWidget);

  // Pause, then resume
  await tester.tap(find.byKey(const Key(HomeWidget.keyPause)));
  await tester.pump(shortWait);
  expect(find.text("Paused"), findsOneWidget);
  await tester.tap(find.byKey(const Key(HomeWidget.keyPause)));
  await tester.pump(shortWait);
  expect(find.text("Paused"), findsNothing);
  expect(find.text(INHALE_TEXT), findsOneWidget);

  await tester.tap(find.byIcon(Icons.stop_rounded));
  await tester.pump(shortWait);
  await tester.pumpAndSettle();
  expect(find.byType(HomeWidget), findsNothing);
  expect(find.byType(SessionReviewWidget), findsOneWidget);

  await tester.pageBack();
  await tester.pumpAndSettle();
  expect(find.byType(SessionReviewWidget), findsNothing);
}

Future<void> main() async {
  late HiveData hiveData;
  setUpAll((() async {
    hiveData = await setupHive();
    if (hiveData.preferences.isEmpty) {
      await createDefaultPref(hiveData.preferences);
    }
  }));

  tearDownAll((() async {}));

  Widget app() => MainWidget(
    appName: APP_NAME,
    version: APP_VERSION,
    preferences: hiveData.preferences,
    sessions: hiveData.sessions,
    settings: hiveData.settings,
  );

  testWidgets('Menu and sections', (WidgetTester tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    // Starts on the calendar, with the Meditate button
    expect(find.byType(SessionsCalendarWidget), findsOneWidget);
    expect(find.byKey(const Key(MeditateButton.keyMeditate)), findsOneWidget);

    // Menu: Calendar, Sessions, Analytics, then the settings and About
    await openDrawer(tester);
    List<String> order = [
      AppShell.keyCalendar,
      AppShell.keySessions,
      AppShell.keyAnalytics,
      AppShell.keyAchievements,
      AppShell.keyPreferences,
      AppShell.keyReminders,
      AppShell.keyMeasurements,
      AppShell.keyBackup,
    ];
    for (String key in order) {
      expect(find.byKey(Key(key)), findsOneWidget);
    }
    for (int i = 0; i < order.length - 1; i++) {
      expect(
        tester.getTopLeft(find.byKey(Key(order[i]))).dy <
            tester.getTopLeft(find.byKey(Key(order[i + 1]))).dy,
        isTrue,
      );
    }
    expect(find.text("About $APP_NAME"), findsOneWidget);

    await tester.tap(find.byKey(const Key(AppShell.keySessions)));
    await tester.pumpAndSettle();
    expect(find.byType(SessionsWidget), findsOneWidget);
    expect(find.byKey(const Key(MeditateButton.keyMeditate)), findsOneWidget);

    await openDrawer(tester);
    await tester.tap(find.byKey(const Key(AppShell.keyAnalytics)));
    await tester.pumpAndSettle();
    expect(find.byType(AnalyticsWidget), findsOneWidget);

    // Back returns to the calendar
    await tester.state<NavigatorState>(find.byType(Navigator).first).maybePop();
    await tester.pumpAndSettle();
    expect(find.byType(SessionsCalendarWidget), findsOneWidget);
  });

  testWidgets('Meditate saves the session and opens its review', (
    WidgetTester tester,
  ) async {
    int before = hiveData.sessions.length;
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await testHomeWidget(tester);

    expect(hiveData.sessions.length, before + 1);
    expect(find.byType(SessionsCalendarWidget), findsOneWidget);
  });
}
