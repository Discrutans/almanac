import 'package:flutter/material.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/almanac_tokens.dart';
import '../../calendar_types.dart';
import 'checklist_tree.dart';

typedef ChecklistTitleChanged = void Function(String id, String title);
typedef ChecklistCompletedChanged = void Function(String id, bool completed);

class ChecklistEditor extends StatefulWidget {
  const ChecklistEditor({
    super.key,
    required this.items,
    required this.onChanged,
  });

  final List<ChecklistItem> items;
  final ValueChanged<List<ChecklistItem>> onChanged;

  @override
  ChecklistEditorState createState() => ChecklistEditorState();
}

class ChecklistEditorState extends State<ChecklistEditor> {
  final _titleController = TextEditingController();

  final _subtaskController = TextEditingController();

  final _subtaskFocusNode = FocusNode();

  final _controllers = <String, TextEditingController>{};
  late List<ChecklistItem> _items;
  String? _pendingSubtaskParentId;
  String? _pendingSubtaskParentTitle;

  @override
  void initState() {
    super.initState();
    _items = widget.items;
  }

  @override
  void didUpdateWidget(covariant ChecklistEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items != widget.items) {
      _items = widget.items;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _subtaskController.dispose();
    _subtaskFocusNode.dispose();
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final entries = flattenChecklistTree(_items);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AlmanacSpacing.md),
        Text(
          l10n.checklistTitle,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: AlmanacSpacing.xxs),
        Text(
          l10n.checklistEditorHint,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: AlmanacSpacing.sm),
        if (_items.isEmpty)
          Text(
            l10n.checklistEmptyEditorHint,
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
        ...entries.map((entry) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ChecklistItemRow(
                entry: entry,
                controllers: _controllers,
                onTitleChanged: _updateTitle,
                onCompletedChanged: _updateCompleted,
                onAddSubtask: _startSubtask,
                onDelete: _delete,
                l10n: l10n,
              ),
              if (_pendingSubtaskParentId == entry.item.id)
                _buildSubtaskInput(entry, l10n),
            ],
          );
        }),
        const SizedBox(height: AlmanacSpacing.sm),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: _titleController,
                maxLines: 1,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(labelText: l10n.checklistNewTask),
                onSubmitted: (_) => _addRootItem(),
              ),
            ),
            const SizedBox(width: AlmanacSpacing.xxs),
            IconButton(
              onPressed: _addRootItem,
              tooltip: l10n.checklistAddTaskTooltip,
              icon: const Icon(Icons.add),
            ),
          ],
        ),
      ],
    );
  }

  /// Adds text from the new-task field to the list if it is not empty.
  void commitPendingDraft() {
    _addRootItem();
  }

  void _addRootItem() {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    setState(() {
      _items = [..._items, ChecklistItem(id: _newId(), title: title)];
      _titleController.clear();
      widget.onChanged(_items);
    });
  }

  void _startSubtask(String parentId, String parentTitle) {
    setState(() {
      _pendingSubtaskParentId = parentId;
      _pendingSubtaskParentTitle = parentTitle;
      _subtaskController.clear();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _subtaskFocusNode.requestFocus();
    });
  }

  void _confirmSubtask() {
    final parentId = _pendingSubtaskParentId;
    final title = _subtaskController.text.trim();
    if (parentId == null || title.isEmpty) return;

    setState(() {
      _items = _items
          .map((item) => _addSubtaskToItem(parentId, title, item))
          .toList();
      _pendingSubtaskParentId = null;
      _pendingSubtaskParentTitle = null;
      _subtaskController.clear();
      widget.onChanged(_items);
    });
  }

  void _cancelSubtask() {
    setState(() {
      _pendingSubtaskParentId = null;
      _pendingSubtaskParentTitle = null;
      _subtaskController.clear();
    });
  }

  ChecklistItem _addSubtaskToItem(
    String parentId,
    String title,
    ChecklistItem item,
  ) {
    if (item.id == parentId) {
      return item.copyWith(
        children: [
          ...item.children,
          ChecklistItem(id: _newId(), title: title),
        ],
      );
    }

    return item.copyWith(
      children: item.children
          .map((child) => _addSubtaskToItem(parentId, title, child))
          .toList(),
    );
  }

  Widget _buildSubtaskInput(
    ChecklistTreeEntry parentEntry,
    AppLocalizations l10n,
  ) {
    final parentTitle = _pendingSubtaskParentTitle ?? parentEntry.item.title;

    return Padding(
      padding: EdgeInsets.only(left: (parentEntry.depth + 1) * 18.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.checklistSubtaskFor(parentTitle),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall,
          ),
          const SizedBox(height: AlmanacSpacing.xxs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ChecklistTreeIndent(
                depth: parentEntry.depth + 1,
                isLast: true,
                ancestorContinues: [
                  ...parentEntry.ancestorContinues,
                  !parentEntry.isLast,
                ],
              ),
              Expanded(
                child: TextField(
                  controller: _subtaskController,
                  focusNode: _subtaskFocusNode,
                  maxLines: 1,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    labelText: l10n.checklistSubtaskName,
                  ),
                  onSubmitted: (_) => _confirmSubtask(),
                ),
              ),
              IconButton(
                onPressed: _confirmSubtask,
                tooltip: l10n.save,
                icon: const Icon(Icons.check),
              ),
              IconButton(
                onPressed: _cancelSubtask,
                tooltip: l10n.cancel,
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _delete(String id) {
    setState(() {
      _items = _items
          .map((item) => _removeItem(id, item))
          .whereType<ChecklistItem>()
          .toList();
      if (_pendingSubtaskParentId == id) {
        _pendingSubtaskParentId = null;
        _pendingSubtaskParentTitle = null;
      }
      _controllers.remove(id)?.dispose();
      widget.onChanged(_items);
    });
  }

  ChecklistItem? _removeItem(String id, ChecklistItem item) {
    if (item.id == id) return null;
    return item.copyWith(
      children: item.children
          .map((child) => _removeItem(id, child))
          .whereType<ChecklistItem>()
          .toList(),
    );
  }

  void _updateTitle(String id, String title) {
    setState(() {
      _items = _items
          .map((item) => _updateTitleInItem(id, title, item))
          .toList();
      widget.onChanged(_items);
    });
  }

  ChecklistItem _updateTitleInItem(
    String id,
    String title,
    ChecklistItem item,
  ) {
    if (item.id == id) return item.copyWith(title: title);

    return item.copyWith(
      children: item.children
          .map((child) => _updateTitleInItem(id, title, child))
          .toList(),
    );
  }

  void _updateCompleted(String id, bool completed) {
    setState(() {
      _items = _items
          .map((item) => _updateCompletedInItem(id, completed, item))
          .toList();
      widget.onChanged(_items);
    });
  }

  ChecklistItem _updateCompletedInItem(
    String id,
    bool completed,
    ChecklistItem item,
  ) {
    if (item.id == id) return item.copyWith(completed: completed);

    return item.copyWith(
      children: item.children
          .map((child) => _updateCompletedInItem(id, completed, child))
          .toList(),
    );
  }

  String _newId() => 'checklist-${DateTime.now().microsecondsSinceEpoch}';
}

class _ChecklistItemRow extends StatelessWidget {
  const _ChecklistItemRow({
    required this.entry,
    required this.controllers,
    required this.onTitleChanged,
    required this.onCompletedChanged,
    required this.onAddSubtask,
    required this.onDelete,
    required this.l10n,
  });

  final ChecklistTreeEntry entry;
  final Map<String, TextEditingController> controllers;
  final ChecklistTitleChanged onTitleChanged;
  final ChecklistCompletedChanged onCompletedChanged;
  final void Function(String id, String title) onAddSubtask;
  final ValueChanged<String> onDelete;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final item = entry.item;
    final colorScheme = Theme.of(context).colorScheme;
    final controller = controllers.putIfAbsent(
      item.id,
      () => TextEditingController(text: item.title),
    );

    if (controller.text != item.title) {
      controller.value = controller.value.copyWith(
        text: item.title,
        selection: TextSelection.collapsed(offset: item.title.length),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AlmanacSpacing.xxs),
      child: Material(
        color: entry.depth == 0
            ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.35)
            : colorScheme.surfaceContainerHighest.withValues(alpha: 0.18),
        borderRadius: AlmanacRadius.input,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AlmanacSpacing.xxs,
            vertical: AlmanacSpacing.xxs,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ChecklistTreeIndent(
                depth: entry.depth,
                isLast: entry.isLast,
                ancestorContinues: entry.ancestorContinues,
              ),
              SizedBox(
                height: 40,
                width: 40,
                child: Checkbox(
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                  value: item.completed,
                  onChanged: (value) {
                    if (value != null) {
                      onCompletedChanged(item.id, value);
                    }
                  },
                ),
              ),
              Expanded(
                child: TextField(
                  controller: controller,
                  maxLines: 1,
                  textInputAction: TextInputAction.done,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    decoration: item.completed
                        ? TextDecoration.lineThrough
                        : null,
                    color: item.completed
                        ? colorScheme.onSurfaceVariant
                        : colorScheme.onSurface,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: entry.depth == 0
                        ? l10n.checklistTaskHint
                        : l10n.checklistSubtaskHint,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AlmanacSpacing.xxs,
                      vertical: AlmanacSpacing.xxs,
                    ),
                  ),
                  onChanged: (value) => onTitleChanged(item.id, value),
                ),
              ),
              _CompactIconButton(
                icon: Icons.add,
                tooltip: l10n.checklistSubtaskTooltip,
                onPressed: () => onAddSubtask(item.id, item.title),
              ),
              _CompactIconButton(
                icon: Icons.delete_outline,
                tooltip: l10n.deleteTooltip,
                onPressed: () => onDelete(item.id),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompactIconButton extends StatelessWidget {
  const _CompactIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: AlmanacSizes.iconButton,
      height: AlmanacSizes.iconButton,
      child: IconButton(
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        tooltip: tooltip,
        icon: Icon(icon, size: 20),
        onPressed: onPressed,
      ),
    );
  }
}
