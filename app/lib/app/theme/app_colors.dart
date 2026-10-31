import 'package:flutter/material.dart';

/// Colours with a meaning (good/bad, score bands) that Material's colour
/// scheme has no slot for. Read with `AppColors.of(context)`.
@immutable
class const AppColors({
  /// Good news: a price drop, a reassuring fact.
  required final Color positive,

  /// Bad news: a price rise, a risk.
  required final Color negative,
  required final Color scoreExcellent,
  required final Color scoreVeryGood,
  required final Color scoreInteresting,
  required final Color scoreNormal,
  required final Color scorePoor,
}) extends ThemeExtension<AppColors> {
  // Deal Score bands, solid behind white text (also on top of photos).

  // Overlays on photos and score badges: the same in light and dark mode.
  static const onPhoto = Color(0xFFFFFFFF);
  static const photoBackdrop = Color(0xFF000000);
  static const photoCounterScrim = Color(0x8A000000);
  static const photoControlScrim = Color(0x73000000);
  static const photoPillScrim = Color(0xB3000000);

  static const light = AppColors(
    positive: Color(0xFF0A7F57),
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
