import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../calendar/widgets/chrome/almanac_mini_color_picker.dart';
import '../data/profiles/context_profile.dart';
import '../core/localization/app_localizations.dart';
import '../calendar/calendar_export_actions.dart';
import '../calendar/guest_calendar_actions.dart';
import '../calendar/test_calendar_fill.dart';
import '../calendar/widgets/test_calendar_fill_catalog_list.dart';
import '../state/calendar_events_notifier.dart';
import '../state/calendar_navigation_notifier.dart';
import '../state/app_providers.dart';
import '../core/ui/almanac_sheets.dart';
import '../core/theme/almanac_tokens.dart';
import '../core/ui/almanac_card.dart';
import '../core/ui/almanac_feedback.dart';
import 'profile_manager_sheet.dart';
import 'workspace_sheet.dart';
import '../schedules/work_schedule_sheet.dart';

part 'settings_actions.dart';
part 'settings_editor.dart';
part 'settings_sections.dart';
part 'guest_calendar_settings_section.dart';

/// Настройки приложения: тема, язык, sync и ссылки.
class SettingsSheet extends ConsumerWidget {
  const SettingsSheet({super.key});

  static Future<void> show(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return showAlmanacSheet<void>(
      context: context,
      title: l10n.settingsTitle,
      child: const SettingsSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(contextProfilesProvider);
    final notifier = ref.read(contextProfilesProvider.notifier);
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SettingsGroup(
          title: l10n.settingsGroupProfile,
          children: [
            const _ProfilesSection(),
            _ThemeSection(active: state.active, notifier: notifier),
          ],
        ),
        _SettingsGroup(
          title: l10n.settingsGroupAppearance,
          children: const [_LocaleSection()],
        ),
        _SettingsGroup(
          title: l10n.settingsGroupServer,
          children: const [_WorkspaceEntrySection()],
        ),
        _SettingsGroup(
          title: l10n.settingsGroupCalendar,
          children: [
            if (state.active.access.canManageSchedules)
              const _WorkScheduleSettingsTile(),
            if (!state.active.access.canBookOnly) const _GuestCalendarSection(),
            const _ExportSection(),
          ],
        ),
        if (state.active.access.canMutateLocalCalendarData)
          _SettingsGroup(
            title: l10n.settingsGroupData,
            children: const [_CalendarDataSection()],
          ),
      ],
    );
  }
}
