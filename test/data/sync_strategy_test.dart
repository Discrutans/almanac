import 'package:flutter_test/flutter_test.dart';
import 'package:almanac/data/remote/sync_strategy.dart';

void main() {
  group('resolveSyncDirection', () {
    test('pushes when remote is missing', () {
      expect(
        resolveSyncDirection(
          localUpdated: DateTime(2026, 1, 2),
          remoteUpdated: null,
        ),
        SyncDirection.push,
      );
    });

    test('pulls when remote is newer', () {
      expect(
        resolveSyncDirection(
          localUpdated: DateTime(2026, 1, 1),
          remoteUpdated: DateTime(2026, 1, 2),
        ),
        SyncDirection.pull,
      );
    });

    test('pushes when local is newer', () {
      expect(
        resolveSyncDirection(
          localUpdated: DateTime(2026, 1, 3),
          remoteUpdated: DateTime(2026, 1, 2),
        ),
        SyncDirection.push,
      );
    });

    test('up to date when equal', () {
      final t = DateTime(2026, 1, 1, 12);
      expect(
        resolveSyncDirection(localUpdated: t, remoteUpdated: t),
        SyncDirection.upToDate,
      );
    });
  });
}
