import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/profiles/context_profile.dart';
import '../core/localization/app_localizations.dart';
import '../state/app_providers.dart';
import '../core/ui/almanac_sheets.dart';
import '../core/theme/almanac_tokens.dart';
import 'create_profile_sheet.dart';
import '../core/ui/almanac_avatar.dart';
import '../core/ui/almanac_feedback.dart';

/// Управление профилями контекста: создание, переименование, удаление, split-view.
class ProfileManagerSheet extends ConsumerWidget {
  const ProfileManagerSheet({super.key});
  static Future<void> show(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return showAlmanacSheet<void>(
      context: context,
      title: l10n.profilesTitle,
      child: const ProfileManagerSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(contextProfilesProvider);
    final notifier = ref.read(contextProfilesProvider.notifier);
    final l10n = AppLocalizations.of(context);
    final canDelete = state.profiles.length > 1;
    final canDisableLastVisible = state.visibleProfileIds.length > 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          state.isSplitView
              ? l10n.splitViewActive(state.visibleLabel)
              : l10n.splitViewHint,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: AlmanacSpacing.md),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: state.profiles.length,
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final profile = state.profiles[index];
            final isActive = profile.id == state.active.id;
            final isVisible = state.isVisible(profile.id);
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AlmanacProfileAvatar(
                    name: profile.name,
                    seedColor: profile.seedColor,
                    isActive: isActive,
                  ),
                  Checkbox(
                    value: isVisible,
                    onChanged: canDisableLastVisible || !isVisible
                        ? (_) => notifier.toggleVisible(profile.id)
                        : null,
                  ),
                ],
              ),
              title: Text(profile.name),
              subtitle: Text(
                [
                  l10n.profileKindChip(profile.kind, profile.role),
                  if (isVisible) l10n.inCalendar,
                  if (isActive) l10n.primaryProfile,
                ].join(' · '),
              ),
              onTap: () => notifier.select(profile.id),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: l10n.makePrimaryTooltip,
                    icon: Icon(
                      isActive ? Icons.star : Icons.star_border,
                      color: isActive ? profile.seedColor : null,
                    ),
                    onPressed: isActive
                        ? null
                        : () => notifier.select(profile.id),
                  ),
                  IconButton(
                    tooltip: l10n.renameTooltip,
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => _renameProfile(context, ref, profile),
                  ),
                  IconButton(
                    tooltip: l10n.deleteTooltip,
                    icon: Icon(
                      Icons.delete_outline,
                      color: canDelete
                          ? context.almanacColors.danger
                          : context.almanacColors.muted,
                    ),
                    onPressed: canDelete
                        ? () => _confirmDelete(context, ref, profile)
                        : null,
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: AlmanacSpacing.sm),
        FilledButton.icon(
          onPressed: () => CreateProfileSheet.show(context),
          icon: const Icon(Icons.add),
          label: Text(l10n.createProfile),
        ),
      ],
    );
  }

  Future<void> _renameProfile(
    BuildContext context,
    WidgetRef ref,
    ContextProfile profile,
  ) async {
    final l10n = AppLocalizations.of(context);
    final rootContext = Navigator.of(context, rootNavigator: true).context;
    final name = await _askProfileName(
      context,
      title: l10n.renameProfile,
      initialValue: profile.name,
    );
    if (name == null) return;
    try {
      ref
          .read(contextProfilesProvider.notifier)
          .rename(id: profile.id, name: name);
    } on ArgumentError catch (e) {
      if (rootContext.mounted) {
        AlmanacFeedback.showError(rootContext, e.message.toString());
      }
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    ContextProfile profile,
  ) async {
    final l10n = AppLocalizations.of(context);
    final rootContext = Navigator.of(context, rootNavigator: true).context;
    final confirmed = await showAlmanacConfirm(
      context: context,
      title: l10n.deleteProfileTitle,
      message: l10n.deleteProfileMessage(profile.name),
      cancelLabel: l10n.cancel,
      confirmLabel: l10n.delete,
      destructive: true,
    );
    if (confirmed != true || !context.mounted) return;
    final notifier = ref.read(contextProfilesProvider.notifier);
    try {
      notifier.delete(profile.id);
    } on StateError catch (e) {
      if (rootContext.mounted) {
        AlmanacFeedback.showError(rootContext, e.message);
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _closeSheet(context);
    });
  }

  void _closeSheet(BuildContext context) {
    if (!context.mounted) return;
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    }
  }

  Future<String?> _askProfileName(
    BuildContext context, {
    required String title,
    required String initialValue,
  }) async {
    final l10n = AppLocalizations.of(context);
    final result = await showAlmanacPrompt(
      context: context,
      title: title,
      label: l10n.title,
      initialValue: initialValue,
      confirmLabel: l10n.save,
      cancelLabel: l10n.cancel,
    );
    final trimmed = result?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
