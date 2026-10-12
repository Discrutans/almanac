import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../core/localization/app_localizations.dart';
import '../../platform/session_types.dart';
import '../../core/theme/almanac_tokens.dart';

const _uuid = Uuid();

class SessionFormFieldsEditor extends StatefulWidget {
  const SessionFormFieldsEditor({
    super.key,
    required this.fields,
    required this.onChanged,
    this.showHeading = true,
    this.hint,
  });

  final List<SessionFormField> fields;
  final ValueChanged<List<SessionFormField>> onChanged;
  final bool showHeading;
  final String? hint;

  @override
  State<SessionFormFieldsEditor> createState() =>
      _SessionFormFieldsEditorState();
}

class _SessionFormFieldsEditorState extends State<SessionFormFieldsEditor> {
  late List<_FieldRow> _rows;
  var _didSeedDefault = false;

  @override
  void initState() {
    super.initState();
    _rows = widget.fields.map(_FieldRow.fromField).toList();
    if (_rows.isEmpty) {
      _rows.add(_FieldRow.newRow());
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didSeedDefault) return;
    if (_rows.length == 1 &&
        _rows.first.controller.text.trim().isEmpty &&
        _rows.first.kind == SessionFormFieldKind.text) {
      _didSeedDefault = true;
      final l10n = AppLocalizations.of(context);
      _rows.first.controller.text = l10n.bookingFieldPresetName;
      _rows.first.required = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _emit();
      });
    } else {
      _didSeedDefault = true;
    }
  }

  @override
  void dispose() {
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  void _emit() {
    widget.onChanged(
      _rows
          .map((row) => row.toField())
          .where((field) => field.label.isNotEmpty)
          .where((field) => !field.isSelect || field.options.isNotEmpty)
          .toList(),
    );
  }

  void _addField({
    String? label,
    bool required = true,
    SessionFormFieldKind kind = SessionFormFieldKind.text,
    List<String> options = const [],
  }) {
    setState(
      () => _rows.add(
        _FieldRow.newRow(
          label: label,
          required: required,
          kind: kind,
          options: options,
        ),
      ),
    );
    _emit();
  }

  void _setKind(int index, SessionFormFieldKind kind) {
    final l10n = AppLocalizations.of(context);
    setState(() {
      final row = _rows[index];
      row.kind = kind;
      if (kind == SessionFormFieldKind.phone &&
          row.controller.text.trim().isEmpty) {
        row.controller.text = l10n.bookingFieldPresetPhone;
      }
      if (kind == SessionFormFieldKind.select) {
        if (row.controller.text.trim().isEmpty ||
            row.controller.text.trim() == l10n.bookingFieldPresetName ||
            row.controller.text.trim() == l10n.bookingFieldPresetPhone) {
          row.controller.text = l10n.bookingFieldPresetService;
        }
        if (row.optionControllers.isEmpty) {
          row.optionControllers.add(TextEditingController());
        }
      }
    });
    _emit();
  }

  void _addOption(int index) {
    setState(() => _rows[index].optionControllers.add(TextEditingController()));
  }

  void _removeOption(int fieldIndex, int optionIndex) {
    setState(() {
      final row = _rows[fieldIndex];
      row.optionControllers.removeAt(optionIndex).dispose();
      if (row.optionControllers.isEmpty) {
        row.optionControllers.add(TextEditingController());
      }
      _emit();
    });
  }

  void _removeField(int index) {
    setState(() {
      _rows.removeAt(index).dispose();
      if (_rows.isEmpty) {
        _rows.add(_FieldRow.newRow());
      }
      _emit();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.showHeading) ...[
          Text(
            l10n.bookingFormFieldsTitle,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: AlmanacSpacing.sm),
        ],
        if (widget.hint != null) ...[
          Text(
            widget.hint!,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: AlmanacSpacing.xs),
        ],
        for (var i = 0; i < _rows.length; i++) ...[
          if (i > 0) const SizedBox(height: AlmanacSpacing.sm),
          _buildRow(context, l10n, scheme, i),
        ],
        const SizedBox(height: AlmanacSpacing.xs),
        Wrap(
          spacing: AlmanacSpacing.xs,
          runSpacing: 0,
          children: [
            TextButton.icon(
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () => _addField(
                label: l10n.bookingFieldPresetService,
                kind: SessionFormFieldKind.select,
              ),
              icon: const Icon(Icons.checklist_outlined, size: 16),
              label: Text(l10n.bookingFieldKindSelect),
            ),
            TextButton.icon(
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () => _addField(),
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: Text(l10n.bookingFieldKindText),
            ),
            TextButton.icon(
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () => _addField(
                label: l10n.bookingFieldPresetPhone,
                kind: SessionFormFieldKind.phone,
              ),
              icon: const Icon(Icons.phone_outlined, size: 16),
              label: Text(l10n.bookingFieldKindPhone),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRow(
    BuildContext context,
    AppLocalizations l10n,
    ColorScheme scheme,
    int index,
  ) {
    final row = _rows[index];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Wrap(
                spacing: AlmanacSpacing.xs,
                runSpacing: 0,
                children: [
                  ChoiceChip(
                    visualDensity: VisualDensity.compact,
                    label: Text(l10n.bookingFieldKindSelect),
                    selected: row.kind == SessionFormFieldKind.select,
                    onSelected: (_) =>
                        _setKind(index, SessionFormFieldKind.select),
                  ),
                  ChoiceChip(
                    visualDensity: VisualDensity.compact,
                    label: Text(l10n.bookingFieldKindText),
                    selected: row.kind == SessionFormFieldKind.text,
                    onSelected: (_) =>
                        _setKind(index, SessionFormFieldKind.text),
                  ),
                  ChoiceChip(
                    visualDensity: VisualDensity.compact,
                    label: Text(l10n.bookingFieldKindPhone),
                    selected: row.kind == SessionFormFieldKind.phone,
                    onSelected: (_) =>
                        _setKind(index, SessionFormFieldKind.phone),
                  ),
                ],
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: l10n.deleteTooltip,
              icon: const Icon(Icons.delete_outline, size: 20),
              onPressed: _rows.length == 1 && row.controller.text.trim().isEmpty
                  ? null
                  : () => _removeField(index),
            ),
          ],
        ),
        const SizedBox(height: AlmanacSpacing.xs),
        TextField(
          controller: row.controller,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            isDense: true,
            labelText: row.kind == SessionFormFieldKind.select
                ? l10n.bookingFieldPresetService
                : l10n.bookingFormFieldLabel,
            suffixIcon: IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: l10n.bookingFieldRequired,
              icon: Icon(
                row.required ? Icons.star : Icons.star_border,
                size: 18,
                color: row.required ? scheme.primary : scheme.outline,
              ),
              onPressed: () {
                setState(() => row.required = !row.required);
                _emit();
              },
            ),
          ),
          onChanged: (_) => _emit(),
        ),
        if (row.kind == SessionFormFieldKind.select) ...[
          const SizedBox(height: AlmanacSpacing.xs),
          for (var o = 0; o < row.optionControllers.length; o++)
            Padding(
              padding: const EdgeInsets.only(bottom: AlmanacSpacing.xs),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: row.optionControllers[o],
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        isDense: true,
                        labelText: '${l10n.bookingFieldOptionLabel} ${o + 1}',
                        hintText: l10n.bookingFieldOptionHint,
                      ),
                      onChanged: (_) => _emit(),
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: l10n.deleteTooltip,
                    icon: const Icon(Icons.remove_circle_outline, size: 18),
                    onPressed: row.optionControllers.length == 1
                        ? null
                        : () => _removeOption(index, o),
                  ),
                ],
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () => _addOption(index),
              icon: const Icon(Icons.add, size: 16),
              label: Text(l10n.bookingFieldAddOption),
            ),
          ),
        ],
      ],
    );
  }
}

class _FieldRow {
  _FieldRow({
    required this.id,
    required this.controller,
    required this.required,
    this.kind = SessionFormFieldKind.text,
    List<TextEditingController>? optionControllers,
  }) : optionControllers = optionControllers ?? [];

  factory _FieldRow.fromField(SessionFormField field) {
    return _FieldRow(
      id: field.id,
      controller: TextEditingController(text: field.label),
      required: field.required,
      kind: field.kind,
      optionControllers: [
        for (final option in field.options) TextEditingController(text: option),
        if (field.kind == SessionFormFieldKind.select && field.options.isEmpty)
          TextEditingController(),
      ],
    );
  }

  factory _FieldRow.newRow({
    String? label,
    bool required = true,
    SessionFormFieldKind kind = SessionFormFieldKind.text,
    List<String> options = const [],
  }) {
    return _FieldRow(
      id: _uuid.v4(),
      controller: TextEditingController(text: label ?? ''),
      required: required,
      kind: kind,
      optionControllers: [
        for (final option in options) TextEditingController(text: option),
        if (kind == SessionFormFieldKind.select && options.isEmpty)
          TextEditingController(),
      ],
    );
  }

  final String id;
  final TextEditingController controller;
  final List<TextEditingController> optionControllers;
  bool required;
  SessionFormFieldKind kind;

  SessionFormField toField() {
    return SessionFormField(
      id: id,
      label: controller.text.trim(),
      required: required,
      kind: kind,
      options: optionControllers
          .map((item) => item.text.trim())
          .where((item) => item.isNotEmpty)
          .toList(),
    );
  }

  void dispose() {
    controller.dispose();
    for (final option in optionControllers) {
      option.dispose();
    }
  }
}
