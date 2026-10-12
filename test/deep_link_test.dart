import 'package:almanac/core/router/deep_link.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseSessionDeepLink', () {
    test('https join link includes server origin', () {
      final link = parseSessionDeepLink(
        Uri.parse('https://calendar.example.com/join/abc123'),
      );
      expect(link?.token, 'abc123');
      expect(link?.serverOrigin, 'https://calendar.example.com');
    });

    test('custom scheme with server query param', () {
      final link = parseSessionDeepLink(
        Uri.parse('almanac://join/token1?server=https%3A%2F%2Fapi.example.com'),
      );
      expect(link?.token, 'token1');
      expect(link?.serverOrigin, 'https://api.example.com');
    });

    test('book path maps to session token', () {
      final link = parseSessionDeepLink(
        Uri.parse('https://calendar.example.com/book/xyz'),
      );
      expect(link?.token, 'xyz');
    });

    test('plan path maps to session token with server origin', () {
      final link = parseSessionDeepLink(
        Uri.parse('https://calendar.example.com/plan/grp42'),
      );
      expect(link?.token, 'grp42');
      expect(link?.serverOrigin, 'https://calendar.example.com');
    });

    test('guest without profile server still gets origin from https join', () {
      final link = parseSessionDeepLink(
        Uri.parse('http://localhost:8080/join/guest-token'),
      );
      expect(link?.token, 'guest-token');
      expect(link?.serverOrigin, 'http://localhost:8080');
    });
  });

  group('parseWorkspaceInvite', () {
    test('almanac connect scheme', () {
      final invite = parseWorkspaceInvite(
        Uri.parse(
          'almanac://connect?server=http%3A%2F%2F192.168.1.10%3A8080&key=abc&profile=default&kind=collaborative',
        ),
      );
      expect(invite?.serverOrigin, 'http://192.168.1.10:8080');
      expect(invite?.apiKey, 'abc');
      expect(invite?.profileId, 'default');
    });

    test('http connect landing', () {
      final invite = parseWorkspaceInvite(
        Uri.parse('http://192.168.1.10:8080/connect?key=secret&profile=work'),
      );
      expect(invite?.serverOrigin, 'http://192.168.1.10:8080');
      expect(invite?.apiKey, 'secret');
      expect(invite?.profileId, 'work');
    });

    test('rejects personal kind', () {
      expect(
        parseWorkspaceInvite(
          Uri.parse(
            'almanac://connect?server=http://192.168.1.10:8080&key=abc&kind=personal',
          ),
        ),
        isNull,
      );
    });
  });
}
