import 'package:flutter/material.dart';

enum BookingConfirmationMode { manual, automatic }

enum BookingRequestStatus { pending, confirmed, rejected }

class BookingTemplate {
  BookingTemplate({
    required this.id,
    required this.profileId,
    required this.token,
    required this.title,
    required this.duration,
    required this.confirmationMode,
  });

  final String id;
  final String profileId;
  final String token;
  final String title;
  final Duration duration;
  final BookingConfirmationMode confirmationMode;
}

class BookingRequest {
  BookingRequest({
    required this.id,
    required this.profileId,
    required this.templateId,
    required this.templateToken,
    required this.start,
    required this.end,
    required this.createdAt,
    required this.status,
    this.notes,
  });

  final String id;
  final String profileId;
  final String templateId;
  final String templateToken;
  final DateTime start;
  final DateTime end;
  final DateTime createdAt;
  final BookingRequestStatus status;
  final String? notes;
}

class BookingSlot {
  BookingSlot({
    required this.start,
    required this.end,
    required this.available,
  });

  final DateTime start;
  final DateTime end;
  final bool available;

  String formatTimeRange(BuildContext context) {
    final local = start;
    final localEnd = end;
    String hhmm(DateTime d) =>
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    return '${hhmm(local)} - ${hhmm(localEnd)}';
  }
}
