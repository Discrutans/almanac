import 'package:flutter/material.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/almanac_tokens.dart';
import '../../../core/ui/almanac_switch_tile.dart';

/// Настройки Pomodoro для события.
class EventPomodoroFields extends StatelessWidget {
  const EventPomodoroFields({
    super.key,
    required this.enabled,
    required this.onEnabledChanged,
    required this.workController,
    required this.breakController,
  });

  final bool enabled;
  final ValueChanged<bool> onEnabledChanged;
  final TextEditingController workController;
  final TextEditingController breakController;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AlmanacSwitchTile(
          value: enabled,
          onChanged: onEnabledChanged,
          title: Text(l10n.pomodoroSwitchLabel),
          subtitle: Text(
            l10n.pomodoroSwitchHint,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        if (enabled) ...[
          const SizedBox(height: AlmanacSpacing.xs),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: workController,
                  decoration: InputDecoration(
                    labelText: l10n.pomodoroWorkMinutesLabel,
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: AlmanacSpacing.sm),
              Expanded(
                child: TextField(
                  controller: breakController,
                  decoration: InputDecoration(
                    labelText: l10n.pomodoroBreakMinutesLabel,
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
