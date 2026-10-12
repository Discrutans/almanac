import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:kalender/kalender.dart';
import '../../booking/booking_types.dart';
import '../../calendar/calendar_types.dart';
import '../../finance/pay_types.dart';
import '../../finance/savings_goal_types.dart';
import '../../platform/group_plan_types.dart';
import '../../platform/platform_types.dart';
import '../../platform/server_url.dart';
import '../../core/theme/almanac_tokens.dart';
import '../profiles/context_profile.dart';
import '../events/event_quick_template.dart';
import '../events/recurrence_exdate.dart';
import '../guest/guest_calendar_subscription.dart';
import 'checklist_codec.dart';
import 'attachment_codec.dart';

/// Снимок всех локальных данных приложения.
class LocalDataSnapshot {
  const LocalDataSnapshot({
    required this.profiles,
    required this.activeProfileId,
    required this.visibleProfileIds,
    required this.eventsByProfile,
    required this.schedulesByProfile,
    required this.templatesByProfile,
    required this.requestsByProfile,
    this.groupPlansByProfile = const {},
    this.savingsGoalsByProfile = const {},
    this.platformConfigsByProfile = const {},
    this.updatedAt,
    this.localeLanguageCode,
    this.swipeActionsHintSeen = false,
    this.weekDragHintSeen = false,
    this.hideEmptyWeekHours = false,
    this.weekHourPaddingBefore = 2,
    this.weekHourPaddingAfter = 1,
    this.weekHourZoomLevel = 1,
    this.agendaToolbarHintSeen = false,
    this.calendarMode,
    this.savedAccentPresets = const [],
    this.eventQuickTemplatesByProfile = const {},
    this.guestCalendarsByProfile = const {},
  });

  final List<ContextProfile> profiles;
  final String activeProfileId;
  final Set<String> visibleProfileIds;
  final Map<String, List<AppEvent>> eventsByProfile;
  final Map<String, List<CyclicWorkSchedule>> schedulesByProfile;
  final Map<String, List<BookingTemplate>> templatesByProfile;
  final Map<String, List<BookingRequest>> requestsByProfile;
  final Map<String, List<GroupPlan>> groupPlansByProfile;
  final Map<String, List<SavingsGoal>> savingsGoalsByProfile;
  final Map<String, PlatformConfig> platformConfigsByProfile;
  final DateTime? updatedAt;
  final String? localeLanguageCode;
  final bool swipeActionsHintSeen;
  final bool weekDragHintSeen;
  final bool hideEmptyWeekHours;
  final int weekHourPaddingBefore;
  final int weekHourPaddingAfter;
  final int weekHourZoomLevel;
  final bool agendaToolbarHintSeen;
  final String? calendarMode;
  final List<int> savedAccentPresets;
  final Map<String, List<EventQuickTemplate>> eventQuickTemplatesByProfile;
  final Map<String, List<GuestCalendarSubscription>> guestCalendarsByProfile;

  LocalDataSnapshot withUpdatedAt(DateTime value) => copyWith(updatedAt: value);

  LocalDataSnapshot copyWith({
    List<ContextProfile>? profiles,
    String? activeProfileId,
    Set<String>? visibleProfileIds,
    Map<String, List<AppEvent>>? eventsByProfile,
    Map<String, List<CyclicWorkSchedule>>? schedulesByProfile,
    Map<String, List<BookingTemplate>>? templatesByProfile,
    Map<String, List<BookingRequest>>? requestsByProfile,
    Map<String, List<GroupPlan>>? groupPlansByProfile,
    Map<String, List<SavingsGoal>>? savingsGoalsByProfile,
    Map<String, PlatformConfig>? platformConfigsByProfile,
    DateTime? updatedAt,
    String? localeLanguageCode,
    bool? swipeActionsHintSeen,
    bool? weekDragHintSeen,
    bool? hideEmptyWeekHours,
    int? weekHourPaddingBefore,
    int? weekHourPaddingAfter,
    int? weekHourZoomLevel,
    bool? agendaToolbarHintSeen,
    String? calendarMode,
    List<int>? savedAccentPresets,
    Map<String, List<EventQuickTemplate>>? eventQuickTemplatesByProfile,
    Map<String, List<GuestCalendarSubscription>>? guestCalendarsByProfile,
  }) {
    return LocalDataSnapshot(
      profiles: profiles ?? this.profiles,
      activeProfileId: activeProfileId ?? this.activeProfileId,
      visibleProfileIds: visibleProfileIds ?? this.visibleProfileIds,
      eventsByProfile: eventsByProfile ?? this.eventsByProfile,
      schedulesByProfile: schedulesByProfile ?? this.schedulesByProfile,
      templatesByProfile: templatesByProfile ?? this.templatesByProfile,
      requestsByProfile: requestsByProfile ?? this.requestsByProfile,
      groupPlansByProfile: groupPlansByProfile ?? this.groupPlansByProfile,
      savingsGoalsByProfile:
          savingsGoalsByProfile ?? this.savingsGoalsByProfile,
      platformConfigsByProfile:
          platformConfigsByProfile ?? this.platformConfigsByProfile,
      updatedAt: updatedAt ?? this.updatedAt,
      localeLanguageCode: localeLanguageCode ?? this.localeLanguageCode,
      swipeActionsHintSeen: swipeActionsHintSeen ?? this.swipeActionsHintSeen,
      weekDragHintSeen: weekDragHintSeen ?? this.weekDragHintSeen,
      hideEmptyWeekHours: hideEmptyWeekHours ?? this.hideEmptyWeekHours,
      weekHourPaddingBefore:
          weekHourPaddingBefore ?? this.weekHourPaddingBefore,
      weekHourPaddingAfter: weekHourPaddingAfter ?? this.weekHourPaddingAfter,
      weekHourZoomLevel: weekHourZoomLevel ?? this.weekHourZoomLevel,
      agendaToolbarHintSeen:
          agendaToolbarHintSeen ?? this.agendaToolbarHintSeen,
      calendarMode: calendarMode ?? this.calendarMode,
      savedAccentPresets: savedAccentPresets ?? this.savedAccentPresets,
      eventQuickTemplatesByProfile:
          eventQuickTemplatesByProfile ?? this.eventQuickTemplatesByProfile,
      guestCalendarsByProfile:
          guestCalendarsByProfile ?? this.guestCalendarsByProfile,
    );
  }

  /// Снимок одного контекстного профиля — для отправки без остальных.
  LocalDataSnapshot sliceForProfile(String profileId) {
    final meta = profiles.where((profile) => profile.id == profileId).toList();
    return LocalDataSnapshot(
      profiles: meta,
      activeProfileId: profileId,
      visibleProfileIds: {profileId},
      eventsByProfile: _listSlice(eventsByProfile, profileId),
      schedulesByProfile: _listSlice(schedulesByProfile, profileId),
      templatesByProfile: _listSlice(templatesByProfile, profileId),
      requestsByProfile: _listSlice(requestsByProfile, profileId),
      groupPlansByProfile: _listSlice(groupPlansByProfile, profileId),
      savingsGoalsByProfile: _listSlice(savingsGoalsByProfile, profileId),
      platformConfigsByProfile: _valueSlice(
        platformConfigsByProfile,
        profileId,
      ),
      updatedAt: updatedAt,
      eventQuickTemplatesByProfile: _listSlice(
        eventQuickTemplatesByProfile,
        profileId,
      ),
      guestCalendarsByProfile: _listSlice(guestCalendarsByProfile, profileId),
    );
  }

  /// Профили с тем же Server URL и API-ключом, что и [connection].
  Set<String> profileIdsSharingConnection(PlatformConfig connection) {
    return {
      for (final entry in platformConfigsByProfile.entries)
        if (sameRemoteWorkspace(
          serverBaseUrl: connection.serverBaseUrl,
          apiKey: connection.apiKey,
          otherServerBaseUrl: entry.value.serverBaseUrl,
          otherApiKey: entry.value.apiKey,
        ))
          entry.key,
    };
  }

  /// Снимок нескольких профилей — для отправки только связанных с одним API.
  LocalDataSnapshot sliceForProfiles(Set<String> profileIds) {
    if (profileIds.length == 1) {
      return sliceForProfile(profileIds.first);
    }
    final ids = profileIds;
    final meta = profiles.where((profile) => ids.contains(profile.id)).toList();
    final active = ids.contains(activeProfileId)
        ? activeProfileId
        : (ids.isEmpty ? activeProfileId : ids.first);
    return LocalDataSnapshot(
      profiles: meta,
      activeProfileId: active,
      visibleProfileIds: visibleProfileIds.intersection(ids),
      eventsByProfile: _listSliceMany(eventsByProfile, ids),
      schedulesByProfile: _listSliceMany(schedulesByProfile, ids),
      templatesByProfile: _listSliceMany(templatesByProfile, ids),
      requestsByProfile: _listSliceMany(requestsByProfile, ids),
      groupPlansByProfile: _listSliceMany(groupPlansByProfile, ids),
      savingsGoalsByProfile: _listSliceMany(savingsGoalsByProfile, ids),
      platformConfigsByProfile: {
        for (final id in ids)
          if (platformConfigsByProfile.containsKey(id))
            id: platformConfigsByProfile[id]!,
      },
      updatedAt: updatedAt,
      eventQuickTemplatesByProfile: _listSliceMany(
        eventQuickTemplatesByProfile,
        ids,
      ),
      guestCalendarsByProfile: _listSliceMany(guestCalendarsByProfile, ids),
    );
  }

  /// Добавляет записи профиля с сервера, не затирая локальные с другими id.
  LocalDataSnapshot unionProfile(
    LocalDataSnapshot incoming,
    String profileId, {
    bool incomingWinsConflicts = false,
  }) {
    return copyWith(
      eventsByProfile: _unionListKey(
        eventsByProfile,
        incoming.eventsByProfile,
        profileId,
        idOf: (event) => event.id,
        incomingWinsConflicts: incomingWinsConflicts,
      ),
      schedulesByProfile: _unionListKey(
        schedulesByProfile,
        incoming.schedulesByProfile,
        profileId,
        idOf: (schedule) => schedule.id,
        incomingWinsConflicts: incomingWinsConflicts,
      ),
      templatesByProfile: _unionListKey(
        templatesByProfile,
        incoming.templatesByProfile,
        profileId,
        idOf: (template) => template.id,
        incomingWinsConflicts: incomingWinsConflicts,
      ),
      requestsByProfile: _unionListKey(
        requestsByProfile,
        incoming.requestsByProfile,
        profileId,
        idOf: (request) => request.id,
        incomingWinsConflicts: incomingWinsConflicts,
      ),
      groupPlansByProfile: _unionListKey(
        groupPlansByProfile,
        incoming.groupPlansByProfile,
        profileId,
        idOf: (plan) => plan.id,
        incomingWinsConflicts: incomingWinsConflicts,
      ),
      savingsGoalsByProfile: _unionListKey(
        savingsGoalsByProfile,
        incoming.savingsGoalsByProfile,
        profileId,
        idOf: (goal) => goal.id,
        incomingWinsConflicts: incomingWinsConflicts,
      ),
      eventQuickTemplatesByProfile: _unionListKey(
        eventQuickTemplatesByProfile,
        incoming.eventQuickTemplatesByProfile,
        profileId,
        idOf: (template) => template.id,
        incomingWinsConflicts: incomingWinsConflicts,
      ),
      guestCalendarsByProfile: _unionListKey(
        guestCalendarsByProfile,
        incoming.guestCalendarsByProfile,
        profileId,
        idOf: (feed) => feed.id,
        incomingWinsConflicts: incomingWinsConflicts,
      ),
    );
  }

  bool hasSameProfileEntryIds(LocalDataSnapshot other, String profileId) {
    return _sameIds(
          eventsByProfile[profileId],
          other.eventsByProfile[profileId],
          (event) => event.id,
        ) &&
        _sameIds(
          schedulesByProfile[profileId],
          other.schedulesByProfile[profileId],
          (schedule) => schedule.id,
        );
  }

  /// Подставляет данные [profileId] из [incoming], остальные профили не трогает.
  LocalDataSnapshot replacingProfile(
    LocalDataSnapshot incoming,
    String profileId,
  ) {
    final incomingMeta = incoming.profiles.where(
      (profile) => profile.id == profileId,
    );
    final byId = {for (final profile in profiles) profile.id: profile};
    if (incomingMeta.isNotEmpty) {
      byId[profileId] = incomingMeta.first;
    }
    return copyWith(
      profiles: byId.values.toList(growable: false),
      eventsByProfile: _replaceKey(
        eventsByProfile,
        incoming.eventsByProfile,
        profileId,
      ),
      schedulesByProfile: _replaceKey(
        schedulesByProfile,
        incoming.schedulesByProfile,
        profileId,
      ),
      templatesByProfile: _replaceKey(
        templatesByProfile,
        incoming.templatesByProfile,
        profileId,
      ),
      requestsByProfile: _replaceKey(
        requestsByProfile,
        incoming.requestsByProfile,
        profileId,
      ),
      groupPlansByProfile: _replaceKey(
        groupPlansByProfile,
        incoming.groupPlansByProfile,
        profileId,
      ),
      savingsGoalsByProfile: _replaceKey(
        savingsGoalsByProfile,
        incoming.savingsGoalsByProfile,
        profileId,
      ),
      platformConfigsByProfile: _replaceKey(
        platformConfigsByProfile,
        incoming.platformConfigsByProfile,
        profileId,
      ),
      eventQuickTemplatesByProfile: _replaceKey(
        eventQuickTemplatesByProfile,
        incoming.eventQuickTemplatesByProfile,
        profileId,
      ),
      guestCalendarsByProfile: _replaceKey(
        guestCalendarsByProfile,
        incoming.guestCalendarsByProfile,
        profileId,
      ),
    );
  }

  bool containsProfile(String profileId) {
    return profiles.any((profile) => profile.id == profileId) ||
        eventsByProfile.containsKey(profileId) ||
        schedulesByProfile.containsKey(profileId);
  }

  Map<String, dynamic> toJson() {
    return {
      'version': 2,
      'activeProfileId': activeProfileId,
      'visibleProfileIds': visibleProfileIds.toList(),
      'profiles': profiles.map(_profileToJson).toList(),
      'eventsByProfile': eventsByProfile.map(
        (profileId, events) =>
            MapEntry(profileId, events.map(_eventToJson).toList()),
      ),
      'schedulesByProfile': schedulesByProfile.map(
        (profileId, schedules) =>
            MapEntry(profileId, schedules.map(_scheduleToJson).toList()),
      ),
      'templatesByProfile': templatesByProfile.map(
        (profileId, templates) =>
            MapEntry(profileId, templates.map(_templateToJson).toList()),
      ),
      'requestsByProfile': requestsByProfile.map(
        (profileId, requests) =>
            MapEntry(profileId, requests.map(_requestToJson).toList()),
      ),
      'groupPlansByProfile': groupPlansByProfile.map(
        (profileId, plans) =>
            MapEntry(profileId, plans.map((plan) => plan.toJson()).toList()),
      ),
      'savingsGoalsByProfile': savingsGoalsByProfile.map(
        (profileId, goals) =>
            MapEntry(profileId, goals.map((goal) => goal.toJson()).toList()),
      ),
      'platformConfigsByProfile': platformConfigsByProfile.map(
        (profileId, config) => MapEntry(profileId, config.toJson()),
      ),
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
      if (localeLanguageCode != null) 'localeLanguageCode': localeLanguageCode,
      'swipeActionsHintSeen': swipeActionsHintSeen,
      'weekDragHintSeen': weekDragHintSeen,
      'hideEmptyWeekHours': hideEmptyWeekHours,
      'weekHourPaddingBefore': weekHourPaddingBefore,
      'weekHourPaddingAfter': weekHourPaddingAfter,
      'weekHourZoomLevel': weekHourZoomLevel,
      'agendaToolbarHintSeen': agendaToolbarHintSeen,
      if (calendarMode != null) 'calendarMode': calendarMode,
      if (savedAccentPresets.isNotEmpty)
        'savedAccentPresets': savedAccentPresets,
      if (eventQuickTemplatesByProfile.isNotEmpty)
        'eventQuickTemplatesByProfile': eventQuickTemplatesByProfile.map(
          (profileId, templates) => MapEntry(
            profileId,
            templates.map((template) => template.toJson()).toList(),
          ),
        ),
      if (guestCalendarsByProfile.isNotEmpty)
        'guestCalendarsByProfile': guestCalendarsByProfile.map(
          (profileId, feeds) =>
              MapEntry(profileId, feeds.map((feed) => feed.toJson()).toList()),
        ),
    };
  }

  factory LocalDataSnapshot.fromJson(Map<String, dynamic> json) {
    final profiles = (json['profiles'] as List<dynamic>? ?? const [])
        .map((value) => _profileFromJson(value as Map<String, dynamic>))
        .toList();

    return LocalDataSnapshot(
      profiles: profiles,
      activeProfileId:
          json['activeProfileId'] as String? ??
          profiles.firstOrNull?.id ??
          'default',
      visibleProfileIds: {
        ...((json['visibleProfileIds'] as List<dynamic>? ?? const ['default'])
            .cast<String>()),
      },
      eventsByProfile: _decodeEvents(json['eventsByProfile']),
      schedulesByProfile: _decodeSchedules(json['schedulesByProfile']),
      templatesByProfile: _decodeTemplates(json['templatesByProfile']),
      requestsByProfile: _decodeRequests(json['requestsByProfile']),
      groupPlansByProfile: _decodeGroupPlans(json['groupPlansByProfile']),
      savingsGoalsByProfile: _decodeSavingsGoals(json['savingsGoalsByProfile']),
      platformConfigsByProfile: _decodePlatformConfigs(
        json['platformConfigsByProfile'],
      ),
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
      localeLanguageCode: json['localeLanguageCode'] as String?,
      swipeActionsHintSeen: json['swipeActionsHintSeen'] as bool? ?? false,
      weekDragHintSeen: json['weekDragHintSeen'] as bool? ?? false,
      hideEmptyWeekHours: json['hideEmptyWeekHours'] as bool? ?? false,
      weekHourPaddingBefore: _decodeWeekHourPadding(
        json['weekHourPaddingBefore'],
        fallback: 2,
      ),
      weekHourPaddingAfter: _decodeWeekHourPadding(
        json['weekHourPaddingAfter'],
        fallback: 1,
      ),
      weekHourZoomLevel: _decodeWeekHourZoomLevel(json['weekHourZoomLevel']),
      agendaToolbarHintSeen: json['agendaToolbarHintSeen'] as bool? ?? false,
      calendarMode: json['calendarMode'] as String?,
      savedAccentPresets:
          (json['savedAccentPresets'] as List<dynamic>? ?? const [])
              .map((value) => value as int)
              .toList(),
      eventQuickTemplatesByProfile: _decodeEventQuickTemplates(
        json['eventQuickTemplatesByProfile'],
      ),
      guestCalendarsByProfile: _decodeGuestCalendars(
        json['guestCalendarsByProfile'],
      ),
    );
  }

  static int _decodeWeekHourPadding(Object? raw, {required int fallback}) {
    final value = raw is int ? raw : fallback;
    return value.clamp(0, 6);
  }

  static int _decodeWeekHourZoomLevel(Object? raw) {
    final value = raw is int ? raw : 1;
    return value.clamp(1, 2);
  }

  static Map<String, List<EventQuickTemplate>> _decodeEventQuickTemplates(
    Object? raw,
  ) {
    if (raw is! Map<String, dynamic>) return const {};
    return raw.map(
      (profileId, value) => MapEntry(
        profileId,
        (value as List<dynamic>)
            .map(
              (item) =>
                  EventQuickTemplate.fromJson(item as Map<String, dynamic>),
            )
            .toList(),
      ),
    );
  }

  static Map<String, List<GuestCalendarSubscription>> _decodeGuestCalendars(
    Object? raw,
  ) {
    if (raw is! Map<String, dynamic>) return const {};
    return raw.map(
      (profileId, value) => MapEntry(
        profileId,
        (value as List<dynamic>)
            .map(
              (item) => GuestCalendarSubscription.fromJson(
                item as Map<String, dynamic>,
              ),
            )
            .toList(),
      ),
    );
  }

  static Map<String, dynamic> _profileToJson(ContextProfile profile) {
    return {
      'id': profile.id,
      'name': profile.name,
      'kind': profile.kind.name,
      'role': profile.role.name,
      'themeMode': profile.themeMode.name,
      'seedColor': profile.seedColor.toARGB32(),
      'accentColor': profile.accentColor.toARGB32(),
    };
  }

  static ContextProfile _profileFromJson(Map<String, dynamic> json) {
    return ContextProfile(
      id: json['id'] as String,
      name: json['name'] as String,
      kind: profileKindFromName(json['kind'] as String?),
      role: profileRoleFromName(json['role'] as String?),
      themeMode: ThemeMode.values.byName(
        json['themeMode'] as String? ?? 'system',
      ),
      seedColor: Color(json['seedColor'] as int? ?? 0xFF2196F3),
      accentColor: Color(
        json['accentColor'] as int? ?? AlmanacBrand.accentEnd.toARGB32(),
      ),
    );
  }

  static Map<String, dynamic> _eventToJson(AppEvent event) {
    return {
      'id': event.id,
      'title': event.title,
      'start': event.start.toIso8601String(),
      'end': event.end.toIso8601String(),
      'startTime': event.startTime,
      'endTime': event.endTime,
      'kind': event.kind.name,
      'colorValue': event.color.toARGB32(),
      'rrule': RecurrenceExdateCodec.encodeStored(
        rrule: event.rrule,
        exclusionDays: event.recurrenceExclusions,
        seriesStart: event.start,
      ),
      'recurrenceUntil': event.recurrenceUntil?.toIso8601String(),
      'seriesId': event.seriesId,
      if (event.parentEventId != null) 'parentEventId': event.parentEventId,
      if (event.recurrenceExclusions.isNotEmpty)
        'recurrenceExclusions': event.recurrenceExclusions
            .map((day) => AppEvent.recurrenceDayKey(day).millisecondsSinceEpoch)
            .toList(),
      if (event.explicitEntrySource != null)
        'entrySource': event.explicitEntrySource!.name,
      'checklistJson': ChecklistCodec.encode(event.checklist),
      if (event.notes != null && event.notes!.isNotEmpty) 'notes': event.notes,
      if (event.isUndated) 'isUndated': true,
      if (event.incomeAmount != null) 'incomeAmount': event.incomeAmount,
      if (event.isGift) 'isGift': true,
      if (event.reminderMinutesBefore != null)
        'reminderMinutesBefore': event.reminderMinutesBefore,
      if (event.overtimeMinutes != null)
        'overtimeMinutes': event.overtimeMinutes,
      if (event.shiftSkipped) 'shiftSkipped': true,
      if (event.unpaidMinutes != null) 'unpaidMinutes': event.unpaidMinutes,
      if (event.pomodoroEnabled) 'pomodoroEnabled': true,
      if (event.pomodoroWorkMinutes != 25)
        'pomodoroWorkMinutes': event.pomodoroWorkMinutes,
      if (event.pomodoroBreakMinutes != 5)
        'pomodoroBreakMinutes': event.pomodoroBreakMinutes,
      if (event.pomodoroCompletedSessions > 0)
        'pomodoroCompletedSessions': event.pomodoroCompletedSessions,
      if (event.pomodoroRemainingSeconds != null)
        'pomodoroRemainingSeconds': event.pomodoroRemainingSeconds,
      if (event.pomodoroOnBreak == true) 'pomodoroOnBreak': true,
      if (event.pomodoroWorkRemainingSeconds != null)
        'pomodoroWorkRemainingSeconds': event.pomodoroWorkRemainingSeconds,
      if (event.pomodoroBreakRemainingSeconds != null)
        'pomodoroBreakRemainingSeconds': event.pomodoroBreakRemainingSeconds,
      if (event.attachments.isNotEmpty)
        'attachmentsJson': AttachmentCodec.encode(event.attachments),
    };
  }

  static AppEvent _eventFromJson(Map<String, dynamic> json) {
    final start = DateTime.parse(json['start'] as String);
    final end = DateTime.parse(json['end'] as String);
    final storedRecurrence = json['rrule'] as String?;
    final parsedRecurrence = RecurrenceExdateCodec.parseStored(
      storedRecurrence,
    );
    final recurrenceExclusions = RecurrenceExdateCodec.mergeExclusionDays(
      parsedRecurrence.exdates,
      _recurrenceExclusionsFromJson(json),
    );

    return AppEvent(
      id: json['id'] as String,
      dateTimeRange: DateTimeRange(start: start, end: end),
      title: json['title'] as String,
      startTime: json['startTime'] as String,
      endTime: json['endTime'] as String,
      kind: AppEvent.kindFromStorage(json['kind'] as String?),
      color: Color(json['colorValue'] as int),
      checklist: ChecklistCodec.decode(json['checklistJson'] as String?),
      rrule: parsedRecurrence.rrule,
      recurrenceUntil: json['recurrenceUntil'] == null
          ? null
          : DateTime.parse(json['recurrenceUntil'] as String),
      seriesId: json['seriesId'] as String?,
      parentEventId: json['parentEventId'] as String?,
      recurrenceExclusions: recurrenceExclusions,
      explicitEntrySource: CalendarEntrySourceX.fromStorage(
        json['entrySource'] as String?,
      ),
      notes: json['notes'] as String?,
      isUndated: json['isUndated'] as bool? ?? false,
      incomeAmount: (json['incomeAmount'] as num?)?.toDouble(),
      isGift: json['isGift'] as bool? ?? false,
      reminderMinutesBefore: json['reminderMinutesBefore'] as int?,
      overtimeMinutes: json['overtimeMinutes'] as int?,
      shiftSkipped: json['shiftSkipped'] as bool? ?? false,
      unpaidMinutes: json['unpaidMinutes'] as int?,
      pomodoroEnabled: json['pomodoroEnabled'] as bool? ?? false,
      pomodoroWorkMinutes: json['pomodoroWorkMinutes'] as int? ?? 25,
      pomodoroBreakMinutes: json['pomodoroBreakMinutes'] as int? ?? 5,
      pomodoroCompletedSessions: json['pomodoroCompletedSessions'] as int? ?? 0,
      pomodoroRemainingSeconds: json['pomodoroRemainingSeconds'] as int?,
      pomodoroOnBreak: json['pomodoroOnBreak'] as bool?,
      pomodoroWorkRemainingSeconds:
          json['pomodoroWorkRemainingSeconds'] as int?,
      pomodoroBreakRemainingSeconds:
          json['pomodoroBreakRemainingSeconds'] as int?,
      attachments: AttachmentCodec.decode(json['attachmentsJson'] as String?),
      interaction: EventInteraction.allowNone(),
    );
  }

  static List<DateTime> _recurrenceExclusionsFromJson(
    Map<String, dynamic> json,
  ) {
    final raw = json['recurrenceExclusions'];
    if (raw is! List) return const [];
    return raw
        .whereType<num>()
        .map((value) => DateTime.fromMillisecondsSinceEpoch(value.toInt()))
        .map(AppEvent.recurrenceDayKey)
        .toList();
  }

  static Map<String, dynamic> _scheduleToJson(CyclicWorkSchedule schedule) {
    return {
      'id': schedule.id,
      'profileId': schedule.profileId,
      'title': schedule.title,
      'kind': schedule.kind.name,
      'rrule': schedule.rrule,
      'cycleStartDate': schedule.cycleStartDate?.toIso8601String(),
      'workDays': schedule.workDays,
      'restDays': schedule.restDays,
      'startTime': schedule.startTime,
      'endTime': schedule.endTime,
      'colorValue': schedule.colorValue,
      'payMode': schedule.payMode.name,
      if (schedule.hourlyRate != null) 'hourlyRate': schedule.hourlyRate,
      if (schedule.dailyRate != null) 'dailyRate': schedule.dailyRate,
      if (schedule.monthlyRate != null) 'monthlyRate': schedule.monthlyRate,
      'standardHoursPerShift': schedule.standardHoursPerShift,
      'overtimeMultiplier': schedule.overtimeMultiplier,
      if (schedule.breakMinutes != 0) 'breakMinutes': schedule.breakMinutes,
      if (schedule.bonusPercent != null) 'bonusPercent': schedule.bonusPercent,
      if (schedule.bonusAmount != null) 'bonusAmount': schedule.bonusAmount,
      if (schedule.vatPercent != null)
        'vatWithholdingPercent': schedule.vatPercent,
    };
  }

  static CyclicWorkSchedule _scheduleFromJson(Map<String, dynamic> json) {
    return CyclicWorkSchedule(
      id: json['id'] as String,
      profileId: json['profileId'] as String,
      title: json['title'] as String,
      kind: CyclicScheduleKind.values.byName(
        json['kind'] as String? ?? 'rrule',
      ),
      rrule: json['rrule'] as String? ?? '',
      cycleStartDate: json['cycleStartDate'] == null
          ? null
          : DateTime.parse(json['cycleStartDate'] as String),
      workDays: json['workDays'] as int? ?? 0,
      restDays: json['restDays'] as int? ?? 0,
      startTime: json['startTime'] as String,
      endTime: json['endTime'] as String,
      colorValue: json['colorValue'] as int,
      payMode: PayRateMode.values.byName(
        json['payMode'] as String? ?? 'hourly',
      ),
      hourlyRate: (json['hourlyRate'] as num?)?.toDouble(),
      dailyRate: (json['dailyRate'] as num?)?.toDouble(),
      monthlyRate: (json['monthlyRate'] as num?)?.toDouble(),
      standardHoursPerShift:
          (json['standardHoursPerShift'] as num?)?.toDouble() ?? 8,
      overtimeMultiplier:
          (json['overtimeMultiplier'] as num?)?.toDouble() ?? 1.5,
      breakMinutes: json['breakMinutes'] as int? ?? 0,
      bonusPercent:
          (json['bonusPercent'] as num?)?.toDouble() ??
          (json.containsKey('vatWithholdingPercent')
              ? null
              : (json['vatPercent'] as num?)?.toDouble()),
      bonusAmount: (json['bonusAmount'] as num?)?.toDouble(),
      vatPercent: (json['vatWithholdingPercent'] as num?)?.toDouble(),
    );
  }

  static Map<String, dynamic> _templateToJson(BookingTemplate template) {
    return {
      'id': template.id,
      'profileId': template.profileId,
      'token': template.token,
      'title': template.title,
      'durationMinutes': template.duration.inMinutes,
      'confirmationMode': template.confirmationMode.name,
    };
  }

  static BookingTemplate _templateFromJson(Map<String, dynamic> json) {
    return BookingTemplate(
      id: json['id'] as String,
      profileId: json['profileId'] as String,
      token: json['token'] as String,
      title: json['title'] as String,
      duration: Duration(minutes: json['durationMinutes'] as int),
      confirmationMode: BookingConfirmationMode.values.byName(
        json['confirmationMode'] as String,
      ),
    );
  }

  static Map<String, dynamic> _requestToJson(BookingRequest request) {
    return {
      'id': request.id,
      'profileId': request.profileId,
      'templateId': request.templateId,
      'templateToken': request.templateToken,
      'start': request.start.toIso8601String(),
      'end': request.end.toIso8601String(),
      'createdAt': request.createdAt.toIso8601String(),
      'status': request.status.name,
      'notes': request.notes,
    };
  }

  static BookingRequest _requestFromJson(Map<String, dynamic> json) {
    return BookingRequest(
      id: json['id'] as String,
      profileId: json['profileId'] as String,
      templateId: json['templateId'] as String,
      templateToken: json['templateToken'] as String,
      start: DateTime.parse(json['start'] as String),
      end: DateTime.parse(json['end'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      status: BookingRequestStatus.values.byName(json['status'] as String),
      notes: json['notes'] as String?,
    );
  }

  static Map<String, List<AppEvent>> _decodeEvents(Object? raw) {
    if (raw is! Map<String, dynamic>) return {};
    return raw.map(
      (profileId, value) => MapEntry(
        profileId,
        (value as List<dynamic>)
            .map((item) => _eventFromJson(item as Map<String, dynamic>))
            .toList(),
      ),
    );
  }

  static Map<String, List<CyclicWorkSchedule>> _decodeSchedules(Object? raw) {
    if (raw is! Map<String, dynamic>) return {};
    return raw.map(
      (profileId, value) => MapEntry(
        profileId,
        (value as List<dynamic>)
            .map((item) => _scheduleFromJson(item as Map<String, dynamic>))
            .toList(),
      ),
    );
  }

  static Map<String, List<BookingTemplate>> _decodeTemplates(Object? raw) {
    if (raw is! Map<String, dynamic>) return {};
    return raw.map(
      (profileId, value) => MapEntry(
        profileId,
        (value as List<dynamic>)
            .map((item) => _templateFromJson(item as Map<String, dynamic>))
            .toList(),
      ),
    );
  }

  static Map<String, List<BookingRequest>> _decodeRequests(Object? raw) {
    if (raw is! Map<String, dynamic>) return {};
    return raw.map(
      (profileId, value) => MapEntry(
        profileId,
        (value as List<dynamic>)
            .map((item) => _requestFromJson(item as Map<String, dynamic>))
            .toList(),
      ),
    );
  }

  static Map<String, List<GroupPlan>> _decodeGroupPlans(Object? raw) {
    if (raw is! Map<String, dynamic>) return {};
    return raw.map(
      (profileId, value) => MapEntry(
        profileId,
        (value as List<dynamic>)
            .map((item) => GroupPlan.fromJson(item as Map<String, dynamic>))
            .toList(),
      ),
    );
  }

  static Map<String, List<SavingsGoal>> _decodeSavingsGoals(Object? raw) {
    if (raw is! Map<String, dynamic>) return {};
    return raw.map(
      (profileId, value) => MapEntry(
        profileId,
        (value as List<dynamic>)
            .map((item) => SavingsGoal.fromJson(item as Map<String, dynamic>))
            .toList(),
      ),
    );
  }

  static Map<String, PlatformConfig> _decodePlatformConfigs(Object? raw) {
    if (raw is! Map<String, dynamic>) return {};
    return raw.map(
      (profileId, value) => MapEntry(
        profileId,
        PlatformConfig.fromJson(value as Map<String, dynamic>),
      ),
    );
  }

  static Map<String, List<T>> _listSlice<T>(
    Map<String, List<T>> source,
    String profileId,
  ) {
    return _listSliceMany(source, {profileId});
  }

  static Map<String, List<T>> _listSliceMany<T>(
    Map<String, List<T>> source,
    Set<String> profileIds,
  ) {
    return {
      for (final profileId in profileIds)
        profileId: List<T>.from(source[profileId] ?? const []),
    };
  }

  static Map<String, T> _valueSlice<T>(
    Map<String, T> source,
    String profileId,
  ) {
    final value = source[profileId];
    return value == null ? <String, T>{} : {profileId: value};
  }

  static Map<String, T> _replaceKey<T>(
    Map<String, T> current,
    Map<String, T> incoming,
    String profileId,
  ) {
    if (!incoming.containsKey(profileId)) return current;
    return {...current, profileId: incoming[profileId] as T};
  }

  static Map<String, List<T>> _unionListKey<T>(
    Map<String, List<T>> current,
    Map<String, List<T>> incoming,
    String profileId, {
    required String Function(T) idOf,
    required bool incomingWinsConflicts,
  }) {
    final merged = _unionById<T>(
      current[profileId] ?? <T>[],
      incoming[profileId] ?? <T>[],
      idOf: idOf,
      incomingWinsConflicts: incomingWinsConflicts,
    );
    return {...current, profileId: merged};
  }

  static List<T> _unionById<T>(
    List<T> local,
    List<T> incoming, {
    required String Function(T) idOf,
    required bool incomingWinsConflicts,
  }) {
    final byId = <String, T>{for (final item in local) idOf(item): item};
    for (final item in incoming) {
      final id = idOf(item);
      if (!byId.containsKey(id) || incomingWinsConflicts) {
        byId[id] = item;
      }
    }
    return byId.values.toList(growable: false);
  }

  static bool _sameIds<T>(
    List<T>? left,
    List<T>? right,
    String Function(T) idOf,
  ) {
    final a = {for (final item in left ?? <T>[]) idOf(item)};
    final b = {for (final item in right ?? <T>[]) idOf(item)};
    return a.length == b.length && a.containsAll(b);
  }

  static String encode(LocalDataSnapshot snapshot) {
    return jsonEncode(snapshot.toJson());
  }

  static LocalDataSnapshot decode(String raw) {
    return LocalDataSnapshot.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }
}

extension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
