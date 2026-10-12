import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/localization/app_localizations.dart';
import '../platform/platform_bootstrap.dart';
import '../platform/high_refresh_rate.dart';
import '../core/router/app_router.dart';
import '../state/app_providers.dart';
import '../core/theme/almanac_theme.dart';

/// Корневая обвязка приложения: локализация, навигация и тема профиля.
class AlmanacApp extends ConsumerWidget {
  const AlmanacApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final locale = ref.watch(appLocaleProvider);

    return MaterialApp.router(
      title: 'Almanac',
      debugShowCheckedModeBanner: false,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: buildAlmanacTheme(
        seedColor: Colors.blue,
        brightness: Brightness.light,
      ),
      darkTheme: buildAlmanacTheme(
        seedColor: Colors.blue,
        brightness: Brightness.dark,
      ),
      themeMode: ThemeMode.system,
      scrollBehavior: const AlmanacScrollBehavior(),
      routerConfig: router,
      builder: (context, child) {
        return DeepLinkListener(
          child: PlatformBootstrap(child: AlmanacProfileTheme(child: child)),
        );
      },
    );
  }
}

/// Тема активного профиля без пересборки [MaterialApp] (сохраняет overlay).
class AlmanacProfileTheme extends ConsumerWidget {
  const AlmanacProfileTheme({super.key, this.child});

  final Widget? child;

  static Brightness _brightnessFor(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return Brightness.light;
      case ThemeMode.dark:
        return Brightness.dark;
      case ThemeMode.system:
        return WidgetsBinding.instance.platformDispatcher.platformBrightness;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(activeProfileNotifierProvider);
    final brightness = _brightnessFor(profile.themeMode);

    final overlay = brightness == Brightness.dark
        ? SystemUiOverlayStyle.light.copyWith(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarContrastEnforced: false,
          )
        : SystemUiOverlayStyle.dark.copyWith(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarContrastEnforced: false,
          );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlay,
      child: Theme(
        data: buildAlmanacTheme(
          seedColor: profile.seedColor,
          brightness: brightness,
          accentColor: profile.accentColor,
        ),
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}
