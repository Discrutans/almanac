import 'package:flutter/widgets.dart';

import 'week_move_controller.dart';

/// Provides the stable [WeekMoveController] for week grid move gestures.
class WeekMoveScope extends InheritedWidget {
  const WeekMoveScope({
    super.key,
    required this.controller,
    required super.child,
  });

  final WeekMoveController controller;

  static WeekMoveController? maybeOf(BuildContext context) {
    return context
        .getInheritedWidgetOfExactType<WeekMoveScope>()
        ?.controller;
  }

  @override
  bool updateShouldNotify(WeekMoveScope oldWidget) {
    return !identical(controller, oldWidget.controller);
  }
}
