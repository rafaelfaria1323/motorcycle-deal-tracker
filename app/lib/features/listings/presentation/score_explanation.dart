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

const _extraLabels = {
  'quickshifter': 'quickshifter',
  'exhaust': 'escape desportivo',
  'luggage': 'malas',
  'heated_grips': 'punhos aquecidos',
  'protection': 'proteções',
  'new_tyres': 'pneus novos',
};

/// The extras found in the ad ("quickshifter, malas"), or null when none.
String? extrasText(Map<String, dynamic>? breakdown) {
  final labels = [
    for (final code in (breakdown?['extras'] as List? ?? const []))
      if (_extraLabels[code] case final label?) label,
  ];
  return labels.isEmpty ? null : labels.join(', ');
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
  static const _lowMileageKm = 5000;
  static const _highMileageKm = 12000;
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

  static ScoreExplanation? explain(Listing listing, {int? currentYear}) {
    final score = listing.dealScore;
    if (score == null) return null;

    final thisYear = currentYear ?? DateTime.now().year;
    final data = listing.scoreBreakdown ?? const <String, dynamic>{};
    final lines = <ExplanationLine>[];

    // Price vs market
    final pct = (data['pct_below_market'] as num?)?.toDouble();
    final market = (data['market_price'] as num?)?.toDouble();
    final price = listing.price;
    if (pct != null && market != null && price != null) {
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
    final marketCount = (data['market_listing_count'] as num?)?.toInt();
    if (marketCount != null && marketCount < _minReliableMarket) {
      lines.add(
        ExplanationLine(
          ExplanationTone.neutral,
          'Valor estimado com poucos anúncios comparáveis ($marketCount)',
        ),
      );
    }

    // Mileage
    final km = listing.mileage;
    if (km != null && km <= _lowMileageKm) {
      lines.add(
        ExplanationLine(
          ExplanationTone.positive,
          'Baixa quilometragem (${Formatters.mileage(km)})',
        ),
      );
    } else if (km != null && km >= _highMileageKm) {
      lines.add(
        ExplanationLine(
          ExplanationTone.negative,
          'Quilometragem elevada (${Formatters.mileage(km)})',
        ),
      );
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
      lines.add(
        ExplanationLine(ExplanationTone.positive, 'Extras indicados: $extras'),
      );
    }

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
