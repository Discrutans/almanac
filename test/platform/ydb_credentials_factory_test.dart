import 'package:almanac/platform/ydb/ydb_credentials_factory.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('normalizePem splits glued Yandex private key', () {
    const glued =
        '-----BEGIN PRIVATE KEY-----MIIEuwIBADANBgkqhkiG9w0BAQEFAASCBKUwggShAgEAAoIB-----END PRIVATE KEY-----';
    final pem = normalizePem(glued);
    expect(pem, startsWith('-----BEGIN PRIVATE KEY-----\n'));
    expect(
      pem,
      contains('\nMIIEuwIBADANBgkqhkiG9w0BAQEFAASCBKUwggShAgEAAoIB\n'),
    );
    expect(pem.trim(), endsWith('-----END PRIVATE KEY-----'));
  });

  test('ydbCredentialsFromSecret rejects y0_ oauth', () async {
    await expectLater(
      ydbCredentialsFromSecret('y0_AgAAAAA'),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('y0_'),
        ),
      ),
    );
  });
}
