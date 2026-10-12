import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/localization/app_localizations.dart';
import '../state/app_providers.dart';
import '../core/theme/almanac_tokens.dart';
import '../core/ui/almanac_avatar.dart';

/// Панель быстрого выбора профиля — только включение/выключение.
class ProfileQuickMenuPanel extends ConsumerWidget {
  const ProfileQuickMenuPanel({
    super.key,
    required this.onClose,
    required this.hostContext,
  });

  static const double minWidth = 280;

  final VoidCallback onClose;
  final BuildContext hostContext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(contextProfilesProvider);
    final notifier = ref.read(contextProfilesProvider.notifier);
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final canDisableLastVisible = state.visibleProfileIds.length > 1;

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: minWidth, maxWidth: 320),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AlmanacSpacing.md,
              AlmanacSpacing.sm,
              AlmanacSpacing.md,
              AlmanacSpacing.xs,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.profilesTitle,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                if (state.isSplitView)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      state.visibleLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          for (final profile in state.profiles)
            _ProfileListTile(
              name: profile.name,
              seedColor: profile.seedColor,
              isActive: profile.id == state.active.id,
              isVisible: state.isVisible(profile.id),
              canToggleVisibility:
                  canDisableLastVisible || !state.isVisible(profile.id),
              inCalendarLabel: l10n.inCalendar,
              primaryLabel: l10n.primaryProfile,
              onSelect: () {
                notifier.select(profile.id);
                onClose();
              },
              onToggleVisibility: () => notifier.toggleVisible(profile.id),
            ),
          const SizedBox(height: AlmanacSpacing.xxs),
        ],
      ),
    );
  }
}

class _ProfileListTile extends StatelessWidget {
  const _ProfileListTile({
    required this.name,
    required this.seedColor,
    required this.isActive,
    required this.isVisible,
    required this.canToggleVisibility,
    required this.inCalendarLabel,
    required this.primaryLabel,
    required this.onSelect,
    required this.onToggleVisibility,
  });

  final String name;
  final Color seedColor;
  final bool isActive;
  final bool isVisible;
  final bool canToggleVisibility;
  final String inCalendarLabel;
  final String primaryLabel;
  final VoidCallback onSelect;
  final VoidCallback onToggleVisibility;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final subtitle = [
      if (isVisible) inCalendarLabel,
      if (isActive) primaryLabel,
    ].join(' · ');

    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      contentPadding: const EdgeInsets.symmetric(horizontal: AlmanacSpacing.md),
      leading: AlmanacProfileAvatar(
        name: name,
        seedColor: seedColor,
        isActive: isActive,
      ),
      title: Text(
        name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
          color: isActive ? scheme.primary : scheme.onSurface,
        ),
      ),
      subtitle: subtitle.isEmpty
          ? null
          : Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
      trailing: Checkbox(
        value: isVisible,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        onChanged: canToggleVisibility ? (_) => onToggleVisibility() : null,
      ),
      onTap: onSelect,
    );
  }
}
