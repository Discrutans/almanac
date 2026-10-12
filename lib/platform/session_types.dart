enum SessionMode { collaborative, booking }

enum SessionStatus { open, closed }

enum SessionBookingRequestStatus { pending, confirmed, rejected }

enum SessionFormFieldKind { text, phone, select }

class SessionFormField {
  const SessionFormField({
    required this.id,
    required this.label,
    this.required = true,
    this.kind = SessionFormFieldKind.text,
    this.options = const [],
  });

  final String id;
  final String label;
  final bool required;
  final SessionFormFieldKind kind;
  final List<String> options;

  bool get isPhone =>
      kind == SessionFormFieldKind.phone || _labelLooksLikePhone(label);

  bool get isSelect => kind == SessionFormFieldKind.select;

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'required': required,
    'kind': kind.name,
    if (options.isNotEmpty) 'options': options,
  };

  factory SessionFormField.fromJson(Map<String, dynamic> json) {
    final label = json['label'] as String;
    return SessionFormField(
      id: json['id'] as String,
      label: label,
      required: json['required'] as bool? ?? true,
      kind: _parseFormFieldKind(json['kind'] as String?, label),
      options: (json['options'] as List<dynamic>? ?? const [])
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList(),
    );
  }
}

SessionFormFieldKind _parseFormFieldKind(String? raw, String label) {
  if (raw == SessionFormFieldKind.phone.name) {
    return SessionFormFieldKind.phone;
  }
  if (raw == SessionFormFieldKind.select.name) {
    return SessionFormFieldKind.select;
  }
  if (_labelLooksLikePhone(label)) return SessionFormFieldKind.phone;
  return SessionFormFieldKind.text;
}

bool _labelLooksLikePhone(String label) {
  final lower = label.toLowerCase();
  return lower.contains('телефон') ||
      lower.contains('phone') ||
      lower.contains('тел.');
}

class SessionSlot {
  const SessionSlot({
    required this.id,
    required this.start,
    required this.end,
    this.label,
    this.color,
  });

  final String id;
  final DateTime start;
  final DateTime end;
  final String? label;
  final String? color;

  Map<String, dynamic> toJson() => {
    'id': id,
    'start': start.toIso8601String(),
    'end': end.toIso8601String(),
    if (label != null) 'label': label,
    if (color != null) 'color': color,
  };

  factory SessionSlot.fromJson(Map<String, dynamic> json) {
    return SessionSlot(
      id: json['id'] as String,
      start: DateTime.parse(json['start'] as String),
      end: DateTime.parse(json['end'] as String),
      label: json['label'] as String?,
      color: json['color'] as String?,
    );
  }
}

class SessionState {
  const SessionState({
    this.slots = const [],
    this.formFields = const [],
    this.settings = const {},
  });

  final List<SessionSlot> slots;
  final List<SessionFormField> formFields;
  final Map<String, dynamic> settings;

  Map<String, dynamic> toJson() => {
    'slots': slots.map((slot) => slot.toJson()).toList(),
    'form_fields': formFields.map((field) => field.toJson()).toList(),
    if (settings.isNotEmpty) 'settings': settings,
  };

  factory SessionState.fromJson(Map<String, dynamic> json) {
    return SessionState(
      slots: (json['slots'] as List<dynamic>? ?? const [])
          .map((item) => SessionSlot.fromJson(item as Map<String, dynamic>))
          .toList(),
      formFields:
          (json['form_fields'] as List<dynamic>? ??
                  json['formFields'] as List<dynamic>? ??
                  const [])
              .map(
                (item) =>
                    SessionFormField.fromJson(item as Map<String, dynamic>),
              )
              .toList(),
      settings: Map<String, dynamic>.from(
        json['settings'] as Map<String, dynamic>? ?? const {},
      ),
    );
  }

  SessionState copyWith({
    List<SessionSlot>? slots,
    List<SessionFormField>? formFields,
    Map<String, dynamic>? settings,
  }) {
    return SessionState(
      slots: slots ?? this.slots,
      formFields: formFields ?? this.formFields,
      settings: settings ?? this.settings,
    );
  }
}

class SessionClientPresence {
  const SessionClientPresence({
    required this.clientId,
    required this.displayName,
    required this.lastSeenAt,
  });

  final String clientId;
  final String displayName;
  final DateTime lastSeenAt;

  Map<String, dynamic> toJson() => {
    'client_id': clientId,
    'display_name': displayName,
    'last_seen_at': lastSeenAt.toUtc().toIso8601String(),
  };

  factory SessionClientPresence.fromJson(Map<String, dynamic> json) {
    return SessionClientPresence(
      clientId: json['client_id'] as String? ?? json['clientId'] as String,
      displayName:
          json['display_name'] as String? ?? json['displayName'] as String,
      lastSeenAt: DateTime.parse(
        json['last_seen_at'] as String? ?? json['lastSeenAt'] as String,
      ),
    );
  }
}

class SessionBookingRequest {
  const SessionBookingRequest({
    required this.id,
    required this.sessionId,
    required this.slotId,
    required this.fields,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String sessionId;
  final String slotId;
  final Map<String, String> fields;
  final SessionBookingRequestStatus status;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'session_id': sessionId,
    'slot_id': slotId,
    'fields': fields,
    'status': status.name,
    'created_at': createdAt.toUtc().toIso8601String(),
  };

  factory SessionBookingRequest.fromJson(Map<String, dynamic> json) {
    final rawFields = json['fields'] as Map<String, dynamic>? ?? const {};
    return SessionBookingRequest(
      id: json['id'] as String,
      sessionId: json['session_id'] as String? ?? json['sessionId'] as String,
      slotId: json['slot_id'] as String? ?? json['slotId'] as String,
      fields: rawFields.map((key, value) => MapEntry(key, value.toString())),
      status: SessionBookingRequestStatus.values.byName(
        json['status'] as String,
      ),
      createdAt: DateTime.parse(
        json['created_at'] as String? ?? json['createdAt'] as String,
      ),
    );
  }
}

class PlatformSession {
  const PlatformSession({
    required this.id,
    required this.token,
    required this.profileId,
    required this.mode,
    required this.title,
    required this.state,
    required this.version,
    required this.status,
    required this.createdAt,
    this.requests = const [],
    this.workspaceApiKey,
  });

  final String id;
  final String token;
  final String profileId;
  final SessionMode mode;
  final String title;
  final SessionState state;
  final int version;
  final SessionStatus status;
  final DateTime createdAt;
  final List<SessionBookingRequest> requests;
  final String? workspaceApiKey;

  bool get isOpen => status == SessionStatus.open;

  PlatformSession copyWith({
    List<SessionBookingRequest>? requests,
    int? version,
    SessionState? state,
    SessionStatus? status,
    String? workspaceApiKey,
  }) {
    return PlatformSession(
      id: id,
      token: token,
      profileId: profileId,
      mode: mode,
      title: title,
      state: state ?? this.state,
      version: version ?? this.version,
      status: status ?? this.status,
      createdAt: createdAt,
      requests: requests ?? this.requests,
      workspaceApiKey: workspaceApiKey ?? this.workspaceApiKey,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'token': token,
    'profile_id': profileId,
    'mode': mode.name,
    'title': title,
    'state': state.toJson(),
    'version': version,
    'status': status.name,
    'created_at': createdAt.toUtc().toIso8601String(),
    'requests': requests.map((request) => request.toJson()).toList(),
    if (workspaceApiKey != null) 'workspace_api_key': workspaceApiKey,
  };

  factory PlatformSession.fromJson(Map<String, dynamic> json) {
    return PlatformSession(
      id: json['id'] as String,
      token: json['token'] as String,
      profileId:
          json['profile_id'] as String? ??
          json['profileId'] as String? ??
          'default',
      mode: SessionMode.values.byName(json['mode'] as String),
      title: json['title'] as String,
      state: SessionState.fromJson(json['state'] as Map<String, dynamic>),
      version: json['version'] as int,
      status: SessionStatus.values.byName(json['status'] as String),
      createdAt: DateTime.parse(
        json['created_at'] as String? ?? json['createdAt'] as String,
      ),
      requests: (json['requests'] as List<dynamic>? ?? const [])
          .map(
            (item) =>
                SessionBookingRequest.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
      workspaceApiKey:
          json['workspace_api_key'] as String? ??
          json['workspaceApiKey'] as String?,
    );
  }
}

extension PlatformSessionBooking on PlatformSession {
  int get slotCapacity {
    final raw = state.settings['slot_capacity'];
    if (raw is int) return raw.clamp(1, 999);
    if (raw is num) return raw.toInt().clamp(1, 999);
    return 1;
  }

  int activeBookingsForSlot(String slotId) {
    return requests
        .where(
          (request) =>
              request.slotId == slotId &&
              (request.status == SessionBookingRequestStatus.pending ||
                  request.status == SessionBookingRequestStatus.confirmed),
        )
        .length;
  }

  int availableSpotsForSlot(String slotId) {
    return (slotCapacity - activeBookingsForSlot(slotId)).clamp(
      0,
      slotCapacity,
    );
  }

  bool isSlotFull(String slotId) => availableSpotsForSlot(slotId) <= 0;
}

class CreateSessionResult {
  const CreateSessionResult({
    required this.id,
    required this.token,
    required this.deepLink,
    required this.mode,
    required this.title,
    this.durationMinutes,
    this.isOpen = true,
    this.accentColor,
  });

  final String id;
  final String token;
  final String deepLink;
  final SessionMode mode;
  final String title;
  final int? durationMinutes;
  final bool isOpen;
  final String? accentColor;

  factory CreateSessionResult.fromJson(Map<String, dynamic> json) {
    return CreateSessionResult(
      id: json['id'] as String,
      token: json['token'] as String,
      deepLink: json['deep_link'] as String? ?? json['deepLink'] as String,
      mode: SessionMode.values.byName(json['mode'] as String),
      title: json['title'] as String,
      durationMinutes: json['duration_minutes'] as int? ?? json['durationMinutes'] as int?,
      isOpen: json['is_open'] as bool? ?? json['isOpen'] as bool? ?? true,
      accentColor: json['accent_color'] as String? ?? json['color'] as String?,
    );
  }
}
