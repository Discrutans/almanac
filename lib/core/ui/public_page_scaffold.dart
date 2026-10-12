import 'package:flutter/material.dart';
import '../localization/app_localizations.dart';
import '../theme/almanac_tokens.dart';
import 'adaptive.dart';

/// Адаптивная оболочка для публичных страниц (/book, /plan).
class PublicPageScaffold extends StatelessWidget {
  const PublicPageScaffold({
    super.key,
    required this.title,
    required this.child,
    this.actions,
  });

  final String title;
  final Widget child;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: actions,
        toolbarHeight: context.compactToolbarHeight,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AlmanacSizes.maxContentWidth,
                ),
                child: Padding(
                  padding: context.isMobileWidth
                      ? const EdgeInsets.symmetric(
                          horizontal: AlmanacSpacing.sm,
                          vertical: AlmanacSpacing.sm,
                        )
                      : context.screenPadding(constraints.maxWidth),
                  child: child,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Пустое состояние для публичных страниц.
class PublicPageEmptyState extends StatelessWidget {
  const PublicPageEmptyState({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PublicPageScaffold(
      title: l10n.appName,
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: context.almanacColors.muted),
        ),
      ),
    );
  }
}
