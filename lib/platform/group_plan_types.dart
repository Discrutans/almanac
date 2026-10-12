enum GroupPlanStatus { open, closed }

/// Вариант времени в групповом планировании.
class PlanSlot {
  const PlanSlot({required this.id, required this.start, required this.end});

  final String id;
  final DateTime start;
  final DateTime end;

  Map<String, dynamic> toJson() => {
    'id': id,
    'start': start.toIso8601String(),
    'end': end.toIso8601String(),
  };

  factory PlanSlot.fromJson(Map<String, dynamic> json) {
    return PlanSlot(
      id: json['id'] as String,
      start: DateTime.parse(json['start'] as String),
      end: DateTime.parse(json['end'] as String),
    );
  }
}

/// Голос участника за один или несколько слотов.
class PlanVote {
  const PlanVote({
    required this.id,
    required this.participantName,
    required this.slotIds,
    required this.createdAt,
  });

  final String id;
  final String participantName;
  final List<String> slotIds;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'participantName': participantName,
    'slotIds': slotIds,
    'createdAt': createdAt.toIso8601String(),
  };

  factory PlanVote.fromJson(Map<String, dynamic> json) {
    return PlanVote(
      id: json['id'] as String,
      participantName: json['participantName'] as String,
      slotIds: (json['slotIds'] as List<dynamic>).cast<String>(),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

/// Групповое планирование: участники голосуют за удобные слоты.
class GroupPlan {
  const GroupPlan({
    required this.id,
    required this.profileId,
    required this.token,
    required this.title,
    required this.slots,
    required this.votes,
    required this.status,
    this.selectedSlotId,
    this.notes,
  });

  final String id;
  final String profileId;
  final String token;
  final String title;
  final List<PlanSlot> slots;
  final List<PlanVote> votes;
  final GroupPlanStatus status;
  final String? selectedSlotId;
  final String? notes;

  bool get isOpen => status == GroupPlanStatus.open;

  PlanSlot? get selectedSlot {
    if (selectedSlotId == null) return null;
    for (final slot in slots) {
      if (slot.id == selectedSlotId) return slot;
    }
    return null;
  }

  /// Количество голосов за каждый слот.
  Map<String, int> voteCountsBySlot() {
    final counts = <String, int>{for (final slot in slots) slot.id: 0};
    for (final vote in votes) {
      for (final slotId in vote.slotIds) {
        counts[slotId] = (counts[slotId] ?? 0) + 1;
      }
    }
    return counts;
  }

  GroupPlan copyWith({
    String? id,
    String? profileId,
    String? token,
    String? title,
    List<PlanSlot>? slots,
    List<PlanVote>? votes,
    GroupPlanStatus? status,
    String? selectedSlotId,
    String? notes,
  }) {
    return GroupPlan(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      token: token ?? this.token,
      title: title ?? this.title,
      slots: slots ?? this.slots,
      votes: votes ?? this.votes,
      status: status ?? this.status,
      selectedSlotId: selectedSlotId ?? this.selectedSlotId,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'profileId': profileId,
    'token': token,
    'title': title,
    'slots': slots.map((s) => s.toJson()).toList(),
    'votes': votes.map((v) => v.toJson()).toList(),
    'status': status.name,
    'selectedSlotId': selectedSlotId,
    'notes': notes,
  };

  factory GroupPlan.fromJson(Map<String, dynamic> json) {
    return GroupPlan(
      id: json['id'] as String,
      profileId: json['profileId'] as String,
      token: json['token'] as String,
      title: json['title'] as String,
      slots: (json['slots'] as List<dynamic>)
          .map((e) => PlanSlot.fromJson(e as Map<String, dynamic>))
          .toList(),
      votes: (json['votes'] as List<dynamic>? ?? const [])
          .map((e) => PlanVote.fromJson(e as Map<String, dynamic>))
          .toList(),
      status: GroupPlanStatus.values.byName(json['status'] as String),
      selectedSlotId: json['selectedSlotId'] as String?,
      notes: json['notes'] as String?,
    );
  }
}

class GroupPlanLookup {
  const GroupPlanLookup({required this.profileId, required this.plan});

  final String profileId;
  final GroupPlan plan;
}
