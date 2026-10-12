import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:almanac/data/local/local_data_codec.dart';
import 'package:almanac/data/local/local_snapshot_store.dart';
import 'package:almanac/data/profiles/context_profile.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  group('LocalSnapshotStore', () {
    late Directory tempDir;
    late File dbFile;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('almanac_snapshot_test_');
      dbFile = File(p.join(tempDir.path, 'test.db'));
    });

    tearDown(() {
      try {
        if (dbFile.existsSync()) dbFile.deleteSync();
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    });

    test('saves and loads snapshot json', () {
      final db = sqlite3.open(dbFile.path);
      db.execute('''
        CREATE TABLE IF NOT EXISTS persisted_snapshots (
          id INTEGER PRIMARY KEY,
          json TEXT NOT NULL,
          updated_at INTEGER NOT NULL
        )
      ''');
      final store = LocalSnapshotStore(db);

      const payload = '{"profiles":[],"activeProfileId":"default"}';
      store.saveSnapshotJson(payload);

      expect(store.loadSnapshotJson(), payload);

      expect(store.saveSnapshotJson('{"updated":true}'), isTrue);
      expect(store.loadSnapshotJson(), '{"updated":true}');
      store.dispose();
    });

    test('roundtrips encoded LocalDataSnapshot', () {
      final db = sqlite3.open(dbFile.path);
      db.execute('''
        CREATE TABLE IF NOT EXISTS persisted_snapshots (
          id INTEGER PRIMARY KEY,
          json TEXT NOT NULL,
          updated_at INTEGER NOT NULL
        )
      ''');
      final store = LocalSnapshotStore(db);

      final snapshot = LocalDataSnapshot(
        profiles: const [ContextProfile(id: 'default', name: 'Test')],
        activeProfileId: 'default',
        visibleProfileIds: {'default'},
        eventsByProfile: const {},
        schedulesByProfile: const {},
        templatesByProfile: const {},
        requestsByProfile: const {},
      );

      store.saveSnapshotJson(LocalDataSnapshot.encode(snapshot));
      final restored = LocalDataSnapshot.decode(store.loadSnapshotJson()!);

      expect(restored.profiles.first.name, 'Test');
      store.dispose();
    });
  });
}
