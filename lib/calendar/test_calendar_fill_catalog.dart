import 'package:flutter/material.dart';

/// Где смотреть фичу тестового заполнения.
enum TestCalendarFillPlacement {
  today,
  week,
  agenda,
  month,
  schedules,
  savings,
}

/// Пункт визуального каталога «Тестовое заполнение».
///
/// Документация для UI; данные генерирует [TestCalendarFill].
@immutable
class TestCalendarFillFeature {
  const TestCalendarFillFeature({
    required this.id,
    required this.icon,
    required this.placements,
  });

  final String id;
  final IconData icon;
  final List<TestCalendarFillPlacement> placements;
}

/// Статический манифест фич тестового набора.
abstract final class TestCalendarFillCatalog {
  static const List<TestCalendarFillFeature> all = [
    // Recurrence — see TestCalendarFill.dailySeriesId / weekly / monthly
    TestCalendarFillFeature(
      id: 'recurrence_daily',
      icon: Icons.repeat,
      placements: [
        TestCalendarFillPlacement.today,
        TestCalendarFillPlacement.week,
        TestCalendarFillPlacement.agenda,
      ],
    ),
    TestCalendarFillFeature(
      id: 'recurrence_weekly',
      icon: Icons.event_repeat,
      placements: [
        TestCalendarFillPlacement.week,
        TestCalendarFillPlacement.agenda,
        TestCalendarFillPlacement.month,
      ],
    ),
    TestCalendarFillFeature(
      id: 'recurrence_monthly',
      icon: Icons.calendar_month_outlined,
      placements: [
        TestCalendarFillPlacement.month,
        TestCalendarFillPlacement.agenda,
      ],
    ),
    TestCalendarFillFeature(
      id: 'recurrence_exclusion',
      icon: Icons.event_busy_outlined,
      placements: [
        TestCalendarFillPlacement.week,
        TestCalendarFillPlacement.agenda,
      ],
    ),
    TestCalendarFillFeature(
      id: 'recurrence_detached',
      icon: Icons.link_off_outlined,
      placements: [
        TestCalendarFillPlacement.week,
        TestCalendarFillPlacement.agenda,
      ],
    ),
    // Today bundle
    TestCalendarFillFeature(
      id: 'today_rich',
      icon: Icons.event_note_outlined,
      placements: [
        TestCalendarFillPlacement.today,
        TestCalendarFillPlacement.week,
        TestCalendarFillPlacement.agenda,
      ],
    ),
    TestCalendarFillFeature(
      id: 'today_adjacent',
      icon: Icons.view_timeline_outlined,
      placements: [
        TestCalendarFillPlacement.today,
        TestCalendarFillPlacement.week,
      ],
    ),
    TestCalendarFillFeature(
      id: 'today_gift',
      icon: Icons.card_giftcard_outlined,
      placements: [
        TestCalendarFillPlacement.today,
        TestCalendarFillPlacement.week,
      ],
    ),
    TestCalendarFillFeature(
      id: 'today_note_attachments',
      icon: Icons.attach_file_outlined,
      placements: [
        TestCalendarFillPlacement.today,
        TestCalendarFillPlacement.month,
      ],
    ),
    TestCalendarFillFeature(
      id: 'today_note_derived',
      icon: Icons.notes_outlined,
      placements: [
        TestCalendarFillPlacement.today,
        TestCalendarFillPlacement.month,
      ],
    ),
    TestCalendarFillFeature(
      id: 'today_checklist',
      icon: Icons.checklist_outlined,
      placements: [
        TestCalendarFillPlacement.today,
        TestCalendarFillPlacement.month,
      ],
    ),
    // Conflict / shifts — conflictEventId, overrides
    TestCalendarFillFeature(
      id: 'conflict_shift',
      icon: Icons.warning_amber_outlined,
      placements: [
        TestCalendarFillPlacement.today,
        TestCalendarFillPlacement.week,
        TestCalendarFillPlacement.schedules,
      ],
    ),
    TestCalendarFillFeature(
      id: 'shift_skip',
      icon: Icons.event_busy,
      placements: [
        TestCalendarFillPlacement.week,
        TestCalendarFillPlacement.schedules,
      ],
    ),
    TestCalendarFillFeature(
      id: 'shift_overtime',
      icon: Icons.more_time_outlined,
      placements: [
        TestCalendarFillPlacement.week,
        TestCalendarFillPlacement.schedules,
      ],
    ),
    TestCalendarFillFeature(
      id: 'office_skip',
      icon: Icons.work_off_outlined,
      placements: [
        TestCalendarFillPlacement.week,
        TestCalendarFillPlacement.schedules,
      ],
    ),
    // Schedules
    TestCalendarFillFeature(
      id: 'schedule_office',
      icon: Icons.work_outline,
      placements: [TestCalendarFillPlacement.schedules],
    ),
    TestCalendarFillFeature(
      id: 'schedule_shift',
      icon: Icons.nightlight_outlined,
      placements: [
        TestCalendarFillPlacement.schedules,
        TestCalendarFillPlacement.week,
      ],
    ),
    // Savings
    TestCalendarFillFeature(
      id: 'savings_overdue',
      icon: Icons.savings_outlined,
      placements: [TestCalendarFillPlacement.savings],
    ),
    TestCalendarFillFeature(
      id: 'savings_long_title',
      icon: Icons.title,
      placements: [TestCalendarFillPlacement.savings],
    ),
    TestCalendarFillFeature(
      id: 'savings_progress',
      icon: Icons.trending_up,
      placements: [TestCalendarFillPlacement.savings],
    ),
    TestCalendarFillFeature(
      id: 'savings_year_end',
      icon: Icons.card_giftcard,
      placements: [TestCalendarFillPlacement.savings],
    ),
    // Stress UI
    TestCalendarFillFeature(
      id: 'stress_long_text',
      icon: Icons.format_align_left,
      placements: [
        TestCalendarFillPlacement.today,
        TestCalendarFillPlacement.agenda,
        TestCalendarFillPlacement.week,
      ],
    ),
    TestCalendarFillFeature(
      id: 'stress_weekend_title',
      icon: Icons.weekend_outlined,
      placements: [
        TestCalendarFillPlacement.week,
        TestCalendarFillPlacement.agenda,
        TestCalendarFillPlacement.month,
      ],
    ),
    TestCalendarFillFeature(
      id: 'stress_monthly_notes',
      icon: Icons.auto_stories_outlined,
      placements: [
        TestCalendarFillPlacement.month,
        TestCalendarFillPlacement.agenda,
      ],
    ),
  ];
}
