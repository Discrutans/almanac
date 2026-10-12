import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/config/app_config.dart';
import 'core/error/almanac_error_guard.dart';
import 'data/local/local_data_store.dart';
import 'notifications/event_reminder_service.dart';
import 'platform/high_refresh_rate.dart';
import 'state/app_providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  installAlmanacErrorGuards();
  await HighRefreshRate.configure();

  final config = AppConfig.fromEnvironment();

  final store = await LocalDataStore.open(seedDemoData: config.seedDemoData);
  store.bindPersistence();
  await EventReminderService.instance.initialize();
  await EventReminderService.instance.syncUpcomingFromRepository(
    eventRepository: store.eventRepository,
    profileIds: store.profileRepository
        .getAll()
        .map((profile) => profile.id)
        .where(
          (id) => store.platformConfigRepository
              .getOrCreateConfig(profileId: id)
              .notificationsEnabled,
        ),
  );

  runApp(
    ProviderScope(
      overrides: [localDataStoreProvider.overrideWithValue(store)],
      child: const AlmanacApp(),
    ),
  );
}
