import '../booking/booking_repository.dart';
import '../booking/booking_types.dart';
import 'group_plan_repository.dart';
import 'group_plan_types.dart';
import 'platform_config_repository.dart';
import 'platform_types.dart';

/// Универсальный API Almanac Platform для встраивания и удалённого сервера.
abstract interface class AlmanacPlatformApi {
  PlatformConfig getWorkspace({required String profileId});

  List<PublicLinkInfo> listPublicLinks({required String profileId});

  BookingTemplate createBookingTemplate({
    required String profileId,
    required String title,
    required Duration duration,
    required BookingConfirmationMode confirmationMode,
  });

  GroupPlan createGroupPlan({
    required String profileId,
    required String title,
    required List<PlanSlot> slots,
    String? notes,
  });

  BookingTemplateLookup? resolveBookingByToken(String token);

  GroupPlanLookup? resolveGroupPlanByToken(String token);

  List<BookingSlot> getBookingSlots({
    required String profileId,
    required String templateToken,
    required DateTime day,
  });

  BookingRequest createBookingRequest({
    required String profileId,
    required String templateToken,
    required DateTime start,
    required DateTime end,
    required BookingConfirmationMode confirmationMode,
  });

  PlanVote submitGroupPlanVote({
    required String profileId,
    required String token,
    required String participantName,
    required List<String> slotIds,
  });
}

/// Локальная реализация — данные в JSON-хранилище приложения.
final class LocalAlmanacPlatformApi implements AlmanacPlatformApi {
  LocalAlmanacPlatformApi({
    required this.bookingRepository,
    required this.groupPlanRepository,
    required this.platformConfigRepository,
    this.publicOrigin = 'http://localhost',
  });

  final BookingRepository bookingRepository;
  final GroupPlanRepository groupPlanRepository;
  final PlatformConfigRepository platformConfigRepository;

  /// Базовый URL для публичных ссылок (в проде — домен приложения).
  final String publicOrigin;

  @override
  PlatformConfig getWorkspace({required String profileId}) {
    bookingRepository.ensureProfile(profileId);
    groupPlanRepository.ensureProfile(profileId);
    return platformConfigRepository.getOrCreateConfig(profileId: profileId);
  }

  @override
  List<PublicLinkInfo> listPublicLinks({required String profileId}) {
    bookingRepository.ensureProfile(profileId);

    final links = <PublicLinkInfo>[];

    for (final template in bookingRepository.listTemplates(
      profileId: profileId,
    )) {
      links.add(
        PublicLinkInfo(
          kind: PublicLinkKind.booking,
          token: template.token,
          title: template.title,
          path: '/book/${template.token}',
        ),
      );
    }

    return links;
  }

  @override
  BookingTemplate createBookingTemplate({
    required String profileId,
    required String title,
    required Duration duration,
    required BookingConfirmationMode confirmationMode,
  }) {
    return bookingRepository.createTemplate(
      profileId: profileId,
      title: title,
      duration: duration,
      confirmationMode: confirmationMode,
    );
  }

  @override
  GroupPlan createGroupPlan({
    required String profileId,
    required String title,
    required List<PlanSlot> slots,
    String? notes,
  }) {
    return groupPlanRepository.createPlan(
      profileId: profileId,
      title: title,
      slots: slots,
      notes: notes,
    );
  }

  @override
  BookingTemplateLookup? resolveBookingByToken(String token) {
    return bookingRepository.findTemplateByTokenGlobally(token);
  }

  @override
  GroupPlanLookup? resolveGroupPlanByToken(String token) {
    return groupPlanRepository.findPlanByTokenGlobally(token);
  }

  @override
  List<BookingSlot> getBookingSlots({
    required String profileId,
    required String templateToken,
    required DateTime day,
  }) {
    return bookingRepository.getSlots(
      profileId: profileId,
      templateToken: templateToken,
      day: day,
    );
  }

  @override
  BookingRequest createBookingRequest({
    required String profileId,
    required String templateToken,
    required DateTime start,
    required DateTime end,
    required BookingConfirmationMode confirmationMode,
  }) {
    return bookingRepository.createRequest(
      profileId: profileId,
      templateToken: templateToken,
      start: start,
      end: end,
      confirmationMode: confirmationMode,
    );
  }

  @override
  PlanVote submitGroupPlanVote({
    required String profileId,
    required String token,
    required String participantName,
    required List<String> slotIds,
  }) {
    return groupPlanRepository.submitVote(
      profileId: profileId,
      token: token,
      participantName: participantName,
      slotIds: slotIds,
    );
  }
}
