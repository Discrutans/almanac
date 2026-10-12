import 'package:flutter/material.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/almanac_tokens.dart';
import '../../../core/ui/almanac_avatar.dart';
import '../../../core/ui/almanac_time_field.dart';
import '../../../data/profiles/context_profile.dart';
import '../chrome/almanac_mini_color_picker.dart';

/// Единый стиль полей формы создания записи.
InputDecoration eventFormInputDecoration(
  BuildContext context, {
  String? labelText,
  String? hintText,
  bool alignLabelWithHint = false,
  Widget? suffixIcon,
}) {
  return InputDecoration(
    labelText: labelText,
    hintText: hintText,
    alignLabelWithHint: alignLabelWithHint,
    suffixIcon: suffixIcon,
  );
}

/// Текстовое поле формы с общим оформлением.
class EventFormTextField extends StatelessWidget {
  const EventFormTextField({
    super.key,
    required this.controller,
    this.labelText,
    this.hintText,
    this.autofocus = false,
    this.minLines = 1,
    this.maxLines = 1,
    this.alignLabelWithHint = false,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String? labelText;
  final String? hintText;
  final bool autofocus;
  final int minLines;
  final int maxLines;
  final bool alignLabelWithHint;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autofocus: autofocus,
      minLines: minLines,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: Theme.of(context).textTheme.bodyMedium,
      decoration: eventFormInputDecoration(
        context,
        labelText: labelText,
        hintText: hintText,
        alignLabelWithHint: alignLabelWithHint,
      ),
    );
  }
}

class EventColorSection extends StatelessWidget {
  const EventColorSection({
    super.key,
    required this.color,
    required this.onChanged,
    this.compact = false,
  });

  final Color color;
  final ValueChanged<Color> onChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!compact)
          Text(
            AppLocalizations.of(context).color,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        if (!compact) const SizedBox(height: AlmanacSpacing.xxs),
        AlmanacMiniColorPicker(color: color, onChanged: onChanged),
      ],
    );
  }
}

class EventMoreOptionsButton extends StatelessWidget {
  const EventMoreOptionsButton({
    super.key,
    required this.expanded,
    required this.onPressed,
  });

  final bool expanded;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return TextButton.icon(
      style: TextButton.styleFrom(
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: AlmanacSpacing.xxs),
      ),
      onPressed: onPressed,
      icon: Icon(expanded ? Icons.expand_less : Icons.expand_more, size: 18),
      label: Text(
        expanded ? l10n.hideMoreOptions : l10n.showMoreOptions,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}

/// Выбор профиля для новой записи.
class EventFormProfilePicker extends StatelessWidget {
  const EventFormProfilePicker({
    super.key,
    required this.profiles,
    required this.selectedProfileId,
    required this.onChanged,
  });

  final List<ContextProfile> profiles;
  final String selectedProfileId;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return DropdownButtonFormField<String>(
      initialValue: selectedProfileId,
      isExpanded: true,
      style: Theme.of(context).textTheme.bodyMedium,
      decoration: eventFormInputDecoration(
        context,
        labelText: l10n.entryProfileLabel,
      ),
      items: [
        for (final profile in profiles)
          DropdownMenuItem(
            value: profile.id,
            child: _ProfileMenuRow(profile: profile),
          ),
      ],
      selectedItemBuilder: (context) => [
        for (final profile in profiles)
          Align(
            alignment: Alignment.centerLeft,
            child: _ProfileMenuRow(profile: profile, dense: true),
          ),
      ],
      onChanged: (value) {
        if (value == null) return;
        onChanged(value);
      },
    );
  }
}

class _ProfileMenuRow extends StatelessWidget {
  const _ProfileMenuRow({required this.profile, this.dense = false});

  final ContextProfile profile;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        AlmanacProfileAvatar(
          name: profile.name,
          seedColor: profile.seedColor,
          size: AlmanacAvatarSize.sm,
        ),
        const SizedBox(width: AlmanacSpacing.xxs),
        Expanded(
          child: Text(
            profile.name,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}

/// Дата и опционально время начала или окончания.
class EventFormDateTimeRow extends StatelessWidget {
  const EventFormDateTimeRow({
    super.key,
    required this.dateLabel,
    required this.date,
    required this.onDateTap,
    this.timeController,
    this.timeLabel,
    this.timeOptional = false,
  });

  final String dateLabel;
  final DateTime date;
  final VoidCallback onDateTap;
  final TextEditingController? timeController;
  final String? timeLabel;
  final bool timeOptional;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final dateText = l10n.eventFormDateLabel(date);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: timeController == null ? 1 : 5,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onDateTap,
              borderRadius: AlmanacRadius.input,
              child: InputDecorator(
                decoration: eventFormInputDecoration(
                  context,
                  labelText: dateLabel,
                  suffixIcon: IconButton(
                    onPressed: onDateTap,
                    icon: const Icon(Icons.calendar_today_outlined, size: 18),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
                ),
                child: Text(
                  dateText,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ),
          ),
        ),
        if (timeController != null) ...[
          const SizedBox(width: AlmanacSpacing.xs),
          Expanded(
            flex: 3,
            child: AlmanacTimeField(
              controller: timeController!,
              label:
                  timeLabel ??
                  (timeOptional ? l10n.endTimeOptional : l10n.startTime),
              helperText: '',
            ),
          ),
        ],
      ],
    );
  }
}

/// Dropdown с общим оформлением формы.
class EventFormDropdownField<T> extends StatelessWidget {
  const EventFormDropdownField({
    super.key,
    required this.value,
    required this.labelText,
    required this.items,
    required this.onChanged,
  });

  final T value;
  final String labelText;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      isExpanded: true,
      style: Theme.of(context).textTheme.bodyMedium,
      decoration: eventFormInputDecoration(context, labelText: labelText),
      items: items,
      onChanged: onChanged,
    );
  }
}
