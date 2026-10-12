import 'dart:io';

/// IPv4 адреса этого устройства, пригодные как Server URL в LAN.
Future<List<String>> lanIPv4Addresses() async {
  final found = <String>[];
  try {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLinkLocal: false,
    );
    for (final iface in interfaces) {
      for (final addr in iface.addresses) {
        final ip = addr.address;
        if (ip.startsWith('127.') || found.contains(ip)) continue;
        found.add(ip);
      }
    }
  } on Object {
    // Нет интерфейсов — останется loopback.
  }
  found.sort(_ipRank);
  return found;
}

Future<String> preferredLanIPv4() async {
  final all = await lanIPv4Addresses();
  return all.isEmpty ? '127.0.0.1' : all.first;
}

int _ipRank(String a, String b) => _rank(a).compareTo(_rank(b));

int _rank(String ip) {
  if (ip.startsWith('192.168.')) return 0;
  if (ip.startsWith('10.')) return 1;
  if (ip.startsWith('172.17.') ||
      ip.startsWith('172.18.') ||
      ip.startsWith('172.19.')) {
    return 9;
  }
  if (ip.startsWith('172.')) return 2;
  return 3;
}
