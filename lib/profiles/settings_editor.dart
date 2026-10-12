part of 'settings_sheet.dart';

class _ThemeSection extends ConsumerWidget {
  const _ThemeSection({required this.active, required this.notifier});

  final ContextProfile active;
  final ContextProfilesNotifier notifier;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    return AlmanacCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.themeMainProfileTitle,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: AlmanacSpacing.xs),
          SegmentedButton<ThemeMode>(
            segments: [
              ButtonSegment(
                value: ThemeMode.light,
                label: Text(l10n.themeLight),
                icon: const Icon(Icons.light_mode),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                label: Text(l10n.themeDark),
                icon: const Icon(Icons.dark_mode),
              ),
              ButtonSegment(
                value: ThemeMode.system,
                label: Text(l10n.themeSystem),
                icon: const Icon(Icons.settings_brightness),
              ),
            ],
            selected: {active.themeMode},
            onSelectionChanged: (selection) {
              notifier.updateTheme(themeMode: selection.first);
            },
          ),
          const SizedBox(height: AlmanacSpacing.sm),
          Text(
            l10n.themeAccentCustom,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: AlmanacSpacing.xs),
          AlmanacMiniColorPicker(
            color: active.accentColor,
            onChanged: (color) => notifier.updateTheme(accentColor: color),
          ),
          const SizedBox(height: AlmanacSpacing.xxs),
          Text(
            l10n.themeAccentHint,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
