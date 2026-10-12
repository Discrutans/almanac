import 'package:flutter/material.dart';
import '../data/profiles/context_profile.dart';
import '../data/schedules/cyclic_schedule_generator.dart';
import '../finance/pay_types.dart';
import '../finance/savings_goal_types.dart';
import 'calendar_types.dart';
import 'note_attachment.dart';

/// Валидный годовой набор для проверки всех функций календаря.
///
/// Данные проходят те же правила, что и ручное создание: время окончания
/// позже начала, чек-листы с уникальными id, цели и графики корректны,
/// личные timed-события не пересекаются между собой. Смены 2/2 и офис
/// не пересекаются. Одно личное событие намеренно пересекает вечернюю
/// смену — репозиторий это хранит, а create/save/edit должны показать конфликт.
abstract final class TestCalendarFill {
  static const officeScheduleId = 'test-fill-office-weekdays';
  static const shiftScheduleId = 'test-fill-shift-2-2';
  static const dailySeriesId = 'test-fill-daily-stretch';
  static const weeklySeriesId = 'test-fill-weekly-review';
  static const monthlySeriesId = 'test-fill-monthly-report';
  static const conflictEventId = 'test-fill-conflict-with-shift';

  static const officeStart = '09:00';
  static const officeEnd = '17:00';
  static const shiftStart = '19:00';
  static const shiftEnd = '23:00';

  static const _textChunks = [
    'Проверка заполнения заметок, списка, недели и карточек. ',
    'Длинный текст для оценки обрезки, переносов и tooltip. ',
    'Смена · чек-лист · накопление · событие · помодоро · доход. ',
  ];

  static List<CyclicWorkSchedule> schedules(String profileId, {int? year}) {
    final y = year ?? DateTime.now().year;
    return [
      CyclicWorkSchedule(
        id: officeScheduleId,
        profileId: profileId,
        title: 'Офис · пн–пт',
        kind: CyclicScheduleKind.rrule,
        rrule: 'FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR',
        startTime: officeStart,
        endTime: officeEnd,
        colorValue: 0xFF795548,
        payMode: PayRateMode.hourly,
        hourlyRate: 650,
        standardHoursPerShift: 8,
        overtimeMultiplier: 1.5,
        breakMinutes: 45,
      ),
      CyclicWorkSchedule(
        id: shiftScheduleId,
        profileId: profileId,
        title: 'Смена 2/2 · вечер',
        kind: CyclicScheduleKind.shiftCycle,
        cycleStartDate: DateTime(y, 1, 1),
        workDays: 2,
        restDays: 2,
        startTime: shiftStart,
        endTime: shiftEnd,
        colorValue: 0xFF8BC34A,
        payMode: PayRateMode.hourly,
        hourlyRate: 520,
        standardHoursPerShift: 4,
      ),
    ];
  }

  static List<SavingsGoal> savingsGoals(
    String profileId, {
    int? year,
    DateTime? now,
  }) {
    final clock = now ?? DateTime.now();
    final y = year ?? clock.year;
    return [
      SavingsGoal(
        id: 'test-fill-savings-vacation-$y',
        profileId: profileId,
        title: 'Отпуск',
        targetAmount: 180_000,
        savedAmount: 64_000,
        targetDate: DateTime(y, 7, 1),
        monthlyLivingExpenses: 48_000,
        note: 'Цель с прошедшей датой — проверка просрочки и прогресса.',
        colorValue: 0xFF009688,
        createdAt: DateTime(y, 1, 8),
      ),
      SavingsGoal(
        id: 'test-fill-savings-laptop-$y',
        profileId: profileId,
        title: 'Ноутбук · длинное название для переноса в списке целей',
        targetAmount: 95_000,
        savedAmount: 41_500,
        targetDate: DateTime(y, 9, 30),
        monthlyLivingExpenses: 42_000,
        note: stressText(
          label: 'Цель накопления',
          charCount: 420,
          dayOfYear: 273,
        ),
        colorValue: 0xFF2196F3,
        createdAt: DateTime(y, 3, 2),
      ),
      SavingsGoal(
        id: 'test-fill-savings-emergency-$y',
        profileId: profileId,
        title: 'Подушка безопасности',
        targetAmount: 250_000,
        savedAmount: 187_000,
        targetDate: DateTime(y, 11, 15),
        monthlyLivingExpenses: 50_000,
        colorValue: 0xFF4CAF50,
        createdAt: DateTime(y, 1, 15),
      ),
      SavingsGoal(
        id: 'test-fill-savings-gifts-$y',
        profileId: profileId,
        title: 'Подарки к Новому году',
        targetAmount: 32_000,
        savedAmount: 6_400,
        targetDate: DateTime(y, 12, 20),
        monthlyLivingExpenses: 45_000,
        note: 'Небольшая цель ближе к концу года.',
        colorValue: 0xFF9C27B0,
        createdAt: clock,
      ),
    ];
  }

  static List<AppEvent> personalEvents(
    String profileId, {
    int? year,
    DateTime? now,
  }) {
    final clock = now ?? DateTime.now();
    final y = year ?? clock.year;
    final today = _clampToYear(y, clock);
    final until = DateTime(y, 12, 31, 23, 59, 59);
    final weeklyStart = _firstWeekday(y, DateTime.monday);
    final excludedMonday = _excludedMonday(today, weeklyStart);
    final conflictDay = _nearestShiftWorkDay(y, today) ?? today;
    final skipShiftDay = _anotherShiftWorkDay(y, conflictDay);
    final overtimeDay = skipShiftDay == null
        ? null
        : _anotherShiftWorkDay(y, conflictDay, alsoSkip: skipShiftDay);
    final officeSkipDay = _officeSkipDay(y, today, conflictDay);
    final dailyExcluded = _nearestWeekend(y, today);

    final events = <AppEvent>[
      _timed(
        id: dailySeriesId,
        profileId: profileId,
        start: DateTime(y, 1, 2, 7, 0),
        end: DateTime(y, 1, 2, 7, 30),
        title: 'Утренняя зарядка',
        color: Colors.teal,
        rrule: 'FREQ=DAILY;INTERVAL=1',
        recurrenceUntil: until,
        seriesId: dailySeriesId,
        recurrenceExclusions: [dailyExcluded],
        reminderMinutesBefore: 10,
        notes:
            'Ежедневная серия. ${dailyExcluded.day}.${dailyExcluded.month} исключён.',
      ),
      _timed(
        id: weeklySeriesId,
        profileId: profileId,
        start: DateTime(
          weeklyStart.year,
          weeklyStart.month,
          weeklyStart.day,
          18,
          0,
        ),
        end: DateTime(
          weeklyStart.year,
          weeklyStart.month,
          weeklyStart.day,
          18,
          45,
        ),
        title: 'Еженедельный обзор',
        color: Colors.indigo,
        rrule: 'FREQ=WEEKLY;BYDAY=MO',
        recurrenceUntil: until,
        seriesId: weeklySeriesId,
        recurrenceExclusions: [excludedMonday],
        reminderMinutesBefore: 60,
        notes: stressText(
          label: 'Повторяющееся событие',
          charCount: 360,
          dayOfYear: weeklyStart.difference(DateTime(y, 1, 1)).inDays + 1,
        ),
      ),
      _timed(
        id: 'test-fill-detached-review-$y',
        profileId: profileId,
        start: DateTime(
          excludedMonday.year,
          excludedMonday.month,
          excludedMonday.day,
          18,
          0,
        ),
        end: DateTime(
          excludedMonday.year,
          excludedMonday.month,
          excludedMonday.day,
          18,
          40,
        ),
        title: 'Обзор · только этот понедельник',
        color: Colors.indigo.shade400,
        notes: 'Отвязанное вхождение серии: день исключён из повторения.',
      ),
      _timed(
        id: monthlySeriesId,
        profileId: profileId,
        start: DateTime(y, 1, 1, 17, 15),
        end: DateTime(y, 1, 1, 17, 45),
        title: 'Отчёт за месяц',
        color: Colors.deepPurple,
        rrule: 'FREQ=MONTHLY;INTERVAL=1',
        recurrenceUntil: until,
        seriesId: monthlySeriesId,
        reminderMinutesBefore: 15,
      ),
      ..._todayBundle(
        profileId: profileId,
        today: today,
        conflictDay: conflictDay,
      ),
      _weekendStandalone(profileId, dailyExcluded),
      ..._monthlyNotesAndChecklists(profileId, y, today),
      ..._monthlyAfternoonEvents(profileId, y, today),
    ];

    if (skipShiftDay != null) {
      events.add(
        _shiftOverride(
          scheduleId: shiftScheduleId,
          profileId: profileId,
          day: skipShiftDay,
          title: 'Смена 2/2 · вечер',
          color: const Color(0xFF8BC34A),
          shiftSkipped: true,
          notes: 'Пропуск смены для проверки быстрых действий и override.',
        ),
      );
    }
    if (overtimeDay != null) {
      events.add(
        _shiftOverride(
          scheduleId: shiftScheduleId,
          profileId: profileId,
          day: overtimeDay,
          title: 'Смена 2/2 · вечер',
          color: const Color(0xFF8BC34A),
          overtimeMinutes: 60,
          unpaidMinutes: 15,
          notes: 'Сверхурочные и неоплаченные минуты на одной смене.',
        ),
      );
    }
    if (officeSkipDay != null) {
      events.add(
        _shiftOverride(
          scheduleId: officeScheduleId,
          profileId: profileId,
          day: officeSkipDay,
          startTime: officeStart,
          endTime: officeEnd,
          title: 'Офис · пн–пт',
          color: const Color(0xFF795548),
          shiftSkipped: true,
          notes: 'Пропущенный офисный день.',
        ),
      );
    }

    return events;
  }

  static List<AppEvent> _todayBundle({
    required String profileId,
    required DateTime today,
    required DateTime conflictDay,
  }) {
    final richStartHour = today.day == 1 ? 8 : 17;
    final richStartMinute = today.day == 1 ? 20 : 0;
    final richEndHour = today.day == 1 ? 8 : 18;
    final richEndMinute = today.day == 1 ? 50 : 0;
    final longBody = stressText(
      label: 'Заметка дня',
      charCount: 520,
      dayOfYear: today.difference(DateTime(today.year, 1, 1)).inDays + 1,
    );
    final derivedBody =
        'Автозаголовок из первой строки\nПолный текст заметки должен быть виден в карточке дня месяца и в превью.';

    return [
      _timed(
        id: 'test-fill-today-rich',
        profileId: profileId,
        start: _at(today, richStartHour, richStartMinute),
        end: _at(today, richEndHour, richEndMinute),
        title:
            'Событие сегодня · длинный заголовок для переноса в неделе и повестке',
        color: Colors.blue,
        notes: longBody,
        incomeAmount: 12_500.5,
        reminderMinutesBefore: 30,
        pomodoroEnabled: true,
        pomodoroWorkMinutes: 25,
        pomodoroBreakMinutes: 5,
        pomodoroCompletedSessions: 1,
      ),
      _timed(
        id: 'test-fill-today-morning-adjacent',
        profileId: profileId,
        start: _at(today, 7, 30),
        end: _at(today, 8, 15),
        title: 'Соседнее утро · без пересечения',
        color: Colors.cyan,
        notes:
            'Стык с ежедневной зарядкой 07:00–07:30 (полуоткрытый интервал).',
      ),
      _timed(
        id: 'test-fill-today-gift',
        profileId: profileId,
        start: _at(today, 18, 50),
        end: _at(today, 19, 0),
        title: 'Подарок коллеге',
        color: Colors.pink,
        incomeAmount: 2_000,
        isGift: true,
        notes: 'Стык со сменой 19:00 (конфликта быть не должно).',
      ),
      _timed(
        id: conflictEventId,
        profileId: profileId,
        start: _at(conflictDay, 19, 30),
        end: _at(conflictDay, 20, 30),
        title: 'Конфликт со сменой 2/2',
        color: Colors.red,
        notes:
            'Намеренное пересечение с вечерней сменой 19:00–23:00. '
            'Набор загружается; сохранение правки смены или этого события '
            'должно показать конфликт.',
        reminderMinutesBefore: 15,
      ),
      _note(
        id: 'test-fill-note-explicit-today',
        profileId: profileId,
        day: today,
        title: 'План на сегодня',
        notes: longBody,
        incomeAmount: 999.99,
        attachments: const [
          NoteAttachment(
            id: 'test-fill-att-plan-pdf',
            fileName: 'план-дня.pdf',
            storagePath: 'attachments/test-fill/plan-dnya.pdf',
            mimeType: 'application/pdf',
          ),
          NoteAttachment(
            id: 'test-fill-att-photo',
            fileName: 'образец.jpg',
            storagePath: 'attachments/test-fill/obrazec.jpg',
            mimeType: 'image/jpeg',
          ),
        ],
      ),
      _note(
        id: 'test-fill-note-derived-today',
        profileId: profileId,
        day: today,
        title: deriveNoteTitleFromBody(derivedBody),
        notes: derivedBody,
      ),
      _checklist(
        id: 'test-fill-checklist-today',
        profileId: profileId,
        day: today,
        title: 'Чек-лист на сегодня',
        pomodoroEnabled: true,
        rootCompleted: false,
      ),
    ];
  }

  static AppEvent _weekendStandalone(String profileId, DateTime day) {
    return _timed(
      id: 'test-fill-weekend-long-title',
      profileId: profileId,
      start: _at(day, 14, 0),
      end: _at(day, 16, 0),
      title:
          'Выходной блок · очень длинный заголовок, чтобы проверить перенос в неделе, повестке и карточке месяца',
      color: Colors.orange,
      notes: stressText(
        label: 'Выходной',
        charCount: 280,
        dayOfYear: day.difference(DateTime(day.year, 1, 1)).inDays + 1,
      ),
      reminderMinutesBefore: 45,
    );
  }

  static List<AppEvent> _monthlyNotesAndChecklists(
    String profileId,
    int year,
    DateTime today,
  ) {
    final events = <AppEvent>[];
    for (var month = 1; month <= 12; month++) {
      final noteDay = DateTime(year, month, 15);
      final derived = month.isEven;
      final body = derived
          ? 'Заметка ${_monthLabel(month)}\nТело без отдельного заголовка — карточка дня показывает полный текст.'
          : stressText(
              label: 'Заметка ${_monthLabel(month)}',
              charCount: month == 3 || month == 9 ? 480 : 160,
              dayOfYear: noteDay.difference(DateTime(year, 1, 1)).inDays + 1,
            );
      events.add(
        _note(
          id: 'test-fill-note-month-$year-$month',
          profileId: profileId,
          day: noteDay,
          title: derived
              ? deriveNoteTitleFromBody(body)
              : 'Заметка · ${_monthLabel(month)}',
          notes: body,
        ),
      );

      if (month == 1 || month == 6 || month == 12 || month == today.month) {
        final checklistDay = DateTime(year, month, 20);
        if (!_sameDay(checklistDay, today)) {
          events.add(
            _checklist(
              id: 'test-fill-checklist-$year-$month',
              profileId: profileId,
              day: checklistDay,
              title: 'Чек-лист · ${_monthLabel(month)}',
              rootCompleted: month.isEven,
            ),
          );
        }
      }
    }
    return events;
  }

  static List<AppEvent> _monthlyAfternoonEvents(
    String profileId,
    int year,
    DateTime today,
  ) {
    final events = <AppEvent>[];
    for (var month = 1; month <= 12; month++) {
      final day = DateTime(year, month, 15, 17, 0);
      if (_sameDay(day, today)) continue;
      events.add(
        _timed(
          id: 'test-fill-event-month-$year-$month',
          profileId: profileId,
          start: day,
          end: DateTime(year, month, 15, 17, 40),
          title: 'Встреча · ${_monthLabel(month)}',
          color: _palette[(month - 1) % _palette.length],
          incomeAmount: month % 3 == 0 ? 3_200 + month * 150.0 : null,
          reminderMinutesBefore: month.isOdd ? 15 : null,
        ),
      );
    }
    return events;
  }

  static AppEvent _timed({
    required String id,
    required String profileId,
    required DateTime start,
    required DateTime end,
    required String title,
    required Color color,
    String? notes,
    String? rrule,
    DateTime? recurrenceUntil,
    String? seriesId,
    List<DateTime> recurrenceExclusions = const [],
    double? incomeAmount,
    bool isGift = false,
    int? reminderMinutesBefore,
    bool pomodoroEnabled = false,
    int pomodoroWorkMinutes = 25,
    int pomodoroBreakMinutes = 5,
    int pomodoroCompletedSessions = 0,
  }) {
    return AppEvent(
      id: id,
      dateTimeRange: DateTimeRange(start: start, end: end),
      title: title,
      startTime: _hhmm(start),
      endTime: _hhmm(end),
      color: color,
      kind: CalendarEntryKind.event,
      contextProfileId: profileId,
      notes: notes,
      rrule: rrule,
      recurrenceUntil: recurrenceUntil,
      seriesId: seriesId ?? (rrule == null ? null : id),
      recurrenceExclusions: recurrenceExclusions,
      incomeAmount: incomeAmount,
      isGift: isGift,
      reminderMinutesBefore: reminderMinutesBefore,
      pomodoroEnabled: pomodoroEnabled,
      pomodoroWorkMinutes: pomodoroWorkMinutes,
      pomodoroBreakMinutes: pomodoroBreakMinutes,
      pomodoroCompletedSessions: pomodoroCompletedSessions,
    );
  }

  static AppEvent _note({
    required String id,
    required String profileId,
    required DateTime day,
    required String title,
    required String notes,
    double? incomeAmount,
    List<NoteAttachment> attachments = const [],
  }) {
    return AppEvent(
      id: id,
      dateTimeRange: AppEvent.dateOnlyRange(day),
      title: title,
      startTime: '',
      endTime: '',
      color: Colors.amber.shade700,
      kind: CalendarEntryKind.note,
      contextProfileId: profileId,
      notes: notes,
      incomeAmount: incomeAmount,
      attachments: attachments,
    );
  }

  static AppEvent _checklist({
    required String id,
    required String profileId,
    required DateTime day,
    required String title,
    bool rootCompleted = false,
    bool pomodoroEnabled = false,
  }) {
    final prefix = '$id-item';
    return AppEvent(
      id: id,
      dateTimeRange: AppEvent.dateOnlyRange(day),
      title: title,
      startTime: '',
      endTime: '',
      color: Colors.teal.shade600,
      kind: CalendarEntryKind.checklist,
      contextProfileId: profileId,
      pomodoroEnabled: pomodoroEnabled,
      pomodoroWorkMinutes: 25,
      pomodoroBreakMinutes: 5,
      checklist: [
        ChecklistItem(
          id: '$prefix-1',
          title: 'Подготовка',
          completed: rootCompleted,
          children: [
            ChecklistItem(
              id: '$prefix-1a',
              title: 'Собрать документы',
              completed: rootCompleted,
            ),
            ChecklistItem(
              id: '$prefix-1b',
              title: 'Проверить вложенный список',
              children: [
                ChecklistItem(
                  id: '$prefix-1b1',
                  title: 'Вложенный пункт',
                  completed: true,
                ),
              ],
            ),
          ],
        ),
        ChecklistItem(id: '$prefix-2', title: 'Покупки и дела'),
      ],
    );
  }

  static AppEvent _shiftOverride({
    required String scheduleId,
    required String profileId,
    required DateTime day,
    required String title,
    required Color color,
    String startTime = shiftStart,
    String endTime = shiftEnd,
    bool shiftSkipped = false,
    int? overtimeMinutes,
    int? unpaidMinutes,
    String? notes,
  }) {
    final startParts = _parseHm(startTime);
    final endParts = _parseHm(endTime);
    final start = DateTime(
      day.year,
      day.month,
      day.day,
      startParts.$1,
      startParts.$2,
    );
    final end = DateTime(
      day.year,
      day.month,
      day.day,
      endParts.$1,
      endParts.$2,
    );
    return AppEvent(
      id: AppEvent.scheduleOverrideId(scheduleId, day),
      dateTimeRange: DateTimeRange(start: start, end: end),
      title: title,
      startTime: startTime,
      endTime: endTime,
      color: color,
      seriesId: 'schedule-$scheduleId',
      contextProfileId: profileId,
      explicitEntrySource: CalendarEntrySource.scheduleOverride,
      notes: notes,
      shiftSkipped: shiftSkipped,
      overtimeMinutes: overtimeMinutes,
      unpaidMinutes: unpaidMinutes,
    );
  }

  static String stressText({
    required String label,
    required int charCount,
    required int dayOfYear,
  }) {
    if (charCount <= 0) return label;
    final header = '[$label · день $dayOfYear · $charCount симв.]\n';
    final buffer = StringBuffer(header);
    var chunkIndex = 0;
    while (buffer.length < charCount) {
      buffer.write(_textChunks[chunkIndex % _textChunks.length]);
      chunkIndex++;
    }
    return buffer.toString().substring(0, charCount);
  }

  static String _monthLabel(int month) {
    const ru = [
      'янв',
      'фев',
      'мар',
      'апр',
      'май',
      'июн',
      'июл',
      'авг',
      'сен',
      'окт',
      'ноя',
      'дек',
    ];
    return ru[month - 1];
  }

  static DateTime _at(DateTime day, int hour, int minute) {
    return DateTime(day.year, day.month, day.day, hour, minute);
  }

  static String _hhmm(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  static (int, int) _parseHm(String value) {
    final parts = value.split(':');
    return (int.parse(parts[0]), int.parse(parts[1]));
  }

  static bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static DateTime _clampToYear(int year, DateTime source) {
    final last = DateTime(year, 12, 31);
    var day = DateTime(year, source.month, source.day);
    if (day.isAfter(last)) return last;
    return DateTime(day.year, day.month, day.day);
  }

  static DateTime _firstWeekday(int year, int weekday) {
    var day = DateTime(year, 1, 1);
    while (day.weekday != weekday) {
      day = day.add(const Duration(days: 1));
    }
    return day;
  }

  static DateTime _excludedMonday(DateTime today, DateTime weeklyStart) {
    var monday = today.subtract(
      Duration(days: today.weekday - DateTime.monday),
    );
    monday = DateTime(monday.year, monday.month, monday.day);
    if (monday.year != today.year || !monday.isAfter(weeklyStart)) {
      monday = weeklyStart.add(const Duration(days: 7));
    }
    return monday;
  }

  static bool _isFillShiftWorkDay(int year, DateTime date) {
    return isShiftWorkDay(
      cycleStartDate: DateTime(year, 1, 1),
      workDays: 2,
      restDays: 2,
      date: date,
    );
  }

  static DateTime _nearestWeekend(int year, DateTime start) {
    for (var offset = 0; offset <= 8; offset++) {
      final forward = start.add(Duration(days: offset));
      if (forward.year == year &&
          (forward.weekday == DateTime.saturday ||
              forward.weekday == DateTime.sunday)) {
        return DateTime(forward.year, forward.month, forward.day);
      }
      if (offset == 0) continue;
      final back = start.subtract(Duration(days: offset));
      if (back.year == year &&
          (back.weekday == DateTime.saturday ||
              back.weekday == DateTime.sunday)) {
        return DateTime(back.year, back.month, back.day);
      }
    }
    return DateTime(year, 1, 3);
  }

  static DateTime? _nearestShiftWorkDay(int year, DateTime start) {
    for (var offset = 0; offset <= 8; offset++) {
      final forward = start.add(Duration(days: offset));
      if (forward.year == year && _isFillShiftWorkDay(year, forward)) {
        return DateTime(forward.year, forward.month, forward.day);
      }
      if (offset == 0) continue;
      final back = start.subtract(Duration(days: offset));
      if (back.year == year && _isFillShiftWorkDay(year, back)) {
        return DateTime(back.year, back.month, back.day);
      }
    }
    return null;
  }

  static DateTime? _anotherShiftWorkDay(
    int year,
    DateTime conflictDay, {
    DateTime? alsoSkip,
  }) {
    for (var offset = 1; offset <= 16; offset++) {
      final back = conflictDay.subtract(Duration(days: offset));
      if (back.year != year) break;
      if (!_isFillShiftWorkDay(year, back)) continue;
      if (alsoSkip != null && _sameDay(back, alsoSkip)) continue;
      return DateTime(back.year, back.month, back.day);
    }
    for (var offset = 1; offset <= 16; offset++) {
      final forward = conflictDay.add(Duration(days: offset));
      if (forward.year != year) break;
      if (!_isFillShiftWorkDay(year, forward)) continue;
      if (alsoSkip != null && _sameDay(forward, alsoSkip)) continue;
      return DateTime(forward.year, forward.month, forward.day);
    }
    return null;
  }

  static DateTime? _officeSkipDay(
    int year,
    DateTime today,
    DateTime conflictDay,
  ) {
    for (var day = 1; day <= 28; day++) {
      final candidate = DateTime(year, today.month, day);
      if (candidate.weekday > DateTime.friday) continue;
      if (_sameDay(candidate, today) || _sameDay(candidate, conflictDay)) {
        continue;
      }
      return candidate;
    }
    return null;
  }

  static const _palette = [
    Colors.blue,
    Colors.deepPurple,
    Colors.orange,
    Colors.pink,
    Colors.cyan,
    Colors.brown,
  ];
}
