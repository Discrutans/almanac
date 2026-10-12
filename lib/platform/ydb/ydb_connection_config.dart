class YdbConnectionConfig {
  const YdbConnectionConfig({
    required this.endpoint,
    required this.database,
    required this.accessKey,
  });

  static const defaultEndpoint = 'grpcs://ydb.serverless.yandexcloud.net:2135';

  static final _databaseParam = RegExp(
    r'[?&]database=([^&\s]+)',
    caseSensitive: false,
  );
  static final _hostLine = RegExp(
    r'((?:grpcs?|https?)://[^\s/?]+(?::\d+)?)',
    caseSensitive: false,
  );
  static final _ruPath = RegExp(r'(/ru-central[^\s?&]*)');

  final String endpoint;
  final String database;
  final String accessKey;

  bool get isConfigured =>
      database.trim().isNotEmpty && accessKey.trim().isNotEmpty;

  static String compact(String raw) =>
      raw.trim().replaceAll(RegExp(r'\s+'), '');

  static bool looksLikeUri(String value) {
    final v = compact(value);
    return v.startsWith('grpc://') ||
        v.startsWith('grpcs://') ||
        v.startsWith('http://') ||
        v.startsWith('https://');
  }

  static bool looksLikeConnectionString(String value) {
    final v = compact(value);
    return looksLikeUri(v) || v.contains('database=');
  }

  static String extractDatabase(String raw) {
    final compactValue = compact(raw);
    if (compactValue.isEmpty) return '';
    final fromQuery = _databaseParam.firstMatch(compactValue);
    if (fromQuery != null) {
      return Uri.decodeQueryComponent(fromQuery.group(1)!);
    }
    if (compactValue.startsWith('/ru-central')) {
      return compactValue.split('?').first;
    }
    final fromPath = _ruPath.firstMatch(compactValue);
    return fromPath?.group(1) ?? '';
  }

  static String extractEndpoint(String raw) {
    final compactValue = compact(raw);
    final match = _hostLine.firstMatch(compactValue);
    if (match != null) return match.group(1)!;
    if (!looksLikeUri(compactValue)) return '';
    final uri = Uri.tryParse(compactValue.split('?').first);
    if (uri == null || uri.host.isEmpty) return '';
    return '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}';
  }

  factory YdbConnectionConfig.parse({
    required String connectionOrPath,
    required String accessKey,
    String? endpoint,
  }) {
    var resolvedEndpoint = extractEndpoint(endpoint ?? '');
    var database = extractDatabase(connectionOrPath);
    if (database.isEmpty && !looksLikeConnectionString(connectionOrPath)) {
      database = connectionOrPath.trim();
    }

    final fromPath = _splitConnectionString(connectionOrPath);
    if (fromPath != null) {
      if (fromPath.endpoint.isNotEmpty && resolvedEndpoint.isEmpty) {
        resolvedEndpoint = fromPath.endpoint;
      }
      if (fromPath.database.isNotEmpty) {
        database = fromPath.database;
      }
    }
    final fromEndpoint = _splitConnectionString(endpoint ?? '');
    if (fromEndpoint != null) {
      if (fromEndpoint.endpoint.isNotEmpty &&
          (resolvedEndpoint.isEmpty ||
              (endpoint ?? '').contains('database='))) {
        resolvedEndpoint = fromEndpoint.endpoint;
      }
      if (database.isEmpty && fromEndpoint.database.isNotEmpty) {
        database = fromEndpoint.database;
      }
    }

    if (resolvedEndpoint.contains('?')) {
      resolvedEndpoint = resolvedEndpoint.split('?').first;
    }
    if (resolvedEndpoint.isEmpty) {
      resolvedEndpoint = defaultEndpoint;
    }
    if (!resolvedEndpoint.contains('://')) {
      resolvedEndpoint = 'grpcs://$resolvedEndpoint';
    }

    return YdbConnectionConfig(
      endpoint: resolvedEndpoint,
      database: database,
      accessKey: accessKey.trim(),
    );
  }

  static ({String endpoint, String database})? _splitConnectionString(
    String raw,
  ) {
    final compactValue = compact(raw);
    if (compactValue.isEmpty) return null;
    final db = extractDatabase(compactValue);
    final ep = extractEndpoint(compactValue);
    if (ep.isEmpty && db.isEmpty) return null;
    return (endpoint: ep, database: db);
  }
}
