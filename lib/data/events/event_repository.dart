import 'calendar_entry_expander.dart';
import '../../calendar/calendar_types.dart';
import '../../calendar/test_events.dart';
import '../schedules/cyclic_schedule_generator.dart';
import '../schedules/cyclic_work_schedule_repository.dart';
import '../local/persisted_repository.dart';

abstract interface class EventRepository {
  void ensureProfile(String profileId);

  /// Удаляет все события профиля.
  void deleteProfileData(String profileId);

  /// Мастер-события (без развёртывания повторений), включая расписания.
  List<AppEvent> getMasterEvents({required String profileId});

  List<AppEvent> getEventsForYear({
    required String profileId,
    required int year,
  });

  /// События с развёрнутыми повторениями для диапазона [rangeStart, rangeEnd).
  List<AppEvent> getEventsForRange({
    required String profileId,
    required DateTime rangeStart,
    required DateTime rangeEnd,
  });

  /// Заметки и чек-листы без даты (Inbox).
  List<AppEvent> getUndatedEvents({required String profileId});

  void addEvent({required String profileId, required AppEvent event});

  void updateEvent({
    required String profileId,
    required AppEvent event,
    required AppEvent updatedEvent,
  });

  void deleteEvent({required String profileId, required String eventId});

  /// Сохраняет переопределение одного дня расписания.
  void upsertScheduleOverride({
    required String profileId,
    required AppEvent override,
  });

  /// Удаляет все переопределения дней для правила [scheduleId].
  void deleteScheduleOverrides({
    required String profileId,
    required String scheduleId,
  });
}

class InMemoryEventRepository
    with PersistedRepository
    implements EventRepository {
  InMemoryEventRepository({
    CyclicWorkScheduleRepository? scheduleRepository,
    this.seedDemoData = true,
  }) : _scheduleRepository =
           scheduleRepository ?? InMemoryCyclicWorkScheduleRepository();

  final CyclicWorkScheduleRepository _scheduleRepository;
  final bool seedDemoData;
  final _eventsByProfile = <String, List<AppEvent>>{};

  Map<String, List<AppEvent>> exportEventsByProfile() {
    return _eventsByProfile.map(
      (profileId, events) => MapEntry(profileId, List<AppEvent>.from(events)),
    );
  }

  void restoreEventsByProfile(Map<String, List<AppEvent>> data) {
    _eventsByProfile
      ..clear()
      ..addAll(
        data.map(
          (profileId, events) =>
              MapEntry(profileId, List<AppEvent>.from(events)),
        ),
      );
  }

  List<AppEvent> _eventsFor(String profileId) {
    return _eventsByProfile.putIfAbsent(profileId, () => []);
  }

  List<AppEvent> _storedMasterEvents(String profileId) {
    ensureProfile(profileId);
    return List.unmodifiable(_eventsFor(profileId));
  }

  List<AppEvent> _scheduleMasterEvents(String profileId) {
    _scheduleRepository.ensureProfile(profileId);
    return CyclicScheduleEventGenerator.masterEvents(
      _scheduleRepository.getForProfile(profileId),
    );
  }

  @override
  void ensureProfile(String profileId) {
    if (_eventsByProfile.containsKey(profileId)) return;
    _scheduleRepository.ensureProfile(profileId);
    _eventsByProfile[profileId] = seedDemoData && profileId == 'default'
        ? TestEvents.currentYear()
        : <AppEvent>[];
    notifyChanged();
  }

  @override
  void deleteProfileData(String profileId) {
    _eventsByProfile.remove(profileId);
    _scheduleRepository.deleteProfileData(profileId);
    notifyChanged();
  }

  @override
  List<AppEvent> getMasterEvents({required String profileId}) {
    return [
      ..._storedMasterEvents(profileId),
      ..._scheduleMasterEvents(profileId),
    ];
  }

  @override
  List<AppEvent> getEventsForYear({
    required String profileId,
    required int year,
  }) {
    final rangeStart = DateTime(year, 1, 1);
    final rangeEnd = DateTime(year + 1, 1, 1);
    return getEventsForRange(
      profileId: profileId,
      rangeStart: rangeStart,
      rangeEnd: rangeEnd,
    );
  }

  @override
  List<AppEvent> getEventsForRange({
    required String profileId,
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) {
    ensureProfile(profileId);

    return CalendarEntryExpander.expandProfile(
      storedMasters: _eventsFor(profileId),
      schedules: _scheduleRepository.getForProfile(profileId),
      rangeStart: rangeStart,
      rangeEnd: rangeEnd,
    );
  }

  @override
  List<AppEvent> getUndatedEvents({required String profileId}) {
    ensureProfile(profileId);
    return [
      for (final event in _eventsFor(profileId))
        if (event.isUndated) event,
    ];
  }

  @override
  void addEvent({required String profileId, required AppEvent event}) {
    ensureProfile(profileId);
    final master = event.hasRecurrence
        ? event.copyWith(seriesId: event.seriesId ?? event.id)
        : event;
    _eventsFor(profileId).add(master);
    notifyChanged();
  }

  @override
  void updateEvent({
    required String profileId,
    required AppEvent event,
    required AppEvent updatedEvent,
  }) {
    ensureProfile(profileId);
    final events = _eventsFor(profileId);

    final lookupId = event.isRecurrenceOccurrence
        ? (event.seriesId ?? event.id.split('-').first)
        : event.id;

    if (event.entrySource == CalendarEntrySource.scheduleGenerated) {
      return;
    }

    final index = events.indexWhere(
      (e) => e.id == lookupId || e.seriesId == lookupId,
    );
    if (index == -1) return;

    final master = updatedEvent.isRecurrenceOccurrence
        ? updatedEvent.copyWith(
            id: lookupId,
            seriesId: lookupId,
            isRecurrenceOccurrence: false,
          )
        : updatedEvent.copyWith(seriesId: updatedEvent.seriesId ?? lookupId);

    events[index] = master;
    notifyChanged();
  }

  @override
  void deleteEvent({required String profileId, required String eventId}) {
    ensureProfile(profileId);
    final events = _eventsFor(profileId);
    if (events.any(
      (event) =>
          (event.id == eventId || event.seriesId == eventId) &&
          event.entrySource == CalendarEntrySource.scheduleGenerated,
    )) {
      return;
    }
    events.removeWhere((e) => e.id == eventId || e.seriesId == eventId);
    notifyChanged();
  }

  @override
  void upsertScheduleOverride({
    required String profileId,
    required AppEvent override,
  }) {
    ensureProfile(profileId);
    final events = _eventsFor(profileId);
    final index = events.indexWhere((event) => event.id == override.id);
    if (index == -1) {
      events.add(override);
    } else {
      events[index] = override;
    }
    notifyChanged();
  }

  @override
  void deleteScheduleOverrides({
    required String profileId,
    required String scheduleId,
  }) {
    ensureProfile(profileId);
    final events = _eventsFor(profileId);
    events.removeWhere(
      (event) =>
          event.entrySource == CalendarEntrySource.scheduleOverride &&
          event.workScheduleId == scheduleId,
    );
    notifyChanged();
  }
}
