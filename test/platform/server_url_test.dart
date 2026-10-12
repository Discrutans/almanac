import 'package:almanac/platform/server_url.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizeServerUrl', () {
    test('fixes Windows backslash after scheme', () {
      expect(
        normalizeServerUrl(r'http:\localhost:8080'),
        'http://localhost:8080',
      );
    });

    test('fixes single slash after scheme', () {
      expect(
        normalizeServerUrl('http:/localhost:8080'),
        'http://localhost:8080',
      );
    });

    test('adds http when scheme missing', () {
      expect(normalizeServerUrl('localhost:8080'), 'http://localhost:8080');
    });

    test('strips trailing slash', () {
      expect(
        normalizeServerUrl('https://api.example.com/'),
        'https://api.example.com',
      );
    });

    test('strips mistaken /v1 suffix', () {
      expect(
        normalizeServerUrl('https://api.example.com/v1'),
        'https://api.example.com',
      );
    });

    test('strips trailing slash and /v1', () {
      expect(
        normalizeServerUrl('https://api.example.com/v1/'),
        'https://api.example.com',
      );
    });

    test('empty stays empty', () {
      expect(normalizeServerUrl('  '), '');
    });

    test('isValidServerUrl rejects empty input', () {
      expect(isValidServerUrl(r'http:\localhost:8080'), isTrue);
      expect(isValidServerUrl(''), isFalse);
      expect(isValidServerUrl('   '), isFalse);
    });
  });

  group('serverUrlToWebSocketBase', () {
    test('https to wss', () {
      expect(
        serverUrlToWebSocketBase('https://api.example.com'),
        'wss://api.example.com',
      );
    });

    test('http to ws', () {
      expect(
        serverUrlToWebSocketBase('http://localhost:8080'),
        'ws://localhost:8080',
      );
    });
  });

  group('sameRemoteWorkspace', () {
    test('requires the same url and key', () {
      expect(
        sameRemoteWorkspace(
          serverBaseUrl: 'http://192.168.10.100:8080',
          apiKey: 'aaa',
          otherServerBaseUrl: 'http://192.168.10.100:8080/',
          otherApiKey: 'aaa',
        ),
        isTrue,
      );
      expect(
        sameRemoteWorkspace(
          serverBaseUrl: 'http://192.168.10.100:8080',
          apiKey: 'aaa',
          otherServerBaseUrl: 'http://192.168.10.100:8080',
          otherApiKey: 'bbb',
        ),
        isFalse,
      );
      expect(
        sameRemoteWorkspace(
          serverBaseUrl: '',
          apiKey: 'aaa',
          otherServerBaseUrl: 'http://192.168.10.100:8080',
          otherApiKey: 'aaa',
        ),
        isFalse,
      );
    });
  });

  group('workspaceShareOrigin', () {
    test('prefers public internet origin over LAN server url', () {
      expect(
        workspaceShareOrigin(
          publicOrigin: 'https://api.example.com/',
          serverBaseUrl: 'http://192.168.1.10:8080',
          lanFallback: 'http://10.0.0.5:8080',
        ),
        'https://api.example.com',
      );
    });

    test('uses public server url when public origin is empty', () {
      expect(
        workspaceShareOrigin(
          publicOrigin: '',
          serverBaseUrl: 'https://calendar.example.com',
        ),
        'https://calendar.example.com',
      );
    });

    test('falls back to LAN only when no internet origin exists', () {
      expect(
        workspaceShareOrigin(
          publicOrigin: '',
          serverBaseUrl: 'http://127.0.0.1:8080',
          lanFallback: 'http://192.168.0.4:8080',
        ),
        'http://127.0.0.1:8080',
      );
    });

    test('isLoopbackOrLanUrl detects private hosts', () {
      expect(isLoopbackOrLanUrl('http://192.168.1.1:8080'), isTrue);
      expect(isLoopbackOrLanUrl('http://10.0.0.8'), isTrue);
      expect(isLoopbackOrLanUrl('https://api.example.com'), isFalse);
    });
  });
}
