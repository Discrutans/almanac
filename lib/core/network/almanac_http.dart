import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Тонкая обёртка над `http`: debug-лог метода, URL и статуса без тел и ключей.
class AlmanacHttpClient extends http.BaseClient {
  AlmanacHttpClient({http.Client? inner}) : _inner = inner ?? http.Client();

  final http.Client _inner;

  static const _secretHeaderNames = {'x-api-key', 'authorization', 'cookie'};

  static const _secretQueryNames = {
    'apikey',
    'api_key',
    'key',
    'token',
    'secret',
    'access_key',
  };

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await _inner.send(request);
    if (kDebugMode) {
      debugPrint(formatLog(request: request, statusCode: response.statusCode));
    }
    return response;
  }

  @override
  void close() => _inner.close();

  static String formatLog({
    required http.BaseRequest request,
    required int statusCode,
  }) {
    return 'HTTP ${request.method} ${sanitizeUrl(request.url)} -> $statusCode';
  }

  static Uri sanitizeUrl(Uri url) {
    if (url.hasQuery) {
      final cleaned = <String, String>{};
      url.queryParameters.forEach((name, value) {
        if (_secretQueryNames.contains(name.toLowerCase())) {
          cleaned[name] = '<redacted>';
        } else {
          cleaned[name] = value;
        }
      });
      return url.replace(queryParameters: cleaned);
    }
    return url;
  }

  static Map<String, String> redactHeaders(Map<String, String> headers) {
    return {
      for (final entry in headers.entries)
        entry.key: _secretHeaderNames.contains(entry.key.toLowerCase())
            ? '<redacted>'
            : entry.value,
    };
  }
}

http.Client almanacHttpClient({http.Client? inner}) {
  if (inner is AlmanacHttpClient) return inner;
  return AlmanacHttpClient(inner: inner);
}
