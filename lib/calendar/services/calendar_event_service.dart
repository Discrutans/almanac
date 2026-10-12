import 'package:flutter/material.dart';
import '../../core/ui/almanac_time_field.dart';
import '../../data/events/event_repository.dart';
import '../../data/profiles/profile_scoped_repositories.dart';
import '../../data/events/recurrence_engine.dart';
import '../../data/events/recurrence_exdate.dart';
import '../calendar_entry_capabilities.dart';
import '../calendar_types.dart';
import '../shift_quick_actions.dart';
import '../event_time_utils.dart';

enum WeekEventPersistKind {
  personalUpdated,
  overrideCreated,
  overrideUpdated,
  occurrenceDetached,
}

/// Снимок переноса на сетке — для Undo.
class WeekEventMoveResult {
  const WeekEventMoveResult({
    required this.original,
    required this.persisted,
    required this.kind,
    this.seriesMasterBefore,
  });

  final AppEvent original;
  final AppEvent persisted;
  final WeekEventPersistKind kind;
  final AppEvent? seriesMasterBefore;
}

/// Операции с событиями календаря (слой domain/application).
///
/// Отделяет работу с репозиториями от виджетов [CalendarScreen]
/// и диалогов создания/редактирования.
class CalendarEventService {
  const CalendarEventService({
    required this.eventRepository,
    required this.combinedRepository,
    required this.activeProfileId,
  });

  final EventRepository eventRepository;
  final CombinedEventRepository combinedRepository;
  final String activeProfileId;

  /// Репозиторий профиля, к которому относится [event].
  ProfileScopedEventRepository repoFor(AppEvent event) {
    final profileId = event.contextProfileId ?? activeProfileId;
    return ProfileScopedEventRepository(eventRepository, profileId);
  }

  /// События для проверки пересечений по времени.
  List<AppEvent> conflictMasters() =>
      combinedRepository.getMasterEventsForConflict();

  /// Создаёт личное событие в активном профиле.
  void createPersonalEvent(
    AppEvent event,
    ProfileScopedEventRepository profileRepo,
  ) {
    profileRepo.addEvent(event);
  }

  /// Обновляет личное или повторяющееся событие.
  void updatePersonalEvent({
    required AppEvent source,
    required AppEvent updated,
  }) {
    final repo = repoFor(source);
    final masterId = source.isRecurrenceOccurrence
        ? (source.seriesId ?? source.id)
        : source.id;
    final master = repo.getMasterEvents().firstWhere(
      (event) => event.id == masterId,
      orElse: () => source,
    );

    repo.updateEvent(
      event: master,
      updatedEvent: updated.copyWith(
        id: master.id,
        seriesId: master.seriesId ?? master.id,
        isRecurrenceOccurrence: false,
        contextProfileId: updated.contextProfileId,
      ),
    );
  }

  /// Сохраняет переопределение одного дня смены/расписания.
  void saveScheduleOverride({
    required AppEvent source,
    required AppEvent updated,
  }) {
    final scheduleId = source.workScheduleId;
    if (scheduleId == null) return;

    final profileId = source.contextProfileId ?? activeProfileId;
    final occurrenceDate =
        AppEvent.scheduleOverrideDateFromId(source.id) ?? source.start;
    final override = updated
        .copyWith(
          id: AppEvent.scheduleOverrideId(scheduleId, occurrenceDate),
          seriesId: 'schedule-$scheduleId',
          isRecurrenceOccurrence: false,
          contextProfileId: profileId,
        )
        .taggedWith(CalendarEntrySource.scheduleOverride);

    repoFor(source).upsertScheduleOverride(override);
  }

  /// Удаляет личное событие (смены расписания удалять нельзя).
  void deletePersonalEvent(AppEvent event) {
    if (event.entrySource.isScheduleRelated) return;

    final repo = repoFor(event);
    final masterId = event.isRecurrenceOccurrence
        ? (event.seriesId ?? event.id)
        : event.id;
    repo.deleteEvent(masterId);
  }

  /// Сбрасывает переопределение одного дня смены.
  bool revertScheduleOverride(AppEvent event) {
    if (!event.capabilities.canRevertOverride) return false;
    repoFor(event).deleteEvent(event.id);
    return true;
  }

  /// Единая точка удаления записи из UI.
  DeleteEntryResult deleteEntry(AppEvent event) {
    if (event.isSavingsGoal) {
      return DeleteEntryResult.blockedSchedule;
    }
    if (event.entrySource == CalendarEntrySource.scheduleOverride) {
      return DeleteEntryResult.blockedNeedsRevert;
    }
    if (event.entrySource == CalendarEntrySource.scheduleGenerated) {
      return DeleteEntryResult.blockedSchedule;
    }
    deletePersonalEvent(event);
    return DeleteEntryResult.deleted;
  }

  /// Удаляет все переопределения дней смены для правила расписания.
  void deleteScheduleOverrides({
    required String profileId,
    required String scheduleId,
  }) {
    eventRepository.deleteScheduleOverrides(
      profileId: profileId,
      scheduleId: scheduleId,
    );
  }

  /// Маршрутизирует сохранение: смена → override, иначе update.
  void persistEditedEvent({
    required AppEvent original,
    required AppEvent updated,
    RecurrenceEditScope recurrenceScope = RecurrenceEditScope.wholeSeries,
  }) {
    if (recurrenceScope == RecurrenceEditScope.thisOccurrenceOnly &&
        (original.isRecurrenceOccurrence || original.hasRecurrence)) {
      detachRecurrenceOccurrence(original: original, updated: updated);
      return;
    }
    if (original.capabilities.editsCreateScheduleOverride) {
      saveScheduleOverride(source: original, updated: updated);
      return;
    }
    updatePersonalEvent(source: original, updated: updated);
  }

  /// Отвязывает одно вхождение серии: исключает день и создаёт отдельное событие.
  AppEvent detachRecurrenceOccurrence({
    required AppEvent original,
    required AppEvent updated,
  }) {
    final masterId = original.seriesId ?? original.id.split('-').first;
    final repo = repoFor(original);
    final master = repo.getMasterEvents().firstWhere(
      (event) => event.id == masterId,
      orElse: () => original,
    );
    final exclusions = RecurrenceExdateCodec.addExclusionDay(
      master.recurrenceExclusions,
      original.start,
    );

    repo.updateEvent(
      event: master,
      updatedEvent: master.copyWith(recurrenceExclusions: exclusions),
    );

    final detachedId = 'event-${DateTime.now().microsecondsSinceEpoch}';
    final detached = updated.copyWith(
      id: detachedId,
      clearRrule: true,
      clearSeriesId: true,
      isRecurrenceOccurrence: false,
      recurrenceExclusions: const [],
      contextProfileId: updated.contextProfileId ?? original.contextProfileId,
    );
    repo.addEvent(detached);
    return detached;
  }

  /// Переносит событие на другой день (недельный drag-and-drop).
  WeekEventMoveResult? movePersonalEventToDate({
    required AppEvent event,
    required DateTime targetDate,
  }) {
    final day = DateTime(targetDate.year, targetDate.month, targetDate.day);
    if (event.isOnDate(day)) return null;
    return _moveWeekEvent(event: event, targetDate: day, startTime: null);
  }

  /// Переносит событие на день и, для timed, на новое время начала.
  WeekEventMoveResult? movePersonalEventToDateTime({
    required AppEvent event,
    required DateTime targetDate,
    TimeOfDay? startTime,
  }) {
    if (startTime == null || !event.isTimed) {
      return movePersonalEventToDate(event: event, targetDate: targetDate);
    }
    final day = DateTime(targetDate.year, targetDate.month, targetDate.day);
    final moved = shiftEventToCalendarDateTime(event, day, startTime);
    final sameSlot =
        event.isOnDate(day) &&
        eventStartMinutesOfDay(event) == eventStartMinutesOfDay(moved);
    if (sameSlot) return null;
    return _moveWeekEvent(event: event, targetDate: day, startTime: startTime);
  }

  /// Меняет длительность timed-события (ручки на сетке недели).
  WeekEventMoveResult? resizePersonalEvent({
    required AppEvent event,
    required int startMinutes,
    required int endMinutes,
  }) {
    if (!event.isTimed) {
      throw StateError('Event cannot be resized');
    }

    final resized = resizeTimedEventTimes(
      event,
      startMinutes: startMinutes,
      endMinutes: endMinutes,
    );
    return persistWeekGridEdit(original: event, updated: resized);
  }

  WeekEventMoveResult? _moveWeekEvent({
    required AppEvent event,
    required DateTime targetDate,
    required TimeOfDay? startTime,
  }) {
    final moved = startTime != null && event.isTimed
        ? shiftEventToCalendarDateTime(event, targetDate, startTime)
        : shiftEventToCalendarDate(event, targetDate);
    AppEvent withParent = moved;
    if (event.isTimed && !event.isFromWorkSchedule) {
      final parent = resolveParentShiftEvent(
        startMinutes: eventStartMinutesOfDay(moved),
        endMinutes: eventDisplayEndMinutesOfDay(moved),
        dayEvents: conflictMasters(),
      );
      withParent = moved.copyWith(
        parentEventId: parent?.id,
        clearParentEventId: parent == null,
      );
    }
    // Personal timed overlaps are allowed; cascade layout shows stacking.
    return persistWeekGridEdit(original: event, updated: withParent);
  }

  /// Persist переноса/resize на недельной сетке (override / this occurrence).
  WeekEventMoveResult persistWeekGridEdit({
    required AppEvent original,
    required AppEvent updated,
  }) {
    if (!original.capabilities.canMoveOnWeekGrid) {
      throw StateError('Event cannot be moved on week grid');
    }

    final series = original.hasRecurrence || original.isRecurrenceOccurrence;
    if (series) {
      final masterId = original.seriesId ?? original.id.split('-').first;
      final repo = repoFor(original);
      final master = repo.getMasterEvents().firstWhere(
        (event) => event.id == masterId,
        orElse: () => original,
      );
      final detached = detachRecurrenceOccurrence(
        original: original,
        updated: updated,
      );
      return WeekEventMoveResult(
        original: original,
        persisted: detached,
        kind: WeekEventPersistKind.occurrenceDetached,
        seriesMasterBefore: master,
      );
    }

    if (original.capabilities.editsCreateScheduleOverride) {
      final created =
          original.entrySource != CalendarEntrySource.scheduleOverride;
      saveScheduleOverride(source: original, updated: updated);
      final scheduleId = original.workScheduleId;
      if (scheduleId == null) {
        throw StateError('Event cannot be moved on week grid');
      }
      final occurrenceDate =
          AppEvent.scheduleOverrideDateFromId(original.id) ?? original.start;
      final persisted = updated
          .copyWith(
            id: AppEvent.scheduleOverrideId(scheduleId, occurrenceDate),
            seriesId: 'schedule-$scheduleId',
            isRecurrenceOccurrence: false,
            contextProfileId: original.contextProfileId ?? activeProfileId,
          )
          .taggedWith(CalendarEntrySource.scheduleOverride);
      _shiftNestedChildrenOf(original: original, updated: persisted);
      return WeekEventMoveResult(
        original: original,
        persisted: persisted,
        kind: created
            ? WeekEventPersistKind.overrideCreated
            : WeekEventPersistKind.overrideUpdated,
      );
    }

    persistEditedEvent(original: original, updated: updated);
    final persisted = updated.copyWith(id: original.id);
    _shiftNestedChildrenOf(original: original, updated: persisted);
    return WeekEventMoveResult(
      original: original,
      persisted: persisted,
      kind: WeekEventPersistKind.personalUpdated,
    );
  }

  void _shiftNestedChildrenOf({
    required AppEvent original,
    required AppEvent updated,
  }) {
    final delta = updated.start.difference(original.start);
    if (delta == Duration.zero && original.id == updated.id) return;
    final children = [
      for (final event in conflictMasters())
        if (event.parentEventId == original.id) event,
    ];
    if (children.isEmpty) return;
    for (final child in children) {
      final movedRange = DateTimeRange(
        start: child.start.add(delta),
        end: child.end.add(delta),
      );
      final localStart = movedRange.start.toLocal();
      final localEnd = movedRange.end.toLocal();
      final moved = child.copyWith(
        dateTimeRange: movedRange,
        startTime: child.startTime.isEmpty
            ? child.startTime
            : formatAlmanacTime(
                TimeOfDay(hour: localStart.hour, minute: localStart.minute),
              ),
        endTime: child.endTime.isEmpty
            ? child.endTime
            : formatAlmanacTime(
                TimeOfDay(hour: localEnd.hour, minute: localEnd.minute),
              ),
        parentEventId: updated.id,
      );
      persistEditedEvent(original: child, updated: moved);
    }
  }

  /// Откатывает [persistWeekGridEdit].
  void undoWeekEventMove(WeekEventMoveResult result) {
    switch (result.kind) {
      case WeekEventPersistKind.personalUpdated:
        updatePersonalEvent(source: result.persisted, updated: result.original);
        return;
      case WeekEventPersistKind.overrideCreated:
        revertScheduleOverride(result.persisted);
        return;
      case WeekEventPersistKind.overrideUpdated:
        saveScheduleOverride(
          source: result.persisted,
          updated: result.original,
        );
        return;
      case WeekEventPersistKind.occurrenceDetached:
        final repo = repoFor(result.persisted);
        repo.deleteEvent(result.persisted.id);
        final masterBefore = result.seriesMasterBefore;
        if (masterBefore == null) return;
        final current = repo.getMasterEvents().where(
          (event) => event.id == masterBefore.id,
        );
        if (current.isEmpty) {
          repo.addEvent(masterBefore);
          return;
        }
        repo.updateEvent(event: current.first, updatedEvent: masterBefore);
        return;
    }
  }

  /// Быстрое действие над сменой (пропуск / сверхурочные).
  void applyShiftQuickAction({
    required AppEvent source,
    required ShiftQuickAction action,
  }) {
    if (!source.capabilities.editsCreateScheduleOverride) return;
    final updated = applyShiftQuickActionPatch(source: source, action: action);
    persistEditedEvent(original: source, updated: updated);
  }
}
