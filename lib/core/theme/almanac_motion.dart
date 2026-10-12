import 'package:flutter/material.dart';
import 'almanac_tokens.dart';

/// Плавное появление/исчезновение кнопок в toolbar.
class AlmanacAnimatedToolbarSlot extends StatelessWidget {
  const AlmanacAnimatedToolbarSlot({
    super.key,
    required this.visible,
    required this.child,
  });

  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ClipRect(
        child: AnimatedAlign(
          duration: AlmanacDurations.smooth,
          curve: AlmanacCurves.emphasis,
          alignment: Alignment.centerRight,
          widthFactor: visible ? 1 : 0,
          heightFactor: 1,
          child: AnimatedOpacity(
            duration: AlmanacDurations.smooth,
            curve: visible ? AlmanacCurves.enter : AlmanacCurves.exit,
            opacity: visible ? 1 : 0,
            child: IgnorePointer(ignoring: !visible, child: child),
          ),
        ),
      ),
    );
  }
}

Widget almanacSlideFadeTransition(
  Widget child,
  Animation<double> animation, {
  Offset begin = const Offset(0, 0.04),
  Offset? end,
}) {
  final curved = CurvedAnimation(
    parent: animation,
    curve: AlmanacCurves.enter,
    reverseCurve: AlmanacCurves.exit,
  );
  return FadeTransition(
    opacity: curved,
    child: SlideTransition(
      position: Tween<Offset>(
        begin: begin,
        end: end ?? Offset.zero,
      ).animate(curved),
      child: child,
    ),
  );
}

Widget almanacCalendarViewTransition(
  Widget child,
  Animation<double> animation, {
  required int direction,
}) {
  final curved = CurvedAnimation(
    parent: animation,
    curve: AlmanacCurves.enter,
    reverseCurve: AlmanacCurves.exit,
  );

  if (direction == 0) {
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.03),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }

  final isIncoming = animation is! ReverseAnimation;
  final tween = isIncoming
      ? Tween<Offset>(begin: Offset(direction * 0.08, 0), end: Offset.zero)
      : Tween<Offset>(begin: Offset.zero, end: Offset(-direction * 0.08, 0));

  return FadeTransition(
    opacity: curved,
    child: SlideTransition(position: tween.animate(curved), child: child),
  );
}

Widget almanacTopPanelTransition(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  return _verticalPanelTransition(animation, child, fromTop: true);
}

Widget almanacBottomPanelTransition(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  return _verticalPanelTransition(animation, child, fromTop: false);
}

Widget _verticalPanelTransition(
  Animation<double> animation,
  Widget child, {
  required bool fromTop,
}) {
  final curved = CurvedAnimation(
    parent: animation,
    curve: AlmanacCurves.emphasis,
    reverseCurve: AlmanacCurves.exit,
  );
  return SlideTransition(
    position: Tween<Offset>(
      begin: Offset(0, fromTop ? -1 : 1),
      end: Offset.zero,
    ).animate(curved),
    child: FadeTransition(
      opacity: Tween<double>(begin: 0.85, end: 1).animate(curved),
      child: child,
    ),
  );
}
