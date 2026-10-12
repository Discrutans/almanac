part of 'settings_sheet.dart';

class _GuestCalendarSection extends ConsumerStatefulWidget {
  const _GuestCalendarSection();

  @override
  ConsumerState<_GuestCalendarSection> createState() =>
      _GuestCalendarSectionState();
}

class _GuestCalendarSectionState extends ConsumerState<_GuestCalendarSection> {
  final _urlController = TextEditingController();

  final _titleController = TextEditingController();
  var _busy = false;

  @override
  void dispose() {
    _urlController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _subscribe() async {
    if (_busy) return;
    setState(() => _busy = true);
    await subscribeGuestCalendarFromUrl(
      context: context,
      ref: ref,
      url: _urlController.text,
      title: _titleController.text,
    );
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final profileId = ref.watch(activeProfileIdProvider);
    final feeds = ref
        .watch(localDataStoreProvider)
        .guestCalendarsFor(profileId);

    return AlmanacCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.guestCalendarTitle,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: AlmanacSpacing.xs),
          TextField(
            controller: _titleController,
            decoration: InputDecoration(labelText: l10n.guestCalendarTitle),
          ),
          const SizedBox(height: AlmanacSpacing.xs),
          TextField(
            controller: _urlController,
            decoration: InputDecoration(hintText: l10n.guestCalendarUrlHint),
          ),
          const SizedBox(height: AlmanacSpacing.sm),
          OutlinedButton(
            onPressed: _busy ? null : _subscribe,
            child: Text(l10n.guestCalendarAddAction),
          ),
          if (feeds.isNotEmpty) ...[
            const SizedBox(height: AlmanacSpacing.sm),
            for (final feed in feeds)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(feed.title),
                subtitle: Text(
                  feed.url,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Text('${feed.cachedEvents.length}'),
              ),
          ],
        ],
      ),
    );
  }
}
