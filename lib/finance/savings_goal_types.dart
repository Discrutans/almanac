import 'savings_goal_calendar_projection.dart';

/// Цель накопления: сумма, срок, заметка и ежемесячные обязательные траты.
class SavingsGoal {
  const SavingsGoal({
    required this.id,
    required this.profileId,
    required this.title,
    required this.targetAmount,
    required this.targetDate,
    this.note,
    this.monthlyLivingExpenses = 0,
    this.savedAmount = 0,
    this.colorValue,
    required this.createdAt,
  });

  final String id;
  final String profileId;
  final String title;
  final double targetAmount;
  final DateTime targetDate;
  final String? note;
  final double monthlyLivingExpenses;
  final double savedAmount;
  final int? colorValue;
  final DateTime createdAt;

  int get effectiveColorValue => colorValue ?? defaultSavingsGoalColorValue;

  SavingsGoal copyWith({
    String? id,
    String? profileId,
    String? title,
    double? targetAmount,
    DateTime? targetDate,
    String? note,
    double? monthlyLivingExpenses,
    double? savedAmount,
    int? colorValue,
    DateTime? createdAt,
  }) {
    return SavingsGoal(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      title: title ?? this.title,
      targetAmount: targetAmount ?? this.targetAmount,
      targetDate: targetDate ?? this.targetDate,
      note: note ?? this.note,
      monthlyLivingExpenses:
          monthlyLivingExpenses ?? this.monthlyLivingExpenses,
      savedAmount: savedAmount ?? this.savedAmount,
      colorValue: colorValue ?? this.colorValue,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'profileId': profileId,
      'title': title,
      'targetAmount': targetAmount,
      'targetDate': DateTime(
        targetDate.year,
        targetDate.month,
        targetDate.day,
      ).toIso8601String(),
      if (note != null && note!.isNotEmpty) 'note': note,
      if (monthlyLivingExpenses > 0)
        'monthlyLivingExpenses': monthlyLivingExpenses,
      if (savedAmount > 0) 'savedAmount': savedAmount,
      if (effectiveColorValue != defaultSavingsGoalColorValue)
        'colorValue': effectiveColorValue,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory SavingsGoal.fromJson(Map<String, dynamic> json) {
    return SavingsGoal(
      id: json['id'] as String,
      profileId: json['profileId'] as String,
      title: json['title'] as String,
      targetAmount: (json['targetAmount'] as num).toDouble(),
      targetDate: DateTime.parse(json['targetDate'] as String),
      note: json['note'] as String?,
      monthlyLivingExpenses:
          (json['monthlyLivingExpenses'] as num?)?.toDouble() ?? 0,
      savedAmount: (json['savedAmount'] as num?)?.toDouble() ?? 0,
      colorValue:
          (json['colorValue'] as num?)?.toInt() ?? defaultSavingsGoalColorValue,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

/// Расчёт по цели накопления.
class SavingsPlanSummary {
  const SavingsPlanSummary({
    required this.goal,
    required this.daysRemaining,
    required this.monthsRemaining,
    required this.monthlySavingsNeeded,
    required this.monthlyLivingExpenses,
    required this.totalMonthlyBudget,
    required this.isOverdue,
    this.surplusAfterBudget,
  });

  final SavingsGoal goal;
  final int daysRemaining;
  final int monthsRemaining;
  final double monthlySavingsNeeded;
  final double monthlyLivingExpenses;
  final double totalMonthlyBudget;
  final bool isOverdue;

  /// Остаток после отложений и обязательных трат (если передан заработок).
  final double? surplusAfterBudget;
}
