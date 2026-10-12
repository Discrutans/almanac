import '../../finance/savings_goal_calendar_projection.dart';
import '../../finance/savings_goal_types.dart';
import '../local/persisted_repository.dart';

abstract interface class SavingsGoalRepository {
  void ensureProfile(String profileId);

  void deleteProfileData(String profileId);

  List<SavingsGoal> getForProfile(String profileId);

  SavingsGoal add(SavingsGoal goal);

  void update({required String profileId, required SavingsGoal goal});

  void delete({required String profileId, required String goalId});
}

class InMemorySavingsGoalRepository
    with PersistedRepository
    implements SavingsGoalRepository {
  InMemorySavingsGoalRepository();

  final _goalsByProfile = <String, List<SavingsGoal>>{};

  Map<String, List<SavingsGoal>> exportGoalsByProfile() {
    return _goalsByProfile.map(
      (profileId, goals) => MapEntry(profileId, List<SavingsGoal>.from(goals)),
    );
  }

  void restoreGoalsByProfile(Map<String, List<SavingsGoal>> data) {
    _goalsByProfile
      ..clear()
      ..addAll(
        data.map(
          (profileId, goals) =>
              MapEntry(profileId, goals.map(_normalizeGoal).toList()),
        ),
      );
  }

  @override
  void ensureProfile(String profileId) {
    _goalsByProfile.putIfAbsent(profileId, () => <SavingsGoal>[]);
  }

  @override
  void deleteProfileData(String profileId) {
    _goalsByProfile.remove(profileId);
    notifyChanged();
  }

  @override
  List<SavingsGoal> getForProfile(String profileId) {
    ensureProfile(profileId);
    return List.unmodifiable(_goalsByProfile[profileId]!.map(_normalizeGoal));
  }

  SavingsGoal _normalizeGoal(SavingsGoal goal) {
    if (goal.colorValue != null) return goal;
    return goal.copyWith(colorValue: defaultSavingsGoalColorValue);
  }

  @override
  SavingsGoal add(SavingsGoal goal) {
    ensureProfile(goal.profileId);
    _goalsByProfile[goal.profileId]!.add(goal);
    notifyChanged();
    return goal;
  }

  @override
  void update({required String profileId, required SavingsGoal goal}) {
    ensureProfile(profileId);
    final goals = _goalsByProfile[profileId]!;
    final index = goals.indexWhere((item) => item.id == goal.id);
    if (index == -1) return;
    goals[index] = goal;
    notifyChanged();
  }

  @override
  void delete({required String profileId, required String goalId}) {
    ensureProfile(profileId);
    _goalsByProfile[profileId]!.removeWhere((goal) => goal.id == goalId);
    notifyChanged();
  }
}
