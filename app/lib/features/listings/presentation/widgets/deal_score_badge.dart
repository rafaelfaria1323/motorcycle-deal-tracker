import 'package:flutter/material.dart';

/// Colour bands follow the concept doc: 90+ excellent, 80+ very good,
/// 70+ interesting, 60+ normal, below 60 poor.
class DealScoreBadge extends StatelessWidget {
  const DealScoreBadge({required this.score, super.key});

  final int score;

  Color get _color {
    if (score >= 90) return const Color(0xFF2E7D32);
    if (score >= 80) return const Color(0xFF558B2F);
    if (score >= 70) return const Color(0xFFF9A825);
    if (score >= 60) return const Color(0xFFEF6C00);
    return const Color(0xFFC62828);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Deal Score $score',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: _color,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          '$score',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
