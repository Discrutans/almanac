import 'package:flutter/material.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/theme/almanac_tokens.dart';
import '../test_calendar_fill_catalog.dart';

/// Компактный скролл-список фич тестового заполнения для настроек.
class TestCalendarFillCatalogList extends StatelessWidget {
  const TestCalendarFillCatalogList({super.key, this.maxHeight = 280});

  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final titleStyle = Theme.of(context).textTheme.bodyMedium;
    final chipStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: scheme.onSurfaceVariant,
      height: 1.1,
    );

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.55),
          ),
          borderRadius: AlmanacRadius.control,
        ),
        child: ClipRRect(
          borderRadius: AlmanacRadius.control,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(
              horizontal: AlmanacSpacing.xs,
              vertical: AlmanacSpacing.xxs,
            ),
            itemCount: TestCalendarFillCatalog.all.length,
            separatorBuilder: (_, _) => Divider(
              height: 1,
              color: scheme.outlineVariant.withValues(alpha: 0.35),
            ),
            itemBuilder: (context, index) {
              final feature = TestCalendarFillCatalog.all[index];
              final placements = feature.placements
                  .map((p) => l10n.testCalendarFillPlacementLabel(p.name))
                  .join(' · ');
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(feature.icon, size: 18, color: scheme.primary),
                    const SizedBox(width: AlmanacSpacing.xs),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.testCalendarFillFeatureTitle(feature.id),
                            style: titleStyle,
                          ),
                          const SizedBox(height: 2),
                          Text(placements, style: chipStyle),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
