class MiniServerInfo {
  const MiniServerInfo({
    required this.port,
    required this.loopbackOrigin,
    required this.lanOrigin,
    required this.lanIps,
  });

  final int port;
  final String loopbackOrigin;
  final String lanOrigin;
  final List<String> lanIps;
}

class MiniServerStore {
  Map<String, dynamic>? Function()? hostSnapshot;
}

class AlmanacMiniServer {
  MiniServerStore get store => MiniServerStore();
  MiniServerInfo? get info => null;
  bool get isRunning => false;
  String advertisedOrigin = '';

  Future<MiniServerInfo> start({int preferredPort = 8080}) {
    throw UnsupportedError('Mini-server requires dart:io');
  }

  Future<void> stop() async {}
}
