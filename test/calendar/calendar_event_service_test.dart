import 'package:almanac/calendar/calendar_entry_capabilities.dart';
import 'package:almanac/calendar/shift_quick_actions.dart';
import 'package:almanac/calendar/calendar_types.dart';
import 'package:almanac/calendar/services/calendar_event_service.dart';
import 'package:almanac/data/events/event_repository.dart';
import 'package:almanac/data/events/recurrence_engine.dart';
import 'package:almanac/data/profiles/profile_scoped_repositories.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('persistEditedEvent saves schedule override for work shift', () {
    final eventRepo = InMemoryEventRepository();
    const profileId = 'profile-1';
    eventRepo.ensureProfile(profileId);

    final service = CalendarEventService(
      eventRepository: eventRepo,
      combinedRepository: CombinedEventRepository(eventRepo, {profileId}),
      activeProfileId: profileId,
    );

    final day = DateTime(2025, 1, 1);
    final source = AppEvent(
      id: 'schedule-abc-${day.millisecondsSinceEpoch}',
      dateTimeRange: DateTimeRange(
        start: DateTime(2025, 1, 1, 8),
        end: DateTime(2025, 1, 1, 20),
      ),
      title: 'Смена',
      startTime: '08:00',
      endTime: '20:00',
      color: Colors.teal,
      seriesId: 'schedule-abc',
      contextProfileId: profileId,
    );

    final updated = source.copyWith(
      endTime: '22:00',
      dateTimeRange: DateTimeRange(
        start: DateTime(2025, 1, 1, 8),
        end: DateTime(2025, 1, 1, 22),
      ),
      overtimeMinutes: 120,
    );

    service.persistEditedEvent(original: source, updated: updated);

    final masters = eventRepo.getMasterEvents(profileId: profileId);
    expect(masters, hasLength(1));
    expect(masters.first.isScheduleOccurrenceOverride, isTrue);
    expect(masters.first.overtimeMinutes, 120);
    expect(masters.first.endTime, '22:00');
  });

  test('persistEditedEvent saves notes on schedule override', () {
    final eventRepo = InMemoryEventRepository();
    const profileId = 'profile-1';
    eventRepo.ensureProfile(profileId);

    final service = CalendarEventService(
      eventRepository: eventRepo,
      combinedRepository: CombinedEventRepository(eventRepo, {profileId}),
      activeProfileId: profileId,
    );

    final day = DateTime(2025, 1, 1);
    final source = AppEvent(
      id: 'schedule-abc-${day.millisecondsSinceEpoch}',
      dateTimeRange: DateTimeRange(
        start: DateTime(2025, 1, 1, 8),
        end: DateTime(2025, 1, 1, 20),
      ),
      title: 'Смена',
      startTime: '08:00',
      endTime: '20:00',
      color: Colors.teal,
      seriesId: 'schedule-abc',
      contextProfileId: profileId,
    );

    service.persistEditedEvent(
      original: source,
      updated: source.copyWith(notes: 'Заметка на смену'),
    );

    final masters = eventRepo.getMasterEvents(profileId: profileId);
    expect(masters, hasLength(1));
    expect(masters.first.notes, 'Заметка на смену');
  });

  test('detachRecurrenceOccurrence excludes day and creates single event', () {
    final eventRepo = InMemoryEventRepository();
    const profileId = 'profile-1';
    eventRepo.ensureProfile(profileId);

    final service = CalendarEventService(
      eventRepository: eventRepo,
      combinedRepository: CombinedEventRepository(eventRepo, {profileId}),
      activeProfileId: profileId,
    );

    const masterId = 'event-series';
    final master = AppEvent(
      id: masterId,
      dateTimeRange: DateTimeRange(
        start: DateTime(2025, 1, 1, 9),
        end: DateTime(2025, 1, 1, 10),
      ),
      title: 'Daily',
      startTime: '09:00',
      endTime: '10:00',
      color: Colors.blue,
      rrule: 'FREQ=DAILY;INTERVAL=1',
      seriesId: masterId,
    );
    eventRepo.addEvent(profileId: profileId, event: master);

    final occurrence = master.copyWith(
      id: '$masterId-${DateTime(2025, 1, 3, 9).millisecondsSinceEpoch}',
      dateTimeRange: DateTimeRange(
        start: DateTime(2025, 1, 3, 9),
        end: DateTime(2025, 1, 3, 10),
      ),
      isRecurrenceOccurrence: true,
    );

    service.persistEditedEvent(
      original: occurrence,
      updated: occurrence.copyWith(title: 'Only Wednesday'),
      recurrenceScope: RecurrenceEditScope.thisOccurrenceOnly,
    );

    final masters = eventRepo.getMasterEvents(profileId: profileId);
    expect(masters, hasLength(2));
    final updatedMaster = masters.firstWhere((event) => event.id == masterId);
    expect(updatedMaster.recurrenceExclusions, hasLength(1));

    final detached = masters.firstWhere((event) => event.id != masterId);
    expect(detached.title, 'Only Wednesday');
    expect(detached.rrule, isNull);
    expect(detached.isRecurrenceOccurrence, isFalse);

    final expanded = RecurrenceEngine.expandEvent(
      updatedMaster,
      rangeStart: DateTime(2025, 1, 1),
      rangeEnd: DateTime(2025, 1, 6),
    );
    expect(expanded.any((event) => event.start.day == 3), isFalse);
  });

  test('applyShiftQuickAction toggles skip and adds overtime', () {
    final eventRepo = InMemoryEventRepository();
    const profileId = 'profile-1';
    eventRepo.ensureProfile(profileId);

    final service = CalendarEventService(
      eventRepository: eventRepo,
      combinedRepository: CombinedEventRepository(eventRepo, {profileId}),
      activeProfileId: profileId,
    );

    final day = DateTime(2025, 1, 1);
    final source = AppEvent(
      id: 'schedule-abc-${day.millisecondsSinceEpoch}',
      dateTimeRange: DateTimeRange(
        start: DateTime(2025, 1, 1, 8),
        end: DateTime(2025, 1, 1, 20),
      ),
      title: 'Смена',
      startTime: '08:00',
      endTime: '20:00',
      color: Colors.teal,
      seriesId: 'schedule-abc',
      contextProfileId: profileId,
    );

    service.applyShiftQuickAction(
      source: source,
      action: ShiftQuickAction.toggleSkip,
    );

    var override = eventRepo.getMasterEvents(profileId: profileId).single;
    expect(override.shiftSkipped, isTrue);

    service.applyShiftQuickAction(
      source: override,
      action: ShiftQuickAction.addOvertime30,
    );

    override = eventRepo.getMasterEvents(profileId: profileId).single;
    expect(override.shiftSkipped, isTrue);
    expect(override.overtimeMinutes, isNull);

    service.applyShiftQuickAction(
      source: override,
      action: ShiftQuickAction.toggleSkip,
    );

    override = eventRepo.getMasterEvents(profileId: profileId).single;
    expect(override.shiftSkipped, isFalse);

    service.applyShiftQuickAction(
      source: override,
      action: ShiftQuickAction.addOvertime30,
    );

    override = eventRepo.getMasterEvents(profileId: profileId).single;
    expect(override.overtimeMinutes, 30);
  });

  test('deleteEntry blocks schedule generated and override entries', () {
    final eventRepo = InMemoryEventRepository();
    const profileId = 'profile-1';
    eventRepo.ensureProfile(profileId);

    final service = CalendarEventService(
      eventRepository: eventRepo,
      combinedRepository: CombinedEventRepository(eventRepo, {profileId}),
      activeProfileId: profileId,
    );

    final day = DateTime(2025, 1, 1);
    final generated = AppEvent(
      id: 'schedule-abc-${day.millisecondsSinceEpoch}',
      dateTimeRange: DateTimeRange(
        start: DateTime(2025, 1, 1, 8),
        end: DateTime(2025, 1, 1, 20),
      ),
      title: 'Смена',
      startTime: '08:00',
      endTime: '20:00',
      color: Colors.teal,
      seriesId: 'schedule-abc',
    );
    final override = generated.copyWith(
      id: AppEvent.scheduleOverrideId('abc', day),
      notes: 'note',
    );
    eventRepo.upsertScheduleOverride(profileId: profileId, override: override);

    expect(service.deleteEntry(generated), DeleteEntryResult.blockedSchedule);
    expect(service.deleteEntry(override), DeleteEntryResult.blockedNeedsRevert);
    expect(eventRepo.getMasterEvents(profileId: profileId), hasLength(1));
  });
}
