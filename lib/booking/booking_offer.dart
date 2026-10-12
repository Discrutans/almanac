import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:kalender/kalender.dart';

import '../calendar/calendar_event_index.dart';
import '../calendar/calendar_types.dart';
import '../core/theme/almanac_tokens.dart';
import '../platform/session_types.dart';

class BookingOfferGuest {
  const BookingOfferGuest({
    required this.profileId,
    required this.name,
    this.fields = const {},
  });

  final String profileId;
  final String name;
  final Map<String, String> fields;

  Map<String, dynamic> toJson() => {
    'p': profileId,
    'n': name,
    if (fields.isNotEmpty) 'f': fields,
  };

  factory BookingOfferGuest.fromJson(Map<String, dynamic> json) {
    final rawFields = json['f'] as Map<String, dynamic>? ?? const {};
    return BookingOfferGuest(
      profileId: '${json['p'] ?? ''}',
      name: '${json['n'] ?? ''}',
      fields: {
        for (final entry in rawFields.entries) entry.key: '${entry.value}',
      },
    );
  }
}

class BookingOfferState {
  const BookingOfferState({
    required this.originalTitle,
    this.capacity = 1,
    this.formFields = const [],
    this.bookings = const [],
  });

  final String originalTitle;
  final int capacity;
  final List<SessionFormField> formFields;
  final List<BookingOfferGuest> bookings;

  int get taken => bookings.length;
  int get free => (capacity - taken).clamp(0, capacity);
  bool get isFull => free <= 0;

  bool isBookedBy(String profileId, {String? guestName}) {
    for (final guest in bookings) {
      if (guest.profileId == profileId) return true;
    }
    final name = guestName?.trim() ?? '';
    if (name.isEmpty) return false;
    return bookings.any((guest) => guest.name == name);
  }

  BookingOfferState add(BookingOfferGuest guest) {
    if (isBookedBy(guest.profileId)) return this;
    if (isFull) return this;
    return BookingOfferState(
      originalTitle: originalTitle,
      capacity: capacity,
      formFields: formFields,
      bookings: [...bookings, guest],
    );
  }

  BookingOfferState remove(String profileId) {
    return BookingOfferState(
      originalTitle: originalTitle,
      capacity: capacity,
      formFields: formFields,
      bookings: [
        for (final guest in bookings)
          if (guest.profileId != profileId) guest,
      ],
    );
  }

  BookingOfferState clearBookings() {
    return BookingOfferState(
      originalTitle: originalTitle,
      capacity: capacity,
      formFields: formFields,
    );
  }

  String displayTitle({required bool forOwner}) {
    if (bookings.isEmpty) return originalTitle;
    if (!forOwner) return originalTitle;
    final names = [
      for (final guest in bookings)
        if (guest.name.trim().isNotEmpty) guest.name.trim(),
    ];
    final who = names.isEmpty
        ? originalTitle
        : '$originalTitle — ${names.join(', ')}';
    if (capacity <= 1) return who;
    return '$who ($taken/$capacity)';
  }
}

/// Свободные слоты записи, которые живут в снимке календаря (YDB), без FastAPI.
abstract final class BookingOfferEvents {
  static const _bookerPrefix = 'booker:';

  static AppEvent fromSlot({
    required SessionSlot slot,
    required String title,
    required String profileId,
    int capacity = 1,
    List<SessionFormField> formFields = const [],
  }) {
    final start = slot.start.toLocal();
    final end = slot.end.toLocal();
    final state = BookingOfferState(
      originalTitle: title,
      capacity: capacity < 1 ? 1 : capacity,
      formFields: formFields,
    );
    return AppEvent(
      id: AppEvent.bookingOfferEventId(slot.id),
      dateTimeRange: DateTimeRange(start: start, end: end),
      title: title,
      startTime: _hhmm(start),
      endTime: _hhmm(end),
      color: AlmanacBrand.bookingOpen,
      checklist: const [],
      interaction: EventInteraction.allowNone(),
      contextProfileId: profileId,
      notes: encodeState(state),
    ).taggedWith(CalendarEntrySource.bookingOffer);
  }

  static AppEvent booked({
    required AppEvent offer,
    required String guestProfileId,
    required String guestName,
    Map<String, String> fields = const {},
  }) {
    return applyGuest(
      offer: offer,
      guest: BookingOfferGuest(
        profileId: guestProfileId,
        name: guestName.trim(),
        fields: fields,
      ),
    );
  }

  static AppEvent applyGuest({
    required AppEvent offer,
    required BookingOfferGuest guest,
  }) {
    final next = readState(offer).add(guest);
    return _withState(offer, next);
  }

  static AppEvent released(AppEvent booked, {String? guestProfileId}) {
    final current = readState(booked);
    final next = guestProfileId == null || guestProfileId.isEmpty
        ? current.clearBookings()
        : current.remove(guestProfileId);
    return _withState(booked, next);
  }

  static AppEvent occupiedView(AppEvent booked, String occupiedTitle) {
    return booked.copyWith(title: occupiedTitle, notes: occupiedTitle);
  }

  static bool isBookingSurface(AppEvent event) {
    switch (event.entrySource) {
      case CalendarEntrySource.bookingOffer:
      case CalendarEntrySource.booking:
      case CalendarEntrySource.bookingSlot:
      case CalendarEntrySource.bookingPending:
        return true;
      case CalendarEntrySource.personal:
      case CalendarEntrySource.scheduleGenerated:
      case CalendarEntrySource.scheduleOverride:
      case CalendarEntrySource.savingsGoalProjected:
      case CalendarEntrySource.guestCalendar:
        return false;
    }
  }

  static bool isBookedBy(
    AppEvent event, {
    required String profileId,
    String? guestName,
  }) {
    if (!isBookingSurface(event)) return false;
    return readState(event).isBookedBy(profileId, guestName: guestName);
  }

  static List<AppEvent> surfaceForGuest({
    required Iterable<AppEvent> events,
    required String guestProfileId,
    required String occupiedTitle,
    String? guestName,
  }) {
    final result = <AppEvent>[];
    for (final event in events) {
      if (!isBookingSurface(event)) continue;
      final state = readState(event);
      final mine = state.isBookedBy(guestProfileId, guestName: guestName);
      if (mine) {
        result.add(
          event.copyWith(
            title: state.displayTitle(forOwner: true),
            explicitEntrySource: CalendarEntrySource.booking,
          ),
        );
      } else if (!state.isFull) {
        result.add(
          event.copyWith(
            title: state.originalTitle,
            explicitEntrySource: CalendarEntrySource.bookingOffer,
          ),
        );
      } else {
        result.add(occupiedView(event, occupiedTitle));
      }
    }
    return result;
  }

  static BookingOfferState readState(AppEvent event) {
    return parseState(event.notes, fallbackTitle: event.title);
  }

  static String encodeState(BookingOfferState state) {
    return jsonEncode({
      'v': 1,
      'title': state.originalTitle,
      'capacity': state.capacity,
      'fields': [for (final field in state.formFields) field.toJson()],
      'bookings': [for (final guest in state.bookings) guest.toJson()],
    });
  }

  static BookingOfferState parseState(
    String? notes, {
    String fallbackTitle = '',
  }) {
    final raw = notes?.trim() ?? '';
    if (raw.startsWith('{')) {
      try {
        final json = jsonDecode(raw) as Map<String, dynamic>;
        final fields = (json['fields'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(SessionFormField.fromJson)
            .toList();
        final bookings = (json['bookings'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(BookingOfferGuest.fromJson)
            .toList();
        final title = '${json['title'] ?? fallbackTitle}';
        final capacity = json['capacity'] as int? ?? 1;
        return BookingOfferState(
          originalTitle: title.isEmpty ? fallbackTitle : title,
          capacity: capacity < 1 ? 1 : capacity,
          formFields: fields,
          bookings: bookings,
        );
      } catch (_) {
        // Fall through to legacy notes.
      }
    }
    final legacy = parseBooker(raw);
    if (legacy != null) {
      return BookingOfferState(
        originalTitle: legacy.originalTitle.isEmpty
            ? fallbackTitle
            : legacy.originalTitle,
        bookings: [
          BookingOfferGuest(profileId: legacy.profileId, name: legacy.name),
        ],
      );
    }
    return BookingOfferState(originalTitle: fallbackTitle);
  }

  static String encodeBooker({
    required String profileId,
    required String name,
    required String originalTitle,
  }) {
    return encodeState(
      BookingOfferState(
        originalTitle: originalTitle,
        bookings: [BookingOfferGuest(profileId: profileId, name: name)],
      ),
    );
  }

  static BookingOfferBooker? parseBooker(String? notes) {
    final raw = notes?.trim() ?? '';
    if (raw.startsWith('{')) {
      final state = parseState(raw);
      if (state.bookings.isEmpty) return null;
      final guest = state.bookings.first;
      return BookingOfferBooker(
        profileId: guest.profileId,
        name: guest.name,
        originalTitle: state.originalTitle,
      );
    }
    if (!raw.startsWith(_bookerPrefix)) return null;
    final lines = raw.split('\n');
    final profileId = lines.first.substring(_bookerPrefix.length).trim();
    if (profileId.isEmpty) return null;
    return BookingOfferBooker(
      profileId: profileId,
      originalTitle: lines.length > 1 ? lines[1] : '',
      name: lines.length > 2 ? lines.sublist(2).join('\n') : '',
    );
  }

  static bool isOnDate(AppEvent event, DateTime date) {
    final start = event.start.toLocal();
    final day = calendarDayKey(date);
    return start.year == day.year &&
        start.month == day.month &&
        start.day == day.day;
  }

  static String timeLabel(AppEvent event) {
    if (event.endTime.trim().isEmpty) return event.startTime;
    return '${event.startTime}–${event.endTime}';
  }

  static AppEvent _withState(AppEvent event, BookingOfferState state) {
    return event.copyWith(
      title: state.displayTitle(forOwner: true),
      notes: encodeState(state),
      color: state.isFull ? AlmanacBrand.bookingFull : AlmanacBrand.bookingOpen,
      explicitEntrySource: state.isFull
          ? CalendarEntrySource.booking
          : CalendarEntrySource.bookingOffer,
    );
  }
}

class BookingOfferBooker {
  const BookingOfferBooker({
    required this.profileId,
    required this.name,
    required this.originalTitle,
  });

  final String profileId;
  final String name;
  final String originalTitle;
}

String _hhmm(DateTime value) =>
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
