import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'ydb_secret_vault.dart';
import 'ydb_snapshot_client.dart';
import 'ydb_workspace_connection.dart';

/// JSON-файл рядом с almanac.db. SA JSON — в [YdbSecretVault], не в файле.
class YdbConnectionStore {
  YdbConnectionStore({this.file, YdbSecretVault? vault})
    : vault = vault ?? MemoryYdbSecretVault();

  File? file;
  final YdbSecretVault vault;
  YdbWorkspaceConnection? _active;

  YdbWorkspaceConnection? get active => _active;

  bool get isConfigured => _active?.isConfigured == true;

  static Future<YdbConnectionStore> openDefault() async {
    final dir = await getApplicationDocumentsDirectory();
    final store = YdbConnectionStore(
      file: File(p.join(dir.path, 'almanac_ydb.json')),
      vault: SecureYdbSecretVault(),
    );
    await store.load();
    return store;
  }

  Future<void> load() async {
    final path = file;
    if (path == null || !await path.exists()) {
      final secret = (await vault.read())?.trim() ?? '';
      _active = secret.isEmpty
          ? null
          : YdbWorkspaceConnection(
              endpoint: '',
              database: '',
              secret: secret,
              workspaceApiKey: '',
            );
      if (_active?.isConfigured != true) _active = null;
      return;
    }
    try {
      final json = jsonDecode(await path.readAsString());
      if (json is! Map<String, dynamic>) {
        _active = null;
        return;
      }
      var connection = YdbWorkspaceConnection.fromJson(json);
      final vaultSecret = (await vault.read())?.trim() ?? '';
      final fileSecret = connection.secret.trim();
      if (vaultSecret.isEmpty && fileSecret.isNotEmpty) {
        await vault.write(fileSecret);
        connection = connection.copyWith(secret: fileSecret);
        await _writePublicFile(path, connection);
      } else if (vaultSecret.isNotEmpty) {
        connection = connection.copyWith(secret: vaultSecret);
        if (fileSecret.isNotEmpty) {
          await _writePublicFile(path, connection);
        }
      }
      _active = connection;
    } catch (error, stack) {
      debugPrint('YdbConnectionStore.load failed: $error\n$stack');
      _active = null;
    }
  }

  Future<void> save(YdbWorkspaceConnection connection) async {
    _active = connection;
    final path = file ?? await _defaultFile();
    file = path;
    final secret = connection.secret.trim();
    if (secret.isEmpty) {
      await vault.delete();
    } else {
      await vault.write(secret);
    }
    await _writePublicFile(path, connection);
  }

  Future<void> clear() async {
    _active = null;
    await closeSharedYdbSnapshotClient();
    await vault.delete();
    final path = file;
    if (path != null && await path.exists()) {
      await path.delete();
    }
  }

  static Future<void> _writePublicFile(
    File path,
    YdbWorkspaceConnection connection,
  ) async {
    await path.writeAsString(jsonEncode(connection.toPublicJson()));
  }

  static Future<File> _defaultFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, 'almanac_ydb.json'));
  }
}
