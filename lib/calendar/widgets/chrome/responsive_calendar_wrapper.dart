import 'package:flutter/material.dart';
import '../../../core/theme/almanac_tokens.dart';
import '../../../core/ui/adaptive.dart';

/// Адаптивная обёртка: центрирует интерфейс и задаёт отступы по брейкпоинтам.
class ResponsiveCalendarWrapper extends StatelessWidget {
  const ResponsiveCalendarWrapper({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: AlmanacSizes.maxContentWidth),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final padding = context.isMobileWidth
                ? const EdgeInsets.symmetric(
                    horizontal: AlmanacSpacing.sm,
                    vertical: AlmanacSpacing.sm,
                  )
                : context.screenPadding(constraints.maxWidth);
            return Padding(padding: padding, child: child);
          },
        ),
      ),
    );
  }
}
