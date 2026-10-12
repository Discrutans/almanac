part of '../session_page.dart';

class _SessionModeChip extends StatelessWidget {
  const _SessionModeChip({required this.session});

  final PlatformSession session;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: Chip(
        avatar: Icon(
          session.mode == SessionMode.collaborative
              ? Icons.edit_calendar
              : Icons.schedule,
          size: 18,
        ),
        label: Text(
          session.mode == SessionMode.collaborative
              ? l10n.newCollaborativeSession
              : l10n.newBookingSession,
        ),
      ),
    );
  }
}

class _SessionDisplayNameCard extends StatelessWidget {
  const _SessionDisplayNameCard({
    required this.controller,
    required this.onApply,
  });

  final TextEditingController controller;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlmanacCard(
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              decoration: InputDecoration(labelText: l10n.sessionDisplayName),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => onApply(),
            ),
          ),
          const SizedBox(width: AlmanacSpacing.sm),
          TextButton(
            onPressed: onApply,
            child: Text(l10n.sessionApplyDisplayName),
          ),
        ],
      ),
    );
  }
}

class _SessionClientsCard extends StatelessWidget {
  const _SessionClientsCard({required this.clients});

  final List<SessionClientPresence> clients;

  @override
  Widget build(BuildContext context) {
    return AlmanacCard(
      child: Wrap(
        spacing: AlmanacSpacing.xs,
        runSpacing: AlmanacSpacing.xs,
        children: clients
            .map(
              (client) => Chip(
                label: Text(client.displayName),
                avatar: const Icon(Icons.person, size: 16),
              ),
            )
            .toList(),
      ),
    );
  }
}
