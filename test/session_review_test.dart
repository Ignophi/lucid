import 'package:flutter_test/flutter_test.dart';

import 'package:lucid/hive_storage.dart';

void main() {
  group('Session review', () {
    test('review fields survive a JSON round trip', () {
      Session session = Session(start: DateTime(2026, 1, 1, 8, 0));
      session.end = DateTime(2026, 1, 1, 8, 10);
      session.breaths = 42;
      session.rating = 85;
      session.sessionType = 'sitting';
      session.comment = 'Calm, a bit sleepy';

      Session copy = Session.fromJson(session.toJson());

      expect(copy.rating, 85);
      expect(copy.sessionType, 'sitting');
      expect(copy.comment, 'Calm, a bit sleepy');
      expect(copy.isReviewed, isTrue);
    });

    test('sessions saved before reviews existed load without a review', () {
      Session copy = Session.fromJson({
        'start': DateTime(2026, 1, 1).millisecondsSinceEpoch,
        'end': DateTime(2026, 1, 1, 0, 5).millisecondsSinceEpoch,
        'breaths': 30,
        'heartrates': null,
        'description': null,
      });

      expect(copy.rating, isNull);
      expect(copy.sessionType, isNull);
      expect(copy.comment, isNull);
      expect(copy.isReviewed, isFalse);
    });
  });
}
