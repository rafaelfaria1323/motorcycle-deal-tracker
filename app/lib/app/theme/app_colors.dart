import 'package:flutter/material.dart';

/// Colours with a meaning (good/bad, score bands) that Material's colour
/// scheme has no slot for. Read with `AppColors.of(context)`.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.positive,
    required this.negative,
    required this.scoreExcellent,
    required this.scoreVeryGood,
    required this.scoreInteresting,
    required this.scoreNormal,
    required this.scorePoor,
  });

  /// Good news: a price drop, a reassuring fact.
  final Color positive;

  /// Bad news: a price rise, a risk.
  final Color negative;

  // Deal Score bands, solid behind white text (also on top of photos).
  final Color scoreExcellent;
  final Color scoreVeryGood;
  final Color scoreInteresting;
  final Color scoreNormal;
  final Color scorePoor;

  static const light = AppColors(
    positive: Color(0xFF0B8A5E),
    negative: Color(0xFFD12B2B),
    scoreExcellent: Color(0xFF0B8A5E),
    scoreVeryGood: Color(0xFF4A8C12),
    scoreInteresting: Color(0xFFB07800),
    scoreNormal: Color(0xFFD45A0A),
    scorePoor: Color(0xFFC92A2A),
  );

  static const dark = AppColors(
    positive: Color(0xFF3DD68C),
    negative: Color(0xFFFF7A7A),
    scoreExcellent: Color(0xFF0E9F6E),
    scoreVeryGood: Color(0xFF55A015),
    scoreInteresting: Color(0xFFC08600),
    scoreNormal: Color(0xFFE0620B),
    scorePoor: Color(0xFFD93636),
  );

  static AppColors of(BuildContext context) =>
      Theme.of(context).extension<AppColors>() ?? light;

  /// Bands from the concept doc: 90+ excellent, 80+ very good,
  /// 70+ interesting, 60+ normal, below 60 poor.
  Color score(int score) {
    if (score >= 90) return scoreExcellent;
    if (score >= 80) return scoreVeryGood;
    if (score >= 70) return scoreInteresting;
    if (score >= 60) return scoreNormal;
    return scorePoor;
  }

  @override
  AppColors copyWith({
    Color? positive,
    Color? negative,
    Color? scoreExcellent,
    Color? scoreVeryGood,
    Color? scoreInteresting,
    Color? scoreNormal,
    Color? scorePoor,
  }) => AppColors(
    positive: positive ?? this.positive,
    negative: negative ?? this.negative,
    scoreExcellent: scoreExcellent ?? this.scoreExcellent,
    scoreVeryGood: scoreVeryGood ?? this.scoreVeryGood,
    scoreInteresting: scoreInteresting ?? this.scoreInteresting,
    scoreNormal: scoreNormal ?? this.scoreNormal,
    scorePoor: scorePoor ?? this.scorePoor,
  );

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other == null) return this;
    return AppColors(
      positive: Color.lerp(positive, other.positive, t)!,
      negative: Color.lerp(negative, other.negative, t)!,
      scoreExcellent: Color.lerp(scoreExcellent, other.scoreExcellent, t)!,
      scoreVeryGood: Color.lerp(scoreVeryGood, other.scoreVeryGood, t)!,
      scoreInteresting: Color.lerp(
        scoreInteresting,
        other.scoreInteresting,
        t,
      )!,
      scoreNormal: Color.lerp(scoreNormal, other.scoreNormal, t)!,
      scorePoor: Color.lerp(scorePoor, other.scorePoor, t)!,
    );
  }
}
