import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../core/localization/app_localizations.dart';
import '../../booking/booking_repository.dart';
import '../../calendar/calendar_types.dart';
import '../../calendar/test_events.dart';
import '../../calendar/test_calendar_fill.dart';
import '../../platform/group_plan_repository.dart';
import '../../platform/platform_config_repository.dart';
import '../../platform/ydb/ydb_connection_store.dart';
import '../events/event_repository.dart';
import '../profiles/context_profile.dart';
import '../profiles/context_profile_repository.dart';
import '../savings/savings_goal_repository.dart';
import '../schedules/cyclic_work_schedule_repository.dart';
import '../../core/theme/almanac_tokens.dart';
import 'local_snapshot_store.dart';
import 'local_data_codec.dart';
import 'persisted_repository.dart';
import '../events/event_quick_template.dart';
import '../guest/guest_calendar_subscription.dart';

/// Локальное хранилище: SQLite snapshot + in-memory repositories.
final class LocalDataStore {
  LocalDataStore._({
    required this.profileRepository,
    required this.eventRepository,
    required this.scheduleRepository,
    required this.bookingRepository,
    required this.groupPlanRepository,
    required this.savingsGoalRepository,
    required this.platformConfigRepository,
    required this.snapshotStore,
    YdbConnectionStore? ydbConnectionStore,
  }) : ydbConnectionStore = ydbConnectionStore ?? YdbConnectionStore();

  final ContextProfileRepository profileRepository;
  final EventRepository eventRepository;
  final CyclicWorkScheduleRepository scheduleRepository;
  final BookingRepository bookingRepository;
  final GroupPlanRepository groupPlanRepository;
  final SavingsGoalRepository savingsGoalRepository;
  final PlatformConfigRepository platformConfigRepository;
  final LocalSnapshotStore? snapshotStore;
  final YdbConnectionStore ydbConnectionStore;

  String? _localeLanguageCode;
  var _swipeActionsHintSeen = false;
  var _weekDragHintSeen = false;
  var _hideEmptyWeekHours = false;
  var _weekHourPaddingBefore = 2;
  var _weekHourPaddingAfter = 1;
  var _weekHourZoomLevel = 1;
  var _agendaToolbarHintSeen = false;
  String? _calendarMode;
  List<int> _savedAccentPresets = [];
  final _eventQuickTemplatesByProfile = <String, List<EventQuickTemplate>>{};
  final _guestCalendarsByProfile = <String, List<GuestCalendarSubscription>>{};
  DateTime? _updatedAt;

  /// Сохранённый код языка UI (`ru`, `en`) или `null` для fallback.
  String? get localeLanguageCode => _localeLanguageCode;

  bool get swipeActionsHintSeen => _swipeActionsHintSeen;

  bool get weekDragHintSeen => _weekDragHintSeen;

  bool get hideEmptyWeekHours => _hideEmptyWeekHours;

  int get weekHourPaddingBefore => _weekHourPaddingBefore;

  int get weekHourPaddingAfter => _weekHourPaddingAfter;

  int get weekHourZoomLevel => _weekHourZoomLevel;

  bool get agendaToolbarHintSeen => _agendaToolbarHintSeen;

  String? get calendarMode => _calendarMode;

  List<Color> get savedAccentPresets =>
      _savedAccentPresets.map((value) => Color(value)).toList(growable: false);

  void saveAccentPreset(Color color) {
    final argb = color.toARGB32();
    if (_savedAccentPresets.contains(argb)) return;
    if (AlmanacBrand.isBuiltinPreset(color)) return;
    _savedAccentPresets = [..._savedAccentPresets, argb];
    _persistSafely();
  }

  void removeAccentPreset(Color color) {
    final argb = color.toARGB32();
    final next = _savedAccentPresets.where((value) => value != argb).toList();
    if (next.length == _savedAccentPresets.length) return;
    _savedAccentPresets = next;
    _persistSafely();
  }

  void saveCalendarMode(String modeName) {
    if (_calendarMode == modeName) return;
    _calendarMode = modeName;
    _persistSafely();
  }

  void markSwipeActionsHintSeen() {
    if (_swipeActionsHintSeen) return;
    _swipeActionsHintSeen = true;
    _persistSafely();
  }

  void markWeekDragHintSeen() {
    if (_weekDragHintSeen) return;
    _weekDragHintSeen = true;
    _persistSafely();
  }

  void setHideEmptyWeekHours(bool value) {
    if (_hideEmptyWeekHours == value) return;
    _hideEmptyWeekHours = value;
    _persistSafely();
  }

  void setWeekHourPaddingBefore(int value) {
    final clamped = value.clamp(0, 6);
    if (_weekHourPaddingBefore == clamped) return;
    _weekHourPaddingBefore = clamped;
    _persistSafely();
  }

  void setWeekHourPaddingAfter(int value) {
    final clamped = value.clamp(0, 6);
    if (_weekHourPaddingAfter == clamped) return;
    _weekHourPaddingAfter = clamped;
    _persistSafely();
  }

  void setWeekHourZoomLevel(int value) {
    final clamped = value.clamp(1, 2);
    if (_weekHourZoomLevel == clamped) return;
    _weekHourZoomLevel = clamped;
    _persistSafely();
  }

  void markAgendaToolbarHintSeen() {
    if (_agendaToolbarHintSeen) return;
    _agendaToolbarHintSeen = true;
    _persistSafely();
  }

  List<EventQuickTemplate> eventQuickTemplatesFor(String profileId) {
    return List<EventQuickTemplate>.from(
      _eventQuickTemplatesByProfile[profileId] ?? const [],
    );
  }

  void upsertEventQuickTemplate({
    required String profileId,
    required EventQuickTemplate template,
  }) {
    final current = List<EventQuickTemplate>.from(
      _eventQuickTemplatesByProfile[profileId] ?? const [],
    );
    final index = current.indexWhere((item) => item.id == template.id);
    if (index >= 0) {
      current[index] = template;
    } else {
      current.add(template);
    }
    _eventQuickTemplatesByProfile[profileId] = current;
    _persistSafely();
  }

  void removeEventQuickTemplate({
    required String profileId,
    required String templateId,
  }) {
    final current = _eventQuickTemplatesByProfile[profileId];
    if (current == null) return;
    final next = current.where((item) => item.id != templateId).toList();
    if (next.length == current.length) return;
    _eventQuickTemplatesByProfile[profileId] = next;
    _persistSafely();
  }

  List<GuestCalendarSubscription> guestCalendarsFor(String profileId) {
    return List<GuestCalendarSubscription>.from(
      _guestCalendarsByProfile[profileId] ?? const [],
    );
  }

  List<GuestCalendarSubscription> allGuestCalendars() {
    return _guestCalendarsByProfile.values
        .expand((feeds) => feeds)
        .toList(growable: false);
  }

  void upsertGuestCalendar(GuestCalendarSubscription subscription) {
    final current = List<GuestCalendarSubscription>.from(
      _guestCalendarsByProfile[subscription.profileId] ?? const [],
    );
    final index = current.indexWhere((item) => item.id == subscription.id);
    if (index >= 0) {
      current[index] = subscription;
    } else {
      current.add(subscription);
    }
    _guestCalendarsByProfile[subscription.profileId] = current;
    _persistSafely();
  }

  void removeGuestCalendar({
    required String profileId,
    required String subscriptionId,
  }) {
    final current = _guestCalendarsByProfile[profileId];
    if (current == null) return;
    final next = current.where((item) => item.id != subscriptionId).toList();
    if (next.length == current.length) return;
    _guestCalendarsByProfile[profileId] = next;
    _persistSafely();
  }

  /// Удаляет все события и рабочие расписания во всех профилях.
  void clearCalendarData() {
    final profiles = profileRepository as InMemoryContextProfileRepository;
    final events = eventRepository as InMemoryEventRepository;
    final schedules =
        scheduleRepository as InMemoryCyclicWorkScheduleRepository;

    final profileIds = profiles.exportProfiles().map((profile) => profile.id);
    events.restoreEventsByProfile({
      for (final profileId in profileIds) profileId: const <AppEvent>[],
    });
    schedules.restoreSchedulesByProfile({
      for (final profileId in profileIds)
        profileId: const <CyclicWorkSchedule>[],
    });
    _persistSafely();
  }

  /// Заполняет профиль валидным тестовым годом: события, смены и цели накопления.
  void applyTestCalendarFill(String profileId) {
    final events = eventRepository as InMemoryEventRepository;
    final schedules =
        scheduleRepository as InMemoryCyclicWorkScheduleRepository;
    final savingsGoals = savingsGoalRepository as InMemorySavingsGoalRepository;

    final eventMap = events.exportEventsByProfile();
    eventMap[profileId] = TestCalendarFill.personalEvents(profileId);
    events.restoreEventsByProfile(eventMap);

    final scheduleMap = schedules.exportSchedulesByProfile();
    scheduleMap[profileId] = TestCalendarFill.schedules(profileId);
    schedules.restoreSchedulesByProfile(scheduleMap);

    final goalMap = savingsGoals.exportGoalsByProfile();
    goalMap[profileId] = TestCalendarFill.savingsGoals(profileId);
    savingsGoals.restoreGoalsByProfile(goalMap);

    _persistSafely();
  }

  static Future<LocalDataStore> open({bool seedDemoData = true}) async {
    LocalSnapshotStore? snapshotStore;
    try {
      snapshotStore = await LocalSnapshotStore.openDefault();
    } catch (error, stackTrace) {
      debugPrint('LocalSnapshotStore.open failed: $error\n$stackTrace');
    }

    final legacyFile = await _resolveLegacyJsonFile();
    final scheduleRepository = InMemoryCyclicWorkScheduleRepository(
      seedDemoData: seedDemoData,
    );
    YdbConnectionStore ydbStore = YdbConnectionStore();
    try {
      ydbStore = await YdbConnectionStore.openDefault();
    } catch (error, stackTrace) {
      debugPrint('YdbConnectionStore.open failed: $error\n$stackTrace');
    }

    final store = LocalDataStore._(
      profileRepository: InMemoryContextProfileRepository(),
      eventRepository: InMemoryEventRepository(
        scheduleRepository: scheduleRepository,
        seedDemoData: seedDemoData,
      ),
      scheduleRepository: scheduleRepository,
      bookingRepository: InMemoryBookingRepository(seedDemoData: seedDemoData),
      groupPlanRepository: InMemoryGroupPlanRepository(),
      savingsGoalRepository: InMemorySavingsGoalRepository(),
      platformConfigRepository: InMemoryPlatformConfigRepository(),
      snapshotStore: snapshotStore,
      ydbConnectionStore: ydbStore,
    );

    final restored = await _restoreWithFallback(
      store: store,
      snapshotStore: snapshotStore,
      legacyFile: legacyFile,
      seedDemoData: seedDemoData,
    );
    if (!restored) {
      store._seedDefaults(seedDemoData: seedDemoData);
      await store.persist();
    }

    return store;
  }

  static Future<bool> _restoreWithFallback({
    required LocalDataStore store,
    required LocalSnapshotStore? snapshotStore,
    required File legacyFile,
    required bool seedDemoData,
  }) async {
    if (snapshotStore != null) {
      final fromDb = snapshotStore.loadSnapshotJson();
      if (fromDb != null) {
        final snapshot = _tryDecodeSnapshot(fromDb);
        if (snapshot != null) {
          store._restore(snapshot);
          return true;
        }
        await _quarantineCorruptPayload(source: 'db', payload: fromDb);
      }
    }

    if (await legacyFile.exists()) {
      try {
        final raw = await legacyFile.readAsString();
        final snapshot = _tryDecodeSnapshot(raw);
        if (snapshot != null) {
          store._restore(snapshot);
          await store.persist();
          await _tryRenameLegacy(legacyFile);
          return true;
        }
        await _quarantineCorruptPayload(
          source: 'json',
          payload: raw,
          file: legacyFile,
        );
      } catch (error, stackTrace) {
        debugPrint('Legacy JSON migration failed: $error\n$stackTrace');
      }
    }

    return false;
  }

  static LocalDataSnapshot? _tryDecodeSnapshot(String raw) {
    try {
      return LocalDataSnapshot.decode(raw);
    } catch (error, stackTrace) {
      debugPrint('LocalDataSnapshot.decode failed: $error\n$stackTrace');
      return null;
    }
  }

  static Future<void> _tryRenameLegacy(File legacyFile) async {
    try {
      await legacyFile.rename('${legacyFile.path}.migrated');
    } catch (_) {
      // Keep legacy file if rename fails.
    }
  }

  static Future<void> _quarantineCorruptPayload({
    required String source,
    required String payload,
    File? file,
  }) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final quarantine = File(
        p.join(dir.path, 'almanac_corrupt_${source}_$stamp.txt'),
      );
      await quarantine.writeAsString(payload);
      if (file != null && await file.exists()) {
        await _tryRenameLegacy(file);
      }
    } catch (error, stackTrace) {
      debugPrint('Quarantine corrupt snapshot failed: $error\n$stackTrace');
    }
  }

  static Future<LocalDataStore> openInMemory({bool seedDemoData = true}) async {
    final scheduleRepository = InMemoryCyclicWorkScheduleRepository(
      seedDemoData: seedDemoData,
    );
    final store = LocalDataStore._(
      profileRepository: InMemoryContextProfileRepository(),
      eventRepository: InMemoryEventRepository(
        scheduleRepository: scheduleRepository,
        seedDemoData: seedDemoData,
      ),
      scheduleRepository: scheduleRepository,
      bookingRepository: InMemoryBookingRepository(seedDemoData: seedDemoData),
      groupPlanRepository: InMemoryGroupPlanRepository(),
      savingsGoalRepository: InMemorySavingsGoalRepository(),
      platformConfigRepository: InMemoryPlatformConfigRepository(),
      snapshotStore: null,
    );
    store._seedDefaults(seedDemoData: seedDemoData);
    return store;
  }

  void bindPersistence() {
    final repos = [
      profileRepository,
      eventRepository,
      scheduleRepository,
      bookingRepository,
      groupPlanRepository,
      savingsGoalRepository,
      platformConfigRepository,
    ];

    for (final repo in repos) {
      if (repo is PersistedRepository) {
        final scheduleRemote = repo is! InMemoryPlatformConfigRepository;
        repo.onChanged = () => _persistSafely(scheduleRemote: scheduleRemote);
      }
    }
  }

  Future<void> persist() async {
    _updatedAt = DateTime.now().toUtc();
    final store = snapshotStore;
    if (store == null) return;
    try {
      final snapshot = _snapshot();
      final ok = store.saveSnapshotJson(LocalDataSnapshot.encode(snapshot));
      if (!ok) {
        debugPrint('LocalDataStore.persist: SQLite save returned false');
      }
    } catch (error, stackTrace) {
      debugPrint('LocalDataStore.persist failed: $error\n$stackTrace');
    }
  }

  /// Текущий снимок для синхронизации (без изменения метки времени).
  LocalDataSnapshot exportSnapshot() => _snapshot();

  /// Восстановить данные из снимка и сохранить локально.
  Future<void> restoreSnapshot(LocalDataSnapshot snapshot) async {
    _restore(snapshot);
    await persist();
  }

  /// Подставить с сервера только один контекстный профиль.
  Future<void> restoreProfileSlice({
    required LocalDataSnapshot remote,
    required String profileId,
  }) async {
    final merged = _snapshot().replacingProfile(remote, profileId);
    _restore(merged);
    await persist();
  }

  /// Добавить с сервера недостающие события профиля, не затирая локальные.
  Future<bool> unionProfileSlice({
    required LocalDataSnapshot remote,
    required String profileId,
    bool remoteWinsConflicts = false,
  }) async {
    final local = _snapshot();
    final merged = local.unionProfile(
      remote,
      profileId,
      incomingWinsConflicts: remoteWinsConflicts,
    );
    if (local.hasSameProfileEntryIds(merged, profileId)) return false;
    _restore(merged);
    await persist();
    return true;
  }

  /// Склеить указанные профили с сервера, не удаляя остальные локальные.
  Future<void> mergeRemoteSnapshot(
    LocalDataSnapshot remote, {
    Set<String>? onlyProfileIds,
  }) async {
    var merged = _snapshot();
    final ids =
        onlyProfileIds ??
        {
          ...remote.profiles.map((profile) => profile.id),
          ...remote.eventsByProfile.keys,
          ...remote.schedulesByProfile.keys,
        };
    for (final profileId in ids) {
      merged = merged.replacingProfile(remote, profileId);
    }
    _restore(merged);
    await persist();
  }

  LocalDataSnapshot _snapshot() {
    final profiles = profileRepository as InMemoryContextProfileRepository;
    final events = eventRepository as InMemoryEventRepository;
    final schedules =
        scheduleRepository as InMemoryCyclicWorkScheduleRepository;
    final bookings = bookingRepository as InMemoryBookingRepository;
    final groupPlans = groupPlanRepository as InMemoryGroupPlanRepository;
    final savingsGoals = savingsGoalRepository as InMemorySavingsGoalRepository;
    final platformConfigs =
        platformConfigRepository as InMemoryPlatformConfigRepository;

    return LocalDataSnapshot(
      profiles: profiles.exportProfiles(),
      activeProfileId: profiles.exportActiveProfileId(),
      visibleProfileIds: profiles.exportVisibleProfileIds(),
      eventsByProfile: events.exportEventsByProfile(),
      schedulesByProfile: schedules.exportSchedulesByProfile(),
      requestsByProfile: bookings.exportRequestsByProfile(),
      templatesByProfile: bookings.exportTemplatesByProfile(),
      groupPlansByProfile: groupPlans.exportPlansByProfile(),
      savingsGoalsByProfile: savingsGoals.exportGoalsByProfile(),
      platformConfigsByProfile: platformConfigs.exportConfigsByProfile(),
      localeLanguageCode: _localeLanguageCode,
      swipeActionsHintSeen: _swipeActionsHintSeen,
      weekDragHintSeen: _weekDragHintSeen,
      hideEmptyWeekHours: _hideEmptyWeekHours,
      weekHourPaddingBefore: _weekHourPaddingBefore,
      weekHourPaddingAfter: _weekHourPaddingAfter,
      weekHourZoomLevel: _weekHourZoomLevel,
      agendaToolbarHintSeen: _agendaToolbarHintSeen,
      calendarMode: _calendarMode,
      savedAccentPresets: _savedAccentPresets,
      eventQuickTemplatesByProfile: _eventQuickTemplatesByProfile.map(
        (profileId, templates) =>
            MapEntry(profileId, List<EventQuickTemplate>.from(templates)),
      ),
      guestCalendarsByProfile: _guestCalendarsByProfile.map(
        (profileId, feeds) =>
            MapEntry(profileId, List<GuestCalendarSubscription>.from(feeds)),
      ),
      updatedAt: _updatedAt,
    );
  }

  void _restore(LocalDataSnapshot snapshot) {
    final profiles = profileRepository as InMemoryContextProfileRepository;
    final events = eventRepository as InMemoryEventRepository;
    final schedules =
        scheduleRepository as InMemoryCyclicWorkScheduleRepository;
    final bookings = bookingRepository as InMemoryBookingRepository;
    final groupPlans = groupPlanRepository as InMemoryGroupPlanRepository;
    final savingsGoals = savingsGoalRepository as InMemorySavingsGoalRepository;
    final platformConfigs =
        platformConfigRepository as InMemoryPlatformConfigRepository;
    final previousConfigs = platformConfigs.exportConfigsByProfile();

    profiles.restore(
      profiles: snapshot.profiles,
      activeProfileId: snapshot.activeProfileId,
      visibleProfileIds: snapshot.visibleProfileIds,
    );
    schedules.restoreSchedulesByProfile(snapshot.schedulesByProfile);
    events.restoreEventsByProfile(snapshot.eventsByProfile);
    bookings.restore(
      templatesByProfile: snapshot.templatesByProfile,
      requestsByProfile: snapshot.requestsByProfile,
    );
    groupPlans.restore(plansByProfile: snapshot.groupPlansByProfile);
    savingsGoals.restoreGoalsByProfile(snapshot.savingsGoalsByProfile);
    platformConfigs.restore(
      configsByProfile: snapshot.platformConfigsByProfile,
    );
    platformConfigs.keepLocalConnectionIfRemoteEmpty(previousConfigs);
    _localeLanguageCode = snapshot.localeLanguageCode;
    _swipeActionsHintSeen = snapshot.swipeActionsHintSeen;
    _weekDragHintSeen = snapshot.weekDragHintSeen;
    _hideEmptyWeekHours = snapshot.hideEmptyWeekHours;
    _weekHourPaddingBefore = snapshot.weekHourPaddingBefore;
    _weekHourPaddingAfter = snapshot.weekHourPaddingAfter;
    _weekHourZoomLevel = snapshot.weekHourZoomLevel;
    _agendaToolbarHintSeen = snapshot.agendaToolbarHintSeen;
    _calendarMode = snapshot.calendarMode;
    _savedAccentPresets = List<int>.from(snapshot.savedAccentPresets);
    _eventQuickTemplatesByProfile
      ..clear()
      ..addAll(
        snapshot.eventQuickTemplatesByProfile.map(
          (profileId, templates) =>
              MapEntry(profileId, List<EventQuickTemplate>.from(templates)),
        ),
      );
    _guestCalendarsByProfile
      ..clear()
      ..addAll(
        snapshot.guestCalendarsByProfile.map(
          (profileId, feeds) =>
              MapEntry(profileId, List<GuestCalendarSubscription>.from(feeds)),
        ),
      );
    if (_localeLanguageCode != null) {
      _refreshDemoLocalizedTitles(_localeLanguageCode!);
    }
    _updatedAt = snapshot.updatedAt;
    _repairLegacyProfileKinds();
  }

  void _repairLegacyProfileKinds() {
    final profiles = profileRepository as InMemoryContextProfileRepository;
    final configs =
        platformConfigRepository as InMemoryPlatformConfigRepository;
    for (final profile in profiles.exportProfiles()) {
      if (profile.kind != ProfileKind.personal) continue;
      final url = configs
          .getOrCreateConfig(profileId: profile.id)
          .serverBaseUrl
          .trim();
      if (url.isEmpty) continue;
      profiles.updateProfile(profile.copyWith(kind: ProfileKind.collaborative));
    }
  }

  /// Сохраняет язык UI и обновляет локализованные demo-заголовки.
  void applyLocale(String languageCode) {
    _localeLanguageCode = languageCode;
    _refreshDemoLocalizedTitles(languageCode);
    _persistSafely();
  }

  void _refreshDemoLocalizedTitles(String languageCode) {
    final l10n = AppLocalizations.forLocale(
      AppLocalizations.localeFromCode(languageCode),
    );
    (profileRepository as InMemoryContextProfileRepository)
        .localizeDefaultProfile(l10n);
    (bookingRepository as InMemoryBookingRepository).localizeDemoContent(l10n);
    (scheduleRepository as InMemoryCyclicWorkScheduleRepository)
        .localizeDemoContent(l10n);
  }

  void _seedDefaults({required bool seedDemoData}) {
    final profiles = profileRepository as InMemoryContextProfileRepository;
    final events = eventRepository as InMemoryEventRepository;
    final schedules =
        scheduleRepository as InMemoryCyclicWorkScheduleRepository;
    final bookings = bookingRepository as InMemoryBookingRepository;
    final groupPlans = groupPlanRepository as InMemoryGroupPlanRepository;
    final savingsGoals = savingsGoalRepository as InMemorySavingsGoalRepository;
    final platformConfigs =
        platformConfigRepository as InMemoryPlatformConfigRepository;
    final l10n = AppLocalizations.forLocale(
      AppLocalizations.localeFromCode(_localeLanguageCode),
    );

    profiles.restore(
      profiles: [ContextProfile(id: 'default', name: l10n.defaultProfileName)],
      activeProfileId: 'default',
      visibleProfileIds: {'default'},
    );
    schedules.ensureProfile('default');
    events.restoreEventsByProfile({
      'default': seedDemoData ? TestEvents.currentYear() : <AppEvent>[],
    });
    bookings.ensureProfile('default');
    groupPlans.ensureProfile('default');
    savingsGoals.ensureProfile('default');
    platformConfigs.getOrCreateConfig(profileId: 'default');
  }

  void _persistSafely({bool scheduleRemote = true}) {
    persist()
        .then((_) {
          if (scheduleRemote) onPersisted?.call();
        })
        .catchError((Object error, StackTrace stackTrace) {
          debugPrint('LocalDataStore persist failed: $error');
        });
  }

  /// Called after a successful local persist (for debounced remote sync).
  void Function()? onPersisted;

  static Future<File> _resolveLegacyJsonFile() async {
    if (kIsWeb) {
      throw UnsupportedError('Local persistence is not supported on web.');
    }

    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, 'almanac_data.json'));
  }
}
