import 'package:lucid/home_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import 'package:lucid/utils.dart';
import 'package:lucid/constants.dart';
import 'package:lucid/sessions_widget.dart';
import 'package:lucid/sessions_calendar_widget.dart';
import 'package:lucid/analytics_widget.dart';
import 'package:lucid/common_widgets.dart';
import 'package:lucid/l10n/generated/app_localizations.dart';
import 'test_utils.dart';

const Duration WAIT = Duration(milliseconds: 1000);
int totalSessions = HomeWidget.totalSessions + 1;

Future<void> tapMenu(WidgetTester tester) async {
  Finder menu = find.byKey(Key(SessionsWidget.keyMenu));
  expect(menu, findsOneWidget);
  await tester.tap(menu);
  await tester.pumpAndSettle();
}

/// The analytics button on the "Since start" card opens all-time analytics.
Future<void> testAnalytics(WidgetTester tester, int sessions) async {
  expect(find.byType(AnalyticsWidget), findsNothing);
  await tester.tap(find.byTooltip("Analytics").first);
  await tester.pumpAndSettle(WAIT);
  expect(find.byType(AnalyticsWidget), findsOneWidget);
  Text count = tester.widget<Text>(
    find.byKey(const Key(AnalyticsWidget.keySessionCount)),
  );
  expect(count.data, "$sessions");
  await tester.pageBack();
  await tester.pumpAndSettle(WAIT);
  expect(find.byType(AnalyticsWidget), findsNothing);
}

Future<void> testSessionsWidget(WidgetTester tester) async {
  // Verify menu items

  await tapMenu(tester);

  // Verify clear all
  Finder clearAll = find.byKey(const Key(CLEAR_ALL_TEXT));
  expect(clearAll, findsOneWidget);
  await tester.tap(clearAll);
  await tester.pumpAndSettle();
  Finder cancel = find.byKey(const Key(CANCEL_TEXT));
  expect(cancel, findsOneWidget);
  await tester.tap(cancel);
  await tester.pumpAndSettle();

  // Verify import and export (they open the system's file dialogs, which
  // are not available in tests, so only check that the menu offers them)
  await tapMenu(tester);
  expect(find.byKey(const Key(IMPORT_TEXT)), findsOneWidget);
  expect(find.byKey(const Key(EXPORT_TEXT)), findsOneWidget);
  tester.state<NavigatorState>(find.byType(Navigator).first).pop();
  await tester.pumpAndSettle();

  // Verify analytics
  await testAnalytics(tester, totalSessions);
}

Future<void> testSessionsCalendarWidget(WidgetTester tester) async {
  // Verify week/month
  Finder button = find.text('Week');
  expect(button, findsOneWidget);
  await tester.tap(button);
  await tester.pumpAndSettle();
  button = find.text('Month');
  expect(button, findsOneWidget);
  await tester.tap(button);
  await tester.pumpAndSettle();
  button = find.text('Week');
  expect(button, findsOneWidget);
}

Future<void> main() async {
  LiveTestWidgetsFlutterBinding();

  late HiveData hiveData;
  setUpAll((() async {
    hiveData = await setupHive();
  }));

  tearDownAll((() async {}));

  group('Sessions Widgets', () {
    late Box sessions;

    setUp(() async {
      sessions = hiveData.sessions;
      await createRandomSessions(
        sessions,
        totalSessions,
        DateTime.now().subtract(const Duration(days: 180)),
        DateTime.now().subtract(const Duration(days: 1)),
      );
    });

    tearDown(() async {
      await sessions.clear();
    });

    testWidgets('SessionsWidget', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SessionsWidget(sessions: sessions),
        ),
      );
      await tester.pump(WAIT);

      await testSessionsWidget(tester);
    });

    testWidgets('SessionsCalendarWidget', (WidgetTester tester) async {
      bool meditate = false;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SessionsCalendarWidget(
            sessions: sessions,
            onMeditate: () => meditate = true,
          ),
        ),
      );

      await tester.pump(WAIT);

      await testSessionsCalendarWidget(tester);

      // Verify the Meditate button
      await tester.tap(find.byKey(const Key(MeditateButton.keyMeditate)));
      await tester.pump();
      expect(meditate, isTrue);

      //debugDumpApp();
    });
  });
}
