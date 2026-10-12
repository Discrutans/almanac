import 'package:flutter_test/flutter_test.dart';
import 'package:almanac/data/profiles/profile_kind.dart';

void main() {
  test('personal can create and edit locally', () {
    const access = ProfileAccess(ProfileKind.personal, ProfileRole.owner);
    expect(access.canCreateEvents, isTrue);
    expect(access.showSyncSettings, isFalse);
    expect(access.needsEventLocks, isFalse);
  });

  test('collaborative members can edit events and need locks', () {
    const access = ProfileAccess(ProfileKind.collaborative, ProfileRole.member);
    expect(access.canCreateEvents, isTrue);
    expect(access.canEditEvents, isTrue);
    expect(access.needsEventLocks, isTrue);
    expect(access.showSyncSettings, isTrue);
    expect(access.canJoinBooking, isTrue);
    expect(access.canBookOnly, isFalse);
    expect(access.canCreateBookingSlots, isFalse);
    expect(access.canCancelOwnBooking, isTrue);
  });

  test('collaborative owner can publish booking slots', () {
    const access = ProfileAccess(ProfileKind.collaborative, ProfileRole.owner);
    expect(access.canCreateEvents, isTrue);
    expect(access.canCreateBookingSlots, isTrue);
    expect(access.canJoinBooking, isTrue);
    expect(access.canBookOnly, isFalse);
    expect(access.canSeeOwnerInbox, isTrue);
    expect(access.canReleaseBooking, isTrue);
    expect(access.canShareWorkspaceInvite, isTrue);
  });

  test('booking members can only book', () {
    const access = ProfileAccess(ProfileKind.booking, ProfileRole.member);
    expect(access.canCreateEvents, isFalse);
    expect(access.canEditEvents, isFalse);
    expect(access.canCreateBookingSlots, isFalse);
    expect(access.canBookOnly, isTrue);
    expect(access.canJoinBooking, isTrue);
    expect(access.canSeeOwnerInbox, isFalse);
    expect(access.needsEventLocks, isTrue);
    expect(access.canCancelOwnBooking, isTrue);
    expect(access.canConfigureWorkspace, isFalse);
    expect(access.canShareWorkspaceInvite, isFalse);
    expect(access.canMutateLocalCalendarData, isFalse);
  });

  test('booking owner manages slots and events', () {
    const access = ProfileAccess(ProfileKind.booking, ProfileRole.owner);
    expect(access.canCreateEvents, isTrue);
    expect(access.canCreateBookingSlots, isTrue);
    expect(access.canBookOnly, isFalse);
    expect(access.canSeeOwnerInbox, isTrue);
    expect(access.canReleaseBooking, isTrue);
    expect(access.canConfigureWorkspace, isTrue);
    expect(access.canShareWorkspaceInvite, isTrue);
  });

  test('collaborative members cannot reconfigure the shared database', () {
    const access = ProfileAccess(ProfileKind.collaborative, ProfileRole.member);
    expect(access.canConfigureWorkspace, isFalse);
    expect(access.canShareWorkspaceInvite, isFalse);
    expect(access.canMutateLocalCalendarData, isFalse);
    expect(access.canCreateEvents, isTrue);
  });
}
