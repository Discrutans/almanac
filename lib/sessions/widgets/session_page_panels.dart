part of '../session_page.dart';

class _CollaborativeBody extends StatelessWidget {
  const _CollaborativeBody({
    required this.session,
    required this.canEdit,
    required this.onAddSlot,
    required this.onEditSlot,
    required this.onRemoveSlot,
  });

  final PlatformSession session;
  final bool canEdit;
  final VoidCallback onAddSlot;
  final ValueChanged<SessionSlot> onEditSlot;
  final ValueChanged<String> onRemoveSlot;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final formatter = DateFormat('dd MMM, HH:mm');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!canEdit)
          Padding(
            padding: const EdgeInsets.only(bottom: AlmanacSpacing.sm),
            child: Text(
              l10n.sessionCollaborativeGuestHint,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ),
        if (session.state.slots.isEmpty)
          AlmanacCard(
            child: Text(
              l10n.sessionNoSlotsYet,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ),
        for (final slot in session.state.slots)
          Padding(
            padding: const EdgeInsets.only(bottom: AlmanacSpacing.sm),
            child: AlmanacCard(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (slot.label != null && slot.label!.isNotEmpty)
                          Text(
                            slot.label!,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        Text(
                          '${formatter.format(slot.start.toLocal())} — '
                          '${formatter.format(slot.end.toLocal())}',
                        ),
                      ],
                    ),
                  ),
                  if (canEdit) ...[
                    IconButton(
                      onPressed: () => onEditSlot(slot),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    IconButton(
                      onPressed: () => onRemoveSlot(slot.id),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ],
              ),
            ),
          ),
        if (canEdit)
          OutlinedButton.icon(
            onPressed: onAddSlot,
            icon: const Icon(Icons.add),
            label: Text(l10n.sessionAddSlot),
          ),
      ],
    );
  }
}

class _BookingBody extends StatelessWidget {
  const _BookingBody({
    required this.session,
    required this.submitted,
    required this.selectedSlotId,
    required this.fieldControllers,
    required this.onSelectSlot,
    required this.onSubmit,
    this.showOwnerBack = false,
    this.onOwnerBack,
  });

  final PlatformSession session;
  final bool submitted;
  final String? selectedSlotId;
  final Map<String, TextEditingController> fieldControllers;
  final ValueChanged<String> onSelectSlot;
  final VoidCallback onSubmit;
  final bool showOwnerBack;
  final VoidCallback? onOwnerBack;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (submitted) {
      return AlmanacCard(child: Text(l10n.bookingRequestSubmitted));
    }

    final formatter = DateFormat('dd MMM, HH:mm');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showOwnerBack && onOwnerBack != null) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onOwnerBack,
              icon: const Icon(Icons.arrow_back),
              label: Text(l10n.sessionOwnerPendingSection),
            ),
          ),
          const SizedBox(height: AlmanacSpacing.xs),
        ],
        Text(
          l10n.bookingSelectSlot,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: AlmanacSpacing.sm),
        for (final slot in session.state.slots)
          _BookingSlotTile(
            session: session,
            slot: slot,
            formatter: formatter,
            selected: selectedSlotId == slot.id,
            onSelect: () => onSelectSlot(slot.id),
          ),
        if (selectedSlotId != null) ...[
          const SizedBox(height: AlmanacSpacing.md),
          for (final field in session.state.formFields)
            Padding(
              padding: const EdgeInsets.only(bottom: AlmanacSpacing.sm),
              child: _BookingAnswerField(
                field: field,
                controller: fieldControllers[field.id]!,
              ),
            ),
          FilledButton(
            onPressed: onSubmit,
            child: Text(l10n.bookingRequestManual),
          ),
        ],
      ],
    );
  }
}

class _BookingAnswerField extends StatelessWidget {
  const _BookingAnswerField({required this.field, required this.controller});

  final SessionFormField field;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (field.isSelect && field.options.isNotEmpty) {
      final current = controller.text;
      final value = field.options.contains(current) ? current : null;
      return DropdownButtonFormField<String>(
        initialValue: value,
        decoration: InputDecoration(labelText: field.label),
        hint: Text(l10n.bookingSelectOptionHint),
        items: [
          for (final option in field.options)
            DropdownMenuItem(value: option, child: Text(option)),
        ],
        onChanged: (selected) => controller.text = selected ?? '',
      );
    }

    return TextField(
      controller: controller,
      keyboardType: field.isPhone ? TextInputType.phone : TextInputType.text,
      inputFormatters: field.isPhone
          ? [FilteringTextInputFormatter.digitsOnly]
          : null,
      decoration: InputDecoration(labelText: field.label),
    );
  }
}

class _BookingSlotTile extends StatelessWidget {
  const _BookingSlotTile({
    required this.session,
    required this.slot,
    required this.formatter,
    required this.selected,
    required this.onSelect,
  });

  final PlatformSession session;
  final SessionSlot slot;
  final DateFormat formatter;
  final bool selected;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final full = session.isSlotFull(slot.id);
    final capacity = session.slotCapacity;
    final free = session.availableSpotsForSlot(slot.id);
    final subtitle = full
        ? l10n.bookingSlotFullLabel
        : capacity > 1
        ? l10n.bookingSlotPlacesLeft(free, capacity)
        : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: AlmanacSpacing.sm),
      child: ListTile(
        enabled: !full,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AlmanacRadius.md),
          side: BorderSide(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).dividerColor,
          ),
        ),
        title: Text(
          '${formatter.format(slot.start.toLocal())} — '
          '${formatter.format(slot.end.toLocal())}',
          style: full
              ? TextStyle(color: Theme.of(context).colorScheme.outline)
              : null,
        ),
        subtitle: subtitle != null ? Text(subtitle) : null,
        trailing: full
            ? Icon(Icons.block, color: Theme.of(context).colorScheme.outline)
            : null,
        onTap: full ? null : onSelect,
      ),
    );
  }
}

class _OwnerRequestsPanel extends StatelessWidget {
  const _OwnerRequestsPanel({
    required this.title,
    required this.requests,
    required this.slots,
    required this.formFields,
    required this.onDecide,
  });

  final String title;
  final List<SessionBookingRequest> requests;
  final List<SessionSlot> slots;
  final List<SessionFormField> formFields;
  final Future<void> Function(
    SessionBookingRequest request,
    SessionBookingRequestStatus status,
  )
  onDecide;

  String _fieldLabel(String fieldId) {
    for (final field in formFields) {
      if (field.id == fieldId) return field.label;
    }
    return fieldId;
  }

  String _slotTime(SessionBookingRequest request, DateFormat formatter) {
    for (final slot in slots) {
      if (slot.id == request.slotId) {
        return '${formatter.format(slot.start.toLocal())} — '
            '${formatter.format(slot.end.toLocal())}';
      }
    }
    return request.slotId;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final formatter = DateFormat('dd MMM, HH:mm');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          requests.isEmpty ? title : l10n.pendingBookingsTitle(requests.length),
          style: Theme.of(context).textTheme.titleSmall,
        ),
        if (requests.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AlmanacSpacing.sm),
            child: Text(
              l10n.bookingSelectSlot,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ),
        const SizedBox(height: AlmanacSpacing.sm),
        for (final request in requests)
          Padding(
            padding: const EdgeInsets.only(bottom: AlmanacSpacing.sm),
            child: AlmanacCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_slotTime(request, formatter)),
                  for (final entry in request.fields.entries)
                    Text('${_fieldLabel(entry.key)}: ${entry.value}'),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => onDecide(
                          request,
                          SessionBookingRequestStatus.confirmed,
                        ),
                        child: Text(l10n.confirmBooking),
                      ),
                      TextButton(
                        onPressed: () => onDecide(
                          request,
                          SessionBookingRequestStatus.rejected,
                        ),
                        child: Text(l10n.rejectBooking),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _SessionFailureView extends StatelessWidget {
  const _SessionFailureView({
    required this.message,
    required this.onRetry,
    required this.showServerHint,
  });

  final String message;
  final VoidCallback onRetry;
  final bool showServerHint;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return PublicPageScaffold(
      title: l10n.openSession,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: context.almanacColors.muted),
          ),
          const SizedBox(height: AlmanacSpacing.md),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: Text(l10n.retry),
          ),
          if (showServerHint) ...[
            const SizedBox(height: AlmanacSpacing.sm),
            Text(
              l10n.sessionServerRequiredHint,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
            const SizedBox(height: AlmanacSpacing.sm),
            OutlinedButton.icon(
              onPressed: () => PlatformLinksSheet.show(context),
              icon: const Icon(Icons.dns),
              label: Text(l10n.editServerUrl),
            ),
          ],
          const SizedBox(height: AlmanacSpacing.sm),
          TextButton(
            onPressed: () => Navigator.of(context).maybePop(),
            child: Text(l10n.cancel),
          ),
        ],
      ),
    );
  }
}
