part of 'app_localizations.dart';

mixin _CommonStrings on _LocalizationStringsBase {
  String get emptyTitle =>
      isRu ? 'Введите название события' : 'Enter event title';
  String get save => isRu ? 'Сохранить' : 'Save';
  String get cancel => isRu ? 'Отмена' : 'Cancel';
  String get undo => isRu ? 'Отменить' : 'Undo';
  String get closeTooltip => isRu ? 'Закрыть' : 'Close';
  String get settingsTitle => isRu ? 'Настройки' : 'Settings';
  String get settingsGroupProfile => isRu ? 'Профиль' : 'Profile';
  String get settingsGroupAppearance => isRu ? 'Оформление' : 'Appearance';
  String get settingsGroupServer => isRu ? 'Сервер' : 'Server';
  String get workspaceTitle =>
      isRu ? 'Рабочее пространство' : 'Workspace';
  String get workspaceSubtitle => isRu
      ? 'Семья, запись клиентов и подключение к своей базе'
      : 'Family, client booking, and your database';
  String get workspaceFamilyTitle => isRu ? 'Семья' : 'Family';
  String get workspaceCommerceTitle =>
      isRu ? 'Запись клиентов' : 'Client booking';
  String get workspaceAdvancedTitle =>
      isRu ? 'Дополнительно' : 'Advanced';
  String get workspaceAdvancedHint => isRu
      ? 'Сервер, API-ключ, мини-сервер и YDB'
      : 'Server, API key, mini-server, and YDB';
  String get inviteFamilyAction =>
      isRu ? 'Пригласить ссылкой' : 'Invite with a link';
  String get inviteFamilyHint => isRu
      ? 'Семья открывает ссылку — без ввода API Key'
      : 'Family opens the link — no API key to type';
  String get inviteFamilyNeedsServer => isRu
      ? 'Сначала укажите сервер в «Дополнительно»'
      : 'Set a server under Advanced first';
  String get familyMembersTitle => isRu ? 'Участники' : 'Members';
  String get showTogetherAction =>
      isRu ? 'Показать вместе' : 'Show together';
  String get familyInviteCopied => isRu
      ? 'Ссылка-приглашение скопирована'
      : 'Invite link copied';
  String familyInviteShareText({
    required String name,
    required String httpLink,
    required String appLink,
  }) => isRu
      ? 'Приглашение в Almanac «$name»\n$httpLink\n$appLink'
      : 'Almanac invite “$name”\n$httpLink\n$appLink';
  String get createBookingTypeAction =>
      isRu ? 'Новый тип записи' : 'New booking type';
  String get bookingTypeEmpty => isRu
      ? 'Нет типов записи. Создайте слоты и ссылку для клиентов.'
      : 'No booking types yet. Create slots and a client link.';
  String get copyBookingLink =>
      isRu ? 'Скопировать ссылку' : 'Copy link';
  String get disableBookingIntake =>
      isRu ? 'Выключить набор' : 'Stop accepting';
  String get bookingTypeClosed => isRu ? 'Набор закрыт' : 'Not accepting';
  String get todayWidgetEmpty =>
      isRu ? 'Нет событий на сегодня' : 'No events today';
  String get todayWidgetTitle => isRu ? 'Сегодня' : 'Today';
  String get settingsGroupCalendar => isRu ? 'Календарь' : 'Calendar';
  String get settingsGroupData => isRu ? 'Данные' : 'Data';
  String get clearCalendarTitle =>
      isRu ? 'Очистить календарь' : 'Clear calendar';
  String get clearCalendarConfirm => isRu
      ? 'Удалить все события и рабочие расписания во всех профилях? '
            'Это действие нельзя отменить.'
      : 'Delete all events and work schedules in every profile? '
            'This cannot be undone.';
  String get clearCalendarDone =>
      isRu ? 'Календарь очищен' : 'Calendar cleared';
  String get testCalendarFillTitle =>
      isRu ? 'Тестовое заполнение' : 'Test calendar fill';
  String get testCalendarFillHint => isRu
      ? 'Валидный год для проверки UI. Данные активного профиля будут заменены.'
      : 'A valid year for UI checks. Active profile data will be replaced.';
  String get testCalendarFillCatalogLabel =>
      isRu ? 'Что загрузится' : 'What gets loaded';
  String get testCalendarFillConfirm => isRu
      ? 'Заменить события, расписания и цели накопления активного профиля '
            'валидным тестовым набором на весь год? Текущие данные профиля будут удалены.'
      : 'Replace the active profile events, schedules, and savings goals '
            'with a valid test set for the whole year? Current profile data will be removed.';
  String testCalendarFillDone(int events, int schedules, int goals) => isRu
      ? 'Добавлено: $events записей, $schedules расписаний, $goals целей накопления'
      : 'Added: $events entries, $schedules schedules, $goals savings goals';

  String testCalendarFillPlacementLabel(String placementId) {
    switch (placementId) {
      case 'today':
        return isRu ? 'Сегодня' : 'Today';
      case 'week':
        return isRu ? 'Неделя' : 'Week';
      case 'agenda':
        return isRu ? 'Повестка' : 'Agenda';
      case 'month':
        return isRu ? 'Месяц' : 'Month';
      case 'schedules':
        return isRu ? 'Графики' : 'Schedules';
      case 'savings':
        return isRu ? 'Цели' : 'Savings';
      default:
        return placementId;
    }
  }

  String testCalendarFillFeatureTitle(String featureId) {
    switch (featureId) {
      case 'recurrence_daily':
        return isRu ? 'Повтор · ежедневно' : 'Recurrence · daily';
      case 'recurrence_weekly':
        return isRu ? 'Повтор · еженедельно' : 'Recurrence · weekly';
      case 'recurrence_monthly':
        return isRu ? 'Повтор · ежемесячно' : 'Recurrence · monthly';
      case 'recurrence_exclusion':
        return isRu ? 'Исключение из серии' : 'Series exclusion';
      case 'recurrence_detached':
        return isRu ? 'Отвязанное вхождение' : 'Detached occurrence';
      case 'today_rich':
        return isRu
            ? 'Сегодня · доход, помодоро, длинный текст'
            : 'Today · income, pomodoro, long text';
      case 'today_adjacent':
        return isRu ? 'Соседний слот без пересечения' : 'Adjacent non-overlap';
      case 'today_gift':
        return isRu ? 'Подарок / доход' : 'Gift / income';
      case 'today_note_attachments':
        return isRu ? 'Заметка со вложениями' : 'Note with attachments';
      case 'today_note_derived':
        return isRu ? 'Заметка с автозаголовком' : 'Note with derived title';
      case 'today_checklist':
        return isRu ? 'Чек-лист с вложенностью' : 'Nested checklist';
      case 'conflict_shift':
        return isRu ? 'Конфликт со сменой' : 'Conflict with shift';
      case 'shift_skip':
        return isRu ? 'Пропуск смены 2/2' : 'Skipped 2/2 shift';
      case 'shift_overtime':
        return isRu ? 'Сверхурочные на смене' : 'Shift overtime';
      case 'office_skip':
        return isRu ? 'Пропуск офисного дня' : 'Skipped office day';
      case 'schedule_office':
        return isRu ? 'График · офис пн–пт' : 'Schedule · office weekdays';
      case 'schedule_shift':
        return isRu ? 'График · смена 2/2' : 'Schedule · shift 2/2';
      case 'savings_overdue':
        return isRu ? 'Цель · просрочка' : 'Goal · overdue';
      case 'savings_long_title':
        return isRu ? 'Цель · длинное название' : 'Goal · long title';
      case 'savings_progress':
        return isRu ? 'Цель · прогресс' : 'Goal · progress';
      case 'savings_year_end':
        return isRu ? 'Цель · конец года' : 'Goal · year end';
      case 'stress_long_text':
        return isRu ? 'Длинный текст / обрезка' : 'Long text / clipping';
      case 'stress_weekend_title':
        return isRu ? 'Длинный заголовок выходного' : 'Weekend long title';
      case 'stress_monthly_notes':
        return isRu
            ? 'Заметки и чек-листы по месяцам'
            : 'Monthly notes and checklists';
      default:
        return featureId;
    }
  }
  String get testProfileInterfaceTitle =>
      isRu ? 'Тестовый интерфейс профиля' : 'Test profile interface';
  String get testProfileInterfaceHint => isRu
      ? 'Временно показать календарь как у выбранного типа. Сохранённый профиль не меняется.'
      : 'Temporarily show the calendar as the selected type. The saved profile stays as it is.';
  String testProfileInterfaceActive(String kind) =>
      isRu ? 'Сейчас: $kind' : 'Now: $kind';
  String get testProfileInterfaceReset =>
      isRu ? 'Сбросить тестовый вид' : 'Reset test view';
  String get openSettingsTooltip => isRu ? 'Настройки' : 'Settings';
  String get inboxTooltip => isRu ? 'Входящие' : 'Inbox';
  String get colorFilterTooltip => isRu ? 'Фильтр по цвету' : 'Color filter';
  String colorFilterActiveLabel(int count) =>
      isRu ? 'Фильтр: $count' : 'Filter: $count';
  String get showMoreOptions => isRu ? 'Ещё параметры' : 'More options';
  String get hideMoreOptions => isRu ? 'Скрыть параметры' : 'Hide options';
  String get openWeekViewAction => isRu ? 'Открыть неделю' : 'Open week view';
  String get manageProfiles =>
      isRu ? 'Управление профилями' : 'Manage profiles';
  String get swipeToEdit => isRu ? 'Редактировать' : 'Edit';
  String get swipeToDelete => isRu ? 'Удалить' : 'Delete';
  String get tapEventToEdit =>
      isRu ? 'Нажмите на событие, чтобы открыть' : 'Tap an event to open it';
  String get emptyAgendaMonthTitle =>
      isRu ? 'В этом месяце нет событий' : 'No events this month';
  String get emptyAgendaMonthHint => isRu
      ? 'Добавьте событие или смахните, чтобы сменить месяц'
      : 'Add an event or swipe to change month';
  String get agendaMonthSwipeHint => isRu
      ? 'Смахните влево или вправо, чтобы сменить месяц'
      : 'Swipe left or right to change month';
  String get agendaViewHints => isRu
      ? 'Смахните влево или вправо, чтобы сменить месяц. '
            'Нажмите на событие, чтобы открыть. '
            'Справа в панели: свернуть или развернуть все дни и перейти к сегодняшнему дню.'
      : 'Swipe left or right to change month. '
            'Tap an event to open it. '
            'Use the toolbar on the right to collapse or expand all days and jump to today.';
  String get agendaToolbarHint => isRu
      ? 'Справа: свернуть или развернуть все дни списка и перейти к сегодняшнему дню'
      : 'On the right: collapse or expand all list days and jump to today';
  String get emptyWeekTitle =>
      isRu ? 'На этой неделе нет событий' : 'No events this week';
  String get emptyWeekHint => isRu
      ? 'Добавьте событие или переключите неделю'
      : 'Add an event or switch to another week';
  String get jumpToTodayChip => isRu ? 'Сегодня' : 'Today';
  String get viewDayEvents => isRu ? 'События дня' : 'Day events';
  String dateActionsTitle(DateTime date) =>
      isRu ? 'Дата: ${fullDate(date)}' : 'Date: ${fullDate(date)}';
  String get pullToRefresh =>
      isRu ? 'Потяните для обновления' : 'Pull to refresh';
  String yearSummary(int events, int activeMonths) => isRu
      ? '$events событий · $activeMonths мес. с событиями'
      : '$events events · $activeMonths active months';
  String monthEventsBadge(int count) => isRu ? '$count соб.' : '$count ev.';
  String get currentMonthBadge => isRu ? 'Сейчас' : 'Now';
  String get title => isRu ? 'Название' : 'Title';
  String get startTime => isRu ? 'Время начала' : 'Start time';
  String get endTime => isRu ? 'Время окончания' : 'End time';
  String get endTimeOptional =>
      isRu ? 'Время окончания (необяз.)' : 'End time (optional)';
  String get endTimeOptionalHint => isRu
      ? 'Оставьте пустым, если длительность неизвестна'
      : 'Leave empty if duration is unknown';
  String get color => isRu ? 'Цвет' : 'Color';
  String get invalidTime =>
      isRu ? 'Введите корректное время в формате HH:MM' : 'Enter time as HH:MM';
  String get noEvents => isRu ? 'События не существуют' : 'No events';
  String get eventsForSelectedDate =>
      isRu ? 'События выбранной даты' : 'Events for selected date';
  String get weekEventsNote => isRu ? 'События недели' : 'Week events';

  String get retry => isRu ? 'Повторить' : 'Retry';
  String get loading => isRu ? 'Загрузка…' : 'Loading…';
  String get loadCalendarError =>
      isRu ? 'Не удалось загрузить календарь' : 'Failed to load calendar';
  String get unexpectedUiError => isRu
      ? 'Интерфейс столкнулся с ошибкой. Данные на устройстве сохранены.'
      : 'The interface hit an error. Data on this device is still saved.';
  String get eventOverlapWarning => isRu
      ? 'Это время пересекается с другим событием'
      : 'This time overlaps with another event';
  String get eventTimeUpdated =>
      isRu ? 'Время события обновлено' : 'Event time updated';
  String eventSaveFailed(Object error) => isRu
      ? 'Не удалось сохранить событие: $error'
      : 'Failed to save event: $error';
  String eventDeleteFailed(Object error) => isRu
      ? 'Не удалось удалить событие: $error'
      : 'Failed to delete event: $error';
  String eventCreateFailed(Object error) => isRu
      ? 'Не удалось создать событие: $error'
      : 'Failed to create event: $error';
  String eventUpdateFailed(Object error) => isRu
      ? 'Не удалось обновить событие: $error'
      : 'Failed to update event: $error';
  String get eventDeleteError =>
      isRu ? 'Не удалось удалить событие' : 'Failed to delete event';
  String get eventUpdateError =>
      isRu ? 'Не удалось обновить событие' : 'Failed to update event';
  String get recurrence => isRu ? 'Повторение' : 'Recurrence';

  @override
  String recurrencePresetLabel(RecurrencePreset preset) => switch (preset) {
    RecurrencePreset.none => isRu ? 'Без повторения' : 'Does not repeat',
    RecurrencePreset.daily => patternDaily,
    RecurrencePreset.weekly => patternWeekly,
    RecurrencePreset.monthly => isRu ? 'Ежемесячно' : 'Monthly',
    RecurrencePreset.custom => isRu ? 'Нестандартное' : 'Custom',
  };
  String get customRecurrenceHint => isRu
      ? 'Правило повторения не редактируется в приложении'
      : 'This recurrence rule cannot be edited in the app';
  String get fromPendingBooking =>
      isRu ? 'Ожидает подтверждения' : 'Pending confirmation';
  String get exportIcsAction => isRu ? 'Экспорт .ics' : 'Export .ics';
  String get shareCalendarAction => isRu ? 'Поделиться' : 'Share';
  String get syncConflictTitle =>
      isRu ? 'Конфlict синхронизации' : 'Sync conflict';
  String get syncConflictMessage => isRu
      ? 'На сервере и локально есть более новые данные. Заменить локальный календарь версией с сервера?'
      : 'Both server and local calendars were updated. Replace local data with the server copy?';
  String get syncUseRemote => isRu ? 'Взять с сервера' : 'Use server';
  String get syncKeepLocal => isRu ? 'Оставить локальные' : 'Keep local';
  String get eventQuickTemplatesTitle => isRu ? 'Шаблоны' : 'Templates';
  String get saveEventTemplateAction =>
      isRu ? 'Сохранить как шаблон' : 'Save as template';
  String get guestCalendarTitle =>
      isRu ? 'Подписка на календарь' : 'Calendar subscription';
  String get guestCalendarUrlHint =>
      isRu ? 'URL .ics календаря' : 'ICS calendar URL';
  String get guestCalendarAddAction => isRu ? 'Подписаться' : 'Subscribe';
  String get moveEventToDate => isRu ? 'Перенести' : 'Move to date';
  String get moveEventToDateTitle =>
      isRu ? 'Перенести на дату' : 'Move to date';
  String shiftHolidayWarning(int count) => isRu
      ? 'В ближайшие 90 дней $count смен попадают на праздники РФ'
      : '$count upcoming shifts fall on Russian public holidays';
  String get profilesTitle => isRu ? 'Профили контекста' : 'Context profiles';
  String get workSchedules => isRu ? 'Рабочие расписания' : 'Work schedules';
  String get platformLinks => isRu ? 'Ссылки и API' : 'Links & API';
  String get createProfile => isRu ? 'Создать профиль' : 'Create profile';
  String get newProfile => isRu ? 'Новый профиль' : 'New profile';
  String get joinSharedProfile =>
      isRu ? 'Подключиться к профилю' : 'Join a profile';
  String get createProfileOnDevice =>
      isRu ? 'Только на этом устройстве' : 'This device only';
  String get createProfileOnDeviceHint => isRu
      ? 'Личный календарь. Без облака, данные остаются здесь.'
      : 'A private calendar. No cloud — data stays on this device.';
  String get createProfileCloud => isRu ? 'С облаком' : 'With the cloud';
  String get createProfileCloudHint => isRu
      ? 'Общий календарь и запись на время. Один раз вставьте строку '
            'подключения и файл ключа из Yandex Cloud.'
      : 'Shared calendar and booking. Paste the YDB connection string and '
            'key file from Yandex Cloud once.';
  String get createProfileJoinHint => isRu
      ? 'Вставьте приглашение целиком. База и права подставятся сами.'
      : 'Paste the whole invite. The database and permissions fill in themselves.';
  String get createProfileBack => isRu ? 'Назад' : 'Back';
  String get createProfileConnect =>
      isRu ? 'Проверить и создать' : 'Test and create';
  String get createProfileShareTitle =>
      isRu ? 'Пространство готово' : 'Workspace is ready';
  String get createProfileShareHint => isRu
      ? 'Отправьте ссылку тем, кто будет вести календарь или записываться.'
      : 'Send the link to people who will share the calendar or book times.';
  String get createProfileDone => isRu ? 'Готово' : 'Done';
  String get ydbInviteInvalid => isRu
      ? 'Это не ссылка Almanac на базу. Скопируйте приглашение целиком.'
      : 'This is not an Almanac database invite. Paste the whole invite.';
  String get createProfileNeedDatabase => isRu
      ? 'Вставьте строку подключения из карточки базы YDB.'
      : 'Paste the connection string from the YDB database card.';
  String get createProfileNeedKey =>
      isRu ? 'Выберите файл ключа JSON.' : 'Choose the JSON key file.';
  String get profileKindPersonal => isRu ? 'Личный' : 'Personal';
  String get profileKindPersonalHint => isRu
      ? 'Только на этом устройстве. Облако появится позже.'
      : 'On this device only. Cloud sync will come later.';
  String get profileKindCollaborative => isRu ? 'Совместный' : 'Shared';
  String get profileKindCollaborativeHint => isRu
      ? 'Все участники добавляют и правят события. Одно событие нельзя править вдвоём.'
      : 'Everyone can add and edit events. Two people cannot edit the same event at once.';
  String get profileKindBooking => isRu ? 'Запись' : 'Booking';
  String get profileKindBookingHint => isRu
      ? 'Вы правите календарь. Подключённые пользователи только записываются.'
      : 'You edit the calendar. Connected people can only book.';
  String get profileRoleOwner => isRu ? 'владелец' : 'owner';
  String get profileRoleMember => isRu ? 'участник' : 'member';
  String profileKindChip(ProfileKind kind, ProfileRole role) {
    final type = switch (kind) {
      ProfileKind.personal => profileKindPersonal,
      ProfileKind.collaborative => profileKindCollaborative,
      ProfileKind.booking => profileKindBooking,
    };
    if (kind == ProfileKind.personal) return type;
    final who = role == ProfileRole.owner
        ? profileRoleOwner
        : profileRoleMember;
    return '$type · $who';
  }

  String get joinProfileIdLabel =>
      isRu ? 'Profile ID владельца' : 'Owner Profile ID';
  String get joinProfileKindLabel => isRu ? 'Тип профиля' : 'Profile type';
  String get joinProfileSubmit => isRu ? 'Подключиться' : 'Join';
  String get copyConnectionDetails =>
      isRu ? 'Скопировать данные для подключения' : 'Copy connection details';
  String get connectionDetailsCopied => isRu
      ? 'URL, API Key и Profile ID скопированы.'
      : 'URL, API key and Profile ID copied.';
  String connectionShareText({
    required String name,
    required String kind,
    required String url,
    required String apiKey,
    required String profileId,
  }) => isRu
      ? 'Almanac «$name» ($kind)\nURL: $url\nAPI Key: $apiKey\nProfile ID: $profileId'
      : 'Almanac “$name” ($kind)\nURL: $url\nAPI Key: $apiKey\nProfile ID: $profileId';
  String get personalProfileLocalHint => isRu
      ? 'Личный профиль хранится только на этом устройстве. Синхронизация с облаком появится позже.'
      : 'This personal profile stays on this device. Cloud sync will come later.';
  String get eventLockedByOther => isRu
      ? 'Сейчас это событие правит другое устройство. Подождите или откройте просмотр.'
      : 'Another device is editing this event. Wait or view it read-only.';
  String get bookingMemberCreateHint => isRu
      ? 'На графике слоты записи. Нажмите слот или «Записаться», чтобы выбрать время.'
      : 'The schedule shows booking slots. Tap a slot or Book to pick a time.';
  String get bookAppointmentAction => isRu ? 'Записаться' : 'Book';
  String get bookingNoSessionsYet => isRu
      ? 'Владелец ещё не открыл запись. Когда появится график, слоты будут на календаре.'
      : 'The owner has not opened booking yet. Slots will appear on the calendar when they do.';
  String get pickBookingSession =>
      isRu ? 'Выберите запись' : 'Choose a booking';
  String get bookingSlotOnSchedule => isRu ? 'Слот записи' : 'Booking slot';
  String get renameProfile => isRu ? 'Переименовать' : 'Rename';
  String get deleteProfileTitle =>
      isRu ? 'Удалить профиль?' : 'Delete profile?';
  String deleteProfileMessage(String name) => isRu
      ? 'Профиль «$name» и все его события и бронирования будут удалены.'
      : 'Profile "$name" and all its events and bookings will be deleted.';
  String get delete => isRu ? 'Удалить' : 'Delete';
  String get linkCopied => isRu ? 'Ссылка скопирована' : 'Link copied';
  String linkCopiedWithUrl(String url) =>
      isRu ? 'Ссылка скопирована: $url' : 'Link copied: $url';
  String get scheduleDeleted =>
      isRu ? 'Расписание удалено' : 'Schedule deleted';
  String scheduleDeleteFailed(Object error) => isRu
      ? 'Не удалось удалить расписание: $error'
      : 'Failed to delete schedule: $error';
  String get deleteScheduleTitle =>
      isRu ? 'Удалить расписание?' : 'Delete schedule?';
  String deleteScheduleMessage(String title, String profileName) => isRu
      ? '«$title» будет удалено из профиля «$profileName».'
      : '"$title" will be removed from profile "$profileName".';
  String saveFailed(Object error) =>
      isRu ? 'Не удалось сохранить: $error' : 'Failed to save: $error';

  // ——— Профили ———
  String splitViewActive(String visibleLabel) => isRu
      ? 'Объединённый календарь: $visibleLabel'
      : 'Merged calendar: $visibleLabel';
  String get splitViewHint => isRu
      ? 'Включите несколько профилей, чтобы видеть их события вместе'
      : 'Enable multiple profiles to see their events together';
  String get inCalendar => isRu ? 'В календаре' : 'In calendar';
  String get primaryProfile =>
      isRu ? 'Основной (создание событий)' : 'Primary (creates events)';
  String get makePrimaryTooltip => isRu ? 'Сделать основным' : 'Set as primary';
  String get renameTooltip => isRu ? 'Переименовать' : 'Rename';
  String get deleteTooltip => isRu ? 'Удалить' : 'Delete';
  String themeTitle(String profileName) => isRu
      ? 'Тема основного профиля ($profileName)'
      : 'Primary profile theme ($profileName)';
  String get themeLight => isRu ? 'Светлая' : 'Light';
  String get themeDark => isRu ? 'Тёмная' : 'Dark';
  String get themeSystem => isRu ? 'Система' : 'System';
  String get themeMainProfileTitle =>
      isRu ? 'Тема основного профиля' : 'Main profile theme';
  String get themeAccentLabel => isRu ? 'Акцент' : 'Accent';
  String get themeAccentHint => isRu
      ? 'Цвет подсветки календаря: выбранный день, вкладки и статистика.'
      : 'Calendar highlight color: selected day, tabs, and stats.';
  String get themeAccentCustom => isRu ? 'Свой цвет' : 'Custom color';
  String get themeAccentSavePreset => isRu ? 'Сохранить пресет' : 'Save preset';
  String get themeAccentPresetSaved =>
      isRu ? 'Пресет акцента сохранён' : 'Accent preset saved';
  String get themeAccentDeletePreset =>
      isRu ? 'Удалить пресет' : 'Remove preset';

  // ——— Язык ———
  String get appName => 'Almanac';
  String get languageSection => isRu ? 'Язык' : 'Language';
  String get languageRu => 'Русский';
  String get languageEn => 'English';

  String monthYear(int month, int year) => '${monthName(month)} $year';
  String weekRange(DateTime start, DateTime end) {
    if (start.month == end.month && start.year == end.year) {
      return '${start.day}-${end.day} ${monthName(start.month)} ${start.year}';
    }
    return '${start.day} ${monthName(start.month)} - ${end.day} ${monthName(end.month)} ${end.year}';
  }

  @override
  String fullDate(DateTime date) =>
      '${monthName(date.month)} ${date.day}, ${date.year}';

  @override
  String agendaMonthYear(DateTime date) => isRu
      ? '${monthName(date.month)} ${date.year}'
      : '${monthName(date.month)} ${date.year}';

  @override
  String monthName(int month) {
    final names = isRu
        ? const [
            'Январь',
            'Февраль',
            'Март',
            'Апрель',
            'Май',
            'Июнь',
            'Июль',
            'Август',
            'Сентябрь',
            'Октябрь',
            'Ноябрь',
            'Декабрь',
          ]
        : const [
            'January',
            'February',
            'March',
            'April',
            'May',
            'June',
            'July',
            'August',
            'September',
            'October',
            'November',
            'December',
          ];
    return names[month - 1];
  }

  @override
  String shortWeekday(int weekday) {
    final names = isRu
        ? const ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс']
        : const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return names[weekday - DateTime.monday];
  }

  @override
  String weekday(int weekday) {
    final names = isRu
        ? const [
            'Понедельник',
            'Вторник',
            'Среда',
            'Четверг',
            'Пятница',
            'Суббота',
            'Воскресенье',
          ]
        : const [
            'Monday',
            'Tuesday',
            'Wednesday',
            'Thursday',
            'Friday',
            'Saturday',
            'Sunday',
          ];
    return names[weekday - DateTime.monday];
  }
}
