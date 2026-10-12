import 'package:almanac/data/remote/remote_auto_sync.dart';
import 'package:almanac/data/remote/remote_sync_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeSync implements RemoteSyncService {
  _FakeSync(this.pullResult);

  RemoteSyncResult pullResult;
  int pulls = 0;
  int pushes = 0;
  String? lastPullProfileId;
  String? lastPushProfileId;

  @override
  bool get isEnabled => true;

  @override
  Future<RemoteSyncResult> pullRemoteChanges({
    bool forceReplaceLocal = false,
    String? onlyProfileId,
  }) async {
    pulls += 1;
    lastPullProfileId = onlyProfileId;
    return pullResult;
  }

  @override
  Future<RemoteSyncResult> pushLocalChanges({
    String? onlyProfileId,
    bool allProfiles = false,
  }) async {
    pushes += 1;
    lastPushProfileId = onlyProfileId;
    return const RemoteSyncResult(success: true, message: 'pushed');
  }

  @override
  Future<RemoteSyncResult> syncAll() async {
    throw UnimplementedError();
  }
}

void main() {
  test('restores when remote is newer and does not push stale local', () async {
    var restored = 0;
    final fake = _FakeSync(
      const RemoteSyncResult(
        success: true,
        message: 'pulled',
        restoredFromRemote: true,
      ),
    );
    final scheduler = RemoteAutoSyncScheduler(
      () => fake,
      onRestored: () => restored += 1,
    );

    await scheduler.syncNow(pushIfLocalNewer: true);

    expect(fake.pulls, 1);
    expect(fake.pushes, 0);
    expect(restored, 1);
  });

  test('pushes when local is newer', () async {
    final fake = _FakeSync(
      const RemoteSyncResult(
        success: true,
        message: 'conflict',
        conflictWithLocal: true,
      ),
    );
    final scheduler = RemoteAutoSyncScheduler(() => fake);

    await scheduler.syncNow(pushIfLocalNewer: true);

    expect(fake.pulls, 1);
    expect(fake.pushes, 1);
  });

  test('idle pull does not overwrite server with old local', () async {
    final fake = _FakeSync(
      const RemoteSyncResult(
        success: true,
        message: 'conflict',
        conflictWithLocal: true,
      ),
    );
    final scheduler = RemoteAutoSyncScheduler(() => fake);

    await scheduler.syncNow(pushIfLocalNewer: false);

    expect(fake.pulls, 1);
    expect(fake.pushes, 0);
  });

  test('auto sync keeps to the selected profile', () async {
    final fake = _FakeSync(
      const RemoteSyncResult(
        success: true,
        message: 'conflict',
        conflictWithLocal: true,
      ),
    );
    final scheduler = RemoteAutoSyncScheduler(() => fake);

    await scheduler.syncNow(pushIfLocalNewer: true, onlyProfileId: 'work');

    expect(fake.lastPullProfileId, 'work');
    expect(fake.lastPushProfileId, 'work');
  });

  test('pushes after local edits even when pull reports up to date', () async {
    final fake = _FakeSync(
      const RemoteSyncResult(success: true, message: 'up to date'),
    );
    final scheduler = RemoteAutoSyncScheduler(() => fake);

    await scheduler.syncNow(pushIfLocalNewer: true);

    expect(fake.pulls, 1);
    expect(fake.pushes, 1);
  });

  test('schedulePush uploads without waiting for a pull conflict', () async {
    final fake = _FakeSync(
      const RemoteSyncResult(success: true, message: 'up to date'),
    );
    final scheduler = RemoteAutoSyncScheduler(() => fake);

    scheduler.schedulePush(delay: Duration.zero, onlyProfileId: 'default');
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(fake.pushes, 1);
    expect(fake.pulls, 0);
    expect(fake.lastPushProfileId, 'default');
  });

  test('schedulePush without delay uploads immediately', () async {
    final fake = _FakeSync(
      const RemoteSyncResult(success: true, message: 'up to date'),
    );
    final scheduler = RemoteAutoSyncScheduler(() => fake);

    scheduler.schedulePush(onlyProfileId: 'work');
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(fake.pushes, 1);
    expect(fake.lastPushProfileId, 'work');
  });
}
