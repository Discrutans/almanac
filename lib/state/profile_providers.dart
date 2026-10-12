import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../booking/booking_repository.dart';
import '../booking/booking_types.dart';
import '../data/events/event_repository.dart';
import '../data/profiles/context_profile.dart';
import '../data/profiles/context_profile_repository.dart';
import '../data/profiles/profile_scoped_repositories.dart';
import '../data/savings/savings_goal_repository.dart';
import '../platform/group_plan_repository.dart';
import '../platform/platform_config_repository.dart';
import '../platform/ydb/ydb_invite.dart';
import 'core_providers.dart';
import 'repository_providers.dart';

final contextProfileRepositoryProvider = Provider<ContextProfileRepository>((
  ref,
) {
  return ref.watch(localDataStoreProvider).profileRepository;
});

final activeProfileIdProvider = Provider<String>((ref) {
  return ref.watch(contextProfilesProvider).active.id;
});

final visibleProfileIdsProvider = Provider<Set<String>>((ref) {
  return Set<String>.of(ref.watch(contextProfilesProvider).visibleProfileIds);
});

final profileEventRepositoryProvider = Provider<ProfileScopedEventRepository>((
  ref,
) {
  final profileId = ref.watch(activeProfileIdProvider);
  return ProfileScopedEventRepository(
    ref.read(eventRepositoryProvider),
    profileId,
  );
});

final combinedEventRepositoryProvider = Provider<CombinedEventRepository>((
  ref,
) {
  final profileIds = ref.watch(visibleProfileIdsProvider);
  return CombinedEventRepository(ref.read(eventRepositoryProvider), profileIds);
});

final profileBookingRepositoryProvider =
    Provider<ProfileScopedBookingRepository>((ref) {
      final profileId = ref.watch(activeProfileIdProvider);
      return ProfileScopedBookingRepository(
        ref.read(bookingRepositoryProvider),
        profileId,
      );
    });

/// Состояние профилей контекста: список, активный и видимые в календаре.
class ContextProfilesState {
  const ContextProfilesState({
    required this.profiles,
    required this.active,
    required this.visibleProfileIds,
  });

  final List<ContextProfile> profiles;
  final ContextProfile active;
  final Set<String> visibleProfileIds;

  bool get isSplitView => visibleProfileIds.length > 1;

  bool isVisible(String profileId) => visibleProfileIds.contains(profileId);

  String get visibleLabel {
    if (!isSplitView) return active.name;

    return profiles
        .where((profile) => visibleProfileIds.contains(profile.id))
        .map((profile) => profile.name)
        .join(' + ');
  }
}

class ContextProfilesNotifier extends Notifier<ContextProfilesState> {
  ContextProfileRepository get _profileRepo =>
      ref.read(contextProfileRepositoryProvider);

  EventRepository get _eventRepo => ref.read(eventRepositoryProvider);

  BookingRepository get _bookingRepo => ref.read(bookingRepositoryProvider);

  GroupPlanRepository get _groupPlanRepo =>
      ref.read(groupPlanRepositoryProvider);

  SavingsGoalRepository get _savingsGoalRepo =>
      ref.read(savingsGoalRepositoryProvider);

  PlatformConfigRepository get _platformConfigRepo =>
      ref.read(platformConfigRepositoryProvider);

  void _sync() {
    state = ContextProfilesState(
      profiles: _profileRepo.getAll(),
      active: _profileRepo.getActive(),
      visibleProfileIds: _profileRepo.getVisibleProfileIds(),
    );
  }

  @override
  ContextProfilesState build() {
    return ContextProfilesState(
      profiles: _profileRepo.getAll(),
      active: _profileRepo.getActive(),
      visibleProfileIds: _profileRepo.getVisibleProfileIds(),
    );
  }

  void select(String profileId) {
    _profileRepo.setActive(profileId);
    _profileRepo.ensureProfileVisible(profileId);
    _eventRepo.ensureProfile(profileId);
    _bookingRepo.ensureProfile(profileId);
    _groupPlanRepo.ensureProfile(profileId);
    _savingsGoalRepo.ensureProfile(profileId);
    _platformConfigRepo.getOrCreateConfig(profileId: profileId);
    _sync();
    ref.read(profileAccessOverrideProvider.notifier).state = null;
  }

  void toggleVisible(String profileId) {
    final wasVisible = state.isVisible(profileId);
    _profileRepo.toggleProfileVisibility(profileId);
    if (!wasVisible) {
      _eventRepo.ensureProfile(profileId);
      _bookingRepo.ensureProfile(profileId);
    }
    _sync();
    ref.read(schedulesVersionProvider.notifier).state++;
  }

  /// Гарантирует, что события профиля видны в календаре после создания.
  void ensureActiveVisible() {
    _profileRepo.ensureProfileVisible(state.active.id);
    _sync();
  }

  /// Делает профиль видимым в календаре, не меняя активный.
  void ensureProfileVisible(String profileId) {
    if (state.profiles.every((profile) => profile.id != profileId)) return;
    _profileRepo.ensureProfileVisible(profileId);
    _eventRepo.ensureProfile(profileId);
    _sync();
  }

  ContextProfile create(
    String name, {
    ProfileKind kind = ProfileKind.personal,
    ProfileRole role = ProfileRole.owner,
    String? id,
  }) {
    final profile = _profileRepo.createProfile(
      name: name,
      kind: kind,
      role: role,
      id: id,
    );
    _profileRepo.setActive(profile.id);
    _eventRepo.ensureProfile(profile.id);
    _bookingRepo.ensureProfile(profile.id);
    _groupPlanRepo.ensureProfile(profile.id);
    _savingsGoalRepo.ensureProfile(profile.id);
    _platformConfigRepo.getOrCreateConfig(profileId: profile.id);
    if (kind == ProfileKind.personal) {
      _platformConfigRepo.updateSyncPreferences(
        profileId: profile.id,
        autoPush: false,
        autoPull: false,
      );
    } else if (role == ProfileRole.member) {
      _platformConfigRepo.updateSyncPreferences(
        profileId: profile.id,
        autoPush: false,
        autoPull: true,
      );
      _platformConfigRepo.updateRole(
        profileId: profile.id,
        role: ProfileRole.member,
      );
    }
    _sync();
    return profile;
  }

  ContextProfile joinShared({
    required String name,
    required String profileId,
    required ProfileKind kind,
    required String serverBaseUrl,
    required String apiKey,
  }) {
    if (kind == ProfileKind.personal) {
      throw ArgumentError('Личный профиль нельзя подключить по ключу');
    }
    final workspaceId = profileId.trim().isEmpty ? 'default' : profileId.trim();
    final existing = _profileRepo.getById(workspaceId);
    final ContextProfile profile;
    if (existing != null && existing.kind == ProfileKind.personal) {
      profile = create(name, kind: kind, role: ProfileRole.member);
    } else if (existing != null) {
      profile = existing;
      _profileRepo.setActive(profile.id);
    } else {
      profile = create(
        name,
        kind: kind,
        role: ProfileRole.member,
        id: workspaceId,
      );
    }
    _platformConfigRepo.updateConnectionSettings(
      profileId: profile.id,
      serverBaseUrl: serverBaseUrl,
      apiKey: apiKey,
      workspaceProfileId: workspaceId,
    );
    _platformConfigRepo.updateRole(
      profileId: profile.id,
      role: ProfileRole.member,
    );
    _sync();
    return profile;
  }

  Future<ContextProfile> joinYdb({
    required String name,
    required YdbWorkspaceInvite invite,
  }) async {
    await ref
        .read(localDataStoreProvider)
        .ydbConnectionStore
        .save(invite.connection);
    final profile = joinShared(
      name: invite.name ?? name,
      profileId: invite.connection.workspaceProfileId,
      kind: invite.kind,
      serverBaseUrl: '',
      apiKey: invite.connection.workspaceApiKey,
    );
    _platformConfigRepo.updateSyncPreferences(
      profileId: profile.id,
      autoPush: true,
      autoPull: true,
    );
    _sync();
    ref.read(platformSettingsRevisionProvider.notifier).state++;
    final sync = ref.read(remoteSyncServiceProvider);
    if (sync.isEnabled) {
      await sync.pullRemoteChanges(onlyProfileId: profile.id);
    }
    return profile;
  }

  void rename({required String id, required String name}) {
    _profileRepo.renameProfile(id: id, name: name);
    _sync();
  }

  void delete(String id) {
    _profileRepo.deleteProfile(id);
    _eventRepo.deleteProfileData(id);
    _bookingRepo.deleteProfileData(id);
    _groupPlanRepo.deleteProfileData(id);
    _savingsGoalRepo.deleteProfileData(id);
    _platformConfigRepo.deleteProfileData(id);
    _sync();
  }

  void updateTheme({
    ThemeMode? themeMode,
    Color? seedColor,
    Color? accentColor,
  }) {
    final updated = state.active.copyWith(
      themeMode: themeMode,
      seedColor: seedColor,
      accentColor: accentColor,
    );
    _profileRepo.updateProfile(updated);
    _sync();
  }
}

final contextProfilesProvider =
    NotifierProvider<ContextProfilesNotifier, ContextProfilesState>(
      ContextProfilesNotifier.new,
    );

/// Активный профиль (удобный shorthand).
final activeProfileNotifierProvider = Provider<ContextProfile>((ref) {
  return ref.watch(contextProfilesProvider).active;
});

final activeProfileAccessProvider = Provider<ProfileAccess>((ref) {
  final override = ref.watch(profileAccessOverrideProvider);
  if (override != null) return override;
  return ref.watch(contextProfilesProvider).active.access;
});

/// Временный тестовый интерфейс (не меняет сохранённый профиль).
final profileAccessOverrideProvider = StateProvider<ProfileAccess?>((ref) {
  return null;
});

final profileListProvider = Provider<List<ContextProfile>>((ref) {
  return ref.watch(contextProfilesProvider).profiles;
});

/// Pending-бронирования всех видимых профилей.
class PendingBookingsNotifier extends Notifier<List<BookingRequest>> {
  @override
  List<BookingRequest> build() {
    ref.watch(visibleProfileIdsProvider);
    return getPendingRequestsForProfiles(
      ref.read(bookingRepositoryProvider),
      ref.read(visibleProfileIdsProvider),
    );
  }

  void refresh() {
    state = getPendingRequestsForProfiles(
      ref.read(bookingRepositoryProvider),
      ref.read(visibleProfileIdsProvider),
    );
  }

  void updateStatus({
    required String profileId,
    required String requestId,
    required BookingRequestStatus status,
  }) {
    ref
        .read(bookingRepositoryProvider)
        .updateRequestStatus(
          profileId: profileId,
          requestId: requestId,
          status: status,
        );
    refresh();
  }
}

final pendingBookingsProvider =
    NotifierProvider<PendingBookingsNotifier, List<BookingRequest>>(
      PendingBookingsNotifier.new,
    );
