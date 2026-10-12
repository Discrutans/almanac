part of '../month_statistics_panel.dart';

class _StatsContent extends StatelessWidget {
  const _StatsContent({
    required this.stats,
    required this.schedules,
    required this.savingsPlans,
    required this.focusedMonth,
    required this.l10n,
    required this.colorScheme,
    required this.onManageSavingsGoals,
  });

  final MonthStatistics stats;
  final List<CyclicWorkSchedule> schedules;
  final List<SavingsPlanSummary> savingsPlans;
  final DateTime focusedMonth;
  final AppLocalizations l10n;
  final ColorScheme colorScheme;
  final VoidCallback onManageSavingsGoals;

  @override
  Widget build(BuildContext context) {
    final occupancyPercent = (stats.occupancyRatio * 100).round();
    final pay = stats.workPay;
    final showWorkPay = pay.shiftCount > 0 || pay.skippedShiftCount > 0;
    final allEventsAreWorkShifts =
        showWorkPay &&
        pay.shiftCount == stats.totalEvents &&
        stats.personalEvents == 0;
    final showScheduleCategory =
        stats.scheduleEvents > 0 &&
        !(showWorkPay &&
            pay.shiftCount == stats.scheduleEvents &&
            stats.personalEvents == 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: AlmanacSpacing.xs,
          runSpacing: AlmanacSpacing.xs,
          children: [
            if (!allEventsAreWorkShifts)
              _StatChip(
                icon: Icons.event_note_outlined,
                label: l10n.statEvents,
                value: '${stats.totalEvents}',
              ),
            _StatChip(
              icon: Icons.calendar_view_day_outlined,
              label: l10n.statDaysWithEvents(
                stats.daysWithEvents,
                stats.daysInMonth,
              ),
              value: l10n.daysRatio(stats.daysWithEvents, stats.daysInMonth),
            ),
            _StatChip(
              icon: Icons.pie_chart_outline,
              label: l10n.statOccupancy,
              value: '$occupancyPercent%',
            ),
            if (stats.holidayCount > 0)
              _StatChip(
                icon: Icons.celebration_outlined,
                label: l10n.statHolidays,
                value: '${stats.holidayCount}',
              ),
            if (stats.noteCount > 0)
              _StatChip(
                icon: Icons.sticky_note_2_outlined,
                label: l10n.statNotes,
                value: '${stats.noteCount}',
              ),
            if (stats.checklistCount > 0)
              _StatChip(
                icon: Icons.checklist_outlined,
                label: l10n.statChecklists,
                value: '${stats.checklistCount}',
              ),
            if (stats.bookingCount > 0)
              _StatChip(
                icon: Icons.event_available_outlined,
                label: l10n.statBookings,
                value: '${stats.bookingCount}',
              ),
            if (stats.pendingBookingCount > 0)
              _StatChip(
                icon: Icons.hourglass_top_rounded,
                label: l10n.statPendingBookings,
                value: '${stats.pendingBookingCount}',
              ),
            if (stats.savingsGoalCount > 0)
              _StatChip(
                icon: Icons.savings_outlined,
                label: l10n.statSavingsGoals,
                value: '${stats.savingsGoalCount}',
              ),
          ],
        ),
        if (showWorkPay) ...[
          const SizedBox(height: AlmanacSpacing.md),
          Text(
            l10n.workPayTitle,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AlmanacSpacing.xs),
          _UnifiedStatGroup(
            metrics: [
              if (pay.shiftCount > 0)
                _StatMetric(
                  icon: Icons.work_outline,
                  label: l10n.statShifts,
                  value: pay.skippedShiftCount > 0
                      ? l10n.paySummaryShifts(
                          pay.shiftCount,
                          pay.skippedShiftCount,
                        )
                      : '${pay.shiftCount}',
                ),
              if (pay.totalWorkMinutes > 0)
                _StatMetric(
                  icon: Icons.schedule_outlined,
                  label: l10n.statWorkTime,
                  value: formatWorkHours(pay.totalWorkMinutes),
                ),
              if (pay.overtimeMinutes > 0)
                _StatMetric(
                  icon: Icons.more_time_outlined,
                  label: l10n.statOvertimeTime,
                  value: formatWorkHours(pay.overtimeMinutes),
                ),
            ],
            detailLines: pay.hasPayConfigured
                ? _WorkPayBreakdown(
                    pay: pay,
                    schedules: schedules,
                    focusedMonth: focusedMonth,
                    l10n: l10n,
                  ).buildLines()
                : null,
            detailTitle: l10n.paySummaryDetails,
          ),
          if (!pay.hasPayConfigured && pay.totalWorkMinutes > 0) ...[
            const SizedBox(height: AlmanacSpacing.xxs),
            Text(
              l10n.payRatesNotConfigured,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
        if (savingsPlans.isNotEmpty) ...[
          const SizedBox(height: AlmanacSpacing.md),
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.savingsSectionTitle,
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              TextButton(
                onPressed: onManageSavingsGoals,
                child: Text(l10n.manageSavingsGoals),
              ),
            ],
          ),
          const SizedBox(height: AlmanacSpacing.xs),
          for (final plan in savingsPlans) ...[
            if (plan != savingsPlans.first)
              const SizedBox(height: AlmanacSpacing.xs),
            _SavingsGoalStats(plan: plan, l10n: l10n),
          ],
        ],
        if (stats.busiestDay != null) ...[
          const SizedBox(height: AlmanacSpacing.sm),
          Text(
            l10n.busiestDay(stats.busiestDay!, stats.busiestDayCount),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        if (stats.checklistProgress != null ||
            (stats.totalEvents > 0 &&
                (stats.personalEvents > 0 || showScheduleCategory))) ...[
          const SizedBox(height: AlmanacSpacing.sm),
          Wrap(
            spacing: AlmanacSpacing.xs,
            runSpacing: AlmanacSpacing.xs,
            children: [
              if (stats.totalEvents > 0) ...[
                if (stats.personalEvents > 0)
                  _StatCategoryChip(
                    icon: Icons.person_outline_rounded,
                    label: l10n.categoryPersonal,
                    value: stats.personalEvents,
                    total: stats.totalEvents,
                    color: colorScheme.primary,
                  ),
                if (showScheduleCategory)
                  _StatCategoryChip(
                    icon: Icons.schedule_outlined,
                    label: l10n.categorySchedule,
                    value: stats.scheduleEvents,
                    total: stats.totalEvents,
                    color: colorScheme.tertiary,
                  ),
              ],
              if (stats.checklistProgress != null)
                _StatCategoryChip(
                  icon: Icons.checklist_rtl_outlined,
                  label: l10n.categoryChecklists,
                  value: stats.checklistTasksDone,
                  total: stats.checklistTasksTotal,
                  countText:
                      '${stats.checklistTasksDone}/${stats.checklistTasksTotal}',
                  color: colorScheme.secondary,
                ),
            ],
          ),
        ],
        if (stats.totalEvents == 0)
          Padding(
            padding: const EdgeInsets.only(top: AlmanacSpacing.sm),
            child: Text(
              l10n.noEventsThisMonth,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.almanacColors.muted,
              ),
            ),
          ),
      ],
    );
  }
}

class _WorkPayBreakdown {
  const _WorkPayBreakdown({
    required this.pay,
    required this.schedules,
    required this.focusedMonth,
    required this.l10n,
  });

  final WorkPaySummary pay;
  final List<CyclicWorkSchedule> schedules;
  final DateTime focusedMonth;
  final AppLocalizations l10n;

  List<String> buildLines() {
    final paidSchedules = activePaidSchedules(
      schedules: schedules,
      summary: pay,
    );
    final lines = <String>[];

    if (paidSchedules.length == 1) {
      final schedule = paidSchedules.first;
      lines.addAll(_linesForSchedule(schedule));
    } else {
      lines.addAll(_aggregateLines());
    }

    if (pay.hasPayConfigured && pay.vatAmount <= 0) {
      lines.add('${l10n.statNetEarnings}: ${formatMoney(pay.totalPay)}');
    }

    return lines;
  }

  List<String> _aggregateLines() {
    final lines = <String>[];
    if (pay.regularPay > 0) {
      lines.add('${l10n.statRegularPay}: ${formatMoney(pay.regularPay)}');
    }
    if (pay.overtimeMinutes > 0) {
      final otHours = formatWorkHours(pay.overtimeMinutes);
      if (pay.overtimePay > 0) {
        lines.add(
          '${l10n.statOvertimeTime}: $otHours · ${formatMoney(pay.overtimePay)}',
        );
      } else {
        lines.add('${l10n.statOvertimeTime}: $otHours');
      }
    }
    if (pay.monthlyPay > 0) {
      lines.add('${l10n.statMonthlyPay}: ${formatMoney(pay.monthlyPay)}');
    }
    if (pay.bonusPay > 0) {
      lines.add(l10n.payBreakdownBonus(formatMoney(pay.bonusPay)));
    }
    if (pay.vatAmount > 0) {
      lines.add(
        l10n.payBreakdownVat(
          formatMoney(pay.grossPay),
          _formatPercent(_aggregateVatPercent()),
          formatMoney(pay.vatAmount),
          formatMoney(pay.totalPay),
        ),
      );
    }
    return lines;
  }

  double _aggregateVatPercent() {
    if (pay.subtotalPay <= 0 || pay.vatAmount <= 0) return 0;
    return pay.vatAmount / pay.subtotalPay * 100;
  }

  String _formatPercent(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(1).replaceAll('.', ',');
  }

  List<String> _linesForSchedule(CyclicWorkSchedule schedule) {
    final lines = <String>[];
    final rateLabel = l10n.payRateLabel(schedule.payMode);

    switch (schedule.payMode) {
      case PayRateMode.hourly:
        final hourly = schedule.hourlyRate ?? 0;
        if (hourly > 0 && pay.regularMinutes > 0) {
          lines.add(
            '$rateLabel: ${l10n.payBreakdownRegularHourly(formatWorkHours(pay.regularMinutes), '${hourly.toStringAsFixed(0)} ₽/ч', formatMoney(pay.regularPay))}',
          );
        }
        if (pay.overtimeMinutes > 0) {
          final otHours = formatWorkHours(pay.overtimeMinutes);
          if (pay.overtimePay > 0 && hourly > 0) {
            lines.add(
              '${l10n.statOvertimeTime}: ${l10n.payBreakdownOvertime(otHours, '${hourly.toStringAsFixed(0)} ₽/ч', _formatMultiplier(schedule.overtimeMultiplier), formatMoney(pay.overtimePay))}',
            );
          } else {
            lines.add('${l10n.statOvertimeTime}: $otHours');
          }
        }
      case PayRateMode.daily:
        final daily = schedule.dailyRate ?? 0;
        if (daily > 0 && pay.shiftCount > 0) {
          lines.add(
            '$rateLabel: ${l10n.payBreakdownDaily(pay.shiftCount, '${daily.toStringAsFixed(0)} ₽', formatMoney(pay.regularPay))}',
          );
        }
        if (pay.overtimeMinutes > 0) {
          final hourly = schedule.hourlyRate ?? 0;
          final otHours = formatWorkHours(pay.overtimeMinutes);
          if (pay.overtimePay > 0 && hourly > 0) {
            lines.add(
              '${l10n.statOvertimeTime}: ${l10n.payBreakdownOvertime(otHours, '${hourly.toStringAsFixed(0)} ₽/ч', _formatMultiplier(schedule.overtimeMultiplier), formatMoney(pay.overtimePay))}',
            );
          } else if (pay.overtimePay > 0) {
            lines.add(
              '${l10n.statOvertimeTime}: $otHours · ${formatMoney(pay.overtimePay)}',
            );
          } else {
            lines.add('${l10n.statOvertimeTime}: $otHours');
          }
        }
      case PayRateMode.monthly:
        final monthly = schedule.monthlyRate ?? 0;
        if (monthly > 0 && pay.monthlyPay > 0) {
          final monthStart = DateTime(focusedMonth.year, focusedMonth.month, 1);
          final monthEnd = DateTime(
            focusedMonth.year,
            focusedMonth.month + 1,
            0,
          );
          final expected = _expectedShiftsInMonth(
            schedule,
            monthStart,
            monthEnd,
          );
          lines.add(
            '$rateLabel: ${l10n.payBreakdownMonthly(pay.shiftCount, expected, formatMoney(pay.monthlyPay))}',
          );
        }
        if (pay.overtimeMinutes > 0) {
          lines.add(
            '${l10n.statOvertimeTime}: ${formatWorkHours(pay.overtimeMinutes)}',
          );
        }
    }

    final slice = pay.breakdownFor(schedule);
    if (slice.bonusPay > 0) {
      lines.add(l10n.payBreakdownBonus(formatMoney(slice.bonusPay)));
    }
    if (slice.vatAmount > 0) {
      final vatPercent = schedule.vatPercent ?? 0;
      lines.add(
        l10n.payBreakdownVat(
          formatMoney(slice.grossPay),
          _formatPercent(vatPercent),
          formatMoney(slice.vatAmount),
          formatMoney(slice.totalPay),
        ),
      );
    }

    return lines;
  }

  String _formatMultiplier(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(1).replaceAll('.', ',');
  }

  int _expectedShiftsInMonth(
    CyclicWorkSchedule schedule,
    DateTime monthStart,
    DateTime monthEnd,
  ) {
    if (schedule.isShiftCycle &&
        schedule.cycleStartDate != null &&
        schedule.workDays > 0) {
      var count = 0;
      for (
        var day = monthStart;
        !day.isAfter(monthEnd);
        day = day.add(const Duration(days: 1))
      ) {
        final start = schedule.cycleStartDate!;
        final cycleLength = schedule.workDays + schedule.restDays;
        if (cycleLength <= 0) continue;
        final anchor = DateTime(start.year, start.month, start.day);
        final diff = day.difference(anchor).inDays;
        if (diff >= 0 && diff % cycleLength < schedule.workDays) count++;
      }
      return count;
    }
    return monthEnd.day;
  }
}
