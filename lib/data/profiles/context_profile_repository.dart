import 'context_profile.dart';
import '../../core/localization/app_localizations.dart';
import '../local/persisted_repository.dart';

abstract interface class ContextProfileRepository {
  List<ContextProfile> getAll();

  ContextProfile? getById(String id);

  ContextProfile getActive();

  void setActive(String profileId);

  ContextProfile createProfile({
    required String name,
    ProfileKind kind = ProfileKind.personal,
    ProfileRole role = ProfileRole.owner,
    String? id,
  });

  /// Подключение к уже существующему общему профилю с тем же id.
  ContextProfile joinProfile({
    required String id,
    required String name,
    required ProfileKind kind,
  });

  void renameProfile({required String id, required String name});

  void updateProfile(ContextProfile profile);

  /// Удаляет профиль. Нельзя удалить последний профиль.
  void deleteProfile(String id);

  /// ID профилей, чьи события показываются в календаре (split-view).
  Set<String> getVisibleProfileIds();

  /// Включает/выключает профиль в объединённом календаре.
  /// Последний видимый профиль отключить нельзя.
  void toggleProfileVisibility(String profileId);

  void ensureProfileVisible(String profileId);

  /// Переименовывает профиль по умолчанию, если имя ещё не менял пользователь.
  void localizeDefaultProfile(AppLocalizations l10n);
}

class InMemoryContextProfileRepository
    with PersistedRepository
    implements ContextProfileRepository {
  InMemoryContextProfileRepository() {
    final l10n = AppLocalizations.forLocale(AppLocalizations.fallback);
    _profiles.add(ContextProfile(id: 'default', name: l10n.defaultProfileName));
    _activeId = 'default';
  }

  final _profiles = <ContextProfile>[];
  final _visibleProfileIds = <String>{'default'};
  late String _activeId;
  var _idCounter = 0;

  List<ContextProfile> exportProfiles() => List.unmodifiable(_profiles);

  String exportActiveProfileId() => _activeId;

  Set<String> exportVisibleProfileIds() => Set.unmodifiable(_visibleProfileIds);

  void restore({
    required List<ContextProfile> profiles,
    required String activeProfileId,
    required Set<String> visibleProfileIds,
  }) {
    _profiles
      ..clear()
      ..addAll(profiles);
    _activeId = activeProfileId;
    _visibleProfileIds
      ..clear()
      ..addAll(visibleProfileIds);
    _idCounter = profiles.length;
  }

  @override
  List<ContextProfile> getAll() => List.unmodifiable(_profiles);

  @override
  ContextProfile? getById(String id) {
    for (final profile in _profiles) {
      if (profile.id == id) return profile;
    }
    return null;
  }

  @override
  ContextProfile getActive() => getById(_activeId) ?? _profiles.first;

  @override
  void setActive(String profileId) {
    if (getById(profileId) != null) {
      _activeId = profileId;
      notifyChanged();
    }
  }

  @override
  ContextProfile createProfile({
    required String name,
    ProfileKind kind = ProfileKind.personal,
    ProfileRole role = ProfileRole.owner,
    String? id,
  }) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(
        name,
        'name',
        'Имя профиля не может быть пустым',
      );
    }

    final profileId = (id ?? '').trim();
    if (profileId.isNotEmpty) {
      if (getById(profileId) != null) {
        throw StateError('Profile already exists: $profileId');
      }
    } else {
      _idCounter += 1;
    }
    final profile = ContextProfile(
      id: profileId.isNotEmpty
          ? profileId
          : 'profile-$_idCounter-${DateTime.now().microsecondsSinceEpoch}',
      name: trimmed,
      kind: kind,
      role: role,
    );
    _profiles.add(profile);
    _visibleProfileIds.add(profile.id);
    notifyChanged();
    return profile;
  }

  @override
  ContextProfile joinProfile({
    required String id,
    required String name,
    required ProfileKind kind,
  }) {
    return createProfile(
      name: name,
      kind: kind,
      role: ProfileRole.member,
      id: id,
    );
  }

  @override
  void renameProfile({required String id, required String name}) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(
        name,
        'name',
        'Имя профиля не может быть пустым',
      );
    }

    final index = _profiles.indexWhere((p) => p.id == id);
    if (index == -1) {
      throw StateError('Profile not found: $id');
    }

    _profiles[index] = _profiles[index].copyWith(name: trimmed);
    notifyChanged();
  }

  @override
  void updateProfile(ContextProfile profile) {
    final index = _profiles.indexWhere((p) => p.id == profile.id);
    if (index == -1) return;
    _profiles[index] = profile;
    notifyChanged();
  }

  @override
  void deleteProfile(String id) {
    if (_profiles.length <= 1) {
      throw StateError('Нельзя удалить последний профиль');
    }

    final index = _profiles.indexWhere((p) => p.id == id);
    if (index == -1) {
      throw StateError('Profile not found: $id');
    }

    _profiles.removeAt(index);

    _visibleProfileIds.remove(id);
    if (_visibleProfileIds.isEmpty) {
      _visibleProfileIds.add(_profiles.first.id);
    }

    if (_activeId == id) {
      _activeId = _profiles.first.id;
    }
    notifyChanged();
  }

  @override
  Set<String> getVisibleProfileIds() => Set.unmodifiable(_visibleProfileIds);

  @override
  void toggleProfileVisibility(String profileId) {
    if (getById(profileId) == null) return;

    if (_visibleProfileIds.contains(profileId)) {
      if (_visibleProfileIds.length <= 1) return;
      _visibleProfileIds.remove(profileId);
      notifyChanged();
      return;
    }

    _visibleProfileIds.add(profileId);
    notifyChanged();
  }

  @override
  void ensureProfileVisible(String profileId) {
    if (getById(profileId) != null) {
      _visibleProfileIds.add(profileId);
      notifyChanged();
    }
  }

  @override
  void localizeDefaultProfile(AppLocalizations l10n) {
    const defaultId = 'default';
    final profile = getById(defaultId);
    if (profile == null) return;

    final ruName = AppLocalizations.forLocale(
      AppLocalizations.fallback,
    ).defaultProfileName;
    final enName = AppLocalizations.forLocale(
      AppLocalizations.localeFromCode('en'),
    ).defaultProfileName;
    if (profile.name == ruName || profile.name == enName) {
      renameProfile(id: defaultId, name: l10n.defaultProfileName);
    }
  }
}
