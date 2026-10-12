import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../booking/booking_calendar_helpers.dart';
import '../booking/booking_types.dart';
import '../core/localization/app_localizations.dart';
import '../core/theme/almanac_tokens.dart';
import '../core/ui/almanac_card.dart';
import '../state/app_providers.dart';

/// Read-only handling for legacy local booking requests still in snapshot.
class LegacyLocalPendingPanel extends ConsumerWidget {
  const LegacyLocalPendingPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(pendingBookingsProvider);
    if (pending.isEmpty) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context);
    final formatter = DateFormat('dd MMM, HH:mm');
    final notifier = ref.read(pendingBookingsProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.legacyLocalPendingSection,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: AlmanacSpacing.xs),
        Text(
          l10n.legacyLocalPendingHint,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
        const SizedBox(height: AlmanacSpacing.sm),
        for (final request in pending)
          Padding(
            padding: const EdgeInsets.only(bottom: AlmanacSpacing.sm),
            child: AlmanacCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${formatter.format(request.start.toLocal())} — '
                    '${formatter.format(request.end.toLocal())}',
                  ),
                  if (request.notes != null && request.notes!.isNotEmpty)
                    Text(request.notes!),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () async {
                          final template = ref
                              .read(bookingRepositoryProvider)
                              .findTemplateByToken(
                                profileId: request.profileId,
                                token: request.templateToken,
                              );
                          notifier.updateStatus(
                            profileId: request.profileId,
                            requestId: request.id,
                            status: BookingRequestStatus.confirmed,
                          );
                          if (!context.mounted) return;
                          applyConfirmedLocalBookingToCalendar(
                            context: context,
                            ref: ref,
                            request: request,
                            templateTitle: template?.title,
                          );
                        },
                        child: Text(l10n.confirmBooking),
                      ),
                      TextButton(
                        onPressed: () => notifier.updateStatus(
                          profileId: request.profileId,
                          requestId: request.id,
                          status: BookingRequestStatus.rejected,
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
