import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/almanac_tokens.dart';
import '../../../data/events/event_quick_template.dart';
import '../../../state/app_providers.dart';

typedef EventQuickTemplateApplyCallback =
    void Function(EventQuickTemplate template);

/// Горизонтальные chips быстрых шаблонов в форме создания записи.
class EventQuickTemplatesBar extends ConsumerWidget {
  const EventQuickTemplatesBar({
    super.key,
    required this.onApply,
    this.onSaveCurrent,
  });

  final EventQuickTemplateApplyCallback onApply;
  final VoidCallback? onSaveCurrent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final profileId = ref.watch(activeProfileIdProvider);
    final templates = ref
        .watch(localDataStoreProvider)
        .eventQuickTemplatesFor(profileId);

    if (templates.isEmpty && onSaveCurrent == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.eventQuickTemplatesTitle,
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
            if (onSaveCurrent != null)
              TextButton(
                onPressed: onSaveCurrent,
                child: Text(l10n.saveEventTemplateAction),
              ),
          ],
        ),
        if (templates.isNotEmpty) ...[
          const SizedBox(height: AlmanacSpacing.xxs),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final template in templates) ...[
                  ActionChip(
                    label: Text(template.title),
                    onPressed: () => onApply(template),
                  ),
                  const SizedBox(width: AlmanacSpacing.xxs),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}
