import 'package:flutter/material.dart';

import '../theme/almanac_tokens.dart';
import 'almanac_scroll.dart';

/// Форма с фиксированными кнопками для [showAlmanacSheet].
///
/// Оболочка панели поднимает [actions] вниз, а [body] оставляет в прокрутке.
class AlmanacFormPanel extends StatelessWidget {
  const AlmanacFormPanel({
    super.key,
    required this.body,
    required this.actions,
  });

  final Widget body;
  final Widget actions;

  @override
  Widget build(BuildContext context) {
    final scope = AlmanacSheetFormScope.maybeOf(context);
    if (scope == null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [body, actions],
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scope.actions.value != actions) {
        scope.actions.value = actions;
      }
    });

    return AnimatedBuilder(
      animation: scope.actions,
      builder: (context, _) {
        if (scope.actions.value != null) return body;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [body, actions],
        );
      },
    );
  }
}

/// Слот кнопок формы в оболочке панели.
class AlmanacSheetFormScope extends InheritedWidget {
  const AlmanacSheetFormScope({
    super.key,
    required this.actions,
    required super.child,
  });

  final ValueNotifier<Widget?> actions;

  static AlmanacSheetFormScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AlmanacSheetFormScope>();
  }

  @override
  bool updateShouldNotify(AlmanacSheetFormScope oldWidget) {
    return actions != oldWidget.actions;
  }
}

/// Прокручиваемое тело панели; кнопки [AlmanacFormPanel] закреплены снизу.
class AlmanacSheetFormHost extends StatefulWidget {
  const AlmanacSheetFormHost({
    super.key,
    required this.child,
    required this.padding,
    required this.onScrollNotification,
    this.shrinkWrap = false,
  });

  final Widget child;
  final EdgeInsets padding;
  final bool Function(ScrollNotification notification) onScrollNotification;
  final bool shrinkWrap;

  @override
  State<AlmanacSheetFormHost> createState() => _AlmanacSheetFormHostState();
}

class _AlmanacSheetFormHostState extends State<AlmanacSheetFormHost> {
  final _actions = ValueNotifier<Widget?>(null);

  @override
  void dispose() {
    _actions.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scroller = NotificationListener<ScrollNotification>(
      onNotification: widget.onScrollNotification,
      child: widget.shrinkWrap
          ? ListView(
              shrinkWrap: true,
              padding: widget.padding,
              keyboardDismissBehavior: AlmanacScroll.keyboardDismiss,
              cacheExtent: AlmanacScroll.listCacheExtent,
              children: [widget.child],
            )
          : SingleChildScrollView(
              keyboardDismissBehavior: AlmanacScroll.keyboardDismiss,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: widget.padding,
              child: widget.child,
            ),
    );

    return AlmanacSheetFormScope(
      actions: _actions,
      child: AnimatedBuilder(
        animation: _actions,
        builder: (context, _) {
          final footer = _actions.value;
          if (footer == null) return scroller;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: scroller),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AlmanacSpacing.md,
                  0,
                  AlmanacSpacing.md,
                  AlmanacSpacing.sm,
                ),
                child: footer,
              ),
            ],
          );
        },
      ),
    );
  }
}
