part of 'app_localizations.dart';

mixin _CalendarStrings on _LocalizationStringsBase {
  String get month => isRu ? 'Месяц' : 'Month';
  String get week => isRu ? 'Неделя' : 'Week';
  String get agenda => isRu ? 'Список' : 'Agenda';
  String get agendaCollapseDay =>
      isRu ? 'Свернуть события дня' : 'Collapse day events';
  String get agendaExpandDay =>
      isRu ? 'Развернуть события дня' : 'Expand day events';
  String get agendaCollapseAll => isRu ? 'Свернуть всё' : 'Collapse all';
  String get agendaExpandAll => isRu ? 'Развернуть всё' : 'Expand all';
  String get year => isRu ? 'Год' : 'Year';
  String get previousPeriod => isRu ? 'Предыдущий период' : 'Previous period';
  String get nextPeriod => isRu ? 'Следующий период' : 'Next period';
  String get today => isRu ? 'Сегодня' : 'Today';
  String get editEvent => isRu ? 'Редактировать событие' : 'Edit event';
  String get duplicateEntry => isRu ? 'Дублировать' : 'Duplicate';
  String get deleteEvent => isRu ? 'Удалить событие' : 'Delete event';
  String get deleteEventConfirm => isRu
      ? 'Удалить это событие? Действие нельзя отменить.'
      : 'Delete this event? This cannot be undone.';
  String get scheduleEventHint => isRu
      ? 'Изменения сохранятся только для этого дня. Правило расписания — в «Рабочие расписания».'
      : 'Changes apply to this day only. Edit the rule in Work schedules.';
  String get scheduleEventDeleteHint => isRu
      ? 'Событие из расписания нельзя удалить здесь. Удалите правило в «Рабочие расписания».'
      : 'Schedule events cannot be deleted here. Remove the rule in Work schedules.';
  String get revertScheduleOverride =>
      isRu ? 'Вернуть как в расписании' : 'Revert to schedule';
  String get revertScheduleOverrideConfirm => isRu
      ? 'Сбросить изменения этого дня и вернуть смену из правила расписания?'
      : 'Discard changes for this day and restore the shift from the schedule rule?';
  String get scheduleOverrideDeleteHint => isRu
      ? 'Чтобы убрать изменения дня, откройте смену и нажмите «Вернуть как в расписании».'
      : 'To discard day changes, open the shift and tap “Revert to schedule”.';
  String get editRecurrenceSeriesBanner => isRu
      ? 'Редактируется вся серия повторений'
      : 'Editing the entire recurrence series';
  String get editRecurrenceScopeLabel =>
      isRu ? 'Применить изменения' : 'Apply changes to';
  String get editThisOccurrence =>
      isRu ? 'Только этот день' : 'This occurrence only';
  String get editWholeSeries => isRu ? 'Вся серия' : 'Entire series';
  String get editSchedule =>
      isRu ? 'Редактировать расписание' : 'Edit schedule';
  String get editScheduleTitle =>
      isRu ? 'Редактировать расписание' : 'Edit schedule';
  String get newScheduleTitle => isRu ? 'Новое расписание' : 'New schedule';
  String get fromWorkSchedule =>
      isRu ? 'Из рабочего расписания' : 'From work schedule';
  String get fromBookingSession => isRu ? 'Из бронирования' : 'From booking';
  String get colorFilterNoMatches => isRu
      ? 'Нет событий выбранных цветов'
      : 'No events match the selected colors';
  String get colorFilterNoMatchesHint => isRu
      ? 'Сбросьте фильтр или выберите другие цвета'
      : 'Reset the filter or pick other colors';
  String get addEvent => isRu ? 'Добавить' : 'Add';
  String get undatedEntryLabel => isRu ? 'Без даты' : 'No date';
  String get undatedEntryHint => isRu
      ? 'Попадёт во входящие, пока не перенесёте на день'
      : 'Goes to Inbox until you schedule a day';
  String get undatedInboxSectionTitle =>
      isRu ? 'Без даты' : 'Unscheduled';
  String get undatedInboxEmpty => isRu
      ? 'Нет заметок и чек-листов без даты'
      : 'No unscheduled notes or checklists';
  String get addUndatedNote =>
      isRu ? 'Заметка без даты' : 'Note without a date';
  String get scheduleOnDayAction =>
      isRu ? 'Назначить день' : 'Schedule a day';
  String get addEntryTitleHint => isRu ? 'Добавьте название' : 'Add title';
  String get allDay => isRu ? 'Весь день' : 'All day';
  String get myCalendar => isRu ? 'Мой календарь' : 'My calendar';
  String get addDescriptionHint =>
      isRu ? 'Добавьте описание' : 'Add description';
  String get defaultEventColor => isRu ? 'Цвет по умолчанию' : 'Default color';
  String get addNotification =>
      isRu ? 'Добавить уведомление' : 'Add notification';
  String get dateLabel => isRu ? 'Дата' : 'Date';
  String get entryProfileLabel => isRu ? 'Профиль' : 'Profile';
  String eventFormDateLabel(DateTime date) {
    final locale = isRu ? 'ru' : 'en';
    return DateFormat('EEE, d MMM y', locale).format(date.toLocal());
  }

  String get createEvent => isRu ? 'Создать событие' : 'Create event';
  String get createEntryTitle => isRu ? 'Что создать?' : 'What to create?';
  String createEntryForDate(DateTime date) =>
      isRu ? 'Создать на ${fullDate(date)}' : 'Create for ${fullDate(date)}';
  String createBarSlotLabel(String timeRange) =>
      isRu ? 'Слот $timeRange' : 'Slot $timeRange';
  String get createForDayAction => isRu ? 'Создать…' : 'Create…';
  String get entryKindEvent => isRu ? 'Событие' : 'Event';
  String get entryKindNote => isRu ? 'Заметка' : 'Note';
  String get entryKindChecklist => isRu ? 'Чек-лист' : 'Checklist';
  String get entryKindEventHint => isRu
      ? 'С временем, напоминанием и повтором'
      : 'With time, reminders, and recurrence';
  String get entryKindNoteHint =>
      isRu ? 'Текст на дату без времени' : 'Text for a date without time';
  String get entryKindChecklistHint =>
      isRu ? 'Список задач на день' : 'Task list for the day';
  String get entryKindWorkSchedule =>
      isRu ? 'Рабочее расписание' : 'Work schedule';
  String get entryKindWorkScheduleHint => isRu
      ? 'Циклические смены и повторяющиеся рабочие дни'
      : 'Recurring shifts and work-day patterns';
  String get entryKindSavingsGoal => isRu ? 'Цель накопления' : 'Savings goal';
  String get createNote => isRu ? 'Создать заметку' : 'Create note';
  String get createChecklist => isRu ? 'Создать чек-лист' : 'Create checklist';
  String get editNote => isRu ? 'Редактировать заметку' : 'Edit note';
  String get editChecklist =>
      isRu ? 'Редактировать чек-лист' : 'Edit checklist';
  String get addNote => isRu ? 'Добавить заметку' : 'Add note';
  String get addChecklist => isRu ? 'Добавить чек-лист' : 'Add checklist';
  String get emptyNoteBody =>
      isRu ? 'Введите текст заметки' : 'Enter note text';
  String get emptyChecklistItems =>
      isRu ? 'Добавьте хотя бы одну задачу' : 'Add at least one checklist item';
  String get defaultNoteTitle => isRu ? 'Заметка' : 'Note';
  String get defaultChecklistTitle => isRu ? 'Чек-лист' : 'Checklist';
  String get noteTitleOptional =>
      isRu ? 'Заголовок (необязательно)' : 'Title (optional)';
  String createEntryTitleForKind(CalendarEntryKind kind) {
    switch (kind) {
      case CalendarEntryKind.event:
        return createEvent;
      case CalendarEntryKind.note:
        return createNote;
      case CalendarEntryKind.checklist:
        return createChecklist;
      case CalendarEntryKind.savingsGoal:
        return addSavingsGoal;
    }
  }

  String editEntryTitleForKind(CalendarEntryKind kind) {
    switch (kind) {
      case CalendarEntryKind.event:
        return editEvent;
      case CalendarEntryKind.note:
        return editNote;
      case CalendarEntryKind.checklist:
        return editChecklist;
      case CalendarEntryKind.savingsGoal:
        return editSavingsGoalTitle;
    }
  }

  String viewEntryTitleForKind(CalendarEntryKind kind) {
    switch (kind) {
      case CalendarEntryKind.event:
        return entryKindEvent;
      case CalendarEntryKind.note:
        return entryKindNote;
      case CalendarEntryKind.checklist:
        return entryKindChecklist;
      case CalendarEntryKind.savingsGoal:
        return entryKindSavingsGoal;
    }
  }

  String get create => isRu ? 'Создать' : 'Create';
  String get notes => isRu ? 'Заметки' : 'Notes';
  String get eventAmountFieldLabel => isRu ? 'Сумма, ₽' : 'Amount, ₽';
  String get eventAmountFieldHint =>
      isRu ? 'Например, оплата за заказ' : 'e.g. payment for a job';
  String get incomeGiftLabel => isRu ? 'Подарок / без оплаты' : 'Gift / unpaid';
  String get incomeGiftHint => isRu
      ? 'Сумма не учитывается в статистике дохода'
      : 'Amount is excluded from income statistics';
  String get recurrenceUntilLabel => isRu ? 'Повторять до' : 'Repeat until';
  String get recurrenceUntilClear =>
      isRu ? 'Без даты окончания' : 'No end date';
  String get shiftQuickSkip => isRu ? 'Пропустить' : 'Skip shift';
  String get shiftQuickUnskip => isRu ? 'Вернуть смену' : 'Unskip';
  String get shiftQuickAddOvertime30 =>
      isRu ? '+30 мин сверхурочных' : '+30 min overtime';
  String get shiftQuickSkipCompact => isRu ? 'Пропуск' : 'Skip';
  String get shiftQuickUnskipCompact => isRu ? 'Вернуть' : 'Back';
  String get shiftQuickOvertimeCompact => isRu ? '+30 мин' : '+30 min';
  String get invalidAmount =>
      isRu ? 'Укажите сумму больше 0' : 'Enter an amount greater than 0';
  String get pomodoroSwitchLabel => 'Pomodoro';
  String get pomodoroSwitchHint => isRu
      ? 'Таймер фокуса для этого события'
      : 'Focus timer linked to this event';
  String get pomodoroWorkMinutesLabel => isRu ? 'Работа, мин' : 'Work, min';
  String get pomodoroBreakMinutesLabel => isRu ? 'Перерыв, мин' : 'Break, min';
  String pomodoroSessionsLine(int completed) =>
      isRu ? 'Сессий: $completed' : 'Sessions: $completed';
  String get pomodoroStart => isRu ? 'Старт' : 'Start';
  String get pomodoroPause => isRu ? 'Пауза' : 'Pause';
  String get pomodoroReset => isRu ? 'Сброс' : 'Reset';
  String get pomodoroStartWork => isRu ? 'Старт задачи' : 'Start work';
  String get pomodoroStartBreak => isRu ? 'Перерыв' : 'Break';
  String get pomodoroEndSession => isRu ? 'Остановить' : 'Stop session';
  String get pomodoroPhaseWork => isRu ? 'Работа' : 'Work';
  String get pomodoroPhaseBreak => isRu ? 'Перерыв' : 'Break';
  String get pomodoroOpenTimer => 'Pomodoro';
  String pomodoroLiveRunning(String time, String phase) =>
      isRu ? 'Pomodoro: $time · $phase' : 'Pomodoro: $time · $phase';
  String pomodoroLivePaused(String time, String phase) => isRu
      ? 'Pomodoro на паузе: $time · $phase'
      : 'Pomodoro paused: $time · $phase';
  String get invalidPomodoroMinutes =>
      isRu ? 'Укажите 1–180 минут' : 'Enter 1–180 minutes';
  String get noteAttachmentsLabel => isRu ? 'Файлы и фото' : 'Files & photos';
  String get addPhotoFromGallery => isRu ? 'Галерея' : 'Gallery';
  String get addPhotoFromCamera => isRu ? 'Камера' : 'Camera';
  String get addFile => isRu ? 'Файл' : 'File';
  String noteAttachmentsCount(int count) =>
      isRu ? '$count влож.' : '$count attached';
  String get attachmentPickError =>
      isRu ? 'Не удалось добавить файл' : 'Could not add file';
  String get openAttachmentError =>
      isRu ? 'Не удалось открыть файл' : 'Could not open file';
  String get reminder => isRu ? 'Напоминание' : 'Reminder';
  String get reminderFireTimeLabel =>
      isRu ? 'Время напоминания' : 'Reminder time';
  String get reminderFireTimeHint => isRu
      ? 'Когда прислать уведомление о событии'
      : 'When to send the event notification';
  String get reminderNeedsEventStart => isRu
      ? 'Сначала укажите время начала события'
      : 'Set the event start time first';
  String reminderBeforeEventSummary(int minutes) => isRu
      ? '${reminderLabel(minutes)} до начала'
      : '${reminderLabel(minutes)} before start';
  String get reminderCustomInvalid => isRu
      ? 'Некорректное время (часы 0–23, минуты 0–59)'
      : 'Invalid time (hours 0–23, minutes 0–59)';

  // ——— События / UI ———
  String get editRecurrenceSeriesHint => isRu
      ? 'Редактирование серии повторяющихся событий'
      : 'Editing a recurring event series';
  String get emptyChecklist => isRu ? 'Чек-лист пустой' : 'Checklist is empty';
  String get checklistTitle => isRu ? 'Чек-лист' : 'Checklist';
  String get checklistEditorHint => isRu
      ? 'Задачи в одной строке; отступ и линии показывают подзадачи.'
      : 'Tasks on one line; indent and lines show subtasks.';
  String get checklistEmptyEditorHint =>
      isRu ? 'Добавьте задачи или подзадачи.' : 'Add tasks or subtasks.';
  String get checklistNewTask => isRu ? 'Новая задача' : 'New task';
  String get checklistAddTaskTooltip => isRu ? 'Добавить задачу' : 'Add task';
  String checklistSubtaskFor(String title) =>
      isRu ? 'Подзадача для «$title»' : 'Subtask for “$title”';
  String get checklistSubtaskName =>
      isRu ? 'Название подзадачи' : 'Subtask name';
  String get checklistTaskHint => isRu ? 'Задача' : 'Task';
  String get checklistSubtaskHint => isRu ? 'Подзадача' : 'Subtask';
  String get checklistSubtaskTooltip => isRu ? 'Подзадача' : 'Subtask';
  String get colorFilterLabel => isRu ? 'Цвет:' : 'Color:';
  String get colorFilterReset => isRu ? 'Сброс' : 'Reset';
  String eventProfileLabel(String name) =>
      isRu ? 'Профиль: $name' : 'Profile: $name';
  String get timeFieldHint => isRu ? 'ЧЧММ' : 'HHMM';
  String get timeFieldHelper =>
      isRu ? 'Введите 4 цифры, например 0930' : 'Enter 4 digits, e.g. 0930';
  String get pickTimeTooltip => isRu ? 'Выбрать время' : 'Pick time';
  String get defaultProfileName => isRu ? 'Личный' : 'Personal';
  String get operationFailed =>
      isRu ? 'Не удалось выполнить операцию' : 'Operation failed';

  // ——— Push-уведомления ———
  String get notificationChannelName =>
      isRu ? 'Напоминания о событиях' : 'Event reminders';
  String get notificationChannelDescription => isRu
      ? 'Напоминания перед началом событий календаря'
      : 'Reminders before calendar events start';
  String get notificationEventStartingNow =>
      isRu ? 'Событие начинается сейчас' : 'Event starts now';
  String notificationInDays(int days, String timeRange) =>
      isRu ? 'Через $days дн. · $timeRange' : 'In $days day(s) · $timeRange';
  String notificationInHours(int hours, String timeRange) =>
      isRu ? 'Через $hours ч · $timeRange' : 'In $hours h · $timeRange';
  String notificationInMinutes(int minutes, String timeRange) =>
      isRu ? 'Через $minutes мин · $timeRange' : 'In $minutes min · $timeRange';

  // ——— Рабочие расписания ———
  String scheduleProfileHint(String profileName) => isRu
      ? 'Профиль: $profileName. Редактируйте правило или отдельные дни в календаре.'
      : 'Profile: $profileName. Edit the rule here or individual days in the calendar.';
  String get noSchedulesHint => isRu
      ? 'Нет расписаний. Добавьте сменный или недельный график.'
      : 'No schedules yet. Add a shift or weekly pattern.';
  String get addSchedule => isRu ? 'Добавить расписание' : 'Add schedule';
  String shiftSchedulePattern(int work, int rest, DateTime? cycleStart) {
    if (cycleStart == null) return '$work/$rest';
    final d = cycleStart.day.toString().padLeft(2, '0');
    final m = cycleStart.month.toString().padLeft(2, '0');
    final date = '$d.$m.${cycleStart.year}';
    return isRu ? '$work/$rest с $date' : '$work/$rest from $date';
  }

  String schedulePatternLabel({
    required bool isShiftCycle,
    required int workDays,
    required int restDays,
    required DateTime? cycleStartDate,
    required String rrule,
  }) {
    if (isShiftCycle) {
      return shiftSchedulePattern(workDays, restDays, cycleStartDate);
    }
    if (rrule.isEmpty) return '—';
    return formatRrule(rrule);
  }

  String formatRrule(String rrule) {
    final normalized = rrule.trim().toUpperCase();
    if (normalized.isEmpty) return '—';

    if (normalized.contains('FREQ=DAILY')) {
      return patternDaily;
    }
    if (normalized.contains('FREQ=MONTHLY')) {
      return recurrencePresetLabel(RecurrencePreset.monthly);
    }

    if (normalized.contains('FREQ=WEEKLY')) {
      final byDay = _extractRruleByDay(normalized);
      if (byDay.isEmpty) {
        return patternWeekly;
      }
      if (_sameRruleDays(byDay, {'MO', 'TU', 'WE', 'TH', 'FR'})) {
        return patternWeekdays;
      }
      if (_sameRruleDays(byDay, {'MO', 'WE', 'FR'})) {
        return patternMonWedFri;
      }
      return rruleWeeklyOn(_formatRruleDayList(byDay));
    }

    return rruleCustom;
  }

  Set<String> _extractRruleByDay(String rrule) {
    final match = RegExp(r'BYDAY=([^;]+)').firstMatch(rrule);
    if (match == null) return const {};
    return match.group(1)!.split(',').map((d) => d.trim()).toSet();
  }

  bool _sameRruleDays(Set<String> left, Set<String> right) {
    if (left.length != right.length) return false;
    return left.containsAll(right);
  }

  String _formatRruleDayList(Set<String> days) {
    const order = ['MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU'];
    const codesToWeekday = {
      'MO': DateTime.monday,
      'TU': DateTime.tuesday,
      'WE': DateTime.wednesday,
      'TH': DateTime.thursday,
      'FR': DateTime.friday,
      'SA': DateTime.saturday,
      'SU': DateTime.sunday,
    };
    final labels = order
        .where(days.contains)
        .map((code) => shortWeekday(codesToWeekday[code]!))
        .toList();
    return labels.join(isRu ? ', ' : ', ');
  }

  String shiftKindLabel(int work, int rest) =>
      isRu ? 'Сменный $work/$rest' : 'Shift $work/$rest';
  String get weekdayKindLabel => isRu ? 'По дням недели' : 'By weekday';
  String get scheduleKindShift => isRu ? 'Сменный' : 'Shift';
  String get scheduleKindWeek => isRu ? 'Неделя' : 'Week';
  String cycleStartDate(String date) =>
      isRu ? 'Дата начала: $date' : 'Start date: $date';
  String get customPattern => isRu ? 'Свой' : 'Custom';
  String get workDaysLabel => isRu ? 'Рабочих дней' : 'Work days';
  String get restDaysLabel => isRu ? 'Выходных дней' : 'Rest days';
  String cycleSummary(int work, int rest) => isRu
      ? 'Цикл: $work раб. + $rest выходн. = ${work + rest} дн.'
      : 'Cycle: $work work + $rest off = ${work + rest} days';
  String get weekdayPattern => isRu ? 'Дни недели' : 'Weekdays';

  @override
  String get patternDaily => isRu ? 'Ежедневно' : 'Daily';
  String get patternWeekdays => isRu ? 'Будни (Пн–Пт)' : 'Weekdays (Mon–Fri)';
  String get patternMonWedFri => isRu ? 'Пн, Ср, Пт' : 'Mon, Wed, Fri';

  @override
  String get patternWeekly => isRu ? 'Еженедельно' : 'Weekly';
  String rruleWeeklyOn(String days) =>
      isRu ? 'Еженедельно: $days' : 'Weekly: $days';
  String get rruleCustom => isRu ? 'Своё правило' : 'Custom rule';
  String get swipeActionsHint => isRu
      ? 'Смахните карточку вправо — редактировать, влево — удалить'
      : 'Swipe right to edit, left to delete';
  String get weekDragHint => isRu
      ? 'Зажмите событие и перетащите его в другой день недели'
      : 'Press and hold an event, then drag it to another day';
  String get weekEventLocked =>
      isRu ? 'Событие заблокировано' : 'Event is locked';
  String get hintDismiss => isRu ? 'Понятно' : 'Got it';
  String get paySection => isRu ? 'Оплата' : 'Pay';
  String get payRateType => isRu ? 'Тип ставки' : 'Rate type';
  String payRateLabel(PayRateMode mode) => switch (mode) {
    PayRateMode.hourly => isRu ? 'Почасовая' : 'Hourly',
    PayRateMode.daily => isRu ? 'Подневная' : 'Daily',
    PayRateMode.monthly => isRu ? 'Помесячная' : 'Monthly',
  };
  String get hourlyRateLabel => isRu ? 'Ставка, ₽/ч' : 'Rate, ₽/h';
  String get dailyRateLabel => isRu ? 'Ставка, ₽/смена' : 'Rate, ₽/shift';
  String get overtimeHourlyRateLabel =>
      isRu ? 'Почасовая для сверхурочных, ₽/ч' : 'Overtime hourly, ₽/h';
  String get monthlyRateLabel => isRu ? 'Оклад, ₽/мес' : 'Salary, ₽/month';
  String get standardHoursLabel => isRu ? 'Норма часов' : 'Standard hours';
  String get overtimeMultiplierLabel => isRu ? 'Коэф. СУ' : 'OT multiplier';
  String get overtimeMultiplierHint => isRu
      ? 'Коэффициент сверхурочных: оплата СУ = часы × ставка × коэф. '
            '(обычно 1,5 или 2).'
      : 'Overtime multiplier: OT pay = hours × rate × multiplier '
            '(often 1.5 or 2).';
  String get breakMinutesLabel =>
      isRu ? 'Перерыв (мин, неоплачиваемый)' : 'Break (min, unpaid)';
  String get payExtrasSection => isRu ? 'Дополнительно' : 'Additional';
  String get vatPercentLabel => isRu ? 'НДФЛ, %' : 'Income tax, %';
  String get vatPercentHint => isRu
      ? 'Удерживается из суммы заработка и премий'
      : 'Withheld from earnings and bonuses';
  String get bonusPercentLabel => isRu ? 'Премия, %' : 'Bonus, %';
  String get bonusPercentHint => isRu
      ? 'Процент от заработка, начисляется сверх ставки'
      : 'Percent of earnings, added on top of base pay';
  String get bonusAmountLabel => isRu ? 'Премия, ₽/мес' : 'Bonus, ₽/month';
  String get bonusAmountHint => isRu
      ? 'Фиксированная доплата за месяц при наличии смен'
      : 'Fixed monthly bonus when shifts are worked';
  String get statBonusPay => isRu ? 'Премия' : 'Bonus';
  String get statVatPay => isRu ? 'НДФЛ (удерж.)' : 'Income tax withheld';
  String payBreakdownBonus(String amount) =>
      isRu ? 'Премия: $amount' : 'Bonus: $amount';
  String payBreakdownBonusPercent(String percent, String amount) =>
      isRu ? 'Премия $percent%: $amount' : 'Bonus $percent%: $amount';
  String payBreakdownVat(
    String gross,
    String percent,
    String vat,
    String net,
  ) => isRu
      ? '$gross − $percent% НДФЛ ($vat) = $net'
      : '$gross − $percent% income tax ($vat) = $net';
  String get shiftStartLabel => isRu ? 'Начало смены' : 'Shift start';
  String get shiftEndLabel => isRu ? 'Конец смены' : 'Shift end';
}
