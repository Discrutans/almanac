import 'package:flutter/material.dart';
import '../../../profiles/profile_switcher.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../profiles/settings_sheet.dart';
import '../../../core/theme/almanac_motion.dart';
import '../../../core/theme/almanac_tokens.dart';
import '../../../core/ui/almanac_buttons.dart';
import '../../../core/ui/almanac_card.dart';

/// Верхняя навигация календаря: крупные стрелки, анимированный заголовок.
class CalendarTopNavBar extends StatelessWidget {
  const CalendarTopNavBar({
    super.key,
    required this.title,
    required this.navDirection,
    required this.onPrevious,
    required this.onNext,
  });

  final String title;
  final int navDirection;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isCompact = AlmanacBreakpoints.isMobile(
      MediaQuery.sizeOf(context).width,
    );
    return AlmanacCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AlmanacSpacing.xs,
        vertical: AlmanacSpacing.xxs + 2,
      ),
      child: Row(
        children: [
          AlmanacNavButton(
            icon: Icons.chevron_left_rounded,
            tooltip: l10n.previousPeriod,
            onPressed: onPrevious,
          ),
          const SizedBox(width: AlmanacSpacing.xxs),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: _AnimatedNavTitle(title: title, direction: navDirection),
            ),
          ),
          const SizedBox(width: AlmanacSpacing.xxs),
          AlmanacNavButton(
            icon: Icons.chevron_right_rounded,
            tooltip: l10n.nextPeriod,
            onPressed: onNext,
          ),
          const SizedBox(width: AlmanacSpacing.xxs),
          AlmanacIconButton(
            icon: Icons.settings_outlined,
            tooltip: l10n.openSettingsTooltip,
            onPressed: () => SettingsSheet.show(context),
          ),
          const SizedBox(width: AlmanacSpacing.xxs),
          ProfileSwitcher(compact: isCompact),
        ],
      ),
    );
  }
}

class _AnimatedNavTitle extends StatefulWidget {
  const _AnimatedNavTitle({required this.title, required this.direction});

  final String title;
  final int direction;

  @override
  State<_AnimatedNavTitle> createState() => _AnimatedNavTitleState();
}

class _AnimatedNavTitleState extends State<_AnimatedNavTitle> {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedSwitcher(
      duration: AlmanacDurations.smooth,
      switchInCurve: AlmanacCurves.enter,
      switchOutCurve: AlmanacCurves.exit,
      transitionBuilder: (child, animation) {
        if (widget.direction == 0) {
          return almanacSlideFadeTransition(
            child,
            animation,
            begin: const Offset(0, 0.04),
          );
        }
        final curved = CurvedAnimation(
          parent: animation,
          curve: AlmanacCurves.enter,
          reverseCurve: AlmanacCurves.exit,
        );
        final isIncoming = animation is! ReverseAnimation;
        final tween = isIncoming
            ? Tween<Offset>(
                begin: Offset(widget.direction * 0.12, 0),
                end: Offset.zero,
              )
            : Tween<Offset>(
                begin: Offset.zero,
                end: Offset(-widget.direction * 0.12, 0),
              );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(position: tween.animate(curved), child: child),
        );
      },
      layoutBuilder: (currentChild, previousChildren) {
        return currentChild ?? const SizedBox.shrink();
      },
      child: Text(
        widget.title,
        key: ValueKey(widget.title),
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w800,
          height: 1.05,
          letterSpacing: -0.3,
          color: scheme.onSurface,
        ),
      ),
    );
  }
}
