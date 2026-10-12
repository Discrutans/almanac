import 'dart:convert';

import 'package:almanac/data/profiles/profile_kind.dart';
import 'package:almanac/platform/ydb/ydb_connection_config.dart';
import 'package:almanac/platform/ydb/ydb_invite.dart';
import 'package:almanac/platform/ydb/ydb_workspace_connection.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('YdbConnectionConfig', () {
    const connection =
        'grpcs://ydb.serverless.yandexcloud.net:2135/?database=/ru-central1/b1g/etn';
    const path = '/ru-central1/b1g/etn';
    const endpoint = 'grpcs://ydb.serverless.yandexcloud.net:2135';

    test('splits console connection string from database field', () {
      final parsed = YdbConnectionConfig.parse(
        connectionOrPath: connection,
        accessKey: '{"service_account_id":"x"}',
      );
      expect(parsed.database, path);
      expect(parsed.endpoint, endpoint);
      expect(parsed.isConfigured, isTrue);
    });

    test('keeps path and default endpoint when only path is given', () {
      final parsed = YdbConnectionConfig.parse(
        connectionOrPath: path,
        accessKey: 'key',
      );
      expect(parsed.database, path);
      expect(parsed.endpoint, YdbConnectionConfig.defaultEndpoint);
    });

    test('splits connection string even with a line break before database=', () {
      const broken =
          'grpcs://ydb.serverless.yandexcloud.net:2135\n/?database=/ru-central1/b1g/etn';
      final parsed = YdbConnectionConfig.parse(
        connectionOrPath: broken,
        accessKey: 'key',
      );
      expect(parsed.database, path);
      expect(parsed.endpoint, endpoint);
    });
  });

  group('Ydb invite', () {
    const connection = YdbWorkspaceConnection(
      endpoint: YdbConnectionConfig.defaultEndpoint,
      database: '/ru-central1/b1g/etn',
      secret: '{"service_account_id":"sa"}',
      workspaceApiKey: 'workspace-key',
      workspaceProfileId: 'shared',
    );

    test('round-trips a guest database invite', () {
      final packed = encodeYdbInvite(
        const YdbWorkspaceInvite(
          connection: connection,
          kind: ProfileKind.collaborative,
          name: 'Семья',
        ),
      );
      expect(packed, startsWith(ydbInvitePrefix));
      final parsed = parseYdbInvite(packed);
      expect(parsed?.connection.database, '/ru-central1/b1g/etn');
      expect(parsed?.connection.secret, '{"service_account_id":"sa"}');
      expect(parsed?.connection.workspaceApiKey, 'workspace-key');
      expect(parsed?.connection.workspaceProfileId, 'shared');
      expect(parsed?.kind, ProfileKind.collaborative);
      expect(parsed?.connection.guestKind, ProfileKind.collaborative);
      expect(parsed?.name, 'Семья');

      final app = parseYdbInvite(Uri.parse(ydbInviteAppLink(parsed!)));
      expect(app?.connection.workspaceApiKey, 'workspace-key');
    });

    test('rejects personal kind in ydb invite', () {
      final payload = base64Url.encode(
        utf8.encode(
          jsonEncode({
            'e': YdbConnectionConfig.defaultEndpoint,
            'd': '/ru-central1/x/y',
            'k': '{}',
            'a': 'k',
            'p': 'default',
            'kind': 'personal',
          }),
        ),
      );
      expect(parseYdbInvite('$ydbInvitePrefix$payload'), isNull);
    });

    test('round-trips booking guest kind', () {
      final packed = encodeYdbInvite(
        const YdbWorkspaceInvite(
          connection: YdbWorkspaceConnection(
            endpoint: YdbConnectionConfig.defaultEndpoint,
            database: '/ru-central1/b1g/etn',
            secret: '{"service_account_id":"sa"}',
            workspaceApiKey: 'workspace-key',
            workspaceProfileId: 'book-1',
            guestKind: ProfileKind.booking,
          ),
          kind: ProfileKind.booking,
          name: 'Студия',
        ),
      );
      final parsed = parseYdbInvite(packed);
      expect(parsed?.kind, ProfileKind.booking);
      expect(parsed?.connection.guestKind, ProfileKind.booking);
      expect(parsed?.connection.workspaceProfileId, 'book-1');
    });

    test('returns null for empty or unrelated text', () {
      expect(parseYdbInvite(''), isNull);
      expect(parseYdbInvite('https://example.com/join/x'), isNull);
    });
  });
}
