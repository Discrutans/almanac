import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/localization/app_localizations.dart';
import '../../platform/server_url.dart';
import '../../core/router/app_router.dart';
import '../../state/guest_session_providers.dart';
import '../../state/remote_config_providers.dart';
import '../../core/ui/almanac_sheets.dart';
import '../../core/theme/almanac_tokens.dart';
import '../../core/ui/almanac_feedback.dart';

class JoinSessionSheet {
  JoinSessionSheet._();

  static Future<void> show(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return showAlmanacSheet<void>(
      context: context,
      placement: AlmanacSheetPlacement.bottom,
      title: l10n.joinSessionByToken,
      size: AlmanacPanelSize.hug,
      child: const _JoinSessionSheetBody(),
    );
  }
}

class _JoinSessionSheetBody extends ConsumerStatefulWidget {
  const _JoinSessionSheetBody();

  @override
  ConsumerState<_JoinSessionSheetBody> createState() =>
      _JoinSessionSheetBodyState();
}

class _JoinSessionSheetBodyState extends ConsumerState<_JoinSessionSheetBody> {
  final _tokenController = TextEditingController();

  final _serverController = TextEditingController();

  @override
  void dispose() {
    _tokenController.dispose();
    _serverController.dispose();
    super.dispose();
  }

  void _join() {
    final l10n = AppLocalizations.of(context);
    final token = _tokenController.text.trim();
    if (token.isEmpty) return;

    final hasRemote = ref.read(hasConfiguredServerProvider);
    if (!hasRemote) {
      final server = normalizeServerUrl(_serverController.text.trim());
      if (!isValidServerUrl(server)) {
        AlmanacFeedback.showError(context, l10n.invalidServerUrl);
        return;
      }
      ref.read(guestSessionServerProvider.notifier).state = server;
    }

    Navigator.pop(context);
    ref.read(appRouterProvider).push('/session/$token');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hasRemote = ref.watch(hasConfiguredServerProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _tokenController,
          decoration: InputDecoration(labelText: l10n.joinSessionTokenHint),
        ),
        if (!hasRemote) ...[
          const SizedBox(height: AlmanacSpacing.sm),
          TextField(
            controller: _serverController,
            decoration: InputDecoration(
              labelText: l10n.joinSessionServerHint,
              hintText: 'http://localhost:8080',
            ),
          ),
        ],
        const SizedBox(height: AlmanacSpacing.md),
        FilledButton(onPressed: _join, child: Text(l10n.openSession)),
      ],
    );
  }
}
