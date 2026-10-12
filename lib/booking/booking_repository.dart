import 'package:uuid/uuid.dart';
import '../core/localization/app_localizations.dart';
import 'booking_types.dart';
import '../data/local/persisted_repository.dart';

const _uuid = Uuid();

/// Результат глобального поиска шаблона бронирования по токену.
class BookingTemplateLookup {
  const BookingTemplateLookup({
    required this.profileId,
    required this.template,
  });

  final String profileId;
  final BookingTemplate template;
}

abstract interface class BookingRepository {
  void ensureProfile(String profileId);

  /// Удаляет шаблоны и запросы профиля.
  void deleteProfileData(String profileId);

  BookingTemplate? findTemplateByToken({
    required String profileId,
    required String token,
  });

  /// Поиск шаблона по токену среди всех профилей (для публичной страницы).
  BookingTemplateLookup? findTemplateByTokenGlobally(String token);

  List<BookingSlot> getSlots({
    required String profileId,
    required String templateToken,
    required DateTime day,
  });

  BookingRequest createRequest({
    required String profileId,
    required String templateToken,
    required DateTime start,
    required DateTime end,
    required BookingConfirmationMode confirmationMode,
  });

  BookingRequest? getRequestById({
    required String profileId,
    required String requestId,
  });

  BookingRequest updateRequestStatus({
    required String profileId,
    required String requestId,
    required BookingRequestStatus status,
  });

  List<BookingRequest> getPendingRequests({required String profileId});

  List<BookingTemplate> listTemplates({required String profileId});

  BookingTemplate createTemplate({
    required String profileId,
    required String title,
    required Duration duration,
    required BookingConfirmationMode confirmationMode,
  });

  void deleteTemplate({required String profileId, required String token});
}

class InMemoryBookingRepository
    with PersistedRepository
    implements BookingRepository {
  InMemoryBookingRepository({this.seedDemoData = true}) {
    ensureProfile('default');
  }

  final bool seedDemoData;

  final _templatesByProfile = <String, Map<String, BookingTemplate>>{};
  final _requestsByProfile = <String, Map<String, BookingRequest>>{};

  Map<String, BookingTemplate> _templatesFor(String profileId) {
    return _templatesByProfile.putIfAbsent(profileId, () => {});
  }

  Map<String, BookingRequest> _requestsFor(String profileId) {
    return _requestsByProfile.putIfAbsent(profileId, () => {});
  }

  Map<String, List<BookingTemplate>> exportTemplatesByProfile() {
    return _templatesByProfile.map(
      (profileId, templates) =>
          MapEntry(profileId, templates.values.toList(growable: false)),
    );
  }

  Map<String, List<BookingRequest>> exportRequestsByProfile() {
    return _requestsByProfile.map(
      (profileId, requests) =>
          MapEntry(profileId, requests.values.toList(growable: false)),
    );
  }

  void restore({
    required Map<String, List<BookingTemplate>> templatesByProfile,
    required Map<String, List<BookingRequest>> requestsByProfile,
  }) {
    _templatesByProfile.clear();
    for (final entry in templatesByProfile.entries) {
      _templatesByProfile[entry.key] = {
        for (final template in entry.value) template.token: template,
      };
    }

    _requestsByProfile.clear();
    for (final entry in requestsByProfile.entries) {
      _requestsByProfile[entry.key] = {
        for (final request in entry.value) request.id: request,
      };
    }
  }

  @override
  void ensureProfile(String profileId) {
    if (_templatesByProfile.containsKey(profileId)) return;

    _templatesFor(profileId);
    _requestsFor(profileId);

    if (profileId == 'default' && seedDemoData) {
      _seedDefaultProfile(profileId);
    }
  }

  void _seedDefaultProfile(String profileId) {
    final l10n = AppLocalizations.forLocale(AppLocalizations.fallback);
    final demo = BookingTemplate(
      id: 'tmpl-1',
      profileId: profileId,
      token: 'demo',
      title: l10n.demoBookingTitle,
      duration: const Duration(minutes: 60),
      confirmationMode: BookingConfirmationMode.manual,
    );
    _templatesFor(profileId)[demo.token] = demo;

    const pendingId = 'req-demo-pending';
    _requestsFor(profileId)[pendingId] = BookingRequest(
      id: pendingId,
      profileId: profileId,
      templateId: demo.id,
      templateToken: demo.token,
      start: DateTime.now().add(const Duration(days: 2, hours: 10)),
      end: DateTime.now().add(const Duration(days: 2, hours: 11)),
      createdAt: DateTime.now(),
      status: BookingRequestStatus.pending,
    );
  }

  /// Обновляет заголовок demo-шаблона при смене языка UI.
  void localizeDemoContent(AppLocalizations l10n) {
    final templates = _templatesByProfile['default'];
    final demo = templates?['demo'];
    if (demo == null) return;
    templates!['demo'] = BookingTemplate(
      id: demo.id,
      profileId: demo.profileId,
      token: demo.token,
      title: l10n.demoBookingTitle,
      duration: demo.duration,
      confirmationMode: demo.confirmationMode,
    );
  }

  @override
  void deleteProfileData(String profileId) {
    _templatesByProfile.remove(profileId);
    _requestsByProfile.remove(profileId);
    notifyChanged();
  }

  @override
  BookingTemplate? findTemplateByToken({
    required String profileId,
    required String token,
  }) {
    ensureProfile(profileId);
    return _templatesFor(profileId)[token];
  }

  @override
  BookingTemplateLookup? findTemplateByTokenGlobally(String token) {
    for (final entry in _templatesByProfile.entries) {
      final template = entry.value[token];
      if (template != null) {
        return BookingTemplateLookup(profileId: entry.key, template: template);
      }
    }
    return null;
  }

  @override
  List<BookingSlot> getSlots({
    required String profileId,
    required String templateToken,
    required DateTime day,
  }) {
    ensureProfile(profileId);
    final template = _templatesFor(profileId)[templateToken];
    if (template == null) return const [];

    const startHour = 10;
    const endHourExclusive = 18;

    final dayOnly = DateTime(day.year, day.month, day.day);

    final busy = _requestsFor(profileId).values
        .where(
          (r) =>
              r.templateToken == templateToken &&
              !(r.end.isBefore(dayOnly) ||
                  r.start.isAfter(dayOnly.add(const Duration(days: 1)))),
        )
        .where(
          (r) =>
              r.status == BookingRequestStatus.confirmed ||
              r.status == BookingRequestStatus.pending,
        )
        .toList();

    bool overlaps(
      DateTime aStart,
      DateTime aEnd,
      DateTime bStart,
      DateTime bEnd,
    ) {
      return aStart.isBefore(bEnd) && bStart.isBefore(aEnd);
    }

    final slots = <BookingSlot>[];
    for (var hour = startHour; hour < endHourExclusive; hour += 1) {
      final slotStart = DateTime(
        dayOnly.year,
        dayOnly.month,
        dayOnly.day,
        hour,
      );
      final slotEnd = slotStart.add(template.duration);

      final isAvailable = !busy.any(
        (r) => overlaps(slotStart, slotEnd, r.start, r.end),
      );

      slots.add(
        BookingSlot(start: slotStart, end: slotEnd, available: isAvailable),
      );
    }

    return slots;
  }

  @override
  BookingRequest createRequest({
    required String profileId,
    required String templateToken,
    required DateTime start,
    required DateTime end,
    required BookingConfirmationMode confirmationMode,
  }) {
    ensureProfile(profileId);
    final templateId = _templatesFor(profileId)[templateToken]?.id ?? 'unknown';
    final id = 'req-${DateTime.now().microsecondsSinceEpoch}';

    final status = switch (confirmationMode) {
      BookingConfirmationMode.automatic => BookingRequestStatus.confirmed,
      BookingConfirmationMode.manual => BookingRequestStatus.pending,
    };

    final req = BookingRequest(
      id: id,
      profileId: profileId,
      templateId: templateId,
      templateToken: templateToken,
      start: start,
      end: end,
      createdAt: DateTime.now(),
      status: status,
    );

    _requestsFor(profileId)[id] = req;
    notifyChanged();
    return req;
  }

  @override
  BookingRequest? getRequestById({
    required String profileId,
    required String requestId,
  }) {
    ensureProfile(profileId);
    return _requestsFor(profileId)[requestId];
  }

  @override
  BookingRequest updateRequestStatus({
    required String profileId,
    required String requestId,
    required BookingRequestStatus status,
  }) {
    ensureProfile(profileId);
    final existing = _requestsFor(profileId)[requestId];
    if (existing == null) {
      throw StateError('Booking request not found: $requestId');
    }

    final updated = BookingRequest(
      id: existing.id,
      profileId: existing.profileId,
      templateId: existing.templateId,
      templateToken: existing.templateToken,
      start: existing.start,
      end: existing.end,
      createdAt: existing.createdAt,
      status: status,
      notes: existing.notes,
    );
    _requestsFor(profileId)[requestId] = updated;
    notifyChanged();
    return updated;
  }

  @override
  List<BookingRequest> getPendingRequests({required String profileId}) {
    ensureProfile(profileId);
    return _requestsFor(
        profileId,
      ).values.where((r) => r.status == BookingRequestStatus.pending).toList()
      ..sort((a, b) => a.start.compareTo(b.start));
  }

  String _generateToken() {
    return _uuid.v4().split('-').first;
  }

  @override
  List<BookingTemplate> listTemplates({required String profileId}) {
    ensureProfile(profileId);
    return _templatesFor(profileId).values.toList()
      ..sort((a, b) => a.title.compareTo(b.title));
  }

  @override
  BookingTemplate createTemplate({
    required String profileId,
    required String title,
    required Duration duration,
    required BookingConfirmationMode confirmationMode,
  }) {
    ensureProfile(profileId);

    var token = _generateToken();
    while (findTemplateByTokenGlobally(token) != null) {
      token = _generateToken();
    }

    final template = BookingTemplate(
      id: _uuid.v4(),
      profileId: profileId,
      token: token,
      title: title,
      duration: duration,
      confirmationMode: confirmationMode,
    );

    _templatesFor(profileId)[token] = template;
    notifyChanged();
    return template;
  }

  @override
  void deleteTemplate({required String profileId, required String token}) {
    ensureProfile(profileId);
    _templatesFor(profileId).remove(token);
    notifyChanged();
  }
}
