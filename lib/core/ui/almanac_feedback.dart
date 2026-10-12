import 'package:flutter/material.dart';
import '../theme/almanac_tokens.dart';

/// Единые уведомления и безопасный запуск асинхронных операций в UI.
///
/// Сводит SnackBar и обработку ошибок в одно место, чтобы экраны
/// не дублировали один и тот же код.
abstract final class AlmanacFeedback {
  static const Duration _successDuration = Duration(seconds: 2);
  static const Duration _errorDuration = Duration(milliseconds: 3500);
  static const Duration _undoDuration = Duration(seconds: 4);

  /// Показывает ошибку внизу экрана.
  static void showError(BuildContext context, String message) {
    if (!context.mounted) return;
    _showSnack(
      context,
      message: message,
      background: Theme.of(context).colorScheme.errorContainer,
      foreground: Theme.of(context).colorScheme.onErrorContainer,
      icon: Icons.error_outline,
      duration: _errorDuration,
    );
  }

  /// Показывает успешное действие.
  static void showSuccess(BuildContext context, String message) {
    if (!context.mounted) return;
    final scheme = Theme.of(context).colorScheme;
    _showSnack(
      context,
      message: message,
      background: scheme.primaryContainer,
      foreground: scheme.onPrimaryContainer,
      icon: Icons.check_circle_outline,
      duration: _successDuration,
    );
  }

  /// Нейтральное короткое сообщение (копирование и т.п.).
  static void showInfo(BuildContext context, String message) {
    if (!context.mounted) return;
    final scheme = Theme.of(context).colorScheme;
    _showSnack(
      context,
      message: message,
      background: scheme.surfaceContainerHighest,
      foreground: scheme.onSurface,
      icon: Icons.info_outline,
      duration: _successDuration,
    );
  }

  /// Выполняет [action] и перехватывает исключения.
  ///
  /// Возвращает результат или `null`, если произошла ошибка.
  static Future<T?> runGuarded<T>(
    BuildContext context,
    Future<T> Function() action, {
    String errorPrefix = 'Operation failed',
  }) async {
    try {
      return await action();
    } catch (error, stackTrace) {
      debugPrint('$errorPrefix: $error\n$stackTrace');
      if (context.mounted) {
        showError(context, '$errorPrefix: $error');
      }
      return null;
    }
  }

  static void _showSnack(
    BuildContext context, {
    required String message,
    required Color background,
    required Color foreground,
    required IconData icon,
    required Duration duration,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= 720;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: duration,
          elevation: AlmanacElevation.raised,
          width: isWide ? 420 : null,
          margin: isWide
              ? null
              : const EdgeInsets.fromLTRB(
                  AlmanacSpacing.md,
                  AlmanacSpacing.sm,
                  AlmanacSpacing.md,
                  AlmanacSpacing.md,
                ),
          padding: const EdgeInsets.symmetric(
            horizontal: AlmanacSpacing.sm,
            vertical: AlmanacSpacing.xs,
          ),
          shape: const RoundedRectangleBorder(
            borderRadius: AlmanacRadius.control,
          ),
          backgroundColor: background,
          content: Row(
            children: [
              Icon(icon, color: foreground, size: 18),
              const SizedBox(width: AlmanacSpacing.xs),
              Expanded(
                child: Text(
                  message,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: foreground,
                    height: 1.25,
                  ),
                ),
              ),
            ],
          ),
          action: actionLabel == null || onAction == null
              ? null
              : SnackBarAction(
                  label: actionLabel,
                  textColor: foreground,
                  onPressed: onAction,
                ),
        ),
      );
  }

  /// Успех с действием «Отменить».
  static void showUndo(
    BuildContext context, {
    required String message,
    required String undoLabel,
    required VoidCallback onUndo,
  }) {
    if (!context.mounted) return;
    final scheme = Theme.of(context).colorScheme;
    _showSnack(
      context,
      message: message,
      background: scheme.primaryContainer,
      foreground: scheme.onPrimaryContainer,
      icon: Icons.check_circle_outline,
      duration: _undoDuration,
      actionLabel: undoLabel,
      onAction: onUndo,
    );
  }
}

/// Компактный блок ошибки с кнопкой повтора.
class AlmanacErrorPanel extends StatelessWidget {
  const AlmanacErrorPanel({
    super.key,
    required this.message,
    required this.onRetry,
    this.retryLabel = 'Retry',
  });

  final String message;
  final VoidCallback onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AlmanacSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_outlined, size: 40, color: scheme.error),
            const SizedBox(height: AlmanacSpacing.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: AlmanacSpacing.md),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(retryLabel),
            ),
          ],
        ),
      ),
    );
  }
}

/// Полупрозрачный оверлей «идёт загрузка» поверх содержимого.
class AlmanacLoadingOverlay extends StatelessWidget {
  const AlmanacLoadingOverlay({
    super.key,
    required this.visible,
    required this.child,
    this.message = 'Loading…',
  });

  final bool visible;
  final Widget child;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (visible)
          Positioned.fill(
            child: ColoredBox(
              color: Colors.black.withValues(alpha: 0.12),
              child: Center(
                child: Material(
                  elevation: AlmanacElevation.raised,
                  borderRadius: AlmanacRadius.card,
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AlmanacSpacing.lg,
                      vertical: AlmanacSpacing.md,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: AlmanacSpacing.sm),
                        Text(message),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Компактная подсказка со скруглёнными углами (список, agenda, лист дня).
class AlmanacHintBanner extends StatelessWidget {
  const AlmanacHintBanner({
    super.key,
    required this.icon,
    required this.message,
    required this.dismissLabel,
    required this.onDismiss,
  });

  final IconData icon;
  final String message;
  final String dismissLabel;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.62),
      elevation: 0,
      borderRadius: AlmanacRadius.card,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AlmanacSpacing.sm,
          vertical: AlmanacSpacing.xs,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: scheme.onSurfaceVariant),
            const SizedBox(width: AlmanacSpacing.sm),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            TextButton(
              onPressed: onDismiss,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(
                  horizontal: AlmanacSpacing.xs,
                ),
              ),
              child: Text(dismissLabel),
            ),
          ],
        ),
      ),
    );
  }
}
