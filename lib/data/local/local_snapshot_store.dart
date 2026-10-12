import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

/// SQLite-backed storage for the encoded [LocalDataSnapshot] blob.
final class LocalSnapshotStore {
  LocalSnapshotStore(this._db);

  final Database _db;

  static Future<LocalSnapshotStore> openDefault() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'almanac.db');
    final db = sqlite3.open(path);
    db.execute('''
      CREATE TABLE IF NOT EXISTS persisted_snapshots (
        id INTEGER PRIMARY KEY,
        json TEXT NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    return LocalSnapshotStore(db);
  }

  String? loadSnapshotJson() {
    try {
      final result = _db.select(
        'SELECT json FROM persisted_snapshots WHERE id = 1 LIMIT 1',
      );
      if (result.isEmpty) return null;
      return result.first.columnAt(0) as String?;
    } catch (error, stackTrace) {
      debugPrint('LocalSnapshotStore.load failed: $error\n$stackTrace');
      return null;
    }
  }

  bool saveSnapshotJson(String json) {
    try {
      final updatedAt = DateTime.now().millisecondsSinceEpoch;
      _db.execute(
        'INSERT INTO persisted_snapshots (id, json, updated_at) VALUES (1, ?, ?) '
        'ON CONFLICT(id) DO UPDATE SET json = excluded.json, updated_at = excluded.updated_at',
        [json, updatedAt],
      );
      return true;
    } catch (error, stackTrace) {
      debugPrint('LocalSnapshotStore.save failed: $error\n$stackTrace');
      return false;
    }
  }

  void dispose() {
    try {
      _db.close();
    } catch (_) {}
  }
}
