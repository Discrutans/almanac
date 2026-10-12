import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../localization/app_localizations.dart';
import '../theme/almanac_motion.dart';
import '../theme/almanac_tokens.dart';
import 'adaptive.dart';
import 'almanac_buttons.dart';
import 'almanac_form_panel.dart';
import 'almanac_panel_layout.dart';

export 'almanac_panel_layout.dart';

/// Позиция модальной панели Almanac.
enum AlmanacSheetPlacement {
  /// Панель сверху: ручка внизу, закрытие свайпом вверх (наверх).
  top,

  /// Панель снизу: ручка сверху (над контентом), закрытие движением вниз.
  bottom,
}

/// Направление закрытия панели перетаскиванием.
enum _AlmanacPanelDismissAxis {
  /// Bottom sheet: тянем вниз.
  down,

  /// Top sheet: тянем вверх.
  up,
}

/// Единая точка входа для модальных панелей приложения.
Future<T?> showAlmanacSheet<T>({
  required BuildContext context,
  AlmanacSheetPlacement placement = AlmanacSheetPlacement.bottom,
  String? title,
  Widget? child,
  WidgetBuilder? builder,
  Widget? footer,
  bool barrierDismissible = true,
  bool enableSwipeUpToClose = true,
  double? maxHeightFactor,
  bool hideTitle = false,
  bool useSafeArea = true,
  AlmanacPanelSize size = AlmanacPanelSize.expanded,
  bool compactWidth = false,
}) {
  final compactBottom =
      placement == AlmanacSheetPlacement.bottom &&
      title == null &&
      child == null;
  if (compactBottom) {
    assert(builder != null, 'builder is required for compact bottom sheets');
    return _showAlmanacBottomSheet<T>(
      context: context,
      builder: builder!,
      barrierDismissible: barrierDismissible,
    );
  }

  assert(title != null, 'title is required');
  assert(child != null || builder != null, 'child or builder is required');
  return _showAlmanacAnchoredSheet<T>(
    context: context,
    placement: placement,
    title: title!,
    child: child ?? builder!(context),
    footer: footer,
    barrierDismissible: barrierDismissible,
    enableDragToClose: enableSwipeUpToClose,
    maxHeightFactor: maxHeightFactor,
    hideTitle: hideTitle,
    size: size,
    compactWidth: compactWidth,
    useSafeArea: useSafeArea,
  );
}

Future<T?> _showAlmanacAnchoredSheet<T>({
  required BuildContext context,
  required AlmanacSheetPlacement placement,
  required String title,
  required Widget child,
  Widget? footer,
  bool barrierDismissible = true,
  bool enableDragToClose = true,
  double? maxHeightFactor,
  bool hideTitle = false,
  AlmanacPanelSize size = AlmanacPanelSize.expanded,
  bool compactWidth = false,
  bool useSafeArea = true,
}) {
  final isTop = placement == AlmanacSheetPlacement.top;
  final screenWidth = MediaQuery.sizeOf(context).width;
  final heightFactor =
      maxHeightFactor ??
      AlmanacPanelLayout.maxHeightFactor(screenWidth, size: size);

  final outerPadding = AlmanacPanelLayout.outerPadding(
    screenWidth: screenWidth,
    isBottom: !isTop,
    size: size,
  );

  final maxWidth = AlmanacPanelLayout.maxWidth(
    screenWidth,
    compact: compactWidth,
    size: size,
  );

  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black54,
    transitionDuration: AlmanacDurations.smooth,
    pageBuilder: (context, animation, secondaryAnimation) {
      final mq = MediaQuery.of(context);
      final fillBehindSystemBars =
          size == AlmanacPanelSize.cover && !useSafeArea;
      final systemTop = AlmanacSystemInsets.top(mq);
      final systemBottom = AlmanacSystemInsets.bottom(mq);
      final systemLeft = AlmanacSystemInsets.left(mq);
      final systemRight = AlmanacSystemInsets.right(mq);
      final paddedOuter = fillBehindSystemBars
          ? outerPadding
          : EdgeInsets.fromLTRB(
              math.max(outerPadding.left, systemLeft),
              isTop ? math.max(outerPadding.top, systemTop) : outerPadding.top,
              math.max(outerPadding.right, systemRight),
              math.max(outerPadding.bottom, systemBottom),
            );

      return Align(
        alignment: isTop ? Alignment.topCenter : Alignment.bottomCenter,
        child: Padding(
          padding: isTop
              ? paddedOuter
              : EdgeInsets.fromLTRB(
                  paddedOuter.left,
                  0,
                  paddedOuter.right,
                  paddedOuter.bottom,
                ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: maxWidth,
              minWidth: size == AlmanacPanelSize.cover ? maxWidth : 0,
              minHeight: size == AlmanacPanelSize.cover ? double.infinity : 0,
            ),
            child: Material(
              color: Colors.transparent,
              child: _AlmanacTopPanelShell(
                placement: placement,
                title: title,
                footer: footer,
                maxHeightFactor: heightFactor,
                enableSwipeUpToClose: enableDragToClose,
                hideTitle: hideTitle,
                size: size,
                chromeInset: fillBehindSystemBars
                    ? EdgeInsets.fromLTRB(
                        systemLeft,
                        systemTop,
                        systemRight,
                        systemBottom,
                      )
                    : EdgeInsets.zero,
                onClose: () => Navigator.of(context).pop(),
                child: child,
              ),
            ),
          ),
        ),
      );
    },
    transitionBuilder: isTop
        ? almanacTopPanelTransition
        : almanacBottomPanelTransition,
  );
}

Future<bool?> showAlmanacConfirm({
  required BuildContext context,
  required String title,
  required String message,
  required String confirmLabel,
  required String cancelLabel,
  bool destructive = false,
}) {
  final colorScheme = Theme.of(context).colorScheme;

  return showAlmanacSheet<bool>(
    context: context,
    placement: AlmanacSheetPlacement.bottom,
    title: title,
    size: AlmanacPanelSize.hug,
    compactWidth: true,
    child: Text(message),
    footer: Builder(
      builder: (dialogContext) {
        return AlmanacDialogActions(
          children: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(cancelLabel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: destructive
                  ? FilledButton.styleFrom(
                      backgroundColor: colorScheme.error,
                      foregroundColor: colorScheme.onError,
                    )
                  : null,
              child: Text(confirmLabel),
            ),
          ],
        );
      },
    ),
  );
}

/// Короткий ввод текста в той же оболочке, что и остальные панели.
Future<String?> showAlmanacPrompt({
  required BuildContext context,
  required String title,
  required String label,
  required String confirmLabel,
  required String cancelLabel,
  String initialValue = '',
  String? helperText,
}) {
  return showAlmanacSheet<String>(
    context: context,
    placement: AlmanacSheetPlacement.bottom,
    title: title,
    size: AlmanacPanelSize.hug,
    compactWidth: true,
    child: _AlmanacPromptForm(
      label: label,
      initialValue: initialValue,
      helperText: helperText,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
    ),
  );
}

/// Owns the text controller for the life of the route, not the caller future.
class _AlmanacPromptForm extends StatefulWidget {
  const _AlmanacPromptForm({
    required this.label,
    required this.initialValue,
    required this.confirmLabel,
    required this.cancelLabel,
    this.helperText,
  });

  final String label;
  final String initialValue;
  final String confirmLabel;
  final String cancelLabel;
  final String? helperText;

  @override
  State<_AlmanacPromptForm> createState() => _AlmanacPromptFormState();
}

class _AlmanacPromptFormState extends State<_AlmanacPromptForm> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.helperText != null) ...[
          Text(
            widget.helperText!,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AlmanacSpacing.sm),
        ],
        TextField(
          controller: _controller,
          autofocus: true,
          decoration: InputDecoration(labelText: widget.label),
          onSubmitted: (value) => Navigator.of(context).pop(value),
        ),
        const SizedBox(height: AlmanacSpacing.md),
        AlmanacDialogActions(
          children: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(widget.cancelLabel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(_controller.text),
              child: Text(widget.confirmLabel),
            ),
          ],
        ),
      ],
    );
  }
}

/// Общая логика закрытия панели перетаскиванием (вниз или вверх).
mixin _AlmanacPanelDismissController<T extends StatefulWidget>
    on State<T>, SingleTickerProviderStateMixin<T> {
  static const dismissDistance = 96.0;
  static const dismissVelocity = 900.0;
  static const maxDragOffset = 240.0;

  VoidCallback get onPanelDismiss;
  bool get panelDismissEnabled => true;
  _AlmanacPanelDismissAxis get panelDismissAxis =>
      _AlmanacPanelDismissAxis.down;

  double _dragOffset = 0;
  double _lastDragVelocity = 0;
  double _scrollDismissPull = 0;
  AnimationController? _snapController;
  Animation<double>? _snapAnimation;
  late final ValueNotifier<double> _dragOffsetListenable;

  double get dragOffset => _dragOffsetListenable.value;

  double get _dismissSign =>
      panelDismissAxis == _AlmanacPanelDismissAxis.up ? -1 : 1;

  void initPanelDismissController() {
    _dragOffsetListenable = ValueNotifier<double>(0);
    _snapController = AnimationController(
      vsync: this,
      duration: AlmanacDurations.smooth,
    );
  }

  void disposePanelDismissController() {
    _snapController?.dispose();
    _dragOffsetListenable.dispose();
  }

  void _setDragOffset(double value) {
    final next = value.clamp(0.0, maxDragOffset);
    if (_dragOffsetListenable.value == next) return;
    _dragOffset = next;
    _dragOffsetListenable.value = next;
  }

  void handlePanelDragUpdate(DragUpdateDetails details) {
    if (!panelDismissEnabled) return;
    _snapController?.stop();
    final dy = details.primaryDelta ?? details.delta.dy;
    final dismissDelta = dy * _dismissSign;
    if (dismissDelta <= 0 && _dragOffset <= 0) return;
    _lastDragVelocity = dismissDelta;
    _setDragOffset(_dragOffset + dismissDelta);
  }

  void handlePanelDragEnd(DragEndDetails details) {
    if (!panelDismissEnabled) return;
    final rawVelocity = details.primaryVelocity ?? _lastDragVelocity * 1000;
    _lastDragVelocity = 0;
    final alongDismiss = rawVelocity * _dismissSign;
    if (_dragOffset >= dismissDistance || alongDismiss >= dismissVelocity) {
      onPanelDismiss();
      return;
    }
    _animateDragOffsetTo(0);
  }

  void _animateDragOffsetTo(double target) {
    final controller = _snapController;
    if (controller == null) {
      _setDragOffset(target);
      return;
    }

    controller.stop();
    final animation = Tween<double>(
      begin: _dragOffset,
      end: target,
    ).animate(CurvedAnimation(parent: controller, curve: AlmanacCurves.enter));
    _snapAnimation?.removeListener(_onSnapTick);
    _snapAnimation = animation;
    animation.addListener(_onSnapTick);
    controller.forward(from: 0).whenComplete(() {
      animation.removeListener(_onSnapTick);
      if (!mounted) return;
      _setDragOffset(target);
    });
  }

  void _onSnapTick() {
    final value = _snapAnimation?.value;
    if (value == null) return;
    _setDragOffset(value);
  }

  bool _isAtDismissScrollEdge(ScrollMetrics metrics) {
    switch (panelDismissAxis) {
      case _AlmanacPanelDismissAxis.down:
        return metrics.pixels <= metrics.minScrollExtent + 1;
      case _AlmanacPanelDismissAxis.up:
        return metrics.pixels >= metrics.maxScrollExtent - 1;
    }
  }

  bool handlePanelScrollDismissNotification(ScrollNotification notification) {
    if (!panelDismissEnabled) return false;

    if (notification is ScrollStartNotification) {
      _scrollDismissPull = 0;
      _snapController?.stop();
      return false;
    }

    if (notification is ScrollUpdateNotification) {
      final drag = notification.dragDetails;
      if (drag == null) return false;

      final dismissDelta = drag.delta.dy * _dismissSign;
      if (_isAtDismissScrollEdge(notification.metrics) && dismissDelta > 0) {
        _scrollDismissPull += dismissDelta;
        _setDragOffset(_scrollDismissPull);
        if (_scrollDismissPull >= dismissDistance) {
          onPanelDismiss();
        }
      } else if (_scrollDismissPull > 0) {
        _scrollDismissPull = (_scrollDismissPull + dismissDelta).clamp(
          0,
          maxDragOffset,
        );
        _setDragOffset(_scrollDismissPull);
      }
      return false;
    }

    if (notification is ScrollEndNotification) {
      if (_scrollDismissPull >= dismissDistance) {
        _scrollDismissPull = 0;
        return false;
      }
      if (_scrollDismissPull > 0) {
        _scrollDismissPull = 0;
        _animateDragOffsetTo(0);
      }
    }

    return false;
  }

  Widget buildPanelDismissDragZone({
    required EdgeInsets padding,
    required Widget child,
    VoidCallback? onTap,
  }) {
    if (!panelDismissEnabled) {
      return Padding(padding: padding, child: child);
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragUpdate: handlePanelDragUpdate,
      onVerticalDragEnd: handlePanelDragEnd,
      onTap: onTap,
      child: Padding(padding: padding, child: child),
    );
  }

  /// Сдвиг панели без setState: контент не пересобирается на 120/144 Гц.
  Widget buildPanelDismissMotion({required Widget child}) {
    if (!panelDismissEnabled) return child;
    return ValueListenableBuilder<double>(
      valueListenable: _dragOffsetListenable,
      builder: (context, offset, paintedChild) {
        return Transform.translate(
          offset: Offset(0, offset * _dismissSign),
          filterQuality: FilterQuality.none,
          child: paintedChild,
        );
      },
      child: child,
    );
  }
}

class _AlmanacTopPanelShell extends StatefulWidget {
  const _AlmanacTopPanelShell({
    required this.title,
    required this.child,
    required this.onClose,
    required this.maxHeightFactor,
    this.placement = AlmanacSheetPlacement.top,
    this.footer,
    this.enableSwipeUpToClose = true,
    this.hideTitle = false,
    this.size = AlmanacPanelSize.expanded,
    this.chromeInset = EdgeInsets.zero,
  });

  final AlmanacSheetPlacement placement;
  final String title;
  final Widget child;
  final Widget? footer;
  final VoidCallback onClose;
  final double maxHeightFactor;
  final bool enableSwipeUpToClose;
  final bool hideTitle;
  final AlmanacPanelSize size;
  final EdgeInsets chromeInset;

  @override
  State<_AlmanacTopPanelShell> createState() => _AlmanacTopPanelShellState();
}

class _AlmanacTopPanelShellState extends State<_AlmanacTopPanelShell>
    with
        SingleTickerProviderStateMixin<_AlmanacTopPanelShell>,
        _AlmanacPanelDismissController<_AlmanacTopPanelShell> {
  static const _handleZonePaddingTop = EdgeInsets.fromLTRB(
    AlmanacSpacing.md,
    AlmanacSpacing.sm,
    AlmanacSpacing.md,
    AlmanacSpacing.xxs,
  );
  static const _handleZonePaddingBottom = EdgeInsets.fromLTRB(
    AlmanacSpacing.md,
    AlmanacSpacing.xxs,
    AlmanacSpacing.md,
    AlmanacSpacing.sm,
  );

  bool get _isTop => widget.placement == AlmanacSheetPlacement.top;

  @override
  VoidCallback get onPanelDismiss => widget.onClose;

  @override
  bool get panelDismissEnabled => widget.enableSwipeUpToClose;

  @override
  _AlmanacPanelDismissAxis get panelDismissAxis =>
      _isTop ? _AlmanacPanelDismissAxis.up : _AlmanacPanelDismissAxis.down;

  @override
  void initState() {
    super.initState();
    initPanelDismissController();
  }

  @override
  void dispose() {
    disposePanelDismissController();
    super.dispose();
  }

  Widget _buildHandleDragZone() {
    return buildPanelDismissDragZone(
      padding: _isTop ? _handleZonePaddingBottom : _handleZonePaddingTop,
      onTap: widget.onClose,
      child: AlmanacPanelDragHandle(
        onTap: widget.enableSwipeUpToClose ? null : widget.onClose,
      ),
    );
  }

  IconData get _closeIcon => _isTop
      ? Icons.keyboard_arrow_up_rounded
      : Icons.keyboard_arrow_down_rounded;

  Widget _buildCompactCloseBar() {
    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AlmanacSpacing.xs,
        0,
        AlmanacSpacing.xxs,
        AlmanacSpacing.xxs,
      ),
      child: Align(
        alignment: Alignment.centerRight,
        child: AlmanacIconButton(
          icon: _closeIcon,
          tooltip: l10n.closeTooltip,
          onPressed: widget.onClose,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final mediaQuery = MediaQuery.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final cover = widget.size == AlmanacPanelSize.cover;
        final maxFromParent = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : mediaQuery.size.height;
        final maxPanelHeight = cover
            ? maxFromParent
            : maxFromParent * widget.maxHeightFactor;
        const scrollBottomPadding = AlmanacSpacing.md;

        final handle = widget.enableSwipeUpToClose
            ? _buildHandleDragZone()
            : null;
        final hug =
            widget.size == AlmanacPanelSize.hug &&
            widget.child is! AlmanacFormPanel;
        final shape = RoundedRectangleBorder(
          borderRadius: AlmanacPanelLayout.borderRadius(
            isBottom: !_isTop,
            size: widget.size,
          ),
        );

        Widget column = Column(
          mainAxisSize: hug ? MainAxisSize.min : MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!_isTop && handle != null) handle,
            if (!widget.hideTitle) ...[
              _AlmanacTopBar(
                title: widget.title,
                onClose: widget.onClose,
                closeIcon: _closeIcon,
              ),
              const Divider(height: 1),
            ] else if (_isTop)
              _buildCompactCloseBar(),
            hug
                ? Flexible(
                    fit: FlexFit.loose,
                    child: _buildScrollableContent(
                      scrollBottomPadding,
                      shrinkWrap: true,
                    ),
                  )
                : Expanded(child: _buildScrollableContent(scrollBottomPadding)),
            if (widget.footer != null) ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(AlmanacSpacing.sm),
                child: widget.footer,
              ),
            ],
            if (_isTop && handle != null) handle,
          ],
        );

        if (widget.chromeInset != EdgeInsets.zero) {
          column = Padding(padding: widget.chromeInset, child: column);
        }

        return buildPanelDismissMotion(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: maxPanelHeight,
              minHeight: cover ? maxPanelHeight : 0,
            ),
            child: Material(
              color: colorScheme.surfaceContainerLow,
              elevation: AlmanacElevation.raised,
              shadowColor: colorScheme.shadow,
              clipBehavior: Clip.hardEdge,
              shape: shape,
              child: column,
            ),
          ),
        );
      },
    );
  }

  Widget _buildScrollableContent(
    double scrollBottomPadding, {
    bool shrinkWrap = false,
  }) {
    final scrollPadding = EdgeInsets.fromLTRB(
      AlmanacSpacing.md,
      widget.hideTitle ? AlmanacSpacing.xs : AlmanacSpacing.md,
      AlmanacSpacing.md,
      scrollBottomPadding,
    );

    return AlmanacSheetFormHost(
      padding: scrollPadding,
      shrinkWrap: shrinkWrap,
      onScrollNotification: handlePanelScrollDismissNotification,
      child: RepaintBoundary(child: widget.child),
    );
  }
}

/// Modal bottom sheet: ручка сверху над контентом, закрытие движением вниз.
Future<T?> _showAlmanacBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) {
  final mediaQuery = MediaQuery.of(context);

  final screenWidth = mediaQuery.size.width;
  final outerPadding = AlmanacPanelLayout.outerPadding(
    screenWidth: screenWidth,
    isBottom: true,
  );

  final maxWidth = AlmanacPanelLayout.maxWidth(screenWidth);

  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black54,
    transitionDuration: AlmanacDurations.smooth,
    pageBuilder: (context, animation, secondaryAnimation) {
      final mq = MediaQuery.of(context);
      final systemTop = AlmanacSystemInsets.top(mq);
      final systemBottom = AlmanacSystemInsets.bottom(mq);
      final systemLeft = AlmanacSystemInsets.left(mq);
      final systemRight = AlmanacSystemInsets.right(mq);
      final availableHeight = math.max(
        0.0,
        mq.size.height - systemTop - systemBottom,
      );
      final maxHeight =
          availableHeight *
          AlmanacPanelLayout.maxHeightFactor(
            screenWidth,
            size: AlmanacPanelSize.hug,
          );

      return Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            math.max(outerPadding.left, systemLeft),
            0,
            math.max(outerPadding.right, systemRight),
            math.max(outerPadding.bottom, systemBottom),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: maxWidth,
              maxHeight: maxHeight,
            ),
            child: _AlmanacBottomSheetShell(
              onDismiss: () => Navigator.of(context).pop(),
              child: builder(context),
            ),
          ),
        ),
      );
    },
    transitionBuilder: almanacBottomPanelTransition,
  );
}

class _AlmanacBottomSheetShell extends StatefulWidget {
  const _AlmanacBottomSheetShell({
    required this.onDismiss,
    required this.child,
  });

  final VoidCallback onDismiss;
  final Widget child;

  @override
  State<_AlmanacBottomSheetShell> createState() =>
      _AlmanacBottomSheetShellState();
}

class _AlmanacBottomSheetShellState extends State<_AlmanacBottomSheetShell>
    with
        SingleTickerProviderStateMixin<_AlmanacBottomSheetShell>,
        _AlmanacPanelDismissController<_AlmanacBottomSheetShell> {
  static const _handleZonePaddingTop = EdgeInsets.fromLTRB(
    AlmanacSpacing.md,
    AlmanacSpacing.sm,
    AlmanacSpacing.md,
    AlmanacSpacing.xxs,
  );

  @override
  VoidCallback get onPanelDismiss => widget.onDismiss;

  @override
  _AlmanacPanelDismissAxis get panelDismissAxis =>
      _AlmanacPanelDismissAxis.down;

  @override
  void initState() {
    super.initState();
    initPanelDismissController();
  }

  @override
  void dispose() {
    disposePanelDismissController();
    super.dispose();
  }

  Widget _buildTopHandleDragZone() {
    return buildPanelDismissDragZone(
      padding: _handleZonePaddingTop,
      onTap: widget.onDismiss,
      child: const AlmanacPanelDragHandle(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return buildPanelDismissMotion(
      child: Material(
        color: colorScheme.surfaceContainerLow,
        elevation: AlmanacElevation.raised,
        shadowColor: colorScheme.shadow,
        clipBehavior: Clip.hardEdge,
        shape: const RoundedRectangleBorder(
          borderRadius: AlmanacRadius.sheetTop,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            const handleExtent =
                AlmanacPanelDragHandle.height +
                AlmanacSpacing.sm +
                AlmanacSpacing.xxs;
            final contentMaxHeight = (constraints.maxHeight - handleExtent)
                .clamp(0.0, double.infinity);

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildTopHandleDragZone(),
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: contentMaxHeight),
                  child: NotificationListener<ScrollNotification>(
                    onNotification: handlePanelScrollDismissNotification,
                    child: RepaintBoundary(child: widget.child),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Ручка закрытия: снизу у top-sheet (свайп вверх) или сверху у bottom-sheet (свайп вниз).
class AlmanacPanelDragHandle extends StatelessWidget {
  const AlmanacPanelDragHandle({super.key, this.onTap});

  static const double height = 28;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final handle = SizedBox(
      width: double.infinity,
      height: height,
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.outlineVariant.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(999),
          ),
          child: const SizedBox(width: 36, height: 4),
        ),
      ),
    );

    return Semantics(
      button: onTap != null,
      label: AppLocalizations.of(context).closeTooltip,
      child: onTap == null
          ? handle
          : Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(999),
                child: handle,
              ),
            ),
    );
  }
}

class _AlmanacTopBar extends StatelessWidget {
  const _AlmanacTopBar({
    required this.title,
    required this.onClose,
    this.closeIcon = Icons.keyboard_arrow_up_rounded,
  });

  final String title;
  final VoidCallback onClose;
  final IconData closeIcon;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return SizedBox(
      height: AlmanacSizes.topBarHeight,
      child: Row(
        children: [
          const SizedBox(width: AlmanacSizes.navButtonSize),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          AlmanacIconButton(
            icon: closeIcon,
            tooltip: l10n.closeTooltip,
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}
