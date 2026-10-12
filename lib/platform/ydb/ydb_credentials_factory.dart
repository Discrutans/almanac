import 'dart:convert';

import 'package:ydb_flutter_sdk/ydb_flutter_sdk.dart';

Future<(YdbCredentials, IYdbTransport?)> ydbCredentialsFromSecret(
  String raw,
) async {
  final secret = raw.trim();
  if (secret.startsWith('{')) {
    return _fromServiceAccountJson(secret);
  }
  if (secret.startsWith('t1.')) {
    return (YdbAuth.oauthDirect(secret), null);
  }
  if (secret.startsWith('y0_')) {
    throw StateError(
      'OAuth-токен y0_ для YDB устарел. '
      'Создайте сервисный аккаунт и вставьте JSON авторизованного ключа.',
    );
  }
  throw StateError(
    'Ожидается JSON-ключ сервисного аккаунта '
    '(поля service_account_id, id, private_key).',
  );
}

(YdbCredentials, IYdbTransport) _fromServiceAccountJson(String raw) {
  late final Map<String, dynamic> json;
  try {
    json = jsonDecode(raw) as Map<String, dynamic>;
  } on FormatException {
    throw StateError(
      'Ключ не похож на JSON. Нажмите «Файл ключа» и выберите authorized_key.json.',
    );
  }

  final saId = json['service_account_id'] as String?;
  final keyId = json['id'] as String?;
  final privateKey = json['private_key'] as String?;
  if (saId == null || saId.isEmpty) {
    throw StateError('В JSON нет service_account_id');
  }
  if (keyId == null || keyId.isEmpty) {
    throw StateError('В JSON нет id ключа');
  }
  if (privateKey == null || privateKey.isEmpty) {
    throw StateError('В JSON нет private_key');
  }

  final iam = IamHttpClient(baseUrl: 'https://iam.api.cloud.yandex.net');
  late final YdbCredentials credentials;
  try {
    credentials = YdbAuth.serviceAccount(
      serviceAccountId: saId,
      signer: RsaJwtSigner.fromPem(normalizePem(privateKey), keyId: keyId),
      transport: iam,
    );
  } catch (_) {
    throw StateError(
      'Не удалось прочитать private_key. Выберите authorized_key.json.',
    );
  }
  return (credentials, iam);
}

String normalizePem(String raw) {
  var pem = raw.trim();
  pem = pem.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  pem = pem.replaceAll(r'\n', '\n');
  pem = pem.replaceAllMapped(
    RegExp(r'-----BEGIN ([A-Z ]+)-----'),
    (match) => '\n-----BEGIN ${match.group(1)}-----\n',
  );
  pem = pem.replaceAllMapped(
    RegExp(r'-----END ([A-Z ]+)-----'),
    (match) => '\n-----END ${match.group(1)}-----\n',
  );

  final begin = RegExp(r'-----BEGIN ([A-Z ]+)-----').firstMatch(pem);
  if (begin == null) {
    throw StateError('В private_key нет блока -----BEGIN …-----');
  }
  final type = begin.group(1)!;
  final endMarker = '-----END $type-----';
  final start = pem.indexOf('-----BEGIN $type-----');
  final end = pem.indexOf(endMarker);
  if (end < 0) {
    throw StateError('В private_key нет блока -----END $type-----');
  }

  final body = pem
      .substring(start + '-----BEGIN $type-----'.length, end)
      .replaceAll(RegExp(r'\s+'), '');
  if (body.isEmpty) {
    throw StateError('private_key пустой');
  }

  final lines = <String>[];
  for (var i = 0; i < body.length; i += 64) {
    final stop = i + 64 > body.length ? body.length : i + 64;
    lines.add(body.substring(i, stop));
  }
  return '-----BEGIN $type-----\n${lines.join('\n')}\n$endMarker\n';
}
