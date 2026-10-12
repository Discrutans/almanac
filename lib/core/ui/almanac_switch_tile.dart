import 'package:flutter/material.dart';
import '../theme/almanac_tokens.dart';

/// Переключатель со скруглённым выделением, как у остальных контролов.
class AlmanacSwitchTile extends StatelessWidget {
  const AlmanacSwitchTile({
    super.key,
    required this.value,
    required this.onChanged,
    required this.title,
    this.subtitle,
    this.dense = false,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final Widget title;
  final Widget? subtitle;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      visualDensity: dense ? VisualDensity.compact : VisualDensity.standard,
      shape: const RoundedRectangleBorder(
        borderRadius: AlmanacFieldLayout.highlightRadius,
      ),
      value: value,
      onChanged: onChanged,
      title: title,
      subtitle: subtitle,
    );
  }
}
