part of 'app_localizations.dart';

mixin _SessionStrings on _LocalizationStringsBase {
  String get sync => isRu ? 'Синхронизировать' : 'Sync';
  String get pushChanges => isRu ? 'Отправить' : 'Push';
  String get pullChanges => isRu ? 'Загрузить' : 'Pull';
  String syncNowHint(String name) => isRu
      ? 'Сверит «$name» с сервером и отправит ваши изменения.'
      : 'Compares “$name” with the server and uploads your changes.';
  String get autoUpdateOnStatus => isRu
      ? 'Автообновление включено: данные подтягиваются при открытии приложения.'
      : 'Auto-update is on: data is pulled when you open the app.';
  String get autoUpdateOffStatus => isRu
      ? 'Автообновление выключено. Нажмите «Синхронизировать», когда нужно.'
      : 'Auto-update is off. Tap Sync when you need a refresh.';
  String get autoPushLabel =>
      isRu ? 'Отправлять этот профиль' : 'Send this profile';
  String autoPushHint(String name) => isRu
      ? 'После правок календарь «$name» сам уйдёт на сервер. Снимите галочку, если это личные данные.'
      : 'After edits, “$name” is uploaded on its own. Turn this off for private calendars.';
  String get autoPullLabel =>
      isRu ? 'Обновлять автоматически' : 'Update automatically';
  String autoPullHint(String name) => isRu
      ? 'Подтягивать изменения «$name» с сервера в фоне.'
      : 'Pull “$name” updates from the server in the background.';
  String get profileNotificationsLabel =>
      isRu ? 'Уведомления этого профиля' : 'Notifications for this profile';
  String profileNotificationsHint(String name) => isRu
      ? 'Напоминания о событиях «$name» и push заявок. Выключите для личного календаря.'
      : 'Event reminders and booking pushes for “$name”. Turn off for a private calendar.';
  String get manualSyncSection => isRu ? 'Вручную' : 'Manual';
  String syncCurrentProfile(String name) =>
      isRu ? 'Профиль «$name»' : 'Profile “$name”';
  String get pushThisCalendar =>
      isRu ? 'Отправить на сервер' : 'Upload to server';
  String pushThisCalendarHint(String name) => isRu
      ? 'На сервер уйдёт только «$name». Остальные профили не отправляем.'
      : 'Only “$name” is uploaded. Other profiles stay on this device.';
  String get pullThisCalendar =>
      isRu ? 'Загрузить с сервера' : 'Download from server';
  String pullThisCalendarHint(String name) => isRu
      ? 'Заменит «$name» копией с сервера. Личные профили без API не трогаем.'
      : 'Replaces “$name” with the server copy. Profiles without this API stay as they are.';
  String get syncLinkedSection => isRu
      ? 'Ещё профили с этим же сервером и ключом'
      : 'Other profiles with this server and key';
  String get pushLinkedCalendars =>
      isRu ? 'Отправить связанные' : 'Upload linked';
  String get pullLinkedCalendars =>
      isRu ? 'Загрузить связанные' : 'Download linked';
  String pushSelectedProfile(String name) =>
      isRu ? 'Отправить «$name»' : 'Push “$name”';
  String pullSelectedProfile(String name) =>
      isRu ? 'Загрузить «$name»' : 'Pull “$name”';
  String get pushAllProfiles => isRu ? 'Отправить всё' : 'Push all';
  String get pullAllProfiles => isRu ? 'Загрузить всё' : 'Pull all';

  // ——— Remote sync (сообщения сервиса) ———
  String get syncPushSuccess => isRu
      ? 'Локальные данные и ссылки отправлены на сервер.'
      : 'Local data and links pushed to the server.';
  String syncPushProfileSuccess(String name) => isRu
      ? 'Профиль «$name» отправлен. Остальные профили на сервере не изменились.'
      : 'Profile “$name” was pushed. Other profiles on the server were left unchanged.';
  String syncPullProfileSuccess(String name) => isRu
      ? 'Профиль «$name» загружен. Остальные локальные профили не тронуты.'
      : 'Profile “$name” was pulled. Other local profiles were left unchanged.';
  String get syncProfileMissingOnServer => isRu
      ? 'На сервере ещё нет этого профиля — сначала отправьте его.'
      : 'This profile is not on the server yet — push it first.';
  String syncPushFailed(Object error) =>
      isRu ? 'Ошибка отправки: $error' : 'Push failed: $error';
  String get syncNoRemoteDataYet => isRu
      ? 'На сервере пока нет данных — выполните отправку.'
      : 'No data on the server yet — push your local copy first.';
  String get syncDisabledEnvHint => isRu
      ? 'Синхронизация выключена. Задайте SERVER_URL и ENABLE_REMOTE_SYNC=true.'
      : 'Sync disabled. Set SERVER_URL and ENABLE_REMOTE_SYNC=true.';
  String get syncServerUrlRequired => isRu
      ? 'Укажите URL сервера в «Ссылки и API» или через --dart-define=SERVER_URL.'
      : 'Set the server URL in Platform Links or via --dart-define=SERVER_URL.';
  String get serverSectionTitle => isRu ? 'Синхронизация' : 'Sync';
  String get serverLocalModeStatus => isRu
      ? 'Этот профиль только на устройстве. Чтобы обмениваться с сервером, укажите Server URL в «Ссылки и API».'
      : 'This profile stays on the device. Set a Server URL in Platform Links to sync it.';
  String get serverSyncDisabledStatus => isRu
      ? 'Сервер настроен, синхронизация выключена (ENABLE_REMOTE_SYNC=false).'
      : 'Server configured, sync disabled (ENABLE_REMOTE_SYNC=false).';
  String serverReadyStatus(String name) => isRu
      ? 'Можно обменять календарь «$name» с сервером.'
      : 'You can exchange the “$name” calendar with the server.';
  String remoteSessionPendingTitle(int count) =>
      isRu ? 'Заявки с сервера ($count)' : 'Server booking requests ($count)';
  String get newBookingRequestTitle =>
      isRu ? 'Новая заявка на запись' : 'New booking request';
  String newBookingRequestNotification(String sessionTitle) => isRu
      ? 'Новая заявка: $sessionTitle'
      : 'New booking request: $sessionTitle';
  String get openSession => isRu ? 'Открыть сессию' : 'Open session';
  String get closeSession => isRu ? 'Закрыть сессию' : 'Close session';
  String get sessionClosed => isRu ? 'Сессия закрыта' : 'Session closed';
  String get sessionDisplayName =>
      isRu ? 'Ваше имя в сессии' : 'Your name in session';
  String get sessionApplyDisplayName => isRu ? 'Применить' : 'Apply';
  String get sessionCollaborativeGuestHint => isRu
      ? 'Слоты редактирует владелец. Изменения синхронизируются в реальном времени.'
      : 'Slots are edited by the owner. Changes sync in real time.';
  String get sessionNoSlotsYet => isRu ? 'Слотов пока нет' : 'No slots yet';
  String get syncPulledNewerRemoteData => isRu
      ? 'Синхронизация: загружены более новые данные с сервера.'
      : 'Sync: pulled newer data from the server.';
  String get syncAlreadyUpToDate =>
      isRu ? 'Данные уже синхронизированы.' : 'Data is already up to date.';
  String syncSyncFailed(Object error) =>
      isRu ? 'Ошибка синхронизации: $error' : 'Sync failed: $error';
  String syncActionUnavailable(String action) => isRu
      ? '$action недоступна: удалённая синхронизация выключена.'
      : '$action unavailable: remote sync is disabled.';

  // ——— Бронирования ———
  String pendingBookingsTitle(int count) =>
      isRu ? 'Ожидают подтверждения ($count)' : 'Pending approval ($count)';
  String get confirmBooking => isRu ? 'Подтвердить' : 'Confirm';
  String get rejectBooking => isRu ? 'Отклонить' : 'Reject';
  String get bookingConfirmedConflict => isRu
      ? 'Бронирование подтверждено, но конфликт с событием'
      : 'Booking confirmed, but it conflicts with an event';
  String bookingConfirmedEvent(String title) =>
      isRu ? 'Запись подтверждена: $title' : 'Booking confirmed: $title';
  String bookingTemplateNotFound(String token) => isRu
      ? 'Шаблон бронирования не найден.\nТокен: $token'
      : 'Booking template not found.\nToken: $token';
  String get bookingDayLabel => isRu ? 'День' : 'Day';
  String get bookingSelectSlot =>
      isRu ? 'Выберите доступный слот.' : 'Select an available slot.';
  String get bookingSlotFull => isRu
      ? 'Это время уже занято. Выберите другой слот.'
      : 'This slot is full. Pick another time.';
  String bookingSlotPlacesLeft(int free, int total) =>
      isRu ? 'Свободно: $free из $total' : 'Available: $free of $total';
  String get bookingSlotFullLabel => isRu ? 'Занято' : 'Full';
  String get bookingBookAuto =>
      isRu ? 'Забронировать (авто подтверждение)' : 'Book (auto confirm)';
  String get bookingRequestManual => isRu
      ? 'Запросить бронирование (ожидает подтверждения)'
      : 'Request booking (pending approval)';
  String get bookingRequestSubmitted => isRu
      ? 'Заявка отправлена. Ожидайте подтверждения организатора.'
      : 'Request sent. Waiting for the host to confirm.';
  String get sessionOwnerPendingSection =>
      isRu ? 'Заявки участников' : 'Participant requests';
  String get sessionGuestPreview => isRu ? 'Как видит гость' : 'Guest preview';
  String bookingStatusLine(String status) =>
      isRu ? 'Статус: $status' : 'Status: $status';
  String bookingPeriodLine(String period) =>
      isRu ? 'Период: $period' : 'Period: $period';
  String bookingRequestStatusLabel(BookingRequestStatus status) =>
      switch (status) {
        BookingRequestStatus.pending =>
          isRu ? 'ожидает подтверждения' : 'pending',
        BookingRequestStatus.confirmed => isRu ? 'подтверждено' : 'confirmed',
        BookingRequestStatus.rejected => isRu ? 'отклонено' : 'rejected',
      };
  String get demoBookingTitle => isRu ? 'Демо бронирование' : 'Demo booking';
  String get demoStandupScheduleTitle =>
      isRu ? 'Планёрка (расписание)' : 'Standup (schedule)';

  // ——— Групповое планирование (публичная страница) ———
  String groupPlanNotFound(String token) => isRu
      ? 'План не найден.\nТокен: $token'
      : 'Plan not found.\nToken: $token';
  String get groupPlanSelectTime =>
      isRu ? 'Выберите удобное время' : 'Pick a convenient time';
  String get groupPlanVotingClosed =>
      isRu ? 'Голосование завершено' : 'Voting closed';
  String groupPlanSlotVotes(int count) =>
      isRu ? 'голосов: $count' : 'votes: $count';
  String get groupPlanYourName => isRu ? 'Ваше имя' : 'Your name';
  String get groupPlanSubmitVote => isRu ? 'Отправить голос' : 'Submit vote';
  String groupPlanThankYou(String name) => isRu
      ? 'Спасибо, $name! Ваш голос учтён.'
      : 'Thanks, $name! Your vote was recorded.';
  String groupPlanSelected(String when) =>
      isRu ? 'Выбрано: $when' : 'Selected: $when';

  // ——— Platform links ———
  String get platformLinksHint => isRu
      ? 'Без своего домена: блок Yandex YDB (бесплатный serverless). '
            'Либо публичный URL API на VPS. Гости открывают ссылку — одна Wi‑Fi не нужна.'
      : 'No domain: use the Yandex YDB block (free serverless). '
            'Or a public API URL on a VPS. Guests open a link — same Wi‑Fi is not required.';
  String get newBookingLink =>
      isRu ? 'Новая ссылка на запись' : 'New booking link';
  String get newCollaborativeSession =>
      isRu ? 'Совместное планирование (сессия)' : 'Collaborative session';
  String get newBookingSession =>
      isRu ? 'Запись на время (сессия)' : 'Booking session';
  String get createEntryCollaborative =>
      isRu ? 'Совместное планирование' : 'Collaborative planning';
  String get createEntryCollaborativeHint => isRu
      ? 'Ссылка для совместного выбора времени на сервере'
      : 'Server link for collaborative scheduling';
  String get createEntryBooking => isRu ? 'Запись на время' : 'Timed booking';
  String get createEntryBookingHint => isRu
      ? 'Когда вы принимаете и что спросить у клиента'
      : 'When you take clients and what to ask them';
  String get bookingIntro => isRu
      ? 'Люди увидят свободные окна и запишутся сами. Укажите, в какие дни и часы вы принимаете.'
      : 'People will see free slots and book themselves. Say which days and hours you take clients.';
  String get bookingTitleHint => isRu
      ? 'Например: стрижка, консультация, тренировка'
      : 'For example: haircut, consult, training';
  String get bookingTitleQuestion =>
      isRu ? 'Как назвать запись?' : 'What is this booking called?';
  String get bookingDaysQuestion =>
      isRu ? 'В какие дни принимаете?' : 'Which days do you take clients?';
  String get bookingDaysWeekdaysPreset => isRu ? 'Будни' : 'Weekdays';
  String get bookingDaysWeekendPreset => isRu ? 'Выходные' : 'Weekend';
  String get bookingDaysEveryDayPreset => isRu ? 'Каждый день' : 'Every day';
  String get bookingShiftSchedule => isRu ? 'Сменный график' : 'Shift schedule';
  String get bookingShiftScheduleHint => isRu
      ? 'Как на работе: сначала рабочие дни, потом выходные. Например 2 через 2.'
      : 'Like shift work: work days, then days off. Example: 2 on, 2 off.';
  String get bookingDaysOfWeek => isRu ? 'Календарь' : 'Calendar';
  String get bookingCalendarMode => isRu ? 'Календарь' : 'Calendar';
  String get bookingPickDatesHint => isRu
      ? 'Нажмите дни, когда принимаете. Можно листать месяцы.'
      : 'Tap the days you take clients. Use the arrows to change month.';
  String get bookingSelectWeekdaysInMonth =>
      isRu ? 'Будни месяца' : 'Weekdays this month';
  String get bookingClearDates => isRu ? 'Сбросить даты' : 'Clear dates';
  String get bookingDurationMinutesField =>
      isRu ? 'Минут на визит' : 'Minutes per visit';
  String get bookingDurationUnitHours => isRu ? 'Часы' : 'Hours';
  String get bookingDurationUnitMinutes => isRu ? 'Минуты' : 'Minutes';
  String get bookingHorizonDaysField =>
      isRu ? 'На сколько дней вперёд' : 'How many days ahead';
  String get bookingStartDateQuestion => isRu
      ? 'С какого числа открыть запись?'
      : 'From which date can people book?';
  String get bookingHoursQuestion =>
      isRu ? 'С какого часа до какого?' : 'From what time until when?';
  String get bookingDurationQuestion =>
      isRu ? 'Сколько длится один визит?' : 'How long is one visit?';
  String bookingDurationMinutes(int minutes) =>
      isRu ? '$minutes мин' : '$minutes min';
  String get bookingDuration1h => isRu ? '1 час' : '1 hour';
  String get bookingDuration90 => isRu ? '1,5 часа' : '1.5 hours';
  String get bookingDuration2h => isRu ? '2 часа' : '2 hours';
  String get bookingHorizonQuestion => isRu
      ? 'На сколько вперёд открыть запись?'
      : 'How far ahead can people book?';
  String get bookingHorizonTwoWeeks => isRu ? '2 недели' : '2 weeks';
  String get bookingHorizonMonth => isRu ? '1 месяц' : '1 month';
  String get bookingHorizonTwoMonths => isRu ? '2 месяца' : '2 months';
  String get bookingHorizonThreeMonths => isRu ? '3 месяца' : '3 months';
  String get bookingCapacityQuestion => isRu
      ? 'Сколько человек на одно время?'
      : 'How many people at the same time?';
  String get bookingOpenAction => isRu ? 'Открыть запись' : 'Open booking';
  String get bookingOpenHint => isRu
      ? 'Ссылка скопируется — её можно отправить клиентам.'
      : 'The link is copied so you can send it to clients.';
  String bookingSlotsPreviewDetail(int count, String samples) => isRu
      ? 'Получится окон: $count. Например: $samples'
      : '$count slots will be created. For example: $samples';
  String get bookingWhatToAsk =>
      isRu ? 'Что спросить у клиента?' : 'What to ask the client?';
  String get bookingWhatToAskHint => isRu
      ? 'Выбор — клиент отметит услугу из ваших вариантов. Написать — ответит сам. Телефон — только цифры.'
      : 'Choice — the client picks from your options. Write — they type an answer. Phone — digits only.';
  String get bookingFieldRequired => isRu ? 'Обязательно' : 'Required';
  String get bookingFieldPresetName => isRu ? 'Имя' : 'Name';
  String get bookingFieldPresetPhone => isRu ? 'Телефон' : 'Phone';
  String get bookingFieldPresetService => isRu ? 'Услуга' : 'Service';
  String get bookingFieldKindSelect => isRu ? 'Выбор' : 'Choice';
  String get bookingFieldKindText => isRu ? 'Написать' : 'Write';
  String get bookingFieldKindPhone => isRu ? 'Телефон' : 'Phone';
  String get bookingFieldSelectHint => isRu
      ? 'Напишите варианты, из которых клиент выберет один. Например услуги.'
      : 'Write the options the client will pick from. For example services.';
  String get bookingFieldTextHint => isRu
      ? 'Клиент напишет ответ сам. Например имя или комментарий.'
      : 'The client types the answer. For example a name or a comment.';
  String get bookingFieldOptionLabel => isRu ? 'Вариант' : 'Option';
  String get bookingFieldOptionHint =>
      isRu ? 'Например: стрижка' : 'For example: haircut';
  String get bookingFieldAddOption => isRu ? 'Ещё вариант' : 'Add option';
  String get bookingAddSelectField => isRu ? 'Добавить выбор' : 'Add a choice';
  String get bookingAddTextField => isRu ? 'Добавить вопрос' : 'Add a question';
  String get bookingAddPhoneField => isRu ? 'Добавить телефон' : 'Add a phone';
  String get bookingSelectOptionHint =>
      isRu ? 'Выберите вариант' : 'Choose an option';
  String get bookingSelectOptionsRequired => isRu
      ? 'У выбора должен быть хотя бы один вариант'
      : 'A choice needs at least one option';
  String get bookingPhoneDigitsHint => isRu
      ? 'Клиент сможет ввести только цифры'
      : 'The client will only be able to enter digits';
  String get bookingFieldPresetComment => isRu ? 'Комментарий' : 'Comment';
  String get bookingCyclePreset22 => isRu ? '2 через 2' : '2 on, 2 off';
  String get bookingCyclePreset13 => isRu ? '1 через 3' : '1 on, 3 off';
  String get bookingCyclePreset52 => isRu ? '5 через 2' : '5 on, 2 off';
  String bookingCycleSummary(int work, int rest) => isRu
      ? '$work рабочих, потом $rest выходных'
      : '$work work days, then $rest off';
  String get bookingOnePerson => isRu ? 'Один человек' : 'One person';
  String get bookingGroup => isRu ? 'Несколько сразу' : 'Several at once';
  String get bookingPreviewTitle =>
      isRu ? 'Как это будет выглядеть' : 'How it will look';
  String get createEntryJoinSession =>
      isRu ? 'Войти по токену' : 'Join by token';
  String get createEntryJoinSessionHint => isRu
      ? 'Открыть существующую сессию по токену'
      : 'Open an existing session by token';
  String get createEntryServerHint => isRu
      ? 'Подключите сервер в «Ссылки и API» — тогда здесь появятся совместное планирование, запись и вход по токену.'
      : 'Connect a server in Links & API to unlock collaborative planning, booking, and join by token here.';
  String get titleRequired => isRu ? 'Укажите название' : 'Enter a title';
  String get createAndCopyLink =>
      isRu ? 'Создать и скопировать ссылку' : 'Create and copy link';
  String get collaborativePlanningDate =>
      isRu ? 'Дата планирования' : 'Planning date';
  String get collaborativeMaxEditors =>
      isRu ? 'Макс. редакторов слотов' : 'Max slot editors';
  String get collaborativeDefaultSlotLabel =>
      isRu ? 'Основной слот' : 'Main slot';
  String get bookingStartDate => isRu ? 'Дата начала' : 'Start date';
  String get bookingScheduleWeekdays => isRu ? 'Дни недели' : 'Weekdays';
  String get bookingScheduleCycle => isRu ? 'Смена' : 'Shifts';
  String get bookingWorkDays =>
      isRu ? 'Рабочих дней подряд' : 'Work days in a row';
  String get bookingRestDays => isRu ? 'Потом выходных' : 'Then days off';
  String bookingTimeFrom(String time) => isRu ? 'С $time' : 'From $time';
  String bookingTimeTo(String time) => isRu ? 'До $time' : 'To $time';
  String get bookingWorkingHours => isRu ? 'Часы приёма' : 'Working hours';
  String get bookingInterval => isRu ? 'Длительность визита' : 'Visit length';
  String get bookingIntervalHint => isRu
      ? 'Следующий человек сможет записаться сразу после этого времени.'
      : 'The next person can book right after this time.';
  String get bookingHorizonDays =>
      isRu ? 'На сколько дней вперёд' : 'Days ahead';
  String get bookingHorizonDaysHint => isRu
      ? 'Дальше этой даты окон не будет, пока вы не откроете запись снова.'
      : 'There will be no slots after this unless you open booking again.';
  String get bookingSlotCapacity =>
      isRu ? 'Человек на одно время' : 'People per time';
  String get bookingSlotCapacityHint => isRu
      ? '1 — как у парикмахера. Больше — группа в одно время: занятие, тренировка.'
      : '1 — like a barber. Higher — a group at the same time: a class or training.';
  String bookingSlotsPreview(int count) =>
      isRu ? 'Будет создано окон: $count' : 'Windows to create: $count';
  String get bookingFormFieldsTitle =>
      isRu ? 'Что спросить у клиента' : 'What to ask the client';
  String get bookingFormFieldLabel => isRu ? 'Вопрос' : 'Question';
  String get bookingAddFormField => isRu ? 'Ещё вопрос' : 'Add a question';
  String get bookingFormFieldsRequired => isRu
      ? 'Напишите хотя бы один вопрос — например «Имя»'
      : 'Add at least one question — for example “Name”';
  String get bookingNoSlotsGenerated => isRu
      ? 'Пока нет ни одного окна. Отметьте дни и проверьте, что конец приёма позже начала.'
      : 'No slots yet. Pick days and make sure the end time is later than the start.';
  String weekdayShort(int weekday) {
    const ru = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
    const en = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final index = weekday - DateTime.monday;
    return isRu ? ru[index] : en[index];
  }

  String get editServerUrl => isRu ? 'URL сервера' : 'Server URL';
  String get joinSessionByToken => isRu ? 'Войти по токену' : 'Join by token';
  String get joinSessionTokenHint =>
      isRu ? 'Токен из ссылки /join/…' : 'Token from /join/… link';
  String get joinSessionServerHint => isRu
      ? 'URL сервера (если не настроен в профиле)'
      : 'Server URL (if not set in profile)';
  String get serverUrlRequired => isRu
      ? 'Укажите URL self-hosted сервера в настройках ссылок.'
      : 'Set the self-hosted server URL in Platform Links first.';
  String get sessionFormFields =>
      isRu ? 'Поля формы (через запятую)' : 'Form fields (comma-separated)';
  String get sessionAddSlot => isRu ? 'Добавить слот' : 'Add slot';
  String get newGroupPlan =>
      isRu ? 'Новое групповое планирование' : 'New group plan';
  String get invalidServerUrl => isRu
      ? 'Некорректный URL. Пример: http://localhost:8080'
      : 'Invalid URL. Example: http://localhost:8080';
  String get serverSetupRequiredHint => isRu
      ? 'Укажите URL self-hosted сервера ниже, чтобы создавать сессии записи и совместного планирования.'
      : 'Set the self-hosted server URL below to create booking and collaborative sessions.';
  String get legacyLocalLinksHint => isRu
      ? 'Локальные ссылки (без сервера). Укажите Server URL для сессий на backend.'
      : 'Local-only links (no server). Set Server URL for backend sessions.';
  String get legacyGroupPlanBanner => isRu
      ? 'Локальное групповое планирование (legacy). Для совместной работы через сервер используйте /join/:token.'
      : 'Local group plan (legacy). Use /join/:token sessions for server-based planning.';
  String get legacyLocalPendingSection =>
      isRu ? 'Локальные заявки (legacy)' : 'Local booking requests (legacy)';
  String get legacyLocalPendingHint => isRu
      ? 'Старые offline-заявки. Для новых записей настройте Server URL и создайте server session.'
      : 'Legacy offline requests. Configure Server URL and create server sessions for new bookings.';
  String get inboxRemoteSectionTitle =>
      isRu ? 'Заявки с сервера (REST)' : 'Server requests (REST)';
  String get inboxLegacySectionTitle =>
      isRu ? 'Офлайн-шаблоны (legacy)' : 'Offline templates (legacy)';
  String get inboxLegacySectionHint => legacyLocalPendingHint;
  String get inboxServerRequiredHint => isRu
      ? 'Входящие заявки с сервера. Откройте «Рабочее пространство» и укажите Server URL.'
      : 'Server booking inbox. Open Workspace and set Server URL first.';
  String get inboxEmptyHint => isRu
      ? 'Нет заметок без даты и заявок на подтверждение.'
      : 'No unscheduled notes or pending booking requests.';
  String inboxLoadFailed(String error) => isRu
      ? 'Не удалось загрузить заявки: $error'
      : 'Failed to load requests: $error';
  String sessionNotFoundHint(String token) => isRu
      ? 'Сессия «$token» не найдена. Проверьте Server URL или токен.'
      : 'Session «$token» not found. Check Server URL or token.';
  String get sessionServerRequiredHint => isRu
      ? 'Гостям нужен Server URL в профиле или параметр server= в deep link.'
      : 'Guests need Server URL in profile or server= in the deep link.';
  String get apiConnection => isRu ? 'API подключение' : 'API connection';
  String get serverSessionsTitle =>
      isRu ? 'Сессии на сервере' : 'Server sessions';
  String get noServerSessionsYet => isRu
      ? 'Нет сессий. Создайте совместное планирование или запись ниже.'
      : 'No sessions yet. Create a collaborative or booking session below.';
  String get testServerConnection =>
      isRu ? 'Проверить подключение' : 'Test connection';
  String get saveConnectionSettings =>
      isRu ? 'Сохранить настройки' : 'Save settings';
  String get connectionSettingsSaved =>
      isRu ? 'Настройки API сохранены' : 'API settings saved';
  String get apiKeyLabel => 'API Key';
  String get profileIdLabel => 'Profile ID';
  String get serverUrlLabel => isRu ? 'URL сервера' : 'Server URL';
  String get publicOriginLabel =>
      isRu ? 'Публичный URL (интернет)' : 'Public URL (internet)';
  String get publicOriginHint => isRu
      ? 'https://api.ваш-домен.ru — его получат гости. Пусто: берётся URL сервера, если он не LAN.'
      : 'https://api.your-domain.com — guests use this. Empty: Server URL, unless it is LAN.';
  String get editPushToken => isRu ? 'Push-токен (FCM)' : 'Push token (FCM)';
  String get pushTokenLabel => 'FCM token';
  String get pushTokenHint => isRu
      ? 'Токен Firebase Cloud Messaging для push о новых заявках. '
            'Альтернатива: --dart-define=PUSH_DEVICE_TOKEN=… при сборке.'
      : 'Firebase Cloud Messaging token for booking request pushes. '
            'Alternative: --dart-define=PUSH_DEVICE_TOKEN=… at build time.';
  String get pushTokenSaved =>
      isRu ? 'Push-токен сохранён' : 'Push token saved';
  String get miniServerTitle =>
      isRu ? 'Сервер на этом устройстве' : 'Server on this device';
  String get miniServerHint => isRu
      ? 'Опционально: этот телефон/ПК сам принимает /v1. Для интернета сначала укажите публичный HTTPS URL выше (VPS или туннель на этот порт). Python не нужен.'
      : 'Optional: this phone/PC serves /v1. For the internet, set a public HTTPS URL above first (VPS or a tunnel to this port). Python is not required.';
  String get miniServerStart =>
      isRu ? 'Включить мини-сервер' : 'Start mini-server';
  String get miniServerStop =>
      isRu ? 'Выключить мини-сервер' : 'Stop mini-server';
  String get miniServerRunning =>
      isRu ? 'Мини-сервер запущен' : 'Mini-server is running';
  String miniServerStarted(String url) => isRu
      ? 'Мини-сервер запущен. Ссылка для гостей: $url'
      : 'Mini-server started. Guest link origin: $url';
  String get miniServerLanUrl =>
      isRu ? 'Адрес в локальной сети' : 'LAN address';
  String get miniServerLocalUrl =>
      isRu ? 'URL на этом устройстве' : 'URL on this device';
  String get miniServerUnsupported => isRu
      ? 'Мини-сервер недоступен в веб-сборке. Для сети укажите публичный URL API.'
      : 'Mini-server is not available in the web build. Use a public API URL for network sharing.';
  String get miniServerFirewallHint => isRu
      ? 'Интернет: проброс порта / Cloudflare Tunnel / FastAPI на VPS. Брандмауэр — если открываете порт. LAN-адрес ниже только для той же Wi‑Fi.'
      : 'Internet: port forward / Cloudflare Tunnel / FastAPI on a VPS. Open the firewall if you expose the port. The LAN address below is same-Wi‑Fi only.';
  String get miniServerGuestLink =>
      isRu ? 'Ссылка для гостей (браузер)' : 'Guest link (browser)';
  String get miniServerGuestAppLink =>
      isRu ? 'Ссылка для гостей (Almanac)' : 'Guest link (Almanac)';
  String get networkLanOnlyWarning => isRu
      ? 'Сейчас в ссылке локальный адрес — гости в другой сети не подключатся. Укажите публичный HTTPS URL.'
      : 'This link uses a local address — guests off this network cannot connect. Set a public HTTPS URL.';
  String get ydbTitle =>
      isRu ? 'Yandex YDB (без домена)' : 'Yandex YDB (no domain)';
  String get ydbHint => isRu
      ? 'Бесплатный serverless YDB: устройства ходят в облако Яндекса напрямую. Домен и VPS не нужны. Один JSON ключа у хозяина, гостям — ссылка на базу.'
      : 'Free serverless YDB: devices talk to Yandex Cloud directly. No domain or VPS. The host keeps the SA JSON; guests get a database invite.';
  String get ydbDatabaseLabel => isRu
      ? 'Путь к базе или строка подключения'
      : 'Database path or connection string';
  String get ydbDatabaseHint =>
      '/ru-central1/…/…  или  grpcs://ydb.serverless.yandexcloud.net:2135/?database=/ru-central1/…';
  String get ydbEndpointLabel => 'Endpoint';
  String get ydbSecretLabel =>
      isRu ? 'JSON ключа сервисного аккаунта' : 'Service account JSON key';
  String get ydbPickKeyFile => isRu ? 'Файл ключа' : 'Key file';
  String get ydbTest => isRu ? 'Проверить связь' : 'Test connection';
  String get ydbSave => isRu ? 'Сохранить и подключить' : 'Save and connect';
  String get ydbConnected => isRu ? 'YDB подключена' : 'YDB connected';
  String get ydbDisconnect => isRu ? 'Отключить YDB' : 'Disconnect YDB';
  String get ydbGuide =>
      isRu ? 'Как создать базу' : 'How to create the database';
  String get ydbGuestLink =>
      isRu ? 'Ссылка на базу для гостей' : 'Database invite for guests';
  String get ydbGuestAppLink => isRu
      ? 'Открыть в Almanac (almanac://ydb)'
      : 'Open in Almanac (almanac://ydb)';
  String get ydbGuestWarning => isRu
      ? 'В ссылке есть ключ SA: кто её получит, читает и пишет эту базу. Не публикуйте в открытый чат.'
      : 'The invite contains the SA key: anyone with it can read and write this database. Do not post it publicly.';
  String get ydbKeyLoaded =>
      isRu ? 'Ключ загружен из файла' : 'Key loaded from file';
  String get ydbInvitePasteLabel =>
      isRu ? 'Ссылка на базу YDB' : 'YDB database invite';
  String get ydbSharedProfileName =>
      isRu ? 'Общий календарь YDB' : 'Shared YDB calendar';
  String get ydbBookingProfileName => isRu ? 'Запись YDB' : 'YDB booking';
  String get ydbGuestModeLabel =>
      isRu ? 'Что могут гости' : 'What guests can do';
  String get ydbModeCollaborative => isRu ? 'Календарь' : 'Calendar';
  String get ydbModeBooking => isRu ? 'Запись' : 'Booking';
  String get ydbModeCollaborativeHint => isRu
      ? 'Гости ведут общий календарь и могут записываться на ваши слоты. На время правки событие блокируется.'
      : 'Guests share the calendar and can also book your slots. An event is locked while someone is editing it.';
  String get ydbModeBookingHint => isRu
      ? 'Вы открываете свободные слоты. Гость только записывается на указанное вами время — править календарь нельзя.'
      : 'You publish free slots. Guests can only book the times you opened — they cannot edit the calendar.';
  String ydbBookingPublished(int count) => isRu
      ? 'Слоты записи опубликованы в календаре: $count'
      : 'Booking slots published to the calendar: $count';
  String get bookThisSlot =>
      isRu ? 'Записаться на это время' : 'Book this time';
  String bookingOfferConfirm(String when) =>
      isRu ? 'Записаться на $when?' : 'Book $when?';
  String get bookingOfferBooked => isRu ? 'Вы записаны' : 'You are booked';
  String get bookingOfferTaken =>
      isRu ? 'Это время уже занято' : 'This time is already booked';
  String get bookingOccupied => isRu ? 'Занято' : 'Booked';
  String get cancelBooking => isRu ? 'Отменить запись' : 'Cancel booking';
  String get cancelBookingConfirm => isRu
      ? 'Отменить запись и снова открыть это время?'
      : 'Cancel this booking and open the time again?';
  String get bookingCancelled => isRu ? 'Запись отменена' : 'Booking cancelled';
  String get releaseBookingTitle =>
      isRu ? 'Освободить время?' : 'Free this time?';
  String get releaseBookingConfirm => isRu
      ? 'Запись будет снята, слот снова станет свободным.'
      : 'The booking will be cleared and the slot will be free again.';
  String get closeBookingSlotTitle =>
      isRu ? 'Закрыть это время?' : 'Close this slot?';
  String get closeBookingSlotConfirm => isRu
      ? 'Гости больше не смогут записаться на этот слот.'
      : 'Guests will no longer be able to book this slot.';
  String get ydbGuestReadOnly => isRu
      ? 'Вы подключены как гость. Менять базу и режим может только владелец.'
      : 'You joined as a guest. Only the owner can change the database or guest mode.';
  String get ydbLeave => isRu ? 'Отключиться от базы' : 'Leave the database';
  String get ydbUnsupportedWeb => isRu
      ? 'YDB с устройства недоступна в веб-сборке. Используйте Android, iOS, Windows или macOS.'
      : 'In-app YDB is not available in the web build. Use Android, iOS, Windows, or macOS.';
  String ydbTestOk(String database) =>
      isRu ? 'Связь с YDB есть: $database' : 'YDB reachable: $database';
  String get serverConnectionOk => isRu
      ? 'Сервер доступен, API key принят.'
      : 'Server reachable, API key accepted.';
  String serverConnectionFailed(String error) =>
      isRu ? 'Ошибка подключения: $error' : 'Connection failed: $error';
  String get publicLinks => isRu ? 'Публичные ссылки' : 'Public links';
  String get noPublicLinksYet => isRu
      ? 'Пока нет ссылок. Создайте тип записи в каталоге.'
      : 'No links yet. Create a booking type in the catalog.';
  String planClosedEventCreated(String title) => isRu
      ? 'План «$title» закрыт, событие создано'
      : 'Plan "$title" closed, event created';
  String get groupPlanning =>
      isRu ? 'Групповое планирование' : 'Group planning';
  String get firstDay => isRu ? 'Первый день' : 'First day';
  String get duration => isRu ? 'Длительность' : 'Duration';
  String durationMinutes(int minutes) => isRu ? '$minutes мин' : '$minutes min';
  String get confirmation => isRu ? 'Подтверждение' : 'Confirmation';
  String get confirmationManual => isRu ? 'Вручную' : 'Manual';
  String get confirmationAuto => isRu ? 'Автоматически' : 'Automatic';
  String get defaultBookingTitle =>
      isRu ? 'Запись на встречу' : 'Meeting booking';
  String get defaultTeamMeetingTitle =>
      isRu ? 'Встреча команды' : 'Team meeting';
  String get descriptionOptional =>
      isRu ? 'Описание (необязательно)' : 'Description (optional)';
  String get planDayOptions => isRu ? 'Вариантов (дней)' : 'Day options';
  String get time => isRu ? 'Время' : 'Time';
  String get add => isRu ? 'Добавить' : 'Add';
  String get defaultShiftTitle => isRu ? 'Смена' : 'Shift';
  String get groupPlansSection => isRu ? 'Групповые планы' : 'Group plans';
  String get noGroupPlans => isRu ? 'Нет активных планов' : 'No active plans';
  String get closePlan =>
      isRu ? 'Закрыть и создать событие' : 'Close & create event';
  String get managePlans => isRu ? 'Управление планами' : 'Manage plans';
  String planOpenVotes(int count) =>
      isRu ? 'Открыто · голосов: $count' : 'Open · votes: $count';
  String planClosedAt(String when) =>
      isRu ? 'Закрыто · $when' : 'Closed · $when';
  String get overtimeFieldLabel =>
      isRu ? 'Сверхурочные (мин)' : 'Overtime (min)';
  String get overtimeFieldHint => isRu
      ? 'Авто по норме смены, если пусто'
      : 'Auto from shift norm if empty';
  String get shiftSkippedLabel => isRu ? 'Пропуск смены' : 'Skip shift';
  String get shiftSkippedHint => isRu
      ? 'Отпуск, больничный — смена видна, но не входит в заработок'
      : 'Leave or sick day — shift stays visible but is not paid';
  String get unpaidMinutesLabel =>
      isRu ? 'Неоплачиваемые минуты' : 'Unpaid minutes';
  String get unpaidMinutesHint => isRu
      ? 'Отпросились на часы — вычитаются из оплачиваемого времени'
      : 'Partial unpaid time is subtracted from paid hours';

  String get slotEditorNewTitle => isRu ? 'Новый слот' : 'New slot';
  String get slotEditorEditTitle => isRu ? 'Изменить слот' : 'Edit slot';
  String get slotEditorLabel =>
      isRu ? 'Подпись (необязательно)' : 'Label (optional)';

  String get ydbGuideTitle =>
      isRu ? 'Как создать базу YDB' : 'How to create a YDB database';
  String get ydbGuideIntro => isRu
      ? 'Almanac ходит в Yandex YDB с устройства. Свой домен и VPS не нужны. '
            'OAuth y0_ не принимается — только JSON авторизованного ключа. '
            'Ключ хранится в защищённом хранилище устройства, в снимок календаря не попадает.'
      : 'Almanac talks to Yandex YDB from the device. No domain or VPS. '
            'OAuth y0_ is rejected — only an authorized key JSON. '
            'The key stays in on-device secure storage and never enters the calendar snapshot.';
  String get ydbGuideCopyConsole =>
      isRu ? 'Скопировать адрес консоли' : 'Copy console address';
  String get ydbGuideStep1Title =>
      isRu ? 'Аккаунт Yandex Cloud' : 'Yandex Cloud account';
  String get ydbGuideStep1Body => isRu
      ? 'console.yandex.cloud → Яндекс ID. Если облака нет — создайте (у serverless YDB есть бесплатный пакет).'
      : 'console.yandex.cloud → Yandex ID. Create a cloud if you do not have one (serverless YDB has a free tier).';
  String get ydbGuideStep2Title => isRu ? 'Каталог' : 'Folder';
  String get ydbGuideStep2Body => isRu
      ? 'Облако → «Создать каталог». Имя любое, например almanac.'
      : 'Cloud → Create folder. Any name, for example almanac.';
  String get ydbGuideStep3Title =>
      isRu ? 'База Serverless YDB' : 'Serverless YDB database';
  String get ydbGuideStep3Body => isRu
      ? '«Managed Service for YDB» → «Создать». Тип: Serverless (не Dedicated). Дождитесь Running.'
      : 'Managed Service for YDB → Create. Type: Serverless (not Dedicated). Wait until it is Running.';
  String get ydbGuideStep4Title =>
      isRu ? 'Строка подключения' : 'Connection string';
  String get ydbGuideStep4Body => isRu
      ? 'Карточка базы → «Подключение». Скопируйте Endpoint:\n'
            'grpcs://ydb.serverless.yandexcloud.net:2135/?database=/ru-central1/<облако>/<база>\n'
            'Вставьте в поле «Путь к базе».'
      : 'Database card → Connection. Copy the Endpoint:\n'
            'grpcs://ydb.serverless.yandexcloud.net:2135/?database=/ru-central1/<cloud>/<db>\n'
            'Paste it into Database path.';
  String get ydbGuideStep5Title =>
      isRu ? 'Сервисный аккаунт' : 'Service account';
  String get ydbGuideStep5Body => isRu
      ? '«Сервисные аккаунты» → создать. Роль на каталог: ydb.editor.'
      : 'Service accounts → create. Folder role: ydb.editor.';
  String get ydbGuideStep6Title => isRu ? 'JSON ключа' : 'Key JSON';
  String get ydbGuideStep6Body => isRu
      ? 'Аккаунт → «Создать авторизованный ключ». Файл authorized_key.json целиком вставьте в Almanac или нажмите «Файл ключа».'
      : 'Account → Create authorized key. Paste the whole authorized_key.json into Almanac or tap Key file.';
  String get ydbGuideStep7Title => isRu ? 'Гости' : 'Guests';
  String get ydbGuideStep7Body => isRu
      ? '«Проверить связь» → «Сохранить». Скопируйте ссылку на базу. Гостю домен не нужен — он вставляет ссылку в «Подключиться к профилю».'
      : 'Test connection → Save. Copy the database invite. Guests do not need a domain — they paste the invite into Join profile.';
}
