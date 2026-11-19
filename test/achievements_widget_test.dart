import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import 'package:lucid/achievements.dart';
import 'package:lucid/achievements_widget.dart';
import 'package:lucid/hive_storage.dart';
import 'package:lucid/l10n/generated/app_localizations.dart';
import 'test_utils.dart';

Widget wrap(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: child,
);

void main() {
  late Box box;
  setUpAll(() async {
    await setupHive();
    box = await Hive.openBox('achievement_sessions');
    // Twelve days in a row, ten minutes each
    for (int i = 0; i < 12; i++) {
      Session s = Session(start: DateTime(2026, 10, 1 + i, 8));
      s.end = s.start.add(const Duration(minutes: 10));
      s.breaths = 60;
      await box.add(s);
    }
  });

  testWidgets('Achievements page shows badges and their levels', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(wrap(AchievementsWidget(sessions: box)));
    await tester.pumpAndSettle();

    expect(find.text("Achievements"), findsOneWidget);
    expect(find.text("Beta"), findsOneWidget);
    expect(find.text("Recently earned"), findsOneWidget);

    // Sessions: level II (1 and 10), 12 of 50 for the next
    Finder sessions = find.byKey(const Key("achievement-$A_SESSIONS"));
    await tester.ensureVisible(sessions);
    await tester.pumpAndSettle();
    await tester.tap(sessions);
    await tester.pumpAndSettle();
    expect(find.text("So far: 12 sessions"), findsOneWidget);
    expect(find.text("Not yet"), findsWidgets);
  });
}
