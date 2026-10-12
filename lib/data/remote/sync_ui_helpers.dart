import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../state/app_providers.dart';
import '../../state/calendar_events_notifier.dart';

/// Обновляет Riverpod после загрузки снимка с сервера.
void refreshAfterRemoteRestore(WidgetRef ref) {
  ref.invalidate(contextProfilesProvider);
  ref.read(calendarEventsProvider.notifier).reload();
  ref.read(pendingBookingsProvider.notifier).refresh();
  ref.read(schedulesVersionProvider.notifier).state++;
  ref.read(appLocaleProvider.notifier).syncFromStore();
  ref.read(weekHourZoomLevelProvider.notifier).syncFromStore();
}
