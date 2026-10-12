/// Короткий эксклюзивный лок события в общем календаре.
class RemoteEventLock {
  const RemoteEventLock({
    required this.eventId,
    required this.deviceId,
    required this.expiresAt,
  });

  final String eventId;
  final String deviceId;
  final DateTime expiresAt;

  bool isExpired([DateTime? now]) {
    return (now ?? DateTime.now().toUtc()).isAfter(expiresAt.toUtc());
  }

  bool isHeldByOther(String deviceId, [DateTime? now]) {
    if (isExpired(now)) return false;
    return this.deviceId != deviceId;
  }

  factory RemoteEventLock.fromJson(Map<String, dynamic> json) {
    final rawExpires = json['expires_at'] ?? json['expiresAt'];
    DateTime expires;
    if (rawExpires is DateTime) {
      expires = rawExpires.toUtc();
    } else {
      expires =
          DateTime.tryParse('$rawExpires')?.toUtc() ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    }
    return RemoteEventLock(
      eventId: '${json['event_id'] ?? json['eventId'] ?? ''}',
      deviceId: '${json['device_id'] ?? json['deviceId'] ?? ''}',
      expiresAt: expires,
    );
  }
}

/// Можно ли взять лок: нет держателя, истёк TTL, или это то же устройство.
bool canTakeEventLock({
  required String deviceId,
  required DateTime now,
  String? holderDeviceId,
  DateTime? expiresAt,
}) {
  if (holderDeviceId == null || holderDeviceId.isEmpty || expiresAt == null) {
    return true;
  }
  if (!expiresAt.toUtc().isAfter(now.toUtc())) return true;
  return holderDeviceId == deviceId;
}
