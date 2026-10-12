import 'package:flutter/material.dart';
import '../core/localization/app_localizations.dart';
import 'calendar_types.dart';
import 'event_time_utils.dart';

/// Короткий читаемый фрагмент: без служебных `[заголовков]` и обрезкой по словам.
String? compactPreviewText(String? raw, {int maxChars = 88}) {
  if (raw == null) return null;
  final pieces = <String>[];
  for (final line in raw.split(RegExp(r'\r?\n'))) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) continue;
    if (trimmed.startsWith('[') && trimmed.endsWith(']')) continue;
    pieces.add(trimmed);
  }
  if (pieces.isEmpty) return null;
  final text = pieces.join(' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  if (text.isEmpty) return null;
  if (text.length <= maxChars) return text;
  var cut = text.substring(0, maxChars).trimRight();
  final lastSpace = cut.lastIndexOf(' ');
  if (lastSpace >= maxChars ~/ 2) {
    cut = cut.substring(0, lastSpace);
  }
  return '$cut…';
}

/// Убирает суффикс «N симв.» из заголовка, чтобы в колонке читалась суть.
String compactEventTitle(String title) {
  final stripped = title
      .replaceFirst(
        RegExp(r'(?:\s*[·•]\s*)?\d+\s*симв\.?\s*$', caseSensitive: false),
        '',
      )
      .trim();
  return stripped.isEmpty ? title : stripped;
}

/// Метаданные для компактных иконок (неделя, список).
class EventMetaChipInfo {
  const EventMetaChipInfo({
    required this.icon,
    required this.tooltip,
    this.label,
  });

  final IconData icon;
  final String tooltip;
  final String? label;
}

/// Единая модель отображения записи для week / agenda / list.
class EventDisplayInfo {
  EventDisplayInfo._({
    required this.title,
    required this.timeRange,
    required this.profileLabel,
    required this.detailLines,
    required this.metaChips,
    required this.tooltipLines,
    required this.isScheduleEvent,
    required this.listIcon,
  });

  final String title;
  final String? timeRange;
  final String? profileLabel;
  final List<String> detailLines;
  final List<EventMetaChipInfo> metaChips;
  final List<String> tooltipLines;
  final bool isScheduleEvent;
  final IconData listIcon;

  List<String> get subtitleLines => [?profileLabel, ...detailLines];

  String? get secondaryText {
    if (detailLines.isEmpty) return null;
    return detailLines.join(' · ');
  }

  String tooltipMessage(AppLocalizations l10n) => tooltipLines.join('\n');

  bool showMetaRow({required bool showForeignProfile}) =>
      metaChips.isNotEmpty || showForeignProfile;

  factory EventDisplayInfo.from(
    AppEvent event,
    AppLocalizations l10n, {
    String? profileLabel,
    bool omitEventTime = false,
    bool omitChecklistProgress = false,
    bool compactMetaLabels = false,
  }) {
    final isSchedule = event.entrySource.isScheduleRelated;
    final isBooking = event.entrySource == CalendarEntrySource.booking;
    final details = <String>[];

    switch (event.kind) {
      case CalendarEntryKind.event:
        if (!omitEventTime && event.isTimed) {
          details.add(formatEventTimeRange(event));
        }
        if (!compactMetaLabels) {
          details.addAll(_amountLines(event));
        }
        if (compactMetaLabels) {
          final preview = compactPreviewText(event.notes);
          if (preview != null) details.add(preview);
        } else {
          final notes = event.notes?.trim();
          if (notes != null && notes.isNotEmpty) {
            details.add(notes);
          }
        }
        details.addAll(_shiftPayLines(event, l10n));
      case CalendarEntryKind.note:
        if (compactMetaLabels) {
          if (!event.isAutoDerivedNoteTitle) {
            final preview = compactPreviewText(event.notes);
            if (preview != null) {
              details.add(preview);
            } else if (event.notes == null || event.notes!.trim().isEmpty) {
              details.add(l10n.notes);
            }
          } else if (event.notes == null || event.notes!.trim().isEmpty) {
            details.add(l10n.notes);
          }
        } else if (event.isAutoDerivedNoteTitle) {
          if (event.notes == null || event.notes!.trim().isEmpty) {
            details.add(l10n.notes);
          }
        } else {
          final secondary = event.noteDisplaySecondary;
          if (secondary != null) {
            details.add(secondary);
          } else {
            details.add(l10n.notes);
          }
        }
        if (!compactMetaLabels) {
          details.addAll(_amountLines(event));
        }
        if (event.hasAttachments && !compactMetaLabels) {
          details.add(l10n.noteAttachmentsCount(event.attachments.length));
        }
      case CalendarEntryKind.checklist:
        if (!omitChecklistProgress) {
          details.add(
            compactMetaLabels
                ? l10n.checklistsCountShort(
                    event.checklistCompletedCount,
                    event.checklistTotalCount,
                  )
                : l10n.checklistsProgress(
                    event.checklistCompletedCount,
                    event.checklistTotalCount,
                  ),
          );
        }
        if (compactMetaLabels) {
          final preview = compactPreviewText(_checklistPreviewSource(event));
          if (preview != null) details.add(preview);
        }
      case CalendarEntryKind.savingsGoal:
        final amount = event.savingsTargetAmount;
        final saved = event.savingsSavedAmount;
        if (amount != null) {
          if (saved != null && saved > 0) {
            details.add(l10n.savingsProgressLine(saved, amount));
          } else {
            details.add(formatMoney(amount));
          }
        }
        final note = event.notes?.trim();
        if (note != null && note.isNotEmpty) {
          details.add(
            compactMetaLabels ? (compactPreviewText(note) ?? note) : note,
          );
        }
    }

    final tooltip = <String>[event.noteDisplayTitle];
    if (event.isTimed) {
      tooltip.add(formatEventTimeRange(event));
    }
    tooltip.addAll(details);
    if (profileLabel != null) {
      tooltip.add(profileLabel);
    }
    if (isBooking) {
      tooltip.add(l10n.fromBookingSession);
    }
    if (event.entrySource == CalendarEntrySource.bookingSlot ||
        event.entrySource == CalendarEntrySource.bookingOffer) {
      tooltip.add(l10n.bookingSlotOnSchedule);
    }
    if (event.entrySource == CalendarEntrySource.bookingPending) {
      tooltip.add(l10n.fromPendingBooking);
    }
    if (event.entrySource == CalendarEntrySource.guestCalendar) {
      tooltip.add(l10n.guestCalendarTitle);
    }

    final meta = <EventMetaChipInfo>[];
    if (isBooking) {
      meta.add(
        EventMetaChipInfo(
          icon: Icons.event_available_outlined,
          tooltip: l10n.fromBookingSession,
          label: compactMetaLabels ? null : l10n.fromBookingSession,
        ),
      );
    }
    if (event.entrySource == CalendarEntrySource.bookingSlot ||
        event.entrySource == CalendarEntrySource.bookingOffer) {
      meta.add(
        EventMetaChipInfo(
          icon: Icons.schedule_outlined,
          tooltip: l10n.bookingSlotOnSchedule,
          label: compactMetaLabels ? null : l10n.bookingSlotOnSchedule,
        ),
      );
    }
    if (event.entrySource == CalendarEntrySource.bookingPending) {
      meta.add(
        EventMetaChipInfo(
          icon: Icons.hourglass_top_rounded,
          tooltip: l10n.fromPendingBooking,
          label: compactMetaLabels ? null : l10n.fromPendingBooking,
        ),
      );
    }
    if (event.entrySource == CalendarEntrySource.guestCalendar) {
      meta.add(
        EventMetaChipInfo(
          icon: Icons.link_outlined,
          tooltip: l10n.guestCalendarTitle,
          label: compactMetaLabels ? null : l10n.guestCalendarTitle,
        ),
      );
    }
    if (event.hasRecurrence) {
      meta.add(
        EventMetaChipInfo(
          icon: Icons.repeat_rounded,
          tooltip: l10n.formatRrule(event.rrule!),
          label: compactMetaLabels ? null : l10n.recurrence,
        ),
      );
    }
    if (event.reminderMinutesBefore != null) {
      meta.add(
        EventMetaChipInfo(
          icon: Icons.notifications_outlined,
          tooltip: l10n.eventReminderLine(event.reminderMinutesBefore!),
          label: compactMetaLabels
              ? null
              : l10n.reminderLabel(event.reminderMinutesBefore),
        ),
      );
    }
    if (event.incomeAmount != null && event.incomeAmount! > 0) {
      final amount = formatMoney(event.incomeAmount!);
      meta.add(
        EventMetaChipInfo(
          icon: Icons.payments_outlined,
          tooltip: amount,
          label: amount,
        ),
      );
    }
    if (event.hasAttachments) {
      meta.add(
        EventMetaChipInfo(
          icon: Icons.attach_file_outlined,
          tooltip: l10n.noteAttachmentsCount(event.attachments.length),
          label: compactMetaLabels
              ? null
              : l10n.noteAttachmentsCount(event.attachments.length),
        ),
      );
    }

    return EventDisplayInfo._(
      title: compactMetaLabels
          ? _compactCardTitle(event)
          : event.noteDisplayTitle,
      timeRange: event.isTimed ? formatEventTimeRange(event) : null,
      profileLabel: profileLabel,
      detailLines: details,
      metaChips: meta,
      tooltipLines: tooltip,
      isScheduleEvent: isSchedule,
      listIcon: _listIcon(event),
    );
  }

  static String _compactCardTitle(AppEvent event) {
    if (event.kind == CalendarEntryKind.note && event.isAutoDerivedNoteTitle) {
      return compactPreviewText(event.notes, maxChars: 56) ??
          compactEventTitle(event.title);
    }
    return compactEventTitle(event.noteDisplayTitle);
  }

  static String? _checklistPreviewSource(AppEvent event) {
    String? incomplete;
    String? any;
    void walk(List<ChecklistItem> items) {
      for (final item in items) {
        any ??= item.title;
        if (!item.completed) {
          incomplete ??= item.title;
        }
        walk(item.children);
      }
    }

    walk(event.checklist);
    return incomplete ?? any;
  }

  static List<String> _amountLines(AppEvent event) {
    if (event.incomeAmount == null || event.incomeAmount! <= 0) {
      return const [];
    }
    return [formatMoney(event.incomeAmount!)];
  }

  static List<String> _shiftPayLines(AppEvent event, AppLocalizations l10n) {
    final lines = <String>[];
    if (event.shiftSkipped) {
      lines.add(l10n.shiftSkippedLabel);
    }
    if (event.unpaidMinutes != null && event.unpaidMinutes! > 0) {
      lines.add('${l10n.unpaidMinutesLabel}: ${event.unpaidMinutes}');
    }
    if (event.overtimeMinutes != null && event.overtimeMinutes! > 0) {
      lines.add('${l10n.overtimeFieldLabel}: ${event.overtimeMinutes}');
    }
    return lines;
  }

  static IconData _listIcon(AppEvent event) {
    if (event.entrySource == CalendarEntrySource.booking ||
        event.entrySource == CalendarEntrySource.bookingSlot ||
        event.entrySource == CalendarEntrySource.bookingOffer) {
      return Icons.event_available_outlined;
    }
    switch (event.kind) {
      case CalendarEntryKind.event:
        return Icons.event_outlined;
      case CalendarEntryKind.note:
        return Icons.sticky_note_2_outlined;
      case CalendarEntryKind.checklist:
        return Icons.checklist_rtl_outlined;
      case CalendarEntryKind.savingsGoal:
        return Icons.savings_outlined;
    }
  }
}
