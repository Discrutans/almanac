import 'package:almanac/booking/booking_offer.dart';
import 'package:almanac/booking/ydb_offer_booking_service.dart';
import 'package:almanac/calendar/calendar_entry_capabilities.dart';
import 'package:almanac/calendar/calendar_types.dart';
import 'package:almanac/platform/session_types.dart';
import 'package:almanac/platform/ydb/ydb_workspace_connection.dart';
import 'package:almanac/data/profiles/profile_kind.dart';
import 'package:almanac/platform/ydb/ydb_connection_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('YdbWorkspaceConnection keeps booking guestKind in JSON', () {
    const connection = YdbWorkspaceConnection(
      endpoint: YdbConnectionConfig.defaultEndpoint,
      database: '/ru-central1/b1g/etn',
      secret: '{}',
      workspaceApiKey: 'k',
      workspaceProfileId: 'p1',
      guestKind: ProfileKind.booking,
    );
    final restored = YdbWorkspaceConnection.fromJson(connection.toJson());
    expect(restored.guestKind, ProfileKind.booking);
    expect(connection.toPublicJson().containsKey('secret'), isFalse);
    expect(connection.toPublicJson()['workspaceApiKey'], 'k');
  });

  test('booking form display name prefers client_name', () {
    expect(
      YdbOfferBookingService.displayName(
        fields: const {'client_name': 'Анна', 'phone': '1'},
        fallback: 'Гость',
      ),
      'Анна',
    );
    expect(
      YdbOfferBookingService.displayName(
        fields: const {'phone': '123'},
        fallback: 'Гость',
      ),
      '123',
    );
  });

  test('booking offer converts to a persisted booking for the guest', () {
    final start = DateTime(2026, 9, 16, 11);
    final offer = BookingOfferEvents.fromSlot(
      slot: SessionSlot(
        id: 'slot-a',
        start: start,
        end: start.add(const Duration(hours: 1)),
      ),
      title: 'Стрижка',
      profileId: 'studio',
    );

    expect(offer.entrySource, CalendarEntrySource.bookingOffer);
    expect(offer.id, AppEvent.bookingOfferEventId('slot-a'));
    expect(offer.isPersistedMaster, isTrue);
    expect(BookingOfferEvents.isOnDate(offer, DateTime(2026, 9, 16)), isTrue);
    expect(BookingOfferEvents.timeLabel(offer), '11:00–12:00');

    final booked = BookingOfferEvents.booked(
      offer: offer,
      guestProfileId: 'anna',
      guestName: 'Анна',
    );
    expect(booked.id, offer.id);
    expect(booked.entrySource, CalendarEntrySource.booking);
    expect(booked.title, 'Стрижка — Анна');
    expect(booked.isPersistedMaster, isTrue);
    expect(BookingOfferEvents.isBookedBy(booked, profileId: 'anna'), isTrue);
    expect(BookingOfferEvents.isBookedBy(booked, profileId: 'other'), isFalse);

    final released = BookingOfferEvents.released(booked);
    expect(released.entrySource, CalendarEntrySource.bookingOffer);
    expect(released.title, 'Стрижка');
  });

  test('booking offers keep capacity until the slot is full', () {
    final start = DateTime(2026, 9, 16, 11);
    var slot = BookingOfferEvents.fromSlot(
      slot: SessionSlot(
        id: 'slot-c',
        start: start,
        end: start.add(const Duration(hours: 1)),
      ),
      title: 'Массаж',
      profileId: 'studio',
      capacity: 2,
      formFields: const [SessionFormField(id: 'client_name', label: 'Имя')],
    );
    expect(slot.entrySource, CalendarEntrySource.bookingOffer);
    expect(BookingOfferEvents.readState(slot).capacity, 2);

    slot = BookingOfferEvents.booked(
      offer: slot,
      guestProfileId: 'anna',
      guestName: 'Анна',
      fields: const {'client_name': 'Анна'},
    );
    expect(slot.entrySource, CalendarEntrySource.bookingOffer);
    expect(slot.title, 'Массаж — Анна (1/2)');

    slot = BookingOfferEvents.booked(
      offer: slot,
      guestProfileId: 'olga',
      guestName: 'Ольга',
    );
    expect(slot.entrySource, CalendarEntrySource.booking);
    expect(BookingOfferEvents.readState(slot).isFull, isTrue);

    slot = BookingOfferEvents.released(slot, guestProfileId: 'anna');
    expect(slot.entrySource, CalendarEntrySource.bookingOffer);
    expect(BookingOfferEvents.readState(slot).taken, 1);
  });

  test('booking guests see only slots and hide other guests names', () {
    final start = DateTime(2026, 9, 16, 11);
    final offer = BookingOfferEvents.fromSlot(
      slot: SessionSlot(
        id: 'slot-a',
        start: start,
        end: start.add(const Duration(hours: 1)),
      ),
      title: 'Стрижка',
      profileId: 'studio',
    );
    final mine = BookingOfferEvents.booked(
      offer: offer,
      guestProfileId: 'anna',
      guestName: 'Анна',
    );
    final other = BookingOfferEvents.booked(
      offer: BookingOfferEvents.fromSlot(
        slot: SessionSlot(
          id: 'slot-b',
          start: start.add(const Duration(hours: 1)),
          end: start.add(const Duration(hours: 2)),
        ),
        title: 'Стрижка',
        profileId: 'studio',
      ),
      guestProfileId: 'olga',
      guestName: 'Ольга',
    );
    final personal = AppEvent(
      id: 'note-1',
      dateTimeRange: offer.dateTimeRange,
      title: 'Секрет владельца',
      startTime: '11:00',
      endTime: '12:00',
      color: const Color(0xFF000000),
    );

    final visible = BookingOfferEvents.surfaceForGuest(
      events: [mine, other, personal],
      guestProfileId: 'anna',
      occupiedTitle: 'Занято',
    );

    expect(visible, hasLength(2));
    expect(visible.any((event) => event.title == 'Секрет владельца'), isFalse);
    expect(
      visible.where(
        (event) => event.entrySource == CalendarEntrySource.booking,
      ),
      hasLength(2),
    );
    final hidden = visible.firstWhere((event) => event.id == other.id);
    expect(hidden.title, 'Занято');
    final own = visible.firstWhere((event) => event.id == mine.id);
    expect(own.title, 'Стрижка — Анна');
  });
}
