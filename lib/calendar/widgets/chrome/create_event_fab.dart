import 'package:flutter/material.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/almanac_tokens.dart';

/// Кнопка создания записи внизу экрана (не перекрывает карточки).
class CalendarCreateBar extends StatelessWidget {
  const CalendarCreateBar({super.key, required this.onPressed, this.label});

  final VoidCallback onPressed;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final highlight = context.profileHighlight;

    final onAccent = Theme.of(context).colorScheme.onPrimary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AlmanacSpacing.md,
        AlmanacSpacing.xs,
        AlmanacSpacing.md,
        AlmanacSpacing.sm,
      ),
      child: SizedBox(
        width: double.infinity,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: AlmanacRadius.control,
            child: Ink(
              decoration: BoxDecoration(
                color: highlight.accentEnd,
                borderRadius: AlmanacRadius.control,
                boxShadow: [
                  BoxShadow(
                    color: highlight.accentEnd.withValues(alpha: 0.22),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: AlmanacSpacing.md,
                vertical: AlmanacSpacing.sm,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_rounded, color: onAccent),
                  const SizedBox(width: AlmanacSpacing.xs),
                  Flexible(
                    child: Text(
                      label ?? l10n.addEvent,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: onAccent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
