import 'package:almanac/booking/booking_repository.dart';
import 'package:almanac/booking/booking_types.dart';
import 'package:almanac/data/profiles/profile_scoped_repositories.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('pending booking inbox flow', () {
    late InMemoryBookingRepository repo;

    setUp(() {
      repo = InMemoryBookingRepository(seedDemoData: false);
      repo.ensureProfile('owner');
      repo.createTemplate(
        profileId: 'owner',
        title: 'Consult',
        duration: const Duration(minutes: 60),
        confirmationMode: BookingConfirmationMode.manual,
      );
    });

    test('create → pending list → confirm removes from pending', () {
      final template = repo.listTemplates(profileId: 'owner').single;
      final start = DateTime(2026, 7, 10, 11);
      final request = repo.createRequest(
        profileId: 'owner',
        templateToken: template.token,
        start: start,
        end: start.add(const Duration(hours: 1)),
        confirmationMode: BookingConfirmationMode.manual,
      );

      expect(request.status, BookingRequestStatus.pending);
      expect(getPendingRequestsForProfiles(repo, {'owner'}), hasLength(1));

      final confirmed = repo.updateRequestStatus(
        profileId: 'owner',
        requestId: request.id,
        status: BookingRequestStatus.confirmed,
      );
      expect(confirmed.status, BookingRequestStatus.confirmed);
      expect(getPendingRequestsForProfiles(repo, {'owner'}), isEmpty);
    });

    test('reject clears pending across visible profiles merge', () {
      repo.ensureProfile('other');
      final template = repo.listTemplates(profileId: 'owner').single;
      final start = DateTime(2026, 7, 11, 9);
      final request = repo.createRequest(
        profileId: 'owner',
        templateToken: template.token,
        start: start,
        end: start.add(const Duration(hours: 1)),
        confirmationMode: BookingConfirmationMode.manual,
      );

      expect(
        getPendingRequestsForProfiles(repo, {'owner', 'other'}),
        hasLength(1),
      );

      repo.updateRequestStatus(
        profileId: 'owner',
        requestId: request.id,
        status: BookingRequestStatus.rejected,
      );
      expect(getPendingRequestsForProfiles(repo, {'owner', 'other'}), isEmpty);
    });
  });
}
