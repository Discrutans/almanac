/// Normalizes self-hosted Almanac API base URL.
///
/// Accepts any host: VPS, Yandex Cloud, Railway, home server, localhost.
/// Fixes common Windows typos (`http:\localhost` → `http://localhost`).
/// Strips trailing slashes and common `/v1` suffix mistakes.
String normalizeServerUrl(String raw) {
  var url = raw.trim();
  if (url.isEmpty) return '';

  // Windows paste / manual entry: backslashes and single slash after scheme.
  url = url.replaceAll('\\', '/');
  url = url.replaceAll(RegExp(r'\s+'), '');

  if (url.startsWith('http:/') && !url.startsWith('http://')) {
    url = 'http://${url.substring('http:/'.length)}';
  } else if (url.startsWith('https:/') && !url.startsWith('https://')) {
    url = 'https://${url.substring('https:/'.length)}';
  } else if (!url.contains('://')) {
    url = 'http://$url';
  }

  while (url.endsWith('/')) {
    url = url.substring(0, url.length - 1);
  }

  if (url.endsWith('/v1')) {
    url = url.substring(0, url.length - 3);
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
  }

  return url;
}

/// Два профиля смотрят на один и тот же self-hosted workspace.
bool sameRemoteWorkspace({
  required String serverBaseUrl,
  required String apiKey,
  required String otherServerBaseUrl,
  required String otherApiKey,
}) {
  final url = normalizeServerUrl(serverBaseUrl);
  final otherUrl = normalizeServerUrl(otherServerBaseUrl);
  final key = apiKey.trim();
  if (url.isEmpty || otherUrl.isEmpty || key.isEmpty) return false;
  return url == otherUrl && key == otherApiKey.trim();
}

/// Whether [raw] becomes a usable HTTP(S) base URL after normalization.
bool isValidServerUrl(String raw) {
  final normalized = normalizeServerUrl(raw);
  if (normalized.isEmpty) return false;
  final uri = Uri.tryParse(normalized);
  return uri != null && uri.host.isNotEmpty && uri.scheme.startsWith('http');
}

/// Loopback / RFC1918 / link-local — не адрес для гостей «по сети».
bool isLoopbackOrLanUrl(String raw) {
  final uri = Uri.tryParse(normalizeServerUrl(raw));
  if (uri == null || uri.host.isEmpty) return false;
  final host = uri.host.toLowerCase();
  if (host == 'localhost' || host == '::1') return true;
  if (host.startsWith('127.')) return true;
  if (host.startsWith('192.168.')) return true;
  if (host.startsWith('10.')) return true;
  if (host.startsWith('169.254.')) return true;
  final match = RegExp(r'^172\.(\d+)\.').firstMatch(host);
  if (match == null) return false;
  final octet = int.tryParse(match.group(1)!);
  return octet != null && octet >= 16 && octet <= 31;
}

/// Origin для гостевых `/connect` и `/join`: сначала публичный интернет, не LAN.
String workspaceShareOrigin({
  required String publicOrigin,
  required String serverBaseUrl,
  String lanFallback = '',
}) {
  final public = normalizeServerUrl(publicOrigin);
  if (public.isNotEmpty && !isLoopbackOrLanUrl(public)) return public;
  final server = normalizeServerUrl(serverBaseUrl);
  if (server.isNotEmpty && !isLoopbackOrLanUrl(server)) return server;
  if (public.isNotEmpty) return public;
  if (server.isNotEmpty) return server;
  return normalizeServerUrl(lanFallback);
}

/// Builds WebSocket URL from HTTP(S) API base URL.
String serverUrlToWebSocketBase(String httpBase) {
  final base = normalizeServerUrl(httpBase);
  if (base.startsWith('https://')) {
    return base.replaceFirst('https://', 'wss://');
  }
  if (base.startsWith('http://')) {
    return base.replaceFirst('http://', 'ws://');
  }
  return base;
}
