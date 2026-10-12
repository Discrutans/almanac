import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../core/localization/app_localizations.dart';
import '../core/router/app_router.dart';
import '../core/theme/almanac_tokens.dart';
import '../core/ui/almanac_card.dart';
import '../core/ui/almanac_feedback.dart';
import '../platform/session_types.dart';
import '../sessions/session_booking_calendar.dart';
import '../state/session_pending_providers.dart';

class RemoteSessionPendingPanel extends ConsumerWidget {
  const RemoteSessionPendingPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(remoteSessionPendingListProvider);
    if (pending.isEmpty) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context);
    final formatter = DateFormat('dd MMM, HH:mm');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.remoteSessionPendingTitle(pending.length),
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: AlmanacSpacing.xs),
        for (final item in pending)
          Padding(
            padding: const EdgeInsets.only(bottom: AlmanacSpacing.sm),
            child: AlmanacCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.sessionTitle,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  Text(
                    _slotLabel(item, formatter),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  for (final field in item.formFields)
                    if (item.request.fields[field.id]?.isNotEmpty ?? false)
                      Text('${field.label}: ${item.request.fields[field.id]}'),
                  Wrap(
                    spacing: AlmanacSpacing.xxs,
                    runSpacing: AlmanacSpacing.xxs,
                    children: [
                      TextButton.icon(
                        onPressed: () => ref
                            .read(appRouterProvider)
                            .push('/session/${item.sessionToken}'),
                        icon: const Icon(Icons.open_in_new, size: 18),
                        label: Text(l10n.openSession),
                      ),
                      TextButton(
                        onPressed: () => _decide(
                          context,
                          ref,
                          item,
                          SessionBookingRequestStatus.confirmed,
                        ),
                        child: Text(l10n.confirmBooking),
                      ),
                      TextButton(
                        onPressed: () => _decide(
                          context,
                          ref,
                          item,
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

  Future<void> _decide(
    BuildContext context,
    WidgetRef ref,
    RemoteSessionPendingRequest item,
    SessionBookingRequestStatus status,
  ) async {
    final l10n = AppLocalizations.of(context);
    final ok = await decideRemoteSessionPending(
      ref,
      item: item,
      status: status,
    );
    if (!context.mounted) return;

    if (!ok) {
      AlmanacFeedback.showError(context, l10n.serverConnectionFailed('decide'));
      return;
    }

    if (status == SessionBookingRequestStatus.confirmed) {
      applyConfirmedSessionBookingToCalendar(
        context: context,
        ref: ref,
        item: item,
      );
    }
  }

  String _slotLabel(RemoteSessionPendingRequest item, DateFormat formatter) {
    for (final slot in item.slots) {
      if (slot.id == item.request.slotId) {
        return '${formatter.format(slot.start.toLocal())} — '
            '${formatter.format(slot.end.toLocal())}';
      }
    }
    return item.request.slotId;
  }
}
