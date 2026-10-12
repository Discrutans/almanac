import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../data/schedules/cyclic_schedule_generator.dart';
import '../finance/pay_types.dart';
import '../calendar/widgets/chrome/almanac_mini_color_picker.dart';
import '../data/profiles/context_profile.dart';
import '../core/localization/app_localizations.dart';
import '../state/app_providers.dart';
import '../core/ui/almanac_sheets.dart';
import '../core/theme/almanac_tokens.dart';
import '../core/ui/almanac_buttons.dart';
import '../core/ui/almanac_avatar.dart';
import '../core/ui/almanac_feedback.dart';
import '../core/ui/almanac_time_field.dart';
part 'work_schedule_list.dart';
part 'work_schedule_editor.dart';
part 'work_schedule_actions.dart';

/// Управление циклическими рабочими расписаниями активного профиля.
class WorkScheduleSheet extends ConsumerStatefulWidget {
  const WorkScheduleSheet({
    super.key,
    this.placement = AlmanacSheetPlacement.top,
  });

  final AlmanacSheetPlacement placement;

  static Future<void> show(
    BuildContext context, {
    AlmanacSheetPlacement placement = AlmanacSheetPlacement.top,
  }) {
    final l10n = AppLocalizations.of(context);
    return showAlmanacSheet<void>(
      context: context,
      placement: placement,
      title: l10n.workSchedules,
      child: WorkScheduleSheet(placement: placement),
    );
  }

  @override
  ConsumerState<WorkScheduleSheet> createState() => _WorkScheduleSheetState();
}
