import 'package:flutter/material.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/almanac_tokens.dart';
import '../../../core/ui/almanac_time_field.dart';
import '../../event_time_utils.dart';

/// Напоминание: время, когда прийдёт уведомление. Пустое поле — без напоминания.
class ReminderField extends StatefulWidget {
  const ReminderField({
    super.key,
    this.eventStartTime = '',
    required this.minutesBefore,
    required this.onChanged,
    this.compact = false,
  });

  final String eventStartTime;
  final int? minutesBefore;
  final ValueChanged<int?> onChanged;
  final bool compact;

  @override
  State<ReminderField> createState() => _ReminderFieldState();
}

class _ReminderFieldState extends State<ReminderField> {
  final TextEditingController _timeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _syncControllerFromWidget();
  }

  @override
  void didUpdateWidget(covariant ReminderField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final startChanged = oldWidget.eventStartTime != widget.eventStartTime;
    final minutesChanged = oldWidget.minutesBefore != widget.minutesBefore;

    if (minutesChanged && !startChanged) {
      _syncControllerFromWidget();
      return;
    }

    if (startChanged) {
      _syncControllerFromWidget();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _emitValue();
      });
    }
  }

  void _syncControllerFromWidget() {
    _timeController.text =
        reminderFireTimeText(
          eventStartTime: widget.eventStartTime,
          minutesBefore: widget.minutesBefore,
        ) ??
        '';
  }

  @override
  void dispose() {
    _timeController.dispose();
    super.dispose();
  }

  bool get _hasEventStart => parseAlmanacTime(widget.eventStartTime) != null;

  int? _readMinutesBefore() {
    if (!_hasEventStart) return null;
    return minutesBeforeFromReminderFireTimeText(
      eventStartTime: widget.eventStartTime,
      reminderTimeText: _timeController.text,
    );
  }

  void _emitValue() {
    if (!_hasEventStart) return;

    final trimmed = _timeController.text.trim();
    if (trimmed.isEmpty) {
      widget.onChanged(null);
      return;
    }

    final minutes = _readMinutesBefore();
    if (minutes != null) widget.onChanged(minutes);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final hasText = _timeController.text.trim().isNotEmpty;
    final minutes = _readMinutesBefore();
    final invalid = _hasEventStart && hasText && minutes == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AlmanacTimeField(
          controller: _timeController,
          label: l10n.reminderFireTimeLabel,
          helperText: widget.compact ? '' : l10n.reminderFireTimeHint,
          isDense: widget.compact,
          readOnly: !_hasEventStart,
          onChanged: () {
            _emitValue();
            setState(() {});
          },
        ),
        if (!widget.compact && !_hasEventStart) ...[
          const SizedBox(height: AlmanacSpacing.xxs),
          Text(
            l10n.reminderNeedsEventStart,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ] else if (!widget.compact && invalid) ...[
          const SizedBox(height: AlmanacSpacing.xxs),
          Text(
            l10n.reminderCustomInvalid,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: scheme.error),
          ),
        ] else if (!widget.compact && minutes != null) ...[
          const SizedBox(height: AlmanacSpacing.xxs),
          Text(
            l10n.reminderBeforeEventSummary(minutes),
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: scheme.primary),
          ),
        ] else if (!widget.compact) ...[
          const SizedBox(height: AlmanacSpacing.xxs),
          Text(l10n.reminderNone, style: Theme.of(context).textTheme.bodySmall),
        ],
      ],
    );
  }
}
