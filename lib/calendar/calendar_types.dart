import 'package:flutter/material.dart';
import 'package:kalender/kalender.dart';
import 'event_domain_state.dart';
import 'note_attachment.dart';

/// Тип записи календаря: событие с временем, заметка, чек-лист или цель накопления.
enum CalendarEntryKind { event, note, checklist, savingsGoal }

extension CalendarEntryKindX on CalendarEntryKind {
  bool get isTimed => this == CalendarEntryKind.event;

  bool get isSavingsGoal => this == CalendarEntryKind.savingsGoal;
}

/// Происхождение записи календаря (источник данных).
enum CalendarEntrySource {
  personal,
  booking,
  bookingPending,
  bookingSlot,
  bookingOffer,
  scheduleGenerated,
  scheduleOverride,
  savingsGoalProjected,
  guestCalendar,
}

extension CalendarEntrySourceX on CalendarEntrySource {
  bool get isScheduleRelated =>
      this == CalendarEntrySource.scheduleGenerated ||
      this == CalendarEntrySource.scheduleOverride;

  /// Запись можно сохранить/удалить в репозитории событий.
  bool get isPersisted =>
      this == CalendarEntrySource.personal ||
      this == CalendarEntrySource.booking ||
      this == CalendarEntrySource.bookingOffer ||
      this == CalendarEntrySource.scheduleOverride;

  /// Запись существует только в памяти при чтении календаря.
  bool get isEphemeralView =>
      this == CalendarEntrySource.scheduleGenerated ||
      this == CalendarEntrySource.savingsGoalProjected ||
      this == CalendarEntrySource.bookingPending ||
      this == CalendarEntrySource.bookingSlot ||
      this == CalendarEntrySource.guestCalendar;

  static CalendarEntrySource? fromStorage(String? name) {
    if (name == null) return null;
    for (final source in CalendarEntrySource.values) {
      if (source.name == name) return source;
    }
    return null;
  }
}

/// Событие календаря на базе CalendarEvent из пакета kalender.
class AppEvent extends CalendarEvent {
  AppEvent({
    required super.id,
    required super.dateTimeRange,
    required this.title,
    required this.startTime,
    required this.endTime,
    required this.color,
    this.kind = CalendarEntryKind.event,
    this.checklist = const [],
    this.rrule,
    this.recurrenceUntil,
    this.seriesId,
    this.parentEventId,
    this.isRecurrenceOccurrence = false,
    this.recurrenceExclusions = const [],
    this.explicitEntrySource,
    this.contextProfileId,
    this.notes,
    this.isUndated = false,
    double? incomeAmount,
    bool? isGift,
    this.reminderMinutesBefore,
    int? overtimeMinutes,
    bool? shiftSkipped,
    int? unpaidMinutes,
    bool? pomodoroEnabled,
    int? pomodoroWorkMinutes,
    int? pomodoroBreakMinutes,
    int? pomodoroCompletedSessions,
    int? pomodoroRemainingSeconds,
    bool? pomodoroOnBreak,
    int? pomodoroWorkRemainingSeconds,
    int? pomodoroBreakRemainingSeconds,
    List<NoteAttachment>? attachments,
    EventPomodoroState? pomodoro,
    EventFinanceState? finance,
    EventShiftPayState? shiftPay,
    EventAttachmentsState? noteAttachments,
    super.interaction,
  }) : pomodoro = EventPomodoroState(
         enabled: pomodoroEnabled ?? pomodoro?.enabled ?? false,
         workMinutes: pomodoroWorkMinutes ?? pomodoro?.workMinutes ?? 25,
         breakMinutes: pomodoroBreakMinutes ?? pomodoro?.breakMinutes ?? 5,
         completedSessions:
             pomodoroCompletedSessions ?? pomodoro?.completedSessions ?? 0,
         remainingSeconds:
             pomodoroRemainingSeconds ?? pomodoro?.remainingSeconds,
         onBreak: pomodoroOnBreak ?? pomodoro?.onBreak,
         workRemainingSeconds:
             pomodoroWorkRemainingSeconds ?? pomodoro?.workRemainingSeconds,
         breakRemainingSeconds:
             pomodoroBreakRemainingSeconds ?? pomodoro?.breakRemainingSeconds,
       ),
       finance = EventFinanceState(
         incomeAmount: incomeAmount ?? finance?.incomeAmount,
         isGift: isGift ?? finance?.isGift ?? false,
       ),
       shiftPay = EventShiftPayState(
         overtimeMinutes: overtimeMinutes ?? shiftPay?.overtimeMinutes,
         shiftSkipped: shiftSkipped ?? shiftPay?.shiftSkipped ?? false,
         unpaidMinutes: unpaidMinutes ?? shiftPay?.unpaidMinutes,
       ),
       noteAttachments = attachments != null
           ? EventAttachmentsState(attachments)
           : (noteAttachments ?? EventAttachmentsState.empty);

  final CalendarEntryKind kind;
  final String title;
  final String startTime;
  final String endTime;
  final Color color;
  final List<ChecklistItem> checklist;

  /// RFC 5545 RRULE (без префикса RRULE:). null — одноразовое событие.
  final String? rrule;

  /// Окончание серии повторений (необязательно).
  final DateTime? recurrenceUntil;

  /// ID мастер-события серии. Для мастера совпадает с [id].
  final String? seriesId;

  /// Родительское событие (смена), в которое вложена эта запись.
  final String? parentEventId;

  /// true для развёрнутого вхождения повторяющегося события.
  final bool isRecurrenceOccurrence;

  /// Календарные дни, исключённые из серии повторений.
  final List<DateTime> recurrenceExclusions;

  /// Явный источник записи (для view-слоя; у мастеров обычно null).
  final CalendarEntrySource? explicitEntrySource;

  /// Профиль-источник (при объединённом просмотре нескольких профилей).
  final String? contextProfileId;

  /// Текстовые заметки к событию.
  final String? notes;

  /// Заметка или чек-лист без календарной даты (Inbox).
  final bool isUndated;

  /// Напоминание: минуты до начала (null — выключено).
  final int? reminderMinutesBefore;

  final EventPomodoroState pomodoro;
  final EventFinanceState finance;
  final EventShiftPayState shiftPay;
  final EventAttachmentsState noteAttachments;

  double? get incomeAmount => finance.incomeAmount;
  bool get isGift => finance.isGift;
  int? get overtimeMinutes => shiftPay.overtimeMinutes;
  bool get shiftSkipped => shiftPay.shiftSkipped;
  int? get unpaidMinutes => shiftPay.unpaidMinutes;
  bool get pomodoroEnabled => pomodoro.enabled;
  int get pomodoroWorkMinutes => pomodoro.workMinutes;
  int get pomodoroBreakMinutes => pomodoro.breakMinutes;
  int get pomodoroCompletedSessions => pomodoro.completedSessions;
  int? get pomodoroRemainingSeconds => pomodoro.remainingSeconds;
  bool? get pomodoroOnBreak => pomodoro.onBreak;
  int? get pomodoroWorkRemainingSeconds => pomodoro.workRemainingSeconds;
  int? get pomodoroBreakRemainingSeconds => pomodoro.breakRemainingSeconds;
  List<NoteAttachment> get attachments => noteAttachments.items;
  bool get hasActivePomodoroTimer => pomodoro.hasActiveTimer;

  bool get hasRecurrence => rrule != null && rrule!.isNotEmpty;

  /// Единая точка определения источника (явный тег или legacy ID).
  CalendarEntrySource get entrySource {
    if (explicitEntrySource != null) return explicitEntrySource!;
    if (isSavingsGoal) return CalendarEntrySource.savingsGoalProjected;
    if (_legacyIsScheduleOccurrenceOverride) {
      return CalendarEntrySource.scheduleOverride;
    }
    if (_legacyIsGeneratedScheduleEvent) {
      return CalendarEntrySource.scheduleGenerated;
    }
    if (_legacyIsBookingEvent) {
      return CalendarEntrySource.booking;
    }
    return CalendarEntrySource.personal;
  }

  static const bookingEventIdPrefix = 'event-from-session-';

  static String bookingEventId(String requestId) =>
      '$bookingEventIdPrefix$requestId';

  static const pendingBookingEventIdPrefix = 'pending-booking-';

  static String pendingBookingEventId(String requestId) =>
      '$pendingBookingEventIdPrefix$requestId';

  static const bookingSlotEventIdPrefix = 'booking-slot:';

  static String bookingSlotEventId(String token, String slotId) =>
      '$bookingSlotEventIdPrefix$token:$slotId';

  static const bookingOfferEventIdPrefix = 'booking-offer:';

  static String bookingOfferEventId(String slotId) =>
      '$bookingOfferEventIdPrefix$slotId';

  static ({String token, String slotId})? parseBookingSlotEventId(String id) {
    if (!id.startsWith(bookingSlotEventIdPrefix)) return null;
    final rest = id.substring(bookingSlotEventIdPrefix.length);
    final separator = rest.indexOf(':');
    if (separator <= 0 || separator == rest.length - 1) return null;
    return (
      token: rest.substring(0, separator),
      slotId: rest.substring(separator + 1),
    );
  }

  bool get _legacyIsBookingEvent => id.startsWith(bookingEventIdPrefix);

  AppEvent taggedWith(CalendarEntrySource source) {
    return copyWith(explicitEntrySource: source);
  }

  bool get _legacyIsScheduleOccurrenceOverride =>
      id.startsWith('schedule-override-');

  bool get _legacyIsGeneratedScheduleEvent {
    if (_legacyIsScheduleOccurrenceOverride) return false;
    final source = seriesId ?? id;
    return source.startsWith('schedule-');
  }

  static DateTime recurrenceDayKey(DateTime date) {
    final local = date.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  bool excludesRecurrenceDay(DateTime instanceStart) {
    if (recurrenceExclusions.isEmpty) return false;
    final key = recurrenceDayKey(instanceStart);
    return recurrenceExclusions.any(
      (excluded) => recurrenceDayKey(excluded) == key,
    );
  }

  bool get isTimed => kind.isTimed;

  /// Диапазон для записей без времени (привязка к календарному дню).
  static DateTimeRange dateOnlyRange(DateTime date) {
    final local = date.toLocal();
    final day = DateTime(local.year, local.month, local.day);
    return DateTimeRange(start: day, end: day.add(const Duration(minutes: 1)));
  }

  static CalendarEntryKind kindFromStorage(String? name) {
    if (name == null) return CalendarEntryKind.event;
    for (final kind in CalendarEntryKind.values) {
      if (kind.name == name) return kind;
    }
    return CalendarEntryKind.event;
  }

  int get checklistTotalCount =>
      checklist.fold<int>(0, (total, item) => total + item.totalCount);

  int get checklistCompletedCount =>
      checklist.fold<int>(0, (total, item) => total + item.completedCount);

  double? get checklistProgress {
    final total = checklistTotalCount;
    if (total == 0) return null;
    return checklistCompletedCount / total;
  }

  @override
  AppEvent copyWith({
    String? id,
    DateTimeRange? dateTimeRange,
    EventInteraction? interaction,
    String? title,
    String? startTime,
    String? endTime,
    Color? color,
    CalendarEntryKind? kind,
    List<ChecklistItem>? checklist,
    String? rrule,
    bool clearRrule = false,
    DateTime? recurrenceUntil,
    bool clearRecurrenceUntil = false,
    String? seriesId,
    bool clearSeriesId = false,
    String? parentEventId,
    bool clearParentEventId = false,
    bool? isRecurrenceOccurrence,
    List<DateTime>? recurrenceExclusions,
    CalendarEntrySource? explicitEntrySource,
    bool clearExplicitEntrySource = false,
    String? contextProfileId,
    String? notes,
    bool? isUndated,
    double? incomeAmount,
    bool? isGift,
    bool clearIncomeAmount = false,
    int? reminderMinutesBefore,
    int? overtimeMinutes,
    bool? shiftSkipped,
    int? unpaidMinutes,
    bool clearOvertimeMinutes = false,
    bool clearUnpaidMinutes = false,
    bool? pomodoroEnabled,
    int? pomodoroWorkMinutes,
    int? pomodoroBreakMinutes,
    int? pomodoroCompletedSessions,
    int? pomodoroRemainingSeconds,
    bool? pomodoroOnBreak,
    int? pomodoroWorkRemainingSeconds,
    int? pomodoroBreakRemainingSeconds,
    bool clearPomodoroRemainingSeconds = false,
    bool clearPomodoroWorkRemainingSeconds = false,
    bool clearPomodoroBreakRemainingSeconds = false,
    List<NoteAttachment>? attachments,
    EventPomodoroState? pomodoro,
    EventFinanceState? finance,
    EventShiftPayState? shiftPay,
    EventAttachmentsState? noteAttachments,
  }) {
    return AppEvent(
      id: id ?? this.id,
      dateTimeRange: dateTimeRange ?? this.dateTimeRange,
      title: title ?? this.title,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      color: color ?? this.color,
      kind: kind ?? this.kind,
      checklist: checklist ?? this.checklist,
      rrule: clearRrule ? null : (rrule ?? this.rrule),
      recurrenceUntil: clearRecurrenceUntil
          ? null
          : (recurrenceUntil ?? this.recurrenceUntil),
      seriesId: clearSeriesId ? null : (seriesId ?? this.seriesId),
      parentEventId: clearParentEventId
          ? null
          : (parentEventId ?? this.parentEventId),
      isRecurrenceOccurrence:
          isRecurrenceOccurrence ?? this.isRecurrenceOccurrence,
      recurrenceExclusions: recurrenceExclusions ?? this.recurrenceExclusions,
      explicitEntrySource: clearExplicitEntrySource
          ? null
          : (explicitEntrySource ?? this.explicitEntrySource),
      contextProfileId: contextProfileId ?? this.contextProfileId,
      notes: notes ?? this.notes,
      isUndated: isUndated ?? this.isUndated,
      reminderMinutesBefore:
          reminderMinutesBefore ?? this.reminderMinutesBefore,
      pomodoro: (pomodoro ?? this.pomodoro).copyWith(
        enabled: pomodoroEnabled,
        workMinutes: pomodoroWorkMinutes,
        breakMinutes: pomodoroBreakMinutes,
        completedSessions: pomodoroCompletedSessions,
        remainingSeconds: pomodoroRemainingSeconds,
        onBreak: pomodoroOnBreak,
        workRemainingSeconds: pomodoroWorkRemainingSeconds,
        breakRemainingSeconds: pomodoroBreakRemainingSeconds,
        clearRemainingSeconds: clearPomodoroRemainingSeconds,
        clearWorkRemainingSeconds: clearPomodoroWorkRemainingSeconds,
        clearBreakRemainingSeconds: clearPomodoroBreakRemainingSeconds,
      ),
      finance: (finance ?? this.finance).copyWith(
        incomeAmount: incomeAmount,
        isGift: isGift,
        clearIncomeAmount: clearIncomeAmount,
      ),
      shiftPay: (shiftPay ?? this.shiftPay).copyWith(
        overtimeMinutes: overtimeMinutes,
        shiftSkipped: shiftSkipped,
        unpaidMinutes: unpaidMinutes,
        clearOvertimeMinutes: clearOvertimeMinutes,
        clearUnpaidMinutes: clearUnpaidMinutes,
      ),
      noteAttachments: attachments != null
          ? EventAttachmentsState(attachments)
          : (noteAttachments ?? this.noteAttachments),
      interaction: interaction ?? this.interaction,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AppEvent &&
        super == other &&
        other.title == title &&
        other.startTime == startTime &&
        other.endTime == endTime &&
        other.color == color &&
        other.kind == kind &&
        other.checklist == checklist &&
        other.rrule == rrule &&
        other.recurrenceUntil == recurrenceUntil &&
        other.seriesId == seriesId &&
        other.parentEventId == parentEventId &&
        other.isRecurrenceOccurrence == isRecurrenceOccurrence &&
        other.recurrenceExclusions == recurrenceExclusions &&
        other.explicitEntrySource == explicitEntrySource &&
        other.contextProfileId == contextProfileId &&
        other.notes == notes &&
        other.isUndated == isUndated &&
        other.finance == finance &&
        other.reminderMinutesBefore == reminderMinutesBefore &&
        other.shiftPay == shiftPay &&
        other.pomodoro == pomodoro &&
        other.noteAttachments == noteAttachments;
  }

  @override
  int get hashCode => Object.hashAll([
    super.hashCode,
    title,
    startTime,
    endTime,
    color,
    kind,
    checklist,
    rrule,
    recurrenceUntil,
    seriesId,
    parentEventId,
    isRecurrenceOccurrence,
    recurrenceExclusions,
    explicitEntrySource,
    contextProfileId,
    notes,
    isUndated,
    finance,
    reminderMinutesBefore,
    shiftPay,
    pomodoro,
    noteAttachments,
  ]);

  bool isOnDate(DateTime date) {
    final local = start.toLocal();
    return local.year == date.year &&
        local.month == date.month &&
        local.day == date.day;
  }

  /// Immediate week-grid drag. Unlockable types: [EntryCapabilities.canUnlockForWeekMove].
  bool get canDragInWeekView =>
      entrySource == CalendarEntrySource.savingsGoalProjected ||
      (entrySource == CalendarEntrySource.personal &&
          !hasRecurrence &&
          !isRecurrenceOccurrence);

  bool get isSavingsGoal => kind.isSavingsGoal;

  /// Событие из рабочего расписания (сгенерированное или override).
  bool get isFromWorkSchedule => entrySource.isScheduleRelated;

  /// Переопределение одного дня сгенерированного расписания.
  bool get isScheduleOccurrenceOverride =>
      entrySource == CalendarEntrySource.scheduleOverride;

  /// Сгенерированное событие расписания (ещё без переопределения).
  bool get isGeneratedScheduleEvent =>
      entrySource == CalendarEntrySource.scheduleGenerated;

  /// ID правила [CyclicWorkSchedule], если событие из расписания.
  String? get workScheduleId {
    if (isScheduleOccurrenceOverride) {
      final body = id.substring('schedule-override-'.length);
      final match = RegExp(r'^(.+)-(\d{13,})$').firstMatch(body);
      return match?.group(1);
    }

    if (!isFromWorkSchedule) return null;

    // seriesId is always `schedule-{scheduleId}` without occurrence timestamp.
    if (seriesId != null && seriesId!.startsWith('schedule-')) {
      return seriesId!.substring('schedule-'.length);
    }

    final body = id.substring('schedule-'.length);
    final match = RegExp(r'^(.+)-(\d{13,})$').firstMatch(body);
    if (match != null) return match.group(1);
    return body;
  }

  /// ID переопределения вхождения расписания на конкретный день.
  static String scheduleOverrideId(String scheduleId, DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    return 'schedule-override-$scheduleId-${day.millisecondsSinceEpoch}';
  }

  /// День вхождения, для которого создан override (из id), иначе null.
  static DateTime? scheduleOverrideDateFromId(String id) {
    const prefix = 'schedule-override-';
    if (!id.startsWith(prefix)) return null;
    final lastDash = id.lastIndexOf('-');
    if (lastDash < prefix.length) return null;
    final millis = int.tryParse(id.substring(lastDash + 1));
    if (millis == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(millis);
  }

  static DateTime dateKey(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static String scheduleOverrideKey(String scheduleId, DateTime date) {
    return '$scheduleId@${dateKey(date).millisecondsSinceEpoch}';
  }
}

/// Заголовок заметки из текста тела (первая строка или усечение).
String deriveNoteTitleFromBody(String notes) {
  final trimmed = notes.trim();
  if (trimmed.isEmpty) return '';
  final firstLine = trimmed.split('\n').first.trim();
  if (firstLine.length <= 48) return firstLine;
  return '${firstLine.substring(0, 45)}…';
}

extension AppEventFinanceDisplay on AppEvent {
  bool get hasFinanceMarker => incomeAmount != null && incomeAmount! > 0;
}

extension AppEventPomodoroDisplay on AppEvent {
  bool get hasPomodoro =>
      pomodoroEnabled &&
      (kind == CalendarEntryKind.event ||
          kind == CalendarEntryKind.checklist) &&
      !isFromWorkSchedule;

  bool get isPomodoroOnBreak => pomodoroOnBreak ?? false;
}

extension AppEventAttachmentsDisplay on AppEvent {
  bool get hasAttachments => attachments.isNotEmpty;

  int get imageAttachmentCount =>
      attachments.where((attachment) => attachment.isImage).length;

  int get fileAttachmentCount => attachments.length - imageAttachmentCount;
}

extension AppEventSavingsDisplay on AppEvent {
  double? get savingsTargetAmount {
    if (!isSavingsGoal) return null;
    return double.tryParse(startTime);
  }

  double? get savingsSavedAmount {
    if (!isSavingsGoal) return null;
    return double.tryParse(endTime);
  }

  double? get savingsProgressRatio {
    final target = savingsTargetAmount;
    final saved = savingsSavedAmount;
    if (target == null || target <= 0 || saved == null) return null;
    return (saved / target).clamp(0.0, 1.0);
  }
}

extension AppEventNoteDisplay on AppEvent {
  /// Заголовок сгенерирован из текста заметки, а не задан пользователем.
  bool get isAutoDerivedNoteTitle {
    if (kind != CalendarEntryKind.note) return false;
    final body = notes?.trim() ?? '';
    if (body.isEmpty) return true;
    return title == deriveNoteTitleFromBody(body);
  }

  /// Основной текст заметки в списках и карточках (без дублирования).
  String get noteDisplayTitle {
    if (kind != CalendarEntryKind.note) return title;
    if (isAutoDerivedNoteTitle) {
      final body = notes?.trim();
      if (body != null && body.isNotEmpty) return body;
    }
    return title;
  }

  /// Дополнительный текст заметки, если задан отдельный заголовок.
  String? get noteDisplaySecondary {
    if (kind != CalendarEntryKind.note || isAutoDerivedNoteTitle) {
      return null;
    }
    final body = notes?.trim();
    if (body == null || body.isEmpty) return null;
    return body;
  }
}

class ChecklistItem {
  const ChecklistItem({
    required this.id,
    required this.title,
    this.completed = false,
    this.children = const [],
  });

  final String id;
  final String title;
  final bool completed;
  final List<ChecklistItem> children;

  int get totalCount =>
      1 + children.fold<int>(0, (total, child) => total + child.totalCount);

  int get completedCount =>
      (completed ? 1 : 0) +
      children.fold<int>(0, (total, child) => total + child.completedCount);

  ChecklistItem copyWith({
    String? id,
    String? title,
    bool? completed,
    List<ChecklistItem>? children,
  }) {
    return ChecklistItem(
      id: id ?? this.id,
      title: title ?? this.title,
      completed: completed ?? this.completed,
      children: children ?? this.children,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ChecklistItem &&
        other.id == id &&
        other.title == title &&
        other.completed == completed &&
        other.children == children;
  }

  @override
  int get hashCode => Object.hash(id, title, completed, children);
}

enum CalendarMode { month, week, agenda, year }

CalendarMode? calendarModeFromName(String? name) {
  if (name == null) return null;
  for (final mode in CalendarMode.values) {
    if (mode.name == name) return mode;
  }
  return null;
}
