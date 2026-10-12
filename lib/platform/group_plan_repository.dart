import 'package:uuid/uuid.dart';
import '../data/local/persisted_repository.dart';
import 'group_plan_types.dart';

const _uuid = Uuid();

abstract interface class GroupPlanRepository {
  void ensureProfile(String profileId);

  void deleteProfileData(String profileId);

  List<GroupPlan> listPlans({required String profileId});

  GroupPlan? findPlanByToken({
    required String profileId,
    required String token,
  });

  GroupPlanLookup? findPlanByTokenGlobally(String token);

  GroupPlan createPlan({
    required String profileId,
    required String title,
    required List<PlanSlot> slots,
    String? notes,
  });

  PlanVote submitVote({
    required String profileId,
    required String token,
    required String participantName,
    required List<String> slotIds,
  });

  GroupPlan closePlan({
    required String profileId,
    required String token,
    required String selectedSlotId,
  });

  void deletePlan({required String profileId, required String token});
}

class InMemoryGroupPlanRepository
    with PersistedRepository
    implements GroupPlanRepository {
  InMemoryGroupPlanRepository();

  final _plansByProfile = <String, Map<String, GroupPlan>>{};

  Map<String, GroupPlan> _plansFor(String profileId) {
    return _plansByProfile.putIfAbsent(profileId, () => {});
  }

  Map<String, List<GroupPlan>> exportPlansByProfile() {
    return _plansByProfile.map(
      (profileId, plans) =>
          MapEntry(profileId, plans.values.toList(growable: false)),
    );
  }

  void restore({required Map<String, List<GroupPlan>> plansByProfile}) {
    _plansByProfile.clear();
    for (final entry in plansByProfile.entries) {
      _plansByProfile[entry.key] = {
        for (final plan in entry.value) plan.token: plan,
      };
    }
  }

  String _generateToken() {
    return _uuid.v4().split('-').first;
  }

  @override
  void ensureProfile(String profileId) {
    _plansFor(profileId);
  }

  @override
  void deleteProfileData(String profileId) {
    _plansByProfile.remove(profileId);
    notifyChanged();
  }

  @override
  List<GroupPlan> listPlans({required String profileId}) {
    ensureProfile(profileId);
    return _plansFor(profileId).values.toList()
      ..sort((a, b) => a.title.compareTo(b.title));
  }

  @override
  GroupPlan? findPlanByToken({
    required String profileId,
    required String token,
  }) {
    ensureProfile(profileId);
    return _plansFor(profileId)[token];
  }

  @override
  GroupPlanLookup? findPlanByTokenGlobally(String token) {
    for (final entry in _plansByProfile.entries) {
      final plan = entry.value[token];
      if (plan != null) {
        return GroupPlanLookup(profileId: entry.key, plan: plan);
      }
    }
    return null;
  }

  @override
  GroupPlan createPlan({
    required String profileId,
    required String title,
    required List<PlanSlot> slots,
    String? notes,
  }) {
    ensureProfile(profileId);
    if (slots.isEmpty) {
      throw ArgumentError('Нужен хотя бы один вариант времени');
    }

    var token = _generateToken();
    while (findPlanByTokenGlobally(token) != null) {
      token = _generateToken();
    }

    final plan = GroupPlan(
      id: _uuid.v4(),
      profileId: profileId,
      token: token,
      title: title,
      slots: slots,
      votes: const [],
      status: GroupPlanStatus.open,
      notes: notes,
    );

    _plansFor(profileId)[token] = plan;
    notifyChanged();
    return plan;
  }

  @override
  PlanVote submitVote({
    required String profileId,
    required String token,
    required String participantName,
    required List<String> slotIds,
  }) {
    ensureProfile(profileId);
    final plan = _plansFor(profileId)[token];
    if (plan == null) {
      throw StateError('Group plan not found: $token');
    }
    if (!plan.isOpen) {
      throw StateError('Голосование закрыто');
    }
    if (participantName.trim().isEmpty) {
      throw ArgumentError('Укажите имя');
    }
    if (slotIds.isEmpty) {
      throw ArgumentError('Выберите хотя бы один слот');
    }

    final validSlotIds = plan.slots.map((s) => s.id).toSet();
    for (final slotId in slotIds) {
      if (!validSlotIds.contains(slotId)) {
        throw ArgumentError('Неизвестный слот: $slotId');
      }
    }

    final vote = PlanVote(
      id: _uuid.v4(),
      participantName: participantName.trim(),
      slotIds: slotIds,
      createdAt: DateTime.now(),
    );

    final updated = plan.copyWith(votes: [...plan.votes, vote]);
    _plansFor(profileId)[token] = updated;
    notifyChanged();
    return vote;
  }

  @override
  GroupPlan closePlan({
    required String profileId,
    required String token,
    required String selectedSlotId,
  }) {
    ensureProfile(profileId);
    final plan = _plansFor(profileId)[token];
    if (plan == null) {
      throw StateError('Group plan not found: $token');
    }

    final slotExists = plan.slots.any((s) => s.id == selectedSlotId);
    if (!slotExists) {
      throw ArgumentError('Неизвестный слот: $selectedSlotId');
    }

    final updated = plan.copyWith(
      status: GroupPlanStatus.closed,
      selectedSlotId: selectedSlotId,
    );
    _plansFor(profileId)[token] = updated;
    notifyChanged();
    return updated;
  }

  @override
  void deletePlan({required String profileId, required String token}) {
    ensureProfile(profileId);
    _plansFor(profileId).remove(token);
    notifyChanged();
  }
}

/// Создаёт слоты на несколько дней с фиксированным временем.
List<PlanSlot> buildPlanSlots({
  required DateTime startDay,
  required int dayCount,
  required int hour,
  required int minute,
  required Duration duration,
}) {
  final slots = <PlanSlot>[];
  for (var i = 0; i < dayCount; i += 1) {
    final day = startDay.add(Duration(days: i));
    final start = DateTime(day.year, day.month, day.day, hour, minute);
    slots.add(PlanSlot(id: _uuid.v4(), start: start, end: start.add(duration)));
  }
  return slots;
}
