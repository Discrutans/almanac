import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import '../calendar/calendar_types.dart';
import '../calendar/event_time_utils.dart';
import '../data/events/event_repository.dart';
import '../core/localization/app_localizations.dart';

/// Запланированное напоминание (для тестов и планировщика).
@immutable
class EventReminderCandidate {
  const EventReminderCandidate({required this.event, required this.fireAt});

  final AppEvent event;
  final DateTime fireAt;
}

/// Собирает ближайшие напоминания из развёрнутых событий.
List<EventReminderCandidate> collectUpcomingEventReminders({
  required Iterable<AppEvent> events,
  required DateTime now,
  int maxCount = EventReminderService.maxScheduledReminders,
}) {
  final pending = <EventReminderCandidate>[];

  for (final event in events) {
    if (!event.isTimed) continue;
    final minutes = event.reminderMinutesBefore;
    if (minutes == null) continue;

    final fireAt = event.start.toLocal().subtract(Duration(minutes: minutes));
    if (!fireAt.isAfter(now)) continue;

    pending.add(EventReminderCandidate(event: event, fireAt: fireAt));
  }

  pending.sort((a, b) => a.fireAt.compareTo(b.fireAt));
  if (pending.length <= maxCount) return pending;
  return pending.sublist(0, maxCount);
}

/// Планировщик напоминаний о событиях.
///
/// На Android/iOS/macOS/Linux/Windows использует [flutter_local_notifications].
class EventReminderService {
  EventReminderService._();
  static final instance = EventReminderService._();

  /// Payload of a tapped reminder; CalendarScreen opens the event.
  static final pendingEventId = ValueNotifier<String?>(null);

  static const maxScheduledReminders = 64;
  static const reminderHorizonDays = 365;

  final Map<String, DateTime> _scheduled = {};
  FlutterLocalNotificationsPlugin? _notifications;
  bool _nativeReady = false;

  Future<void> initialize() async {
    if (kIsWeb) return;

    try {
      tz_data.initializeTimeZones();
      final timezoneInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezoneInfo.identifier));

      _notifications = FlutterLocalNotificationsPlugin();
      const initSettings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        ),
        macOS: DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        ),
        linux: LinuxInitializationSettings(defaultActionName: 'Open'),
        windows: WindowsInitializationSettings(
          appName: 'Almanac',
          appUserModelId: 'Almanac.Calendar.App',
          guid: 'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
        ),
      );

      final initialized = await _notifications!.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: _onNotificationResponse,
      );
      _nativeReady = initialized ?? false;

      final launch = await _notifications!.getNotificationAppLaunchDetails();
      final launchPayload = launch?.notificationResponse?.payload;
      if (launch?.didNotificationLaunchApp == true &&
          launchPayload != null &&
          launchPayload.isNotEmpty) {
        pendingEventId.value = launchPayload;
      }

      await _requestPlatformPermissions();

      if (kDebugMode) {
        debugPrint(
          'EventReminderService: native=${_nativeReady ? 'on' : 'off'}',
        );
      }
    } catch (error, stackTrace) {
      _nativeReady = false;
      debugPrint('EventReminderService init failed: $error\n$stackTrace');
    }
  }

  Future<void> _requestPlatformPermissions() async {
    final notifications = _notifications;
    if (notifications == null) return;

    if (Platform.isAndroid) {
      final android = notifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await android?.requestNotificationsPermission();
      await android?.requestExactAlarmsPermission();
    }

    if (Platform.isIOS) {
      await notifications
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    }

    if (Platform.isMacOS) {
      await notifications
          .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    }
  }

  Future<void> showInstant({
    required String title,
    required String body,
  }) async {
    if (!_nativeReady || _notifications == null) {
      if (kDebugMode) debugPrint('Instant notification: $title — $body');
      return;
    }

    await _notifications!.show(
      id: title.hashCode & 0x7fffffff,
      title: title,
      body: body,
      notificationDetails: _instantNotificationDetails(),
    );
  }

  /// Перепланирует все ближайшие напоминания по данным репозитория.
  Future<void> syncUpcomingFromRepository({
    required EventRepository eventRepository,
    required Iterable<String> profileIds,
    Locale locale = AppLocalizations.fallback,
  }) async {
    final now = DateTime.now();
    final rangeStart = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: 1));
    final rangeEnd = rangeStart.add(
      const Duration(days: reminderHorizonDays + 1),
    );

    final merged = <AppEvent>[];
    for (final profileId in profileIds) {
      merged.addAll(
        eventRepository.getEventsForRange(
          profileId: profileId,
          rangeStart: rangeStart,
          rangeEnd: rangeEnd,
        ),
      );
    }

    final candidates = collectUpcomingEventReminders(events: merged, now: now);

    if (_nativeReady && _notifications != null) {
      await _notifications!.cancelAll();
    }
    _scheduled.clear();

    for (final candidate in candidates) {
      await _scheduleReminder(
        candidate.event,
        fireAt: candidate.fireAt,
        locale: locale,
      );
    }

    if (kDebugMode && candidates.isNotEmpty) {
      debugPrint(
        'EventReminderService: scheduled ${candidates.length} reminders',
      );
    }
  }

  Future<void> syncEvent(
    AppEvent event, {
    Locale locale = AppLocalizations.fallback,
  }) async {
    await cancelEvent(event.id);
    if (!event.isTimed) return;
    final minutes = event.reminderMinutesBefore;
    if (minutes == null) return;

    final fireAt = event.start.subtract(Duration(minutes: minutes));
    if (!fireAt.isAfter(DateTime.now())) return;

    await _scheduleReminder(event, fireAt: fireAt, locale: locale);
  }

  Future<void> cancelEvent(String eventId) async {
    _scheduled.remove(eventId);
    if (_nativeReady && _notifications != null) {
      await _notifications!.cancel(id: _notificationId(eventId));
    }
  }

  String _reminderKey(AppEvent event) {
    if (event.entrySource.isScheduleRelated) {
      final scheduleId = event.workScheduleId;
      if (scheduleId != null) {
        return AppEvent.scheduleOverrideKey(scheduleId, event.start);
      }
    }
    return event.id;
  }

  Future<void> syncAll(
    Iterable<AppEvent> events, {
    Locale locale = AppLocalizations.fallback,
  }) async {
    if (_nativeReady && _notifications != null) {
      await _notifications!.cancelAll();
    }
    _scheduled.clear();

    final candidates = collectUpcomingEventReminders(
      events: events,
      now: DateTime.now(),
    );
    for (final candidate in candidates) {
      await _scheduleReminder(
        candidate.event,
        fireAt: candidate.fireAt,
        locale: locale,
      );
    }
  }

  Map<String, DateTime> get scheduled => Map.unmodifiable(_scheduled);

  Future<void> _scheduleReminder(
    AppEvent event, {
    required DateTime fireAt,
    Locale locale = AppLocalizations.fallback,
  }) async {
    final minutes = event.reminderMinutesBefore;
    if (minutes == null) return;

    final eventKey = _reminderKey(event);
    _scheduled[eventKey] = fireAt;
    final l10n = AppLocalizations.forLocale(locale);

    if (!_nativeReady || _notifications == null) {
      if (kDebugMode) {
        debugPrint(
          'Reminder (in-memory): ${event.title} at $fireAt '
          '(${l10n.reminderLabel(minutes)})',
        );
      }
      return;
    }

    try {
      await _notifications!.zonedSchedule(
        id: _notificationId(eventKey),
        title: event.title,
        body: _notificationBody(event, minutes, l10n),
        scheduledDate: tz.TZDateTime.from(fireAt, tz.local),
        notificationDetails: _eventReminderDetails(l10n),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: event.id,
      );

      if (kDebugMode) {
        debugPrint(
          'Reminder scheduled: ${event.title} at $fireAt '
          '(${l10n.reminderLabel(minutes)})',
        );
      }
    } catch (error, stackTrace) {
      _scheduled.remove(eventKey);
      debugPrint(
        'EventReminderService schedule failed for ${event.id}: $error\n'
        '$stackTrace',
      );
    }
  }

  NotificationDetails _eventReminderDetails(AppLocalizations l10n) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        'almanac_event_reminders',
        l10n.notificationChannelName,
        channelDescription: l10n.notificationChannelDescription,
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: const DarwinNotificationDetails(),
      macOS: const DarwinNotificationDetails(),
      linux: const LinuxNotificationDetails(),
      windows: const WindowsNotificationDetails(),
    );
  }

  NotificationDetails _instantNotificationDetails() {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        'almanac_session_booking',
        'Session booking',
        channelDescription: 'Booking request alerts',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: const DarwinNotificationDetails(),
      macOS: const DarwinNotificationDetails(),
      linux: const LinuxNotificationDetails(),
      windows: const WindowsNotificationDetails(),
    );
  }

  static void _onNotificationResponse(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;
    pendingEventId.value = payload;
  }

  int _notificationId(String eventId) => eventId.hashCode & 0x7fffffff;

  String _notificationBody(
    AppEvent event,
    int minutesBefore,
    AppLocalizations l10n,
  ) {
    final timeRange = formatEventTimeRange(event);
    if (minutesBefore == 0) return l10n.notificationEventStartingNow;
    if (minutesBefore >= 1440 && minutesBefore % 1440 == 0) {
      return l10n.notificationInDays(minutesBefore ~/ 1440, timeRange);
    }
    if (minutesBefore >= 60 && minutesBefore % 60 == 0) {
      return l10n.notificationInHours(minutesBefore ~/ 60, timeRange);
    }
    return l10n.notificationInMinutes(minutesBefore, timeRange);
  }
}
