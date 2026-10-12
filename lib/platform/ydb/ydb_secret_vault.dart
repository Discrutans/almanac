import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Хранилище SA JSON. Не пишет секрет в snapshot и не в plaintext-файл.
abstract class YdbSecretVault {
  Future<String?> read();
  Future<void> write(String secret);
  Future<void> delete();
}

/// Память: тесты и fallback, если плагин недоступен.
class MemoryYdbSecretVault implements YdbSecretVault {
  MemoryYdbSecretVault([this._value]);

  String? _value;

  @override
  Future<String?> read() async => _value;

  @override
  Future<void> write(String secret) async {
    _value = secret;
  }

  @override
  Future<void> delete() async {
    _value = null;
  }
}

/// Keychain / Keystore / Credential Manager.
class SecureYdbSecretVault implements YdbSecretVault {
  SecureYdbSecretVault({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const key = 'almanac_ydb_sa_json';

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read() async {
    try {
      return await _storage.read(key: key);
    } catch (error, stack) {
      debugPrint('SecureYdbSecretVault.read failed: $error\n$stack');
      return null;
    }
  }

  @override
  Future<void> write(String secret) async {
    try {
      await _storage.write(key: key, value: secret);
    } catch (error, stack) {
      debugPrint('SecureYdbSecretVault.write failed: $error\n$stack');
    }
  }

  @override
  Future<void> delete() async {
    try {
      await _storage.delete(key: key);
    } catch (error, stack) {
      debugPrint('SecureYdbSecretVault.delete failed: $error\n$stack');
    }
  }
}
