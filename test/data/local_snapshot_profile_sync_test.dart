import 'package:almanac/calendar/calendar_types.dart';
import 'package:almanac/data/local/local_data_codec.dart';
import 'package:almanac/data/profiles/context_profile.dart';
import 'package:almanac/platform/platform_types.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalender/kalender.dart';

LocalDataSnapshot _snapshot({
  required List<ContextProfile> profiles,
  required String activeProfileId,
}) {
  return LocalDataSnapshot(
    profiles: profiles,
    activeProfileId: activeProfileId,
    visibleProfileIds: profiles.map((profile) => profile.id).toSet(),
    eventsByProfile: const {},
    schedulesByProfile: const {},
    templatesByProfile: const {},
    requestsByProfile: const {},
  );
}

void main() {
  const mainProfile = ContextProfile(id: 'default', name: 'Основной');
  const workProfile = ContextProfile(id: 'work', name: 'Работа');

  test('sliceForProfile keeps only the selected profile', () {
    final snapshot = _snapshot(
      profiles: const [mainProfile, workProfile],
      activeProfileId: 'work',
    );

    final sliced = snapshot.sliceForProfile('work');

    expect(sliced.profiles.map((profile) => profile.id), ['work']);
    expect(sliced.eventsByProfile.keys, ['work']);
    expect(sliced.schedulesByProfile.keys, ['work']);
    expect(sliced.visibleProfileIds, {'work'});
  });

  test('replacingProfile updates one profile and keeps the rest', () {
    final local = _snapshot(
      profiles: const [mainProfile, workProfile],
      activeProfileId: 'default',
    );
    final incoming = _snapshot(
      profiles: const [ContextProfile(id: 'work', name: 'Смена')],
      activeProfileId: 'work',
    );

    final merged = local.replacingProfile(incoming, 'work');

    expect(merged.profiles.map((profile) => profile.id).toSet(), {
      'default',
      'work',
    });
    expect(
      merged.profiles.firstWhere((profile) => profile.id == 'work').name,
      'Смена',
    );
    expect(
      merged.profiles.firstWhere((profile) => profile.id == 'default').name,
      'Основной',
    );
    expect(merged.activeProfileId, 'default');
  });

  test('unionProfile adds remote-only events and keeps local ones', () {
    final localNote = AppEvent(
      id: 'local-note',
      dateTimeRange: DateTimeRange(
        start: DateTime(2026, 9, 11, 10),
        end: DateTime(2026, 9, 11, 11),
      ),
      title: 'Локальная',
      startTime: '10:00',
      endTime: '11:00',
      color: const Color(0xFF3366CC),
      kind: CalendarEntryKind.note,
      interaction: EventInteraction.allowNone(),
    );
    final remoteNote = AppEvent(
      id: 'remote-note',
      dateTimeRange: DateTimeRange(
        start: DateTime(2026, 9, 11, 12),
        end: DateTime(2026, 9, 11, 13),
      ),
      title: 'С ПК',
      startTime: '12:00',
      endTime: '13:00',
      color: const Color(0xFF3366CC),
      kind: CalendarEntryKind.note,
      interaction: EventInteraction.allowNone(),
    );
    final local = LocalDataSnapshot(
      profiles: const [mainProfile],
      activeProfileId: 'default',
      visibleProfileIds: {'default'},
      eventsByProfile: {
        'default': [localNote],
      },
      schedulesByProfile: const {},
      templatesByProfile: const {},
      requestsByProfile: const {},
    );
    final remote = LocalDataSnapshot(
      profiles: const [mainProfile],
      activeProfileId: 'default',
      visibleProfileIds: {'default'},
      eventsByProfile: {
        'default': [remoteNote],
      },
      schedulesByProfile: const {},
      templatesByProfile: const {},
      requestsByProfile: const {},
    );

    final merged = local.unionProfile(remote, 'default');
    final ids = merged.eventsByProfile['default']!.map((event) => event.id);

    expect(ids, containsAll(['local-note', 'remote-note']));
    expect(local.hasSameProfileEntryIds(merged, 'default'), isFalse);
  });

  test('profileIdsSharingConnection skips profiles without that API', () {
    const work = PlatformConfig(
      profileId: 'work',
      apiKey: 'work-key',
      serverBaseUrl: 'http://192.168.10.100:8080',
    );
    const personal = PlatformConfig(
      profileId: 'personal',
      apiKey: 'personal-key',
    );
    final snapshot = LocalDataSnapshot(
      profiles: const [mainProfile, workProfile],
      activeProfileId: 'work',
      visibleProfileIds: {'default', 'work'},
      eventsByProfile: const {},
      schedulesByProfile: const {},
      templatesByProfile: const {},
      requestsByProfile: const {},
      platformConfigsByProfile: const {'work': work, 'personal': personal},
    );

    expect(snapshot.profileIdsSharingConnection(work), {'work'});
    expect(
      snapshot.sliceForProfiles({'work'}).profiles.map((profile) => profile.id),
      ['work'],
    );
  });
}
