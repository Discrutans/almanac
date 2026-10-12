import 'dart:async';
import 'remote_sync_service.dart';

/// Debounced calendar sync after local edits, and quiet pull on resume.
final class RemoteAutoSyncScheduler {
  RemoteAutoSyncScheduler(this._serviceFactory, {this.onRestored});

  final RemoteSyncService Function() _serviceFactory;
  void Function()? onRestored;
  Timer? _debounce;

  void schedulePush({Duration delay = Duration.zero, String? onlyProfileId}) {
    _debounce?.cancel();
    if (delay <= Duration.zero) {
      unawaited(_pushNow(onlyProfileId: onlyProfileId));
      return;
    }
    _debounce = Timer(delay, () {
      unawaited(_pushNow(onlyProfileId: onlyProfileId));
    });
  }

  Future<void> pushNow({String? onlyProfileId}) {
    _debounce?.cancel();
    return _pushNow(onlyProfileId: onlyProfileId);
  }

  Future<void> _pushNow({String? onlyProfileId}) async {
    final service = _serviceFactory();
    if (!service.isEnabled) return;
    await service.pushLocalChanges(onlyProfileId: onlyProfileId);
  }

  /// Pull if the server is newer. Push only when this device has newer local data.
  Future<void> syncNow({
    bool pushIfLocalNewer = true,
    String? onlyProfileId,
  }) async {
    final service = _serviceFactory();
    if (!service.isEnabled) return;
    final pull = await service.pullRemoteChanges(onlyProfileId: onlyProfileId);
    if (pull.restoredFromRemote) {
      onRestored?.call();
      return;
    }
    if (pushIfLocalNewer && pull.success) {
      await service.pushLocalChanges(onlyProfileId: onlyProfileId);
    }
  }

  void dispose() {
    _debounce?.cancel();
  }
}
