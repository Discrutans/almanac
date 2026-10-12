import '../../data/remote/event_lock_service.dart';
import '../calendar_types.dart';

/// Обёртка над [EventLockService]: refresh/acquire/release + уведомление UI.
class CalendarEventLockGuard {
  const CalendarEventLockGuard({required this.locks, required this.onChanged});

  final EventLockService locks;
  final void Function() onChanged;

  Future<bool> isLockedByOther({
    required AppEvent event,
    required bool needsLocks,
  }) async {
    if (!needsLocks) return false;
    await locks.refreshActive();
    onChanged();
    return locks.isLockedByOther(event.id);
  }

  Future<EventLockResult> acquire(String eventId) async {
    final result = await locks.acquire(eventId);
    onChanged();
    return result;
  }

  Future<void> release(String eventId) async {
    await locks.release(eventId);
    onChanged();
  }
}
