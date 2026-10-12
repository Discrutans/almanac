import 'package:flutter/foundation.dart';

/// Репозиторий, который уведомляет о необходимости сохранения на диск.
mixin PersistedRepository {
  VoidCallback? onChanged;

  @protected
  void notifyChanged() => onChanged?.call();
}
