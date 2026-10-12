import 'package:flutter_test/flutter_test.dart';
import 'package:almanac/booking/booking_types.dart';
import 'package:almanac/platform/almanac_platform_api.dart';
import 'package:almanac/platform/group_plan_repository.dart';
import 'package:almanac/platform/group_plan_types.dart';
import 'package:almanac/platform/platform_config_repository.dart';
import 'package:almanac/platform/platform_types.dart';
import 'package:almanac/booking/booking_repository.dart';

void main() {
  late InMemoryBookingRepository bookingRepo;
  late InMemoryGroupPlanRepository groupPlanRepo;
  late InMemoryPlatformConfigRepository platformConfigRepo;
  late LocalAlmanacPlatformApi api;

  setUp(() {
    bookingRepo = InMemoryBookingRepository();
    groupPlanRepo = InMemoryGroupPlanRepository();
    platformConfigRepo = InMemoryPlatformConfigRepository();
    api = LocalAlmanacPlatformApi(
      bookingRepository: bookingRepo,
      groupPlanRepository: groupPlanRepo,
      platformConfigRepository: platformConfigRepo,
    );
  });

  test('creates workspace with api key', () {
    final config = api.getWorkspace(profileId: 'default');
    expect(config.profileId, 'default');
    expect(config.apiKey, isNotEmpty);
  });

  test('creates booking template and resolves by token', () {
    final template = api.createBookingTemplate(
      profileId: 'default',
      title: 'Test booking',
      duration: const Duration(minutes: 30),
      confirmationMode: BookingConfirmationMode.automatic,
    );

    final lookup = api.resolveBookingByToken(template.token);
    expect(lookup, isNotNull);
    expect(lookup!.template.title, 'Test booking');
  });

  test('creates group plan and accepts votes', () {
    final slots = buildPlanSlots(
      startDay: DateTime(2026, 6, 25),
      dayCount: 3,
      hour: 18,
      minute: 0,
      duration: const Duration(hours: 1),
    );

    final plan = api.createGroupPlan(
      profileId: 'default',
      title: 'Team sync',
      slots: slots,
    );

    expect(plan.slots, hasLength(3));
    expect(plan.token, isNotEmpty);

    final vote = api.submitGroupPlanVote(
      profileId: 'default',
      token: plan.token,
      participantName: 'Alice',
      slotIds: [plan.slots.first.id, plan.slots.last.id],
    );

    expect(vote.participantName, 'Alice');
    expect(vote.slotIds, hasLength(2));

    final resolved = api.resolveGroupPlanByToken(plan.token);
    expect(resolved!.plan.votes, hasLength(1));
    expect(resolved.plan.voteCountsBySlot()[plan.slots.first.id], 1);
  });

  test('lists public links for profile', () {
    api.createBookingTemplate(
      profileId: 'default',
      title: 'Booking',
      duration: const Duration(minutes: 60),
      confirmationMode: BookingConfirmationMode.manual,
    );

    final slots = buildPlanSlots(
      startDay: DateTime(2026, 7, 1),
      dayCount: 2,
      hour: 10,
      minute: 0,
      duration: const Duration(minutes: 45),
    );

    api.createGroupPlan(profileId: 'default', title: 'Plan', slots: slots);

    final links = api.listPublicLinks(profileId: 'default');
    expect(links.length, greaterThanOrEqualTo(2)); // demo + new booking
    expect(links.any((l) => l.path.startsWith('/book/')), isTrue);
    expect(links.any((l) => l.path.startsWith('/plan/')), isFalse);
  });

  test('group plan persists vote counts after close', () {
    final slots = buildPlanSlots(
      startDay: DateTime(2026, 8, 1),
      dayCount: 2,
      hour: 12,
      minute: 0,
      duration: const Duration(hours: 1),
    );

    final plan = groupPlanRepo.createPlan(
      profileId: 'default',
      title: 'Close test',
      slots: slots,
    );

    groupPlanRepo.submitVote(
      profileId: 'default',
      token: plan.token,
      participantName: 'Bob',
      slotIds: [slots.first.id],
    );

    final closed = groupPlanRepo.closePlan(
      profileId: 'default',
      token: plan.token,
      selectedSlotId: slots.first.id,
    );

    expect(closed.status, GroupPlanStatus.closed);
    expect(closed.selectedSlotId, slots.first.id);
  });

  test('connection settings stay on one profile and do not copy to others', () {
    const customKey = '11111111-1111-1111-1111-111111111111';
    platformConfigRepo.updateConnectionSettings(
      profileId: 'default',
      serverBaseUrl: 'http://192.168.10.100:8080',
      apiKey: customKey,
      workspaceProfileId: 'default',
    );

    final extra = platformConfigRepo.getOrCreateConfig(profileId: 'profile-2');
    expect(extra.profileId, 'profile-2');
    expect(extra.serverBaseUrl, isEmpty);
    expect(extra.apiKey, isNot(customKey));

    final afterRenameField = platformConfigRepo.updateConnectionSettings(
      profileId: extra.profileId,
      serverBaseUrl: 'http://192.168.10.100:8080',
      apiKey: customKey,
      workspaceProfileId: 'default',
    );
    expect(afterRenameField.profileId, 'default');
    expect(afterRenameField.apiKey, customKey);
    expect(
      platformConfigRepo.getOrCreateConfig(profileId: 'default').apiKey,
      customKey,
    );
    expect(
      platformConfigRepo
          .getOrCreateConfig(profileId: extra.profileId)
          .profileId,
      'default',
    );
  });

  test('keeps HTTP workspace id on a local profile map key', () {
    platformConfigRepo.restore(
      configsByProfile: {
        'profile-2': const PlatformConfig(
          profileId: 'default',
          apiKey: '22222222-2222-2222-2222-222222222222',
          serverBaseUrl: 'http://192.168.10.100:8080',
        ),
      },
    );

    final stored = platformConfigRepo.getOrCreateConfig(profileId: 'profile-2');
    expect(stored.profileId, 'default');
    expect(stored.serverBaseUrl, 'http://192.168.10.100:8080');
  });

  test('idsSharingConnectionWith ignores profiles without that API', () {
    platformConfigRepo.updateConnectionSettings(
      profileId: 'work',
      serverBaseUrl: 'http://192.168.10.100:8080',
      apiKey: 'work-key',
      workspaceProfileId: 'work',
    );
    platformConfigRepo.getOrCreateConfig(profileId: 'personal');

    expect(platformConfigRepo.idsSharingConnectionWith('work'), {'work'});
  });

  test('sync preferences default on and persist per profile', () {
    final created = platformConfigRepo.getOrCreateConfig(profileId: 'work');
    expect(created.autoPush, isTrue);
    expect(created.autoPull, isTrue);
    expect(created.notificationsEnabled, isTrue);

    platformConfigRepo.updateSyncPreferences(
      profileId: 'work',
      autoPush: false,
      autoPull: false,
      notificationsEnabled: false,
    );
    final work = platformConfigRepo.getOrCreateConfig(profileId: 'work');
    expect(work.autoPush, isFalse);
    expect(work.autoPull, isFalse);
    expect(work.notificationsEnabled, isFalse);

    final personal = platformConfigRepo.getOrCreateConfig(
      profileId: 'personal',
    );
    expect(personal.autoPush, isTrue);
    expect(personal.notificationsEnabled, isTrue);
  });

  test('legacy platform config JSON keeps auto-sync and notifications on', () {
    final restored = PlatformConfig.fromJson({
      'profileId': 'default',
      'apiKey': 'key',
      'serverBaseUrl': 'http://192.168.10.100:8080',
    });
    expect(restored.autoPush, isTrue);
    expect(restored.autoPull, isTrue);
    expect(restored.notificationsEnabled, isTrue);

    final encoded = restored
        .copyWith(autoPush: false, notificationsEnabled: false)
        .toJson();
    final roundTrip = PlatformConfig.fromJson(encoded);
    expect(roundTrip.autoPush, isFalse);
    expect(roundTrip.autoPull, isTrue);
    expect(roundTrip.notificationsEnabled, isFalse);
  });
}
