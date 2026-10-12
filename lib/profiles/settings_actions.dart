part of 'settings_sheet.dart';

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AlmanacSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(
              left: AlmanacSpacing.xxs,
              bottom: AlmanacSpacing.xs,
            ),
            child: Text(
              title.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: context.almanacColors.muted,
                letterSpacing: 0.8,
              ),
            ),
          ),
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: AlmanacSpacing.xs),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _CalendarDataSection extends ConsumerWidget {
  const _CalendarDataSection();

  Future<void> _fillCalendar(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showAlmanacConfirm(
      context: context,
      title: l10n.testCalendarFillTitle,
      message: l10n.testCalendarFillConfirm,
      cancelLabel: l10n.cancel,
      confirmLabel: l10n.testCalendarFillTitle,
    );
    if (confirmed != true || !context.mounted) return;

    final profileId = ref.read(activeProfileIdProvider);
    final store = ref.read(localDataStoreProvider);
    store.applyTestCalendarFill(profileId);

    ref.read(schedulesVersionProvider.notifier).state++;
    ref.read(savingsGoalsVersionProvider.notifier).state++;
    ref.read(calendarEventsProvider.notifier).reload();

    if (!context.mounted) return;
    AlmanacFeedback.showSuccess(
      context,
      l10n.testCalendarFillDone(
        TestCalendarFill.personalEvents(profileId).length,
        TestCalendarFill.schedules(profileId).length,
        TestCalendarFill.savingsGoals(profileId).length,
      ),
    );
  }

  Future<void> _clearCalendar(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showAlmanacConfirm(
      context: context,
      title: l10n.clearCalendarTitle,
      message: l10n.clearCalendarConfirm,
      cancelLabel: l10n.cancel,
      confirmLabel: l10n.clearCalendarTitle,
      destructive: true,
    );
    if (confirmed != true || !context.mounted) return;

    ref.read(localDataStoreProvider).clearCalendarData();
    ref.read(calendarEventsProvider.notifier).reload();
    if (context.mounted) {
      AlmanacFeedback.showSuccess(context, l10n.clearCalendarDone);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final muted = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );

    return AlmanacCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (kDebugMode) ...[
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(top: AlmanacSpacing.xs),
              title: Text(
                l10n.testCalendarFillTitle,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              subtitle: Text(l10n.testCalendarFillHint, style: muted),
              children: [
                Text(
                  l10n.testCalendarFillCatalogLabel,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: AlmanacSpacing.xs),
                const TestCalendarFillCatalogList(),
                const SizedBox(height: AlmanacSpacing.sm),
                OutlinedButton.icon(
                  onPressed: () => _fillCalendar(context, ref),
                  icon: const Icon(Icons.science_outlined),
                  label: Text(l10n.testCalendarFillTitle),
                ),
                const SizedBox(height: AlmanacSpacing.sm),
                const _TestProfileInterfaceButton(),
              ],
            ),
            const SizedBox(height: AlmanacSpacing.sm),
            const Divider(height: 1),
            const SizedBox(height: AlmanacSpacing.sm),
          ],
          OutlinedButton.icon(
            onPressed: () => _clearCalendar(context, ref),
            icon: const Icon(Icons.delete_sweep_outlined),
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            label: Text(l10n.clearCalendarTitle),
          ),
        ],
      ),
    );
  }
}

class _TestProfileInterfaceButton extends ConsumerWidget {
  const _TestProfileInterfaceButton();

  static const _previews = <ProfileAccess>[
    ProfileAccess(ProfileKind.personal, ProfileRole.owner),
    ProfileAccess(ProfileKind.collaborative, ProfileRole.owner),
    ProfileAccess(ProfileKind.collaborative, ProfileRole.member),
    ProfileAccess(ProfileKind.booking, ProfileRole.owner),
    ProfileAccess(ProfileKind.booking, ProfileRole.member),
  ];

  Future<void> _openPicker(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final selected = await showAlmanacSheet<ProfileAccess>(
      context: context,
      placement: AlmanacSheetPlacement.bottom,
      title: l10n.testProfileInterfaceTitle,
      size: AlmanacPanelSize.hug,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.testProfileInterfaceHint,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AlmanacSpacing.sm),
          for (final access in _previews)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(_iconFor(access)),
              title: Text(l10n.profileKindChip(access.kind, access.role)),
              onTap: () => Navigator.pop(context, access),
            ),
        ],
      ),
    );
    if (selected == null || !context.mounted) return;
    ref.read(profileAccessOverrideProvider.notifier).state = selected;
    ref.read(calendarEventsProvider.notifier).reload();
    if (!context.mounted) return;
    Navigator.of(context).pop();
  }

  static IconData _iconFor(ProfileAccess access) {
    return switch (access.kind) {
      ProfileKind.personal => Icons.phone_android_outlined,
      ProfileKind.collaborative => Icons.groups_outlined,
      ProfileKind.booking => Icons.event_available_outlined,
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final override = ref.watch(profileAccessOverrideProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.tonalIcon(
          onPressed: () => _openPicker(context, ref),
          icon: const Icon(Icons.switch_account_outlined),
          label: Text(
            override == null
                ? l10n.testProfileInterfaceTitle
                : l10n.testProfileInterfaceActive(
                    l10n.profileKindChip(override.kind, override.role),
                  ),
          ),
        ),
        if (override != null) ...[
          const SizedBox(height: AlmanacSpacing.xs),
          TextButton(
            onPressed: () {
              ref.read(profileAccessOverrideProvider.notifier).state = null;
              ref.read(calendarEventsProvider.notifier).reload();
            },
            child: Text(l10n.testProfileInterfaceReset),
          ),
        ],
      ],
    );
  }
}

class _ProfilesSection extends ConsumerWidget {
  const _ProfilesSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    return AlmanacCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.profilesTitle,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: AlmanacSpacing.xs),
          OutlinedButton.icon(
            onPressed: () => ProfileManagerSheet.show(context),
            icon: const Icon(Icons.manage_accounts_outlined),
            label: Text(l10n.manageProfiles),
          ),
        ],
      ),
    );
  }
}
