part of 'app_localizations.dart';

mixin _FinanceStrings on _LocalizationStringsBase {
  String statsTitle(int month) => isRu
      ? 'Статистика · ${monthName(month)}'
      : 'Statistics · ${monthName(month)}';
  String get statEvents => isRu ? 'Событий' : 'Events';
  String statDaysWithEvents(int withEvents, int inMonth) =>
      isRu ? 'Дней с событиями' : 'Days with events';
  String daysRatio(int withEvents, int inMonth) => '$withEvents/$inMonth';
  String get statOccupancy => isRu ? 'Загрузка' : 'Occupancy';
  String get statHolidays => isRu ? 'Праздники' : 'Holidays';
  String get statNotes => isRu ? 'Заметки' : 'Notes';
  String get statChecklists => isRu ? 'Чек-листы' : 'Checklists';
  String get statBookings => isRu ? 'Брони' : 'Bookings';
  String get statPendingBookings => isRu ? 'Ожидают' : 'Pending';
  String get statSavingsGoals => isRu ? 'Накопления' : 'Savings';
  String savingsProgressLine(double saved, double target) => isRu
      ? 'Накоплено ${formatMoney(saved)} из ${formatMoney(target)}'
      : 'Saved ${formatMoney(saved)} of ${formatMoney(target)}';
  String get workPayTitle => isRu ? 'Смены и заработок' : 'Shifts & pay';
  String get statShifts => isRu ? 'Смены' : 'Shifts';
  String get statSkippedShifts => isRu ? 'Пропуски' : 'Skipped';
  String get statWorkTime => isRu ? 'Рабочее время' : 'Work time';
  String get statOvertimeTime => isRu ? 'Сверхурочное время' : 'Overtime hours';
  String get statOvertimePay => isRu ? 'Оплата СУ' : 'OT pay';
  String get statRegularPay => isRu ? 'По норме' : 'Regular pay';
  String get statMonthlyPay => isRu ? 'Оклад' : 'Salary';
  String get statBaseEarnings => isRu ? 'Заработок' : 'Earnings';
  String get statNetEarnings => isRu ? 'Итого' : 'Total';
  String get statEarnings => statBaseEarnings;
  String get statOvertime => statOvertimeTime;
  String overtimeIncluded(String amount) =>
      isRu ? 'в т.ч. сверхурочные: $amount' : 'incl. overtime: $amount';
  String payBreakdownRegularHourly(String hours, String rate, String total) =>
      isRu ? '$hours × $rate = $total' : '$hours × $rate = $total';
  String payBreakdownOvertime(
    String hours,
    String rate,
    String multiplier,
    String total,
  ) => isRu
      ? '$hours × $rate × $multiplier = $total'
      : '$hours × $rate × $multiplier = $total';
  String payBreakdownDaily(int shifts, String rate, String total) => isRu
      ? '$shifts смен × $rate = $total'
      : '$shifts shifts × $rate = $total';
  String payBreakdownMonthly(int worked, int expected, String total) => isRu
      ? '$worked из $expected смен · $total'
      : '$worked of $expected shifts · $total';
  String get payBreakdownTotal => isRu ? 'Итого' : 'Total';
  String get paySummaryTotal => isRu ? 'Итого к получению' : 'Total payout';
  String get paySummaryDetails =>
      isRu ? 'Детали расчёта' : 'Calculation details';
  String get statTotalHours => isRu ? 'Всего часов' : 'Total hours';
  String paySummaryShifts(int count, int skipped) => skipped > 0
      ? (isRu
            ? '$count смен · пропусков $skipped'
            : '$count shifts · $skipped skipped')
      : (isRu ? '$count смен' : '$count shifts');
  String paySummaryRegularHours(String hours) =>
      isRu ? 'По норме: $hours' : 'Regular: $hours';
  String paySummaryOvertimeHours(String hours) =>
      isRu ? 'Сверхурочные: $hours' : 'Overtime: $hours';
  String paySummaryVatLine(String percent, String amount) =>
      isRu ? 'НДФЛ ($percent%): $amount' : 'Income tax ($percent%): $amount';
  String paySummaryVatLabel(String percent) =>
      isRu ? 'НДФЛ ($percent%)' : 'Income tax ($percent%)';
  String paySummaryVatOn(String subtotal) =>
      isRu ? 'от $subtotal' : 'on $subtotal';
  String get payRatesNotConfigured => isRu
      ? 'Укажите ставку в «Рабочем расписании», чтобы видеть заработок'
      : 'Set rates in Work schedule to see earnings';
  String busiestDay(DateTime date, int count) => isRu
      ? 'Самый насыщенный день: ${fullDate(date)} ($count)'
      : 'Busiest day: ${fullDate(date)} ($count)';
  String get categoryPersonal => isRu ? 'Личные' : 'Personal';
  String get categorySchedule => isRu ? 'По расписанию' : 'Scheduled';
  String get categoryChecklists => isRu ? 'Чек-листы' : 'Checklists';
  String checklistsProgress(int done, int total) =>
      isRu ? 'Чек-листы: $done из $total' : 'Checklists: $done of $total';
  String checklistsCountShort(int done, int total) => '$done/$total';
  String get byWeeks => isRu ? 'По неделям' : 'By week';
  String get noEventsThisMonth =>
      isRu ? 'В этом месяце пока нет событий.' : 'No events this month yet.';

  @override
  String reminderLabel(int? minutes) {
    if (minutes == null) return isRu ? 'Без напоминания' : 'No reminder';
    if (minutes == 0) return isRu ? 'В момент начала' : 'At start time';
    if (minutes >= 1440 && minutes % 1440 == 0) {
      final days = minutes ~/ 1440;
      return isRu ? 'За $days дн.' : '$days day(s) before';
    }
    if (minutes >= 60 && minutes % 60 == 0) {
      final hours = minutes ~/ 60;
      return isRu ? 'За $hours ч' : '$hours h before';
    }
    return isRu ? 'За $minutes мин' : '$minutes min before';
  }

  String eventReminderLine(int minutes) => isRu
      ? 'Напоминание: ${reminderLabel(minutes)}'
      : 'Reminder: ${reminderLabel(minutes)}';
  String get reminderNone => isRu ? 'Без напоминания' : 'No reminder';
  String get reminderAtStart => isRu ? 'В момент начала' : 'At start time';
  String reminderMinutesBefore(int minutes) =>
      isRu ? 'За $minutes мин' : '$minutes min before';
  String reminderHoursBefore(int hours) =>
      isRu ? 'За $hours ч' : '$hours h before';
  String reminderDaysBefore(int days) =>
      isRu ? 'За $days дн.' : '$days day(s) before';

  // ——— Цели накопления ———
  String get savingsGoalsTitle => isRu ? 'Цели накопления' : 'Savings goals';
  String get newSavingsGoalTitle => isRu ? 'Новая цель' : 'New goal';

  @override
  String get editSavingsGoalTitle => isRu ? 'Редактировать цель' : 'Edit goal';

  @override
  String get addSavingsGoal => isRu ? 'Добавить цель' : 'Add goal';
  String get edit => isRu ? 'Изменить' : 'Edit';
  String savingsGoalsProfileHint(String profile) =>
      isRu ? 'Цели профиля «$profile»' : 'Goals for profile “$profile”';
  String get savingsGoalsEmptyHint => isRu
      ? 'Создайте цель: укажите сумму, срок и на что копите.'
      : 'Create a goal with target amount, deadline, and a note.';
  String savingsGoalListSubtitle(String amount, String date, String monthly) =>
      isRu
      ? '$amount к $date · откладывать $monthly/мес'
      : '$amount by $date · save $monthly/mo';
  String get deleteSavingsGoalTitle => isRu ? 'Удалить цель?' : 'Delete goal?';
  String get deleteSavingsGoalConfirm => isRu
      ? 'Цель и её расчёт будут удалены.'
      : 'The goal and its plan will be removed.';
  String get savingsGoalDeleted => isRu ? 'Цель удалена' : 'Goal deleted';
  String get savingsGoalTitleLabel => isRu ? 'Название цели' : 'Goal title';
  String get savingsGoalAmountLabel =>
      isRu ? 'Сумма накопления, ₽' : 'Target amount, ₽';
  String get savingsGoalSavedLabel =>
      isRu ? 'Уже накоплено, ₽' : 'Already saved, ₽';
  String get savingsGoalDateLabel => isRu ? 'Дата цели' : 'Target date';
  String get savingsGoalNoteLabel =>
      isRu ? 'На что копите' : 'What you are saving for';
  String get savingsGoalNoteHint => isRu
      ? 'Например: отпуск, ноутбук, ремонт'
      : 'E.g. vacation, laptop, renovation';
  String get savingsGoalLivingLabel =>
      isRu ? 'Обязательные траты, ₽/мес' : 'Fixed expenses, ₽/month';
  String get savingsGoalLivingHint => isRu
      ? 'Еда, связь, аренда и др. — не входят в сумму цели, но учитываются в бюджете'
      : 'Food, phone, rent, etc. — not part of the goal, but part of monthly budget';
  String get savingsGoalPreviewTitle => isRu ? 'Расчёт' : 'Plan preview';
  String savingsGoalDaysLeft(int days) =>
      isRu ? 'Осталось $days дн.' : '$days days left';
  String get savingsGoalOverdueHint => isRu
      ? 'Срок уже прошёл — нужна вся сумма сразу'
      : 'Deadline passed — full amount due now';
  String savingsGoalMonthlyPayment(String amount) => isRu
      ? 'Минимальный ежемесячный взнос: $amount'
      : 'Minimum monthly savings: $amount';
  String savingsGoalMonthlyBudget(String total, String living) => isRu
      ? 'Бюджет на месяц: $total (в т.ч. обязательные траты $living)'
      : 'Monthly budget: $total (incl. fixed expenses $living)';
  String get savingsGoalTitleRequired =>
      isRu ? 'Укажите название цели' : 'Enter a goal title';
  String get savingsGoalAmountRequired =>
      isRu ? 'Укажите сумму больше 0' : 'Enter an amount greater than 0';
  String get savingsGoalLivingInvalid => isRu
      ? 'Сумма обязательных трат не может быть отрицательной'
      : 'Fixed expenses cannot be negative';
  String get savingsSectionTitle => isRu ? 'Накопления' : 'Savings';
  String savingsGoalStatTarget(String amount) =>
      isRu ? 'Цель $amount' : 'Target $amount';
  String savingsGoalStatMonthly(String amount) =>
      isRu ? 'Откладывать $amount/мес' : 'Save $amount/mo';
  String savingsGoalStatBudget(String amount) =>
      isRu ? 'Бюджет $amount/мес' : 'Budget $amount/mo';
  String savingsGoalStatSurplus(String amount) => isRu
      ? 'Остаток${amount.isEmpty ? '' : ' $amount'}'
      : 'Surplus${amount.isEmpty ? '' : ' $amount'}';
  String savingsGoalStatDeficit(String amount) => isRu
      ? 'Не хватает${amount.isEmpty ? '' : ' $amount'}'
      : 'Short${amount.isEmpty ? '' : ' $amount'}';
  String get manageSavingsGoals => isRu ? 'Цели накопления' : 'Savings goals';
}
