import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/local/local_data_store.dart';
import '../../data/profiles/profile_kind.dart';
import '../../core/router/deep_link.dart';
import '../platform_config_repository.dart';
import '../server_url.dart';
import 'almanac_mini_server.dart'
    if (dart.library.html) 'almanac_mini_server_stub.dart';

/// Запуск и остановка встроенного Platform API.
class MiniServerController extends ChangeNotifier {
  MiniServerController({
    required this.store,
    required this.platformConfigRepository,
  });

  final LocalDataStore store;
  final PlatformConfigRepository platformConfigRepository;

  final AlmanacMiniServer _server = AlmanacMiniServer();

  MiniServerInfo? _info;
  String? _error;
  var _busy = false;
  var _advertisedOrigin = '';

  MiniServerInfo? get info => _info;
  String? get error => _error;
  bool get busy => _busy;
  bool get running => _server.isRunning;
  bool get supported => !kIsWeb;

  Future<bool> start({required String profileId}) async {
    if (!supported) {
      _error = 'Mini-server недоступен в веб-сборке.';
      notifyListeners();
      return false;
    }
    if (_busy) return running;
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      _server.store.hostSnapshot = () => store.exportSnapshot().toJson();
      final current = platformConfigRepository.getOrCreateConfig(
        profileId: profileId,
      );
      final existingPublic = normalizeServerUrl(current.publicOrigin);
      final existingServer = normalizeServerUrl(current.serverBaseUrl);
      final publicOnInternet =
          existingPublic.isNotEmpty && !isLoopbackOrLanUrl(existingPublic);
      final serverOnInternet =
          existingServer.isNotEmpty && !isLoopbackOrLanUrl(existingServer);
      _advertisedOrigin = publicOnInternet
          ? existingPublic
          : (serverOnInternet ? existingServer : '');
      _server.advertisedOrigin = _advertisedOrigin;
      final info = await _server.start();
      _info = info;
      final bindLocally =
          existingServer.isEmpty ||
          isLoopbackOrLanUrl(existingServer) ||
          existingServer == info.loopbackOrigin ||
          existingServer == info.lanOrigin;
      platformConfigRepository.updateConnectionSettings(
        profileId: profileId,
        serverBaseUrl: bindLocally ? info.loopbackOrigin : existingServer,
        apiKey: current.apiKey,
        workspaceProfileId: current.profileId,
        publicOrigin: publicOnInternet ? existingPublic : current.publicOrigin,
      );
      platformConfigRepository.updateSyncPreferences(
        profileId: profileId,
        autoPush: true,
        autoPull: true,
      );
      _busy = false;
      notifyListeners();
      return true;
    } catch (error) {
      _error = error.toString();
      _busy = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> stop({required String profileId}) async {
    if (_busy) return;
    _busy = true;
    notifyListeners();
    final bound = _info;
    await _server.stop();
    _info = null;
    if (bound != null) {
      final current = platformConfigRepository.getOrCreateConfig(
        profileId: profileId,
      );
      final url = normalizeServerUrl(current.serverBaseUrl);
      if (url == bound.loopbackOrigin || url == bound.lanOrigin) {
        final keepPublic = !isLoopbackOrLanUrl(current.publicOrigin);
        platformConfigRepository.updateConnectionSettings(
          profileId: profileId,
          serverBaseUrl: '',
          apiKey: current.apiKey,
          workspaceProfileId: current.profileId,
          publicOrigin: keepPublic ? current.publicOrigin : '',
        );
      }
    }
    _busy = false;
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(_server.stop());
    super.dispose();
  }

  List<String> get lanIps => _info?.lanIps ?? const [];

  String shareOrigin({required String profileId}) {
    final config = platformConfigRepository.getOrCreateConfig(
      profileId: profileId,
    );
    return workspaceShareOrigin(
      publicOrigin: config.publicOrigin,
      serverBaseUrl: config.serverBaseUrl,
      lanFallback: _advertisedOrigin.isNotEmpty
          ? _advertisedOrigin
          : (_info?.lanOrigin ?? ''),
    );
  }

  Uri? guestHttpInvite({
    required String profileId,
    required ProfileKind kind,
    String? name,
  }) {
    final origin = shareOrigin(profileId: profileId);
    if (origin.isEmpty) return null;
    final config = platformConfigRepository.getOrCreateConfig(
      profileId: profileId,
    );
    if (config.apiKey.trim().isEmpty) return null;
    return workspaceInviteHttp(
      origin: origin,
      apiKey: config.apiKey,
      profileId: config.profileId,
      kind: kind == ProfileKind.personal ? ProfileKind.collaborative : kind,
      name: name,
    );
  }

  String? guestAppInvite({
    required String profileId,
    required ProfileKind kind,
    String? name,
  }) {
    final origin = shareOrigin(profileId: profileId);
    if (origin.isEmpty) return null;
    final config = platformConfigRepository.getOrCreateConfig(
      profileId: profileId,
    );
    if (config.apiKey.trim().isEmpty) return null;
    return workspaceInviteAppLink(
      origin: origin,
      apiKey: config.apiKey,
      profileId: config.profileId,
      kind: kind == ProfileKind.personal ? ProfileKind.collaborative : kind,
      name: name,
    );
  }
}
