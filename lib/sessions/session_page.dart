import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../core/localization/app_localizations.dart';
import '../platform/remote_almanac_platform_api.dart';
import '../platform/server_url.dart';
import '../platform/session_types.dart';
import '../platform/session_websocket_client.dart';
import '../state/app_providers.dart';
import '../state/guest_session_providers.dart';
import '../state/session_pending_providers.dart';
import 'session_booking_calendar.dart';
import 'session_slot_editor.dart';
import '../profiles/platform_links_sheet.dart';
import '../core/ui/almanac_sheets.dart';
import '../core/theme/almanac_tokens.dart';
import '../core/ui/almanac_card.dart';
import '../core/ui/almanac_feedback.dart';
import '../core/ui/almanac_scroll.dart';
import '../core/ui/public_page_scaffold.dart';

part 'widgets/session_page_panels.dart';
part 'widgets/session_page_chrome.dart';

const _uuid = Uuid();

class SessionPage extends ConsumerStatefulWidget {
  const SessionPage({super.key, required this.token, this.initialSlotId});

  final String token;
  final String? initialSlotId;

  @override
  ConsumerState<SessionPage> createState() => _SessionPageState();
}

class _SessionPageState extends ConsumerState<SessionPage> {
  SessionWebSocketClient? _client;
  PlatformSession? _session;
  List<SessionClientPresence> _clients = const [];
  String? _error;
  bool _loading = true;
  bool _submittedBooking = false;
  String? _selectedSlotId;
  final _fieldControllers = <String, TextEditingController>{};
  final _nameController = TextEditingController(text: 'Guest');

  bool _showGuestPreview = false;
  bool _awaitingBookingResponse = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _connect());
  }

  @override
  void dispose() {
    _client?.dispose();
    _nameController.dispose();
    for (final controller in _fieldControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  RemoteAlmanacPlatformApi? _remoteApi() {
    final api = ref.read(almanacPlatformApiProvider);
    return api is RemoteAlmanacPlatformApi ? api : null;
  }

  String _serverBaseUrl() {
    final remote = _remoteApi();
    if (remote != null) return remote.baseUrl;

    final guestOrigin = ref.read(guestSessionServerProvider);
    if (guestOrigin != null && guestOrigin.isNotEmpty) {
      return normalizeServerUrl(guestOrigin);
    }

    final profileId = ref.read(activeProfileIdProvider);
    final config = ref
        .read(platformConfigRepositoryProvider)
        .getOrCreateConfig(profileId: profileId);
    return config.serverBaseUrl.isNotEmpty
        ? normalizeServerUrl(config.serverBaseUrl)
        : normalizeServerUrl(ref.read(publicOriginProvider));
  }

  Future<void> _reconnectWithName() async {
    await _client?.dispose();
    _client = null;
    await _connect();
  }

  Future<void> _connect() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final remote = _remoteApi();
      String? ownerApiKey;
      final access = ref.read(activeProfileAccessProvider);
      if (remote != null && !access.canBookOnly) {
        final profileId = ref.read(activeProfileIdProvider);
        ownerApiKey = ref
            .read(platformConfigRepositoryProvider)
            .getOrCreateConfig(profileId: profileId)
            .apiKey;
      }

      final client = SessionWebSocketClient(
        baseUrl: _serverBaseUrl(),
        token: widget.token,
        displayName: _nameController.text.trim().isEmpty
            ? 'Guest'
            : _nameController.text.trim(),
        apiKey: ownerApiKey,
      );
      await client.connect();
      _client = client;

      client.messages.listen((message) {
        if (!mounted) return;
        final type = message['type'] as String?;
        if (type == 'error') {
          final errorMessage = message['message'] as String? ?? 'Error';
          AlmanacFeedback.showError(context, errorMessage);
          if (_awaitingBookingResponse) {
            _awaitingBookingResponse = false;
          }
        }
        if (type == 'booking_request_created' && _awaitingBookingResponse) {
          _awaitingBookingResponse = false;
          _submittedBooking = true;
        }
        setState(() {
          _session = client.session ?? _session;
          _clients = client.clients;
          if (_session != null) {
            _ensureFieldControllers(_session!);
            _maybeSelectInitialSlot(_session!);
            if (_selectedSlotId != null &&
                _session!.isSlotFull(_selectedSlotId!)) {
              _selectedSlotId = null;
            }
          }
        });
      });

      await Future<void>.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      setState(() {
        _session = client.session;
        _clients = client.clients;
        _loading = false;
        if (_session != null) {
          _ensureFieldControllers(_session!);
          _maybeSelectInitialSlot(_session!);
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  void _ensureFieldControllers(PlatformSession session) {
    for (final field in session.state.formFields) {
      _fieldControllers.putIfAbsent(field.id, TextEditingController.new);
    }
  }

  void _maybeSelectInitialSlot(PlatformSession session) {
    final slotId = widget.initialSlotId;
    if (slotId == null || _selectedSlotId != null) return;
    final exists = session.state.slots.any((slot) => slot.id == slotId);
    if (!exists || session.isSlotFull(slotId)) return;
    _selectedSlotId = slotId;
  }

  Future<void> _sendPatch(List<Map<String, dynamic>> ops) async {
    await _client?.sendPatch(ops: ops);
  }

  Future<void> _addSlot() async {
    final edited = await SessionSlotEditor.show(context: context);
    if (edited == null) return;
    final slot = SessionSlot(
      id: _uuid.v4(),
      start: edited.start,
      end: edited.end,
      label: edited.label,
    );
    await _sendPatch([
      {'op': 'addSlot', 'slot': slot.toJson()},
    ]);
  }

  Future<void> _editSlot(SessionSlot slot) async {
    final edited = await SessionSlotEditor.show(
      context: context,
      initial: slot,
    );
    if (edited == null) return;
    await _sendPatch([
      {
        'op': 'updateSlot',
        'slot': SessionSlot(
          id: slot.id,
          start: edited.start,
          end: edited.end,
          label: edited.label,
        ).toJson(),
      },
    ]);
  }

  Future<void> _removeSlot(String slotId) async {
    await _sendPatch([
      {'op': 'removeSlot', 'slot_id': slotId},
    ]);
  }

  Future<void> _submitBooking() async {
    final session = _session;
    final slotId = _selectedSlotId;
    if (session == null || slotId == null) return;

    final fields = <String, String>{};
    for (final field in session.state.formFields) {
      final value = _fieldControllers[field.id]?.text.trim() ?? '';
      if (field.required && value.isEmpty) {
        AlmanacFeedback.showError(context, '${field.label}: required');
        return;
      }
      fields[field.id] = value;
    }

    if (session.isSlotFull(slotId)) {
      AlmanacFeedback.showError(
        context,
        AppLocalizations.of(context).bookingSlotFull,
      );
      return;
    }

    await _client?.sendBookingRequest(slotId: slotId, fields: fields);
    setState(() => _awaitingBookingResponse = true);
  }

  Future<void> _decideRequest(
    SessionBookingRequest request,
    SessionBookingRequestStatus status,
  ) async {
    final remote = _remoteApi();
    final session = _session;
    if (remote == null || session == null) return;

    try {
      await remote.decideBookingRequestRemote(
        profileId: session.profileId,
        token: widget.token,
        requestId: request.id,
        status: status,
      );
    } catch (error) {
      if (mounted) {
        AlmanacFeedback.showError(context, error.toString());
      }
      return;
    }

    if (status == SessionBookingRequestStatus.confirmed && mounted) {
      final slot = session.state.slots
          .where((candidate) => candidate.id == request.slotId)
          .firstOrNull;
      if (slot != null) {
        applyConfirmedSessionBookingToCalendar(
          context: context,
          ref: ref,
          item: RemoteSessionPendingRequest(
            sessionToken: widget.token,
            sessionTitle: session.title,
            request: request,
            formFields: session.state.formFields,
            slots: session.state.slots,
          ),
        );
      }
    }

    refreshRemoteSessionPending(ref);
  }

  Future<void> _closeSession() async {
    final remote = _remoteApi();
    final session = _session;
    if (remote == null || session == null) return;

    final l10n = AppLocalizations.of(context);
    final confirmed = await showAlmanacConfirm(
      context: context,
      title: l10n.closeSession,
      message: session.title,
      confirmLabel: l10n.closeSession,
      cancelLabel: l10n.cancel,
    );
    if (confirmed != true || !mounted) return;

    try {
      await remote.closeSessionRemote(
        profileId: session.profileId,
        token: widget.token,
      );
      ref.invalidate(sessionLinksProvider(session.profileId));
      if (mounted) {
        AlmanacFeedback.showSuccess(context, l10n.sessionClosed);
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (mounted) {
        AlmanacFeedback.showError(context, error.toString());
      }
    }
  }

  bool get _hasServerUrl {
    final base = _serverBaseUrl();
    return base.isNotEmpty && isValidServerUrl(base);
  }

  bool get _isOwner {
    final session = _session;
    if (session == null) return false;
    if (_remoteApi() == null) return false;
    final access = ref.watch(activeProfileAccessProvider);
    if (access.isMember) return false;
    final profileId = ref.watch(activeProfileIdProvider);
    return session.profileId == profileId;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final session = _session;

    if (_loading) {
      return PublicPageScaffold(
        title: l10n.platformLinks,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return _SessionFailureView(
        message: _error!,
        onRetry: _connect,
        showServerHint: !_hasServerUrl,
      );
    }

    if (session == null) {
      return _SessionFailureView(
        message: l10n.sessionNotFoundHint(widget.token),
        onRetry: _connect,
        showServerHint: !_hasServerUrl,
      );
    }

    return PublicPageScaffold(
      title: session.title,
      actions: _isOwner
          ? [
              IconButton(
                tooltip: l10n.closeSession,
                onPressed: _closeSession,
                icon: const Icon(Icons.close),
              ),
            ]
          : null,
      child: SingleChildScrollView(
        keyboardDismissBehavior: AlmanacScroll.keyboardDismiss,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SessionModeChip(session: session),
            const SizedBox(height: AlmanacSpacing.sm),
            if (!_isOwner) ...[
              _SessionDisplayNameCard(
                controller: _nameController,
                onApply: _reconnectWithName,
              ),
              const SizedBox(height: AlmanacSpacing.md),
            ],
            if (_clients.isNotEmpty) _SessionClientsCard(clients: _clients),
            const SizedBox(height: AlmanacSpacing.md),
            if (session.mode == SessionMode.collaborative)
              _CollaborativeBody(
                session: session,
                canEdit: true,
                onAddSlot: _addSlot,
                onEditSlot: _editSlot,
                onRemoveSlot: _removeSlot,
              )
            else if (_isOwner && !_showGuestPreview) ...[
              _OwnerRequestsPanel(
                title: l10n.sessionOwnerPendingSection,
                requests: session.requests
                    .where(
                      (request) =>
                          request.status == SessionBookingRequestStatus.pending,
                    )
                    .toList(),
                slots: session.state.slots,
                formFields: session.state.formFields,
                onDecide: _decideRequest,
              ),
              const SizedBox(height: AlmanacSpacing.sm),
              OutlinedButton.icon(
                onPressed: () => setState(() => _showGuestPreview = true),
                icon: const Icon(Icons.visibility_outlined),
                label: Text(l10n.sessionGuestPreview),
              ),
            ] else
              _BookingBody(
                session: session,
                submitted: _submittedBooking,
                selectedSlotId: _selectedSlotId,
                fieldControllers: _fieldControllers,
                onSelectSlot: (slotId) =>
                    setState(() => _selectedSlotId = slotId),
                onSubmit: _submitBooking,
                showOwnerBack: _isOwner && _showGuestPreview,
                onOwnerBack: () => setState(() {
                  _showGuestPreview = false;
                  _submittedBooking = false;
                  _selectedSlotId = null;
                }),
              ),
          ],
        ),
      ),
    );
  }
}
