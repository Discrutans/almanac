import 'package:flutter/material.dart';

import '../core/localization/app_localizations.dart';
import '../core/theme/almanac_tokens.dart';

/// Section headers and copy for REST vs offline pending lists.
class PendingBookingsFacade {
  PendingBookingsFacade._();

  static Widget remoteSectionHeader(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AlmanacSpacing.xs),
      child: Text(
        l10n.inboxRemoteSectionTitle,
        style: Theme.of(context).textTheme.titleSmall,
      ),
    );
  }

  static Widget legacySectionHeader(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AlmanacSpacing.xs),
      child: Text(
        l10n.inboxLegacySectionTitle,
        style: Theme.of(context).textTheme.titleSmall,
      ),
    );
  }

  static Widget legacySectionHint(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Text(
      l10n.inboxLegacySectionHint,
      style: Theme.of(context).textTheme.bodySmall,
    );
  }
}
