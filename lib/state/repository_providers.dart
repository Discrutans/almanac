import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../booking/booking_repository.dart';
import '../data/events/event_repository.dart';
import '../data/remote/event_lock_service.dart';
import '../data/remote/remote_sync_service.dart';
import '../data/schedules/cyclic_work_schedule_repository.dart';
import '../data/savings/savings_goal_repository.dart';
import '../platform/group_plan_repository.dart';
import '../platform/platform_config_repository.dart';
import 'core_providers.dart';

final remoteSyncServiceProvider = Provider<RemoteSyncService>((ref) {
  ref.watch(platformSettingsRevisionProvider);
  return createRemoteSyncService(
    config: ref.watch(appConfigProvider),
    store: ref.watch(localDataStoreProvider),
    locale: ref.watch(appLocaleProvider),
  );
});

final eventLockServiceProvider = Provider<EventLockService>((ref) {
  return EventLockService(
    config: ref.watch(appConfigProvider),
    store: ref.watch(localDataStoreProvider),
    platformConfigRepository: ref.watch(platformConfigRepositoryProvider),
  );
});

final cyclicWorkScheduleRepositoryProvider =
    Provider<CyclicWorkScheduleRepository>((ref) {
      return ref.watch(localDataStoreProvider).scheduleRepository;
    });

final eventRepositoryProvider = Provider<EventRepository>((ref) {
  return ref.watch(localDataStoreProvider).eventRepository;
});

final bookingRepositoryProvider = Provider<BookingRepository>((ref) {
  return ref.watch(localDataStoreProvider).bookingRepository;
});

final groupPlanRepositoryProvider = Provider<GroupPlanRepository>((ref) {
  return ref.watch(localDataStoreProvider).groupPlanRepository;
});

final savingsGoalRepositoryProvider = Provider<SavingsGoalRepository>((ref) {
  return ref.watch(localDataStoreProvider).savingsGoalRepository;
});

final platformConfigRepositoryProvider = Provider<PlatformConfigRepository>((
  ref,
) {
  return ref.watch(localDataStoreProvider).platformConfigRepository;
});
