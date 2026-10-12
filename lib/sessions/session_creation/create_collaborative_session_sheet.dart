import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../core/localization/app_localizations.dart';
import '../../platform/session_types.dart';
import '../../state/app_providers.dart';
import '../../core/ui/almanac_sheets.dart';
import '../../core/theme/almanac_tokens.dart';
import '../../core/ui/almanac_feedback.dart';
import '../../core/ui/almanac_scroll.dart';
import 'session_creation_service.dart';

const _uuid = Uuid();

class CreateCollaborativeSessionSheet {
  CreateCollaborativeSessionSheet._();

  static Future<void> show(BuildContext context, {DateTime? initialDate}) {
    return showAlmanacSheet<void>(
      context: context,
      placement: AlmanacSheetPlacement.bottom,
      builder: (context) => _CreateCollaborativeSessionSheetBody(
        initialDate: initialDate ?? DateTime.now(),
      ),
    );
  }
}

class _CreateCollaborativeSessionSheetBody extends ConsumerStatefulWidget {
  const _CreateCollaborativeSessionSheetBody({required this.initialDate});

  final DateTime initialDate;

  @override
  ConsumerState<_CreateCollaborativeSessionSheetBody> createState() =>
      _CreateCollaborativeSessionSheetBodyState();
}

class _CreateCollaborativeSessionSheetBodyState
    extends ConsumerState<_CreateCollaborativeSessionSheetBody> {
  final _titleController = TextEditingController();
  late DateTime _planningDate;
  int _maxEditors = 3;
  bool _creating = false;

  @override
  void initState() {
    super.initState();
    _planningDate = DateTime(
      widget.initialDate.year,
      widget.initialDate.month,
      widget.initialDate.day,
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final l10n = AppLocalizations.of(context);
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      AlmanacFeedback.showError(context, l10n.titleRequired);
      return;
    }

    setState(() => _creating = true);
    final profileId = ref.read(activeProfileIdProvider);
    final planningDay = DateTime(
      _planningDate.year,
      _planningDate.month,
      _planningDate.day,
      10,
    );
    final slot = SessionSlot(
      id: _uuid.v4(),
      start: planningDay,
      end: planningDay.add(const Duration(hours: 1)),
      label: l10n.collaborativeDefaultSlotLabel,
    );

    await createRemoteSession(
      context: context,
      ref: ref,
      profileId: profileId,
      mode: SessionMode.collaborative,
      title: title,
      slots: [slot],
      settings: {
        'planning_date': _planningDate.toIso8601String(),
        'max_editors': _maxEditors,
        'editors': <String>[],
      },
    );

    if (mounted) {
      setState(() => _creating = false);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();

    return Padding(
      padding: const EdgeInsets.only(
        left: AlmanacSpacing.md,
        right: AlmanacSpacing.md,
        bottom: AlmanacSpacing.md,
      ),
      child: SingleChildScrollView(
        keyboardDismissBehavior: AlmanacScroll.keyboardDismiss,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.newCollaborativeSession,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AlmanacSpacing.sm),
            TextField(
              controller: _titleController,
              decoration: InputDecoration(labelText: l10n.title),
            ),
            const SizedBox(height: AlmanacSpacing.sm),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.collaborativePlanningDate),
              subtitle: Text(
                DateFormat('d MMM yyyy', locale).format(_planningDate),
              ),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _planningDate,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null) {
                  setState(() => _planningDate = picked);
                }
              },
            ),
            DropdownButtonFormField<int>(
              initialValue: _maxEditors,
              decoration: InputDecoration(
                labelText: l10n.collaborativeMaxEditors,
              ),
              items: List.generate(
                10,
                (index) => DropdownMenuItem(
                  value: index + 1,
                  child: Text('${index + 1}'),
                ),
              ),
              onChanged: (value) {
                if (value != null) setState(() => _maxEditors = value);
              },
            ),
            const SizedBox(height: AlmanacSpacing.md),
            FilledButton.icon(
              onPressed: _creating ? null : _create,
              icon: _creating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.link),
              label: Text(l10n.createAndCopyLink),
            ),
          ],
        ),
      ),
    );
  }
}
