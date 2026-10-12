import 'package:flutter_test/flutter_test.dart';
import 'package:almanac/booking/booking_repository.dart';
import 'package:almanac/booking/booking_types.dart';
import 'package:almanac/calendar/calendar_types.dart';
import 'package:almanac/data/events/event_repository.dart';
import 'package:almanac/data/profiles/profile_scoped_repositories.dart';
import 'package:kalender/kalender.dart';
import 'package:flutter/material.dart';

AppEvent _sampleEvent(String id) {
  final start = DateTime(2026, 7, 1, 10);
  return AppEvent(
    id: id,
    dateTimeRange: DateTimeRange(
      start: start,
      end: start.add(const Duration(hours: 1)),
    ),
    title: 'Event $id',
    startTime: '10:00',
    endTime: '11:00',
    color: Colors.blue,
    interaction: EventInteraction.allowNone(),
  );
}

void main() {
  group('Profile data isolation', () {
    late InMemoryEventRepository eventRepo;
    late InMemoryBookingRepository bookingRepo;

    setUp(() {
      eventRepo = InMemoryEventRepository();
      bookingRepo = InMemoryBookingRepository();
    });

    test('events are isolated per profile', () {
      final defaultCount = eventRepo
          .getMasterEvents(profileId: 'default')
          .length;

      eventRepo.addEvent(profileId: 'work', event: _sampleEvent('b'));

      expect(
        eventRepo.getMasterEvents(profileId: 'default').length,
        defaultCount,
      );
      expect(eventRepo.getMasterEvents(profileId: 'work').length, 1);
      expect(
        eventRepo.getMasterEvents(profileId: 'work').first.title,
        'Event b',
      );
    });

    test('deleting profile removes its events', () {
      eventRepo.ensureProfile('work');
      eventRepo.addEvent(profileId: 'work', event: _sampleEvent('x'));

      eventRepo.deleteProfileData('work');

      eventRepo.ensureProfile('work');
      expect(eventRepo.getMasterEvents(profileId: 'work'), isEmpty);
    });

    test('booking requests are isolated per profile', () {
      bookingRepo.ensureProfile('work');

      final defaultSlots = bookingRepo.getSlots(
        profileId: 'default',
        templateToken: 'demo',
        day: DateTime(2026, 7, 10),
      );
      final workSlots = bookingRepo.getSlots(
        profileId: 'work',
        templateToken: 'demo',
        day: DateTime(2026, 7, 10),
      );

      expect(defaultSlots, isNotEmpty);
      expect(workSlots, isEmpty);

      final slot = defaultSlots.firstWhere((s) => s.available);
      bookingRepo.createRequest(
        profileId: 'default',
        templateToken: 'demo',
        start: slot.start,
        end: slot.end,
        confirmationMode: BookingConfirmationMode.manual,
      );

      expect(
        bookingRepo.getPendingRequests(profileId: 'default').length,
        greaterThan(1),
      );
      expect(bookingRepo.getPendingRequests(profileId: 'work'), isEmpty);
    });

    test('global token lookup resolves profile', () {
      final lookup = bookingRepo.findTemplateByTokenGlobally('demo');

      expect(lookup, isNotNull);
      expect(lookup!.profileId, 'default');
      expect(lookup.template.token, 'demo');
    });

    test('deleting profile removes booking data', () {
      bookingRepo.ensureProfile('work');
      bookingRepo.deleteProfileData('work');
      bookingRepo.ensureProfile('work');

      expect(
        bookingRepo.findTemplateByToken(profileId: 'work', token: 'demo'),
        isNull,
      );
    });

    test('combined repository merges events from visible profiles', () {
      eventRepo.addEvent(
        profileId: 'default',
        event: _sampleEvent('only-default'),
      );

      eventRepo.ensureProfile('work');
      eventRepo.addEvent(profileId: 'work', event: _sampleEvent('only-work'));

      final combined = CombinedEventRepository(eventRepo, {'default', 'work'});

      final merged = combined.getEventsForRange(
        rangeStart: DateTime(2026, 7, 1),
        rangeEnd: DateTime(2026, 8, 1),
      );

      expect(merged.any((e) => e.id.contains('only-default')), isTrue);
      expect(merged.any((e) => e.id.contains('only-work')), isTrue);
      expect(merged.every((e) => e.contextProfileId != null), isTrue);
    });
  });
}
