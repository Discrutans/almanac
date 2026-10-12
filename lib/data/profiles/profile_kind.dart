/// Формат профиля контекста.
enum ProfileKind {
  /// Только это устройство. Облако — позже.
  personal,

  /// Общий календарь: все участники добавляют и правят события.
  collaborative,

  /// Владелец правит календарь, участники только записываются.
  booking,
}

/// Роль на совместном или профиле записи.
enum ProfileRole { owner, member }

extension ProfileKindX on ProfileKind {
  bool get usesServer => this != ProfileKind.personal;

  bool get needsEventLocks =>
      this == ProfileKind.collaborative || this == ProfileKind.booking;
}

/// Права активного (или выбранного) профиля.
class ProfileAccess {
  const ProfileAccess(this.kind, this.role);

  factory ProfileAccess.of({
    required ProfileKind kind,
    required ProfileRole role,
  }) => ProfileAccess(kind, role);

  final ProfileKind kind;
  final ProfileRole role;

  bool get isOwner => role == ProfileRole.owner;
  bool get isMember => role == ProfileRole.member;
  bool get isPersonal => kind == ProfileKind.personal;
  bool get isCollaborative => kind == ProfileKind.collaborative;
  bool get isBooking => kind == ProfileKind.booking;
  bool get usesServer => kind.usesServer;
  bool get needsEventLocks => kind.needsEventLocks;

  bool get canCreateEvents => switch (kind) {
    ProfileKind.personal => true,
    ProfileKind.collaborative => true,
    ProfileKind.booking => isOwner,
  };

  bool get canEditEvents => canCreateEvents;

  bool get canDeleteEvents => canEditEvents;

  bool get canManageSchedules => canCreateEvents;

  /// Слоты записи публикует владелец любого облачного пространства.
  bool get canCreateBookingSlots => isOwner && usesServer;

  bool get canJoinBooking => usesServer;

  bool get canBookOnly => isBooking && isMember;

  bool get canSeeOwnerInbox => isOwner && usesServer;

  bool get canCancelOwnBooking => isMember && usesServer;

  bool get canReleaseBooking => isOwner && usesServer;

  bool get canConfigureWorkspace => isOwner;

  bool get canShareWorkspaceInvite => isOwner && usesServer;

  bool get canMutateLocalCalendarData => isOwner;

  bool get showSyncSettings => usesServer;
}

ProfileKind profileKindFromName(
  String? raw, {
  ProfileKind fallback = ProfileKind.personal,
}) {
  if (raw == null || raw.isEmpty) return fallback;
  for (final kind in ProfileKind.values) {
    if (kind.name == raw) return kind;
  }
  return fallback;
}

ProfileRole profileRoleFromName(
  String? raw, {
  ProfileRole fallback = ProfileRole.owner,
}) {
  if (raw == null || raw.isEmpty) return fallback;
  for (final role in ProfileRole.values) {
    if (role.name == raw) return role;
  }
  return fallback;
}
