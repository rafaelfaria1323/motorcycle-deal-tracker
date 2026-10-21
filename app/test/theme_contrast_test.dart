import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motorcycle_deal_tracker/app/theme/app_colors.dart';
import 'package:motorcycle_deal_tracker/app/theme/app_theme.dart';

/// WCAG 2 contrast ratio, 1 to 21.
double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// WCAG AA: 4.5 for ordinary text, 3 for large text (24px, or 18.7px
/// bold; the Deal Score badges are 18-28px bold display figures).
const _text = 4.5;
const _large = 3.0;

void main() {
  for (final (name, theme, colors) in [
    ('light', AppTheme.light, AppColors.light),
    ('dark', AppTheme.dark, AppColors.dark),
  ]) {
    final scheme = theme.colorScheme;
    // Text sits on the page background and on cards.
    final backgrounds = {
      'page': scheme.surface,
      'card': scheme.surfaceContainerLowest,
    };

    group('$name theme', () {
      for (final MapEntry(key: where, value: background)
          in backgrounds.entries) {
        final texts = {
          'onSurface': scheme.onSurface,
          'onSurfaceVariant': scheme.onSurfaceVariant,
          'positive': colors.positive,
          'negative': colors.negative,
          'tertiary': scheme.tertiary,
          'error': scheme.error,
        };
        for (final MapEntry(key: text, value: color) in texts.entries) {
          test('$text text on the $where background is readable', () {
            expect(_contrast(color, background), greaterThanOrEqualTo(_text));
          });
        }
      }

      test('text on the containers is readable', () {
        expect(
          _contrast(scheme.onPrimaryContainer, scheme.primaryContainer),
          greaterThanOrEqualTo(_text),
        );
        expect(
          _contrast(scheme.onSecondaryContainer, scheme.secondaryContainer),
          greaterThanOrEqualTo(_text),
        );
        expect(
          _contrast(scheme.onTertiaryContainer, scheme.tertiaryContainer),
          greaterThanOrEqualTo(_text),
        );
        expect(
          _contrast(scheme.onErrorContainer, scheme.errorContainer),
          greaterThanOrEqualTo(_text),
        );
        expect(
          _contrast(scheme.onInverseSurface, scheme.inverseSurface),
          greaterThanOrEqualTo(_text),
        );
      });

      test('every Deal Score band is readable behind its white figure', () {
        for (final score in [95, 85, 75, 65, 40]) {
          expect(
            _contrast(AppColors.onPhoto, colors.score(score)),
            greaterThanOrEqualTo(_large),
            reason: 'score $score',
          );
        }
      });

      // The racing orange: white on filled buttons, small orange labels on
      // the page and cards, and snack bar actions on the inverse surface.
      test('the primary colour is readable as text and behind text', () {
        expect(
          _contrast(scheme.onPrimary, scheme.primary),
          greaterThanOrEqualTo(_text),
        );
        for (final background in backgrounds.values) {
          expect(
            _contrast(scheme.primary, background),
            greaterThanOrEqualTo(_text),
          );
        }
        expect(
          _contrast(scheme.inversePrimary, scheme.inverseSurface),
          greaterThanOrEqualTo(_text),
        );
      });
    });
  }
}
