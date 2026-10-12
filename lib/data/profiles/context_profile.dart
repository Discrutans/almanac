import 'package:flutter/material.dart';
import '../../finance/pay_types.dart';
import '../../core/theme/almanac_tokens.dart';
import 'profile_kind.dart';

export 'profile_kind.dart';

/// Профиль контекста — изолированное рабочее пространство без привязки к аккаунту.
class ContextProfile {
  const ContextProfile({
    required this.id,
    required this.name,
    this.kind = ProfileKind.personal,
    this.role = ProfileRole.owner,
    this.themeMode = ThemeMode.system,
    this.seedColor = Colors.blue,
    this.accentColor = AlmanacBrand.accentEnd,
  });

  final String id;
  final String name;
  final ProfileKind kind;
  final ProfileRole role;
  final ThemeMode themeMode;
  final Color seedColor;
  final Color accentColor;

  ProfileAccess get access => ProfileAccess(kind, role);

  ContextProfile copyWith({
    String? id,
    String? name,
    ProfileKind? kind,
    ProfileRole? role,
    ThemeMode? themeMode,
    Color? seedColor,
    Color? accentColor,
  }) {
    return ContextProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      kind: kind ?? this.kind,
      role: role ?? this.role,
      themeMode: themeMode ?? this.themeMode,
      seedColor: seedColor ?? this.seedColor,
      accentColor: accentColor ?? this.accentColor,
    );
  }
}

/// Тип циклического расписания.
enum CyclicScheduleKind {
  /// Классическое повторение по RRULE (дни недели и т.д.).
  rrule,

  /// Сменный график: N рабочих / M выходных от даты начала.
  shiftCycle,
}

/// Предустановленный сменный график (рабочие/выходные дни).
class ShiftCyclePreset {
  const ShiftCyclePreset({
    required this.label,
    required this.workDays,
    required this.restDays,
  });

  final String label;
  final int workDays;
  final int restDays;

  static const List<ShiftCyclePreset> values = [
    ShiftCyclePreset(label: '2/2', workDays: 2, restDays: 2),
    ShiftCyclePreset(label: '1/3', workDays: 1, restDays: 3),
    ShiftCyclePreset(label: '3/3', workDays: 3, restDays: 3),
    ShiftCyclePreset(label: '5/2', workDays: 5, restDays: 2),
    ShiftCyclePreset(label: '2/5', workDays: 2, restDays: 5),
  ];

  static ShiftCyclePreset? findByLabel(String label) {
    for (final preset in values) {
      if (preset.label == label) return preset;
    }
    return null;
  }
}

/// Правило циклического рабочего расписания для генерации событий.
class CyclicWorkSchedule {
  const CyclicWorkSchedule({
    required this.id,
    required this.profileId,
    required this.title,
    required this.startTime,
    required this.endTime,
    required this.colorValue,
    this.kind = CyclicScheduleKind.rrule,
    this.rrule = '',
    this.cycleStartDate,
    this.workDays = 0,
    this.restDays = 0,
    this.payMode = PayRateMode.hourly,
    this.hourlyRate,
    this.dailyRate,
    this.monthlyRate,
    this.standardHoursPerShift = 8,
    this.overtimeMultiplier = 1.5,
    this.breakMinutes = 0,
    this.bonusPercent,
    this.bonusAmount,
    this.vatPercent,
  });

  final String id;
  final String profileId;
  final String title;
  final String startTime;
  final String endTime;
  final int colorValue;
  final CyclicScheduleKind kind;
  final String rrule;

  /// Дата начала сменного цикла (день 0 = первый рабочий день).
  final DateTime? cycleStartDate;
  final int workDays;
  final int restDays;
  final PayRateMode payMode;
  final double? hourlyRate;
  final double? dailyRate;
  final double? monthlyRate;
  final double standardHoursPerShift;
  final double overtimeMultiplier;
  final int breakMinutes;
  final double? bonusPercent;
  final double? bonusAmount;
  final double? vatPercent;

  bool get isShiftCycle => kind == CyclicScheduleKind.shiftCycle;

  CyclicWorkSchedule copyWith({
    String? id,
    String? profileId,
    String? title,
    String? startTime,
    String? endTime,
    int? colorValue,
    CyclicScheduleKind? kind,
    String? rrule,
    DateTime? cycleStartDate,
    int? workDays,
    int? restDays,
    PayRateMode? payMode,
    double? hourlyRate,
    double? dailyRate,
    double? monthlyRate,
    double? standardHoursPerShift,
    double? overtimeMultiplier,
    int? breakMinutes,
    double? bonusPercent,
    double? bonusAmount,
    double? vatPercent,
  }) {
    return CyclicWorkSchedule(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      title: title ?? this.title,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      colorValue: colorValue ?? this.colorValue,
      kind: kind ?? this.kind,
      rrule: rrule ?? this.rrule,
      cycleStartDate: cycleStartDate ?? this.cycleStartDate,
      workDays: workDays ?? this.workDays,
      restDays: restDays ?? this.restDays,
      payMode: payMode ?? this.payMode,
      hourlyRate: hourlyRate ?? this.hourlyRate,
      dailyRate: dailyRate ?? this.dailyRate,
      monthlyRate: monthlyRate ?? this.monthlyRate,
      standardHoursPerShift:
          standardHoursPerShift ?? this.standardHoursPerShift,
      overtimeMultiplier: overtimeMultiplier ?? this.overtimeMultiplier,
      breakMinutes: breakMinutes ?? this.breakMinutes,
      bonusPercent: bonusPercent ?? this.bonusPercent,
      bonusAmount: bonusAmount ?? this.bonusAmount,
      vatPercent: vatPercent ?? this.vatPercent,
    );
  }
}

/// Настройки темы для профиля контекста.
class ProfileThemeSettings {
  const ProfileThemeSettings({
    required this.themeMode,
    required this.seedColor,
  });

  final ThemeMode themeMode;
  final Color seedColor;
}
