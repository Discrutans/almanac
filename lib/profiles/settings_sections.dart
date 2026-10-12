part of 'settings_sheet.dart';

class _WorkspaceEntrySection extends ConsumerWidget {
  const _WorkspaceEntrySection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return AlmanacCard(
      child: ListTile(
        leading: const Icon(Icons.cloud_outlined),
        title: Text(l10n.workspaceTitle),
        subtitle: Text(l10n.workspaceSubtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => WorkspaceSheet.show(context),
      ),
    );
  }
}

class _LocaleSection extends ConsumerWidget {
  const _LocaleSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = ref.watch(appLocaleProvider);
    final notifier = ref.read(appLocaleProvider.notifier);

    return AlmanacCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.languageSection,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: AlmanacSpacing.xs),
          SegmentedButton<String>(
            segments: [
              ButtonSegment(value: 'ru', label: Text(l10n.languageRu)),
              ButtonSegment(value: 'en', label: Text(l10n.languageEn)),
            ],
            selected: {locale.languageCode},
            onSelectionChanged: (selection) {
              notifier.setLanguageCode(selection.first);
            },
          ),
        ],
      ),
    );
  }
}

class _ExportSection extends ConsumerWidget {
  const _ExportSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final nav = ref.watch(calendarNavigationProvider);
    final events = ref.watch(filteredCalendarEventsProvider);

    return AlmanacCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.shareCalendarAction,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: AlmanacSpacing.xs),
          OutlinedButton.icon(
            onPressed: events.isEmpty
                ? null
                : () => shareVisibleEventsAsIcs(
                    context: context,
                    events: events,
                    calendarName: nav.headerTitle(l10n),
                  ),
            icon: const Icon(Icons.ios_share_outlined),
            label: Text(l10n.exportIcsAction),
          ),
        ],
      ),
    );
  }
}

class _WorkScheduleSettingsTile extends StatelessWidget {
  const _WorkScheduleSettingsTile();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlmanacCard(
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.schedule_outlined),
        title: Text(l10n.entryKindWorkSchedule),
        subtitle: Text(l10n.entryKindWorkScheduleHint),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => WorkScheduleSheet.show(context),
      ),
    );
  }
}
