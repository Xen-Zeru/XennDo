import 'package:flutter/material.dart';

@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.priorityLow,
    required this.priorityMedium,
    required this.priorityHigh,
    required this.success,
    required this.warning,
    required this.info,
  });

  final Color priorityLow;
  final Color priorityMedium;
  final Color priorityHigh;
  final Color success;
  final Color warning;
  final Color info;

  static const AppColors light = AppColors(
    priorityLow: Color(0xFF00695F),
    priorityMedium: Color(0xFF7A5900),
    priorityHigh: Color(0xFFB3261E),
    success: Color(0xFF2E6B34),
    warning: Color(0xFF7A5900),
    info: Color(0xFF005C8F),
  );

  static const AppColors dark = AppColors(
    priorityLow: Color(0xFF79D9C9),
    priorityMedium: Color(0xFFFFC857),
    priorityHigh: Color(0xFFFFB4AB),
    success: Color(0xFF9ED8A4),
    warning: Color(0xFFFFC857),
    info: Color(0xFF9CCBFF),
  );

  @override
  AppColors copyWith({
    Color? priorityLow,
    Color? priorityMedium,
    Color? priorityHigh,
    Color? success,
    Color? warning,
    Color? info,
  }) {
    return AppColors(
      priorityLow: priorityLow ?? this.priorityLow,
      priorityMedium: priorityMedium ?? this.priorityMedium,
      priorityHigh: priorityHigh ?? this.priorityHigh,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      info: info ?? this.info,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) {
      return this;
    }

    return AppColors(
      priorityLow: Color.lerp(priorityLow, other.priorityLow, t)!,
      priorityMedium: Color.lerp(priorityMedium, other.priorityMedium, t)!,
      priorityHigh: Color.lerp(priorityHigh, other.priorityHigh, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      info: Color.lerp(info, other.info, t)!,
    );
  }
}

extension AppColorsContext on BuildContext {
  AppColors get appColors =>
      Theme.of(this).extension<AppColors>() ?? AppColors.light;
}
