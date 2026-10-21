import 'dart:math';

import 'package:equatable/equatable.dart';

import '../../../core/formatting/formatters.dart';
import '../domain/entities/listing.dart';

enum ExplanationTone { positive, negative, neutral }

class ExplanationLine extends Equatable {
  const ExplanationLine(this.tone, this.text);

  final ExplanationTone tone;
  final String text;

  @override
  List<Object?> get props => [tone, text];
}

class ScoreExplanation extends Equatable {
  const ScoreExplanation({
    required this.score,
    required this.label,
    required this.lines,
    this.slicesUsed,
    this.slicesTotal,
  });

  final int score;
  final String label;
  final List<ExplanationLine> lines;
  final int? slicesUsed;
  final int? slicesTotal;

  @override
  List<Object?> get props => [score, label, lines, slicesUsed, slicesTotal];
}

/// The equipment codes of `listing_extras`, in the order they are offered
/// as filters, with their labels.
const extraLabels = {
  'quickshifter': 'quickshifter',
  'exhaust': 'escape desportivo',
  'luggage': 'malas',
  'heated_grips': 'punhos aquecidos',
  'protection': 'proteções',
  'new_tyres': 'pneus novos',
  'tail_tidy': 'suporte de matrícula curto',
  'screen': 'bolha fumada ou desportiva',
  'levers': 'manetes ajustáveis',
  'mirrors': 'espelhos de ponta de guiador',
  'phone_mount': 'suporte de telemóvel ou USB',
  'alarm': 'alarme ou localizador',
  'steering_damper': 'amortecedor de direção',
  'centre_stand': 'descanso central',
  'cruise_control': 'cruise control',
  'suspension': 'suspensão melhorada',
  'led_indicators': 'piscas LED',
  'passenger_grips': 'pegas para o pendura',
  'original_parts': 'peças de origem incluídas',
};

/// The extras found in the ad ("quickshifter, malas"), or null when none.
String? extrasText(Map<String, dynamic>? breakdown) {
  final labels = [
    for (final code in (breakdown?['extras'] as List? ?? const []))
      ?extraLabels[code],
  ];
  return labels.isEmpty ? null : labels.join(', ');
}

/// The seller slice: the dealer's score from its ads' warning signs
/// (relists, sharp price changes, repeats, no mileage; `dealer_score`), or
/// null when it was not scored (private seller, fewer than 5 bikes).
ExplanationLine? sellerLine(Map<String, dynamic>? breakdown) {
  final score = ((breakdown?['scores'] as Map?)?['seller'] as num?)?.round();
  if (score == null) return null;
  final bikes = (breakdown?['dealer_bikes'] as num?)?.toInt();
  final detail = '$score/100${bikes == null ? '' : ' em $bikes motas'}';
  if (score >= 80) {
    return ExplanationLine(
      ExplanationTone.positive,
      'Stand com anúncios fiáveis ($detail)',
    );
  }
  if (score < 50) {
    return ExplanationLine(
      ExplanationTone.negative,
      'Stand com muitos sinais de alerta nos anúncios ($detail)',
    );
  }
  return ExplanationLine(
    ExplanationTone.neutral,
    'Stand com alguns sinais de alerta nos anúncios ($detail)',
  );
}

/// The kilometres a year that count as normal for a motorcycle (cars do
/// 10-12 000). Keep in step with expected_mileage() in the database.
const normalKmPerYear = 5000;

/// [day] as a decimal year (2 July 2026 is about 2026.5), as
/// decimal_year() in the database.
double decimalYear(DateTime day) =>
    day.year +
    DateTime.utc(
          day.year,
          day.month,
          day.day,
        ).difference(DateTime.utc(day.year)).inDays /
        365.25;

/// The normal mileage of a bike of [year] at [reference] (a decimal year,
/// [decimalYear]): from mid-year registration, never less than one year's.
/// Counted in days, so it doesn't jump on 1 January.
int expectedMileage(int year, num reference) =>
    (max(reference - year - 0.5, 1) * normalKmPerYear).round();

/// How [km] compares with the normal for a bike of [year]: low (half the
/// normal or less), normal (up to 10 % over), high, very high (over twice).
/// Without a year, only a low mileage is said.
ExplanationLine? mileageForAge(int? km, int? year, num reference) {
  if (km == null) return null;
  final kmText = Formatters.mileage(km);
  if (year == null) {
    return km <= normalKmPerYear
        ? ExplanationLine(ExplanationTone.positive, 'Poucos km ($kmText)')
        : null;
  }
  final normal = expectedMileage(year, reference);
  final ratio = km / normal;
  final normalText = 'normal: cerca de ${Formatters.mileage(normal)}';
  if (ratio <= 0.5) {
    return ExplanationLine(
      ExplanationTone.positive,
      'Poucos km para o ano ($kmText; $normalText)',
    );
  }
  if (ratio > 2) {
    return ExplanationLine(
      ExplanationTone.negative,
      'Muitos km para o ano ($kmText; $normalText)',
    );
  }
  if (ratio > 1.1) {
    return ExplanationLine(
      ExplanationTone.negative,
      'Km acima do normal para o ano ($kmText; $normalText)',
    );
  }
  return ExplanationLine(
    ExplanationTone.neutral,
    'Km normais para o ano ($kmText)',
  );
}

/// Turns the stored score data into human-readable lines.
/// Only things that actually influence the score are listed.
abstract final class ScoreExplainer {
  static const _riskLines = <String, (ExplanationTone, String)>{
    'price_far_below_market': (
      ExplanationTone.negative,
      'Preço muito abaixo do mercado, confirme se é real',
    ),
    'price_below_market': (
      ExplanationTone.negative,
      'Preço bastante abaixo do mercado',
    ),
    'possible_accident': (
      ExplanationTone.negative,
      'A descrição pode indicar acidente',
    ),
    'no_mileage': (ExplanationTone.negative, 'Quilometragem não indicada'),
    'no_year': (ExplanationTone.negative, 'Ano não indicado'),
    'suspicious_mileage': (
      ExplanationTone.negative,
      'Quilometragem pouco provável para o ano, confirme com o vendedor',
    ),
    'thin_description': (ExplanationTone.negative, 'Descrição muito curta'),
    'no_location': (ExplanationTone.negative, 'Localização não indicada'),
    'many_owners': (ExplanationTone.negative, 'Três ou mais registos (donos)'),
    'no_service_book': (
      ExplanationTone.negative,
      'Sem livro de revisões completo',
    ),
    'imported': (ExplanationTone.negative, 'Mota importada'),
    'text_year_mismatch': (
      ExplanationTone.negative,
      'O ano escrito na descrição não bate certo com o do anúncio',
    ),
    'text_mileage_mismatch': (
      ExplanationTone.negative,
      'A descrição fala em mais quilómetros do que o anúncio indica',
    ),
    'text_origin_mismatch': (
      ExplanationTone.negative,
      'A descrição diz importada, o anúncio diz nacional',
    ),
    'text_service_book_mismatch': (
      ExplanationTone.negative,
      'A descrição diz sem livro, o anúncio diz livro de revisões',
    ),
    'relisted': (
      ExplanationTone.negative,
      'Já esteve à venda noutro anúncio e não foi vendida',
    ),
    'relisted_often': (
      ExplanationTone.negative,
      'Posta à venda várias vezes ou há mais de 90 dias sem ser vendida',
    ),
    'first_owner': (ExplanationTone.positive, 'Primeiro dono'),
    'service_book': (ExplanationTone.positive, 'Livro de revisões completo'),
    'under_warranty': (
      ExplanationTone.positive,
      'Ainda com garantia de fábrica',
    ),
  };

  // Presentation thresholds for the wording only; the score itself is
  // calculated in the database.
  static const _priceNoticePct = 3.0;
  static const _minReliableMarket = 3;

  static String label(int score) {
    if (score >= 90) return 'Excelente';
    if (score >= 80) return 'Muito bom';
    if (score >= 70) return 'Interessante';
    if (score >= 60) return 'Normal';
    return 'Fraco';
  }

  static String riskLabel(int risk) {
    if (risk >= 50) return 'Elevado';
    if (risk >= 20) return 'Médio';
    return 'Baixo';
  }

  static ScoreExplanation? explain(Listing listing, {DateTime? today}) {
    final score = listing.dealScore;
    if (score == null) return null;

    final now = today ?? DateTime.now();
    final thisYear = now.year;
    final data = listing.scoreBreakdown ?? const <String, dynamic>{};
    final lines = <ExplanationLine>[];

    // Price vs market
    final pct = (data['pct_below_market'] as num?)?.toDouble();
    final market = (data['market_price'] as num?)?.toDouble();
    final price = listing.price;
    final marketCount = (data['market_listing_count'] as num?)?.toInt();
    // Below 3 comparables the price is not scored, so it is not explained.
    final priceScored =
        marketCount == null || marketCount >= _minReliableMarket;
    if (pct != null && market != null && price != null && priceScored) {
      final amount = Formatters.price((market - price).abs());
      final pctText = Formatters.percent(pct.abs());
      if (pct >= _priceNoticePct) {
        lines.add(
          ExplanationLine(
            ExplanationTone.positive,
            '$pctText ($amount) abaixo do valor estimado',
          ),
        );
      } else if (pct <= -_priceNoticePct) {
        lines.add(
          ExplanationLine(
            ExplanationTone.negative,
            '$pctText ($amount) acima do valor estimado',
          ),
        );
      } else {
        lines.add(
          const ExplanationLine(
            ExplanationTone.neutral,
            'Preço em linha com o valor estimado',
          ),
        );
      }
      lines.add(
        ExplanationLine(
          ExplanationTone.neutral,
          'Valor estimado para este ano e quilometragem (pelos preços '
          'pedidos de motas comparáveis): '
          '${Formatters.price(market)}',
        ),
      );
    }
    if (!priceScored) {
      lines.add(
        ExplanationLine(
          ExplanationTone.neutral,
          'Ainda poucos anúncios comparáveis ($marketCount) para estimar '
          'o valor: o preço não conta',
        ),
      );
    }
    if (data['capped_without_price'] == true) {
      lines.add(
        const ExplanationLine(
          ExplanationTone.neutral,
          'Sem comparação de preço, a pontuação fica no máximo em 70',
        ),
      );
    }

    // Mileage, against what is normal for the bike's age
    if (mileageForAge(listing.mileage, listing.year, decimalYear(now))
        case final line?) {
      lines.add(line);
    }

    // Year
    final year = listing.year;
    if (year != null && year >= thisYear) {
      lines.add(ExplanationLine(ExplanationTone.positive, 'Modelo de $year'));
    } else if (year != null && year <= thisYear - 3) {
      lines.add(
        ExplanationLine(
          ExplanationTone.negative,
          'Modelo de $year (mais antigo)',
        ),
      );
    }

    // Version / equipment
    if (extrasText(data) case final extras?) {
      final bonus = (data['equipment_bonus'] as num?)?.toInt();
      lines.add(
        ExplanationLine(
          ExplanationTone.positive,
          bonus == null || bonus == 0
              ? 'Extras indicados: $extras'
              : 'Extras indicados (+$bonus): $extras',
        ),
      );
    }

    if (sellerLine(data) case final line?) lines.add(line);

    // Risk signals; some are reassuring and read as positives.
    for (final code in (data['risk_reasons'] as List? ?? const [])) {
      final entry = _riskLines[code];
      if (entry != null) lines.add(ExplanationLine(entry.$1, entry.$2));
    }

    return ScoreExplanation(
      score: score,
      label: label(score),
      lines: lines,
      slicesUsed: (data['slices_used'] as num?)?.toInt(),
      slicesTotal: (data['slices_total'] as num?)?.toInt(),
    );
  }
}
