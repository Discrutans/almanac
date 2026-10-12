import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../localization/app_localizations.dart';
import '../theme/almanac_tokens.dart';

/// Глобальный перехват сбоев UI и платформы: экран ошибки вместо аварийного закрытия.
void installAlmanacErrorGuards() {
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Almanac platform error: $error\n$stack');
    return true;
  };
  installAlmanacErrorWidget();
}

/// Подмена [ErrorWidget] без перехвата [FlutterError.onError] (безопасно для тестов).
void installAlmanacErrorWidget() {
  ErrorWidget.builder = (details) => AlmanacErrorSurface(details: details);
}

/// Замена жёлто-чёрного [ErrorWidget]: сообщение без падения приложения.
class AlmanacErrorSurface extends StatelessWidget {
  const AlmanacErrorSurface({super.key, required this.details});

  final FlutterErrorDetails details;

  @override
  Widget build(BuildContext context) {
    final locale =
        Localizations.maybeLocaleOf(context) ?? AppLocalizations.fallback;
    final l10n = AppLocalizations.forLocale(locale);
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: scheme.surface,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AlmanacSpacing.md),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline_rounded, size: 40, color: scheme.error),
              AlmanacGap.sm,
              Text(
                l10n.unexpectedUiError,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              if (kDebugMode) ...[
                AlmanacGap.sm,
                Text(
                  details.exceptionAsString(),
                  textAlign: TextAlign.center,
                  maxLines: 6,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
