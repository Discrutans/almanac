import 'package:almanac/core/network/almanac_http.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('sanitizes secret query params and never logs API keys', () {
    final url = Uri.parse(
      'http://192.168.1.10:8080/v1/calendar/snapshot?api_key=secret&foo=bar',
    );
    final cleaned = AlmanacHttpClient.sanitizeUrl(url);
    expect(cleaned.queryParameters['api_key'], '<redacted>');
    expect(cleaned.queryParameters['foo'], 'bar');

    final headers = AlmanacHttpClient.redactHeaders({
      'X-Api-Key': 'super-secret',
      'Content-Type': 'application/json',
    });
    expect(headers['X-Api-Key'], '<redacted>');
    expect(headers['Content-Type'], 'application/json');

    final request = http.Request('GET', url);
    request.headers['X-Api-Key'] = 'super-secret';
    final line = AlmanacHttpClient.formatLog(request: request, statusCode: 200);
    expect(line, contains('HTTP GET'));
    expect(line, contains('-> 200'));
    expect(line, isNot(contains('super-secret')));
    expect(line, isNot(contains('secret')));
  });

  test('logs method, url and status through the client wrapper', () async {
    final inner = MockClient((request) async {
      expect(request.headers['X-Api-Key'], 'keep-for-wire');
      return http.Response('{}', 201);
    });
    final client = AlmanacHttpClient(inner: inner);
    final response = await client.get(
      Uri.parse('http://example.test/v1/workspace'),
      headers: const {'X-Api-Key': 'keep-for-wire'},
    );
    expect(response.statusCode, 201);
    client.close();
  });
}
