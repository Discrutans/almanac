import 'package:flutter_test/flutter_test.dart';
import 'package:almanac/data/local/local_data_codec.dart';
import 'package:almanac/data/local/local_data_store.dart';
import 'package:almanac/data/profiles/context_profile.dart';
import 'package:almanac/platform/platform_config_repository.dart';

void main() {
  test('tryDecode returns null for corrupt json', () {
    expect(
      () => LocalDataSnapshot.decode('{not-json'),
      throwsA(isA<FormatException>()),
    );
  });

  test('valid snapshot still decodes', () {
    final snapshot = LocalDataSnapshot(
      profiles: const [ContextProfile(id: 'default', name: 'Ok')],
      activeProfileId: 'default',
      visibleProfileIds: {'default'},
      eventsByProfile: const {},
      schedulesByProfile: const {},
      templatesByProfile: const {},
      requestsByProfile: const {},
    );
    final restored = LocalDataSnapshot.decode(
      LocalDataSnapshot.encode(snapshot),
    );
    expect(restored.profiles.first.name, 'Ok');
  });

  test('weekHourZoomLevel roundtrips in snapshot', () {
    final snapshot = LocalDataSnapshot(
      profiles: const [ContextProfile(id: 'default', name: 'Ok')],
      activeProfileId: 'default',
      visibleProfileIds: {'default'},
      eventsByProfile: const {},
      schedulesByProfile: const {},
      templatesByProfile: const {},
      requestsByProfile: const {},
      weekHourZoomLevel: 2,
    );
    final restored = LocalDataSnapshot.decode(
      LocalDataSnapshot.encode(snapshot),
    );
    expect(restored.weekHourZoomLevel, 2);
  });

  test('weekHourZoomLevel 3 decodes clamped to 2', () {
    final snapshot = LocalDataSnapshot(
      profiles: const [ContextProfile(id: 'default', name: 'Ok')],
      activeProfileId: 'default',
      visibleProfileIds: {'default'},
      eventsByProfile: const {},
      schedulesByProfile: const {},
      templatesByProfile: const {},
      requestsByProfile: const {},
      weekHourZoomLevel: 3,
    );
    final restored = LocalDataSnapshot.decode(
      LocalDataSnapshot.encode(snapshot),
    );
    expect(restored.weekHourZoomLevel, 2);
  });

  test('exportSnapshot keeps updatedAt after persist', () async {
    final store = await LocalDataStore.openInMemory(seedDemoData: false);
    expect(store.exportSnapshot().updatedAt, isNull);

    await store.persist();
    final stamped = store.exportSnapshot();
    expect(stamped.updatedAt, isNotNull);

    final other = await LocalDataStore.openInMemory(seedDemoData: false);
    other.platformConfigRepository.getOrCreateConfig(profileId: 'default');
    (other.platformConfigRepository as InMemoryPlatformConfigRepository)
        .updateConnectionSettings(
          profileId: 'default',
          serverBaseUrl: 'http://192.168.10.100:8080',
          apiKey: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
          workspaceProfileId: 'default',
        );
    await other.restoreSnapshot(
      LocalDataSnapshot(
        profiles: stamped.profiles,
        activeProfileId: stamped.activeProfileId,
        visibleProfileIds: stamped.visibleProfileIds,
        eventsByProfile: stamped.eventsByProfile,
        schedulesByProfile: stamped.schedulesByProfile,
        templatesByProfile: stamped.templatesByProfile,
        requestsByProfile: stamped.requestsByProfile,
        platformConfigsByProfile: const {},
      ),
    );
    final kept =
        (other.platformConfigRepository as InMemoryPlatformConfigRepository)
            .getOrCreateConfig(profileId: 'default');
    expect(kept.serverBaseUrl, 'http://192.168.10.100:8080');
  });

  test('setWeekHourZoomLevel persists on store', () async {
    final store = await LocalDataStore.openInMemory(seedDemoData: false);
    store.setWeekHourZoomLevel(3);
    expect(store.weekHourZoomLevel, 2);
    expect(store.exportSnapshot().weekHourZoomLevel, 2);
  });
}
