import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/localization/app_localizations.dart';
import '../core/theme/almanac_tokens.dart';
import '../state/app_providers.dart';
import '../state/calendar_events_notifier.dart';
import '../state/remote_config_providers.dart';
import '../state/session_pending_providers.dart';
import 'inbox_undated_panel.dart';
import 'legacy_local_pending_panel.dart';
import 'pending_bookings_facade.dart';
import 'remote_session_pending_panel.dart';

class InboxSheetBody extends ConsumerWidget {
  const InboxSheetBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final hasRemote = ref.watch(hasConfiguredServerProvider);
    final remotePending = ref.watch(remoteSessionPendingListProvider);
    final remoteError = ref.watch(remoteSessionPendingErrorProvider);
    final localPending = ref.watch(pendingBookingsProvider);
    final undated = ref.watch(undatedInboxEventsProvider);
    final access = ref.watch(activeProfileAccessProvider);
    final showBookings = access.canSeeOwnerInbox || localPending.isNotEmpty;

    final bookingsEmpty =
        remotePending.isEmpty && localPending.isEmpty && remoteError == null;
    final allEmpty = undated.isEmpty && bookingsEmpty && remoteError == null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const InboxUndatedPanel(),
        if (showBookings) ...[
          const SizedBox(height: AlmanacSpacing.md),
          if (remoteError != null) ...[
            Text(
              l10n.inboxLoadFailed(remoteError),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
            const SizedBox(height: AlmanacSpacing.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => refreshRemoteSessionPending(ref),
                icon: const Icon(Icons.refresh),
                label: Text(l10n.retry),
              ),
            ),
            const SizedBox(height: AlmanacSpacing.sm),
          ],
          if (hasRemote) ...[
            PendingBookingsFacade.remoteSectionHeader(context),
            const RemoteSessionPendingPanel(),
          ],
          if (localPending.isNotEmpty) ...[
            if (hasRemote && remotePending.isNotEmpty)
              const SizedBox(height: AlmanacSpacing.md),
            PendingBookingsFacade.legacySectionHeader(context),
            const SizedBox(height: AlmanacSpacing.xxs),
            PendingBookingsFacade.legacySectionHint(context),
            const SizedBox(height: AlmanacSpacing.sm),
            const LegacyLocalPendingPanel(),
          ],
        ],
        if (allEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AlmanacSpacing.sm),
            child: Text(
              l10n.inboxEmptyHint,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.almanacColors.muted,
              ),
            ),
          ),
      ],
    );
  }
}
