import 'package:almanac/data/remote/event_lock.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 9, 16, 18);

  test('free lock can be taken', () {
    expect(canTakeEventLock(deviceId: 'a', now: now), isTrue);
  });

  test('same device can refresh its lock', () {
    expect(
      canTakeEventLock(
        deviceId: 'a',
        now: now,
        holderDeviceId: 'a',
        expiresAt: now.add(const Duration(seconds: 90)),
      ),
      isTrue,
    );
  });

  test('other device cannot take a live lock', () {
    expect(
      canTakeEventLock(
        deviceId: 'b',
        now: now,
        holderDeviceId: 'a',
        expiresAt: now.add(const Duration(seconds: 90)),
      ),
      isFalse,
    );
  });

  test('expired lock can be taken by anyone', () {
    expect(
      canTakeEventLock(
        deviceId: 'b',
        now: now,
        holderDeviceId: 'a',
        expiresAt: now.subtract(const Duration(seconds: 1)),
      ),
      isTrue,
    );
  });

  test('RemoteEventLock.isHeldByOther ignores own device and expired ttl', () {
    final live = RemoteEventLock(
      eventId: 'e1',
      deviceId: 'a',
      expiresAt: DateTime.utc(2026, 9, 16, 19),
    );
    expect(live.isHeldByOther('b', now), isTrue);
    expect(live.isHeldByOther('a', now), isFalse);

    final expired = RemoteEventLock(
      eventId: 'e1',
      deviceId: 'a',
      expiresAt: DateTime.utc(2026, 9, 16, 17),
    );
    expect(expired.isHeldByOther('b', now), isFalse);
  });
}
