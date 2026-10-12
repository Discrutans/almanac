import 'dart:convert';
import 'dart:io';

import 'package:almanac/platform/ydb/ydb_connection_store.dart';
import 'package:almanac/platform/ydb/ydb_secret_vault.dart';
import 'package:almanac/platform/ydb/ydb_workspace_connection.dart';
import 'package:almanac/data/profiles/profile_kind.dart';
import 'package:almanac/platform/ydb/ydb_connection_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('saves SA JSON in the vault, not in the on-disk file', () async {
    final dir = await Directory.systemTemp.createTemp('almanac_ydb_');
    final file = File('${dir.path}/almanac_ydb.json');
    final vault = MemoryYdbSecretVault();
    final store = YdbConnectionStore(file: file, vault: vault);

    const connection = YdbWorkspaceConnection(
      endpoint: YdbConnectionConfig.defaultEndpoint,
      database: '/ru-central1/b1g/etn',
      secret: '{"service_account_id":"sa"}',
      workspaceApiKey: 'workspace-key',
      workspaceProfileId: 'shared',
      guestKind: ProfileKind.booking,
    );

    await store.save(connection);

    expect(await vault.read(), '{"service_account_id":"sa"}');
    final disk = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    expect(disk.containsKey('secret'), isFalse);
    expect(disk.containsKey('accessKey'), isFalse);
    expect(disk['database'], '/ru-central1/b1g/etn');
    expect(disk['workspaceApiKey'], 'workspace-key');
    expect(store.active?.secret, '{"service_account_id":"sa"}');

    final reloaded = YdbConnectionStore(file: file, vault: vault);
    await reloaded.load();
    expect(reloaded.active?.secret, '{"service_account_id":"sa"}');
    expect(reloaded.active?.guestKind, ProfileKind.booking);

    await dir.delete(recursive: true);
  });

  test(
    'migrates a legacy plaintext secret from the JSON file into the vault',
    () async {
      final dir = await Directory.systemTemp.createTemp('almanac_ydb_legacy_');
      final file = File('${dir.path}/almanac_ydb.json');
      await file.writeAsString(
        jsonEncode(const {
          'endpoint': YdbConnectionConfig.defaultEndpoint,
          'database': '/ru-central1/b1g/etn',
          'secret': '{"legacy":true}',
          'workspaceApiKey': 'k',
          'workspaceProfileId': 'default',
          'guestKind': 'collaborative',
        }),
      );
      final vault = MemoryYdbSecretVault();
      final store = YdbConnectionStore(file: file, vault: vault);
      await store.load();

      expect(await vault.read(), '{"legacy":true}');
      expect(store.active?.secret, '{"legacy":true}');
      final disk =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      expect(disk.containsKey('secret'), isFalse);

      await dir.delete(recursive: true);
    },
  );
}
