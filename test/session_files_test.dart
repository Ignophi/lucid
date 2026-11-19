import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import 'package:lucid/hive_storage.dart';
import 'package:lucid/session_files.dart';
import 'test_utils.dart';

void main() {
  late HiveData hiveData;
  setUpAll(() async {
    hiveData = await setupHive();
  });

  test('import adds new sessions and keeps them in order', () async {
    Box box = await Hive.openBox('import_sessions');
    Session stored = Session(start: DateTime(2026, 11, 2, 7))
      ..end = DateTime(2026, 11, 2, 7, 10)
      ..breaths = 60;
    await box.add(stored);

    String csv =
        'start,end,breaths,rating\n'
        '2026-11-03 07:00:00,2026-11-03 07:20:00,100,80\n'
        '2026-11-01 07:00:00,2026-11-01 07:05:00,30,\n'
        '2026-11-02 07:00:00,2026-11-02 07:10:00,60,70\n'
        'not a date,2026-11-04 07:00:00,10,\n';
    ImportSummary summary = await importSessions(box, csv);
    expect(summary.added, 2);
    expect(summary.updated, 1); // the stored session gets its rating
    expect(summary.skipped, 1);

    List<Session> all = storedSessions(box);
    expect([for (Session s in all) s.start.day], [1, 2, 3]); // oldest first
    expect(all[1].rating, 70);
    await box.close();
  });

  test('backup file names and settings', () async {
    expect(
      Backup.fileName(DateTime(2026, 11, 18)),
      'lucid-sessions-2026-11.csv',
    );
    expect(
      exportFileName(DateTime(2026, 1, 5)),
      'lucid-sessions-2026-01-05.csv',
    );
    expect(Backup.isEnabled(hiveData.settings), isTrue); // on by default
    await Backup.setEnabled(hiveData.settings, false);
    expect(Backup.isEnabled(hiveData.settings), isFalse);
    await Backup.setEnabled(hiveData.settings, true);
    // Not on an Android phone here: nothing is saved, nothing recorded
    expect(await Backup.save(hiveData.settings, hiveData.sessions), isNull);
    expect(Backup.lastTime(hiveData.settings), isNull);
  });
}
