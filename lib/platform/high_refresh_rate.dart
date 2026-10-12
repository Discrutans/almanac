import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/ui/almanac_scroll.dart';

export '../core/ui/almanac_scroll.dart' show AlmanacScrollBehavior;

/// Включает максимальную частоту кадров и жесты под 90/120/144 Гц+.
abstract final class HighRefreshRate {
  static const _channel = MethodChannel(
    'com.example.almanac/high_refresh_rate',
  );

  static Future<void> configure() async {
    _tuneGestures();
    _tuneRenderingCaches();

    if (kIsWeb) return;

    await _enableNative();
  }

  /// Ресемплинг указателя к vsync убирает дрожание скролла на 120/144 Гц.
  static void _tuneGestures() {
    GestureBinding.instance.resamplingEnabled = true;
  }

  static void _tuneRenderingCaches() {
    final imageCache = PaintingBinding.instance.imageCache;
    imageCache.maximumSize = 256;
    imageCache.maximumSizeBytes = 96 << 20;
  }

  static Future<void> _enableNative() async {
    try {
      final rate = await _channel.invokeMethod<num>('enable');
      if (kDebugMode) {
        final engineRate = almanacDisplayRefreshRate();
        final native = rate?.toDouble() ?? engineRate;
        if (native > 60) {
          debugPrint(
            'Almanac: display refresh ${native.toStringAsFixed(0)} Hz '
            '(engine ${engineRate.toStringAsFixed(0)})',
          );
        }
      }
    } on PlatformException {
      // Native channel unavailable on older builds.
    } on MissingPluginException {
      // Tests / desktop without the platform handler.
    }
  }
}
