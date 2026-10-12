import '../../core/localization/app_localizations.dart';
import '../profiles/context_profile.dart';
import '../local/persisted_repository.dart';

abstract interface class CyclicWorkScheduleRepository {
  void ensureProfile(String profileId);

  void deleteProfileData(String profileId);

  List<CyclicWorkSchedule> getForProfile(String profileId);

  CyclicWorkSchedule add(CyclicWorkSchedule schedule);

  void update({
    required String profileId,
    required CyclicWorkSchedule schedule,
  });

  void delete({required String profileId, required String scheduleId});
}

class InMemoryCyclicWorkScheduleRepository
    with PersistedRepository
    implements CyclicWorkScheduleRepository {
  InMemoryCyclicWorkScheduleRepository({this.seedDemoData = true}) {
    if (seedDemoData) {
      ensureProfile('default');
    }
  }

  final bool seedDemoData;

  final _schedulesByProfile = <String, List<CyclicWorkSchedule>>{};

  Map<String, List<CyclicWorkSchedule>> exportSchedulesByProfile() {
    return _schedulesByProfile.map(
      (profileId, schedules) =>
          MapEntry(profileId, List<CyclicWorkSchedule>.from(schedules)),
    );
  }

  void restoreSchedulesByProfile(Map<String, List<CyclicWorkSchedule>> data) {
    _schedulesByProfile
      ..clear()
      ..addAll(
        data.map(
          (profileId, schedules) =>
              MapEntry(profileId, List<CyclicWorkSchedule>.from(schedules)),
        ),
      );
  }

  @override
  void ensureProfile(String profileId) {
    if (_schedulesByProfile.containsKey(profileId)) return;
    _schedulesByProfile[profileId] = seedDemoData && profileId == 'default'
        ? [_defaultStandupSchedule(profileId)]
        : <CyclicWorkSchedule>[];
  }

  CyclicWorkSchedule _defaultStandupSchedule(String profileId) {
    final l10n = AppLocalizations.forLocale(AppLocalizations.fallback);
    return CyclicWorkSchedule(
      id: 'sched-default-standup',
      profileId: profileId,
      title: l10n.demoStandupScheduleTitle,
      kind: CyclicScheduleKind.rrule,
      rrule: 'FREQ=WEEKLY;BYDAY=MO,WE,FR',
      startTime: '09:30',
      endTime: '10:00',
      colorValue: 0xFF009688,
    );
  }

  /// Обновляет заголовок demo-расписания при смене языка UI.
  void localizeDemoContent(AppLocalizations l10n) {
    final schedules = _schedulesByProfile['default'];
    if (schedules == null) return;
    final index = schedules.indexWhere((s) => s.id == 'sched-default-standup');
    if (index == -1) return;
    schedules[index] = schedules[index].copyWith(
      title: l10n.demoStandupScheduleTitle,
    );
  }

  @override
  void deleteProfileData(String profileId) {
    _schedulesByProfile.remove(profileId);
    notifyChanged();
  }

  @override
  List<CyclicWorkSchedule> getForProfile(String profileId) {
    ensureProfile(profileId);
    return List.unmodifiable(_schedulesByProfile[profileId]!);
  }

  @override
  CyclicWorkSchedule add(CyclicWorkSchedule schedule) {
    ensureProfile(schedule.profileId);
    _schedulesByProfile[schedule.profileId]!.add(schedule);
    notifyChanged();
    return schedule;
  }

  @override
  void update({
    required String profileId,
    required CyclicWorkSchedule schedule,
  }) {
    ensureProfile(profileId);
    final schedules = _schedulesByProfile[profileId]!;
    final index = schedules.indexWhere((item) => item.id == schedule.id);
    if (index == -1) return;
    schedules[index] = schedule;
    notifyChanged();
  }

  @override
  void delete({required String profileId, required String scheduleId}) {
    ensureProfile(profileId);
    _schedulesByProfile[profileId]!.removeWhere(
      (schedule) => schedule.id == scheduleId,
    );
    notifyChanged();
  }
}
