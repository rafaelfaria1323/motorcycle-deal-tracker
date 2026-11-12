import 'package:flutter_test/flutter_test.dart';
import 'package:motorcycle_deal_tracker/core/formatting/formatters.dart';
import 'package:motorcycle_deal_tracker/core/localization/app_language.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/entities/listing.dart';
import 'package:motorcycle_deal_tracker/features/listings/presentation/score_explanation.dart';

Listing listingWith(List<String> reasons) => Listing(
  id: '1',
  source: 'standvirtual',
  url: 'https://example.com/1',
  brand: 'Yamaha',
  model: 'MT-07',
  status: ListingStatus.active,
  sellerType: SellerType.dealer,
  images: const [],
  dealScore: 75,
  scoreBreakdown: {'risk_reasons': reasons},
);

void main() {
  test('reassuring facts read as positives, worrying ones as negatives', () {
    final lines = ScoreExplainer.explain(
      listingWith(['many_owners', 'first_owner', 'under_warranty']),
    )!.lines;

    expect(
      lines,
      contains(
        const ExplanationLine(
          ExplanationTone.negative,
          'Três ou mais registos (donos)',
        ),
      ),
    );
    expect(
      lines,
      contains(
        const ExplanationLine(ExplanationTone.positive, 'Primeiro dono'),
      ),
    );
    expect(
      lines,
      contains(
        const ExplanationLine(
          ExplanationTone.positive,
          'Ainda com garantia de fábrica',
        ),
      ),
    );
  });

  test('an implausible mileage reads as a negative', () {
    final lines = ScoreExplainer.explain(
      listingWith(['suspicious_mileage']),
    )!.lines;

    expect(lines, hasLength(1));
    expect(lines.single.tone, ExplanationTone.negative);
    expect(lines.single.text, startsWith('Quilometragem pouco provável'));
  });

  test('a relisted bike reads as a negative', () {
    for (final code in ['relisted', 'relisted_often']) {
      final lines = ScoreExplainer.explain(listingWith([code]))!.lines;

      expect(lines, hasLength(1));
      expect(lines.single.tone, ExplanationTone.negative);
    }
    expect(
      ScoreExplainer.explain(listingWith(['relisted']))!.lines.single.text,
      'Já esteve à venda noutro anúncio e não foi vendida',
    );
  });

  test('photos reused from another ad read as a negative', () {
    final lines = ScoreExplainer.explain(
      listingWith(['photos_reused']),
    )!.lines;

    expect(lines, hasLength(1));
    expect(lines.single.tone, ExplanationTone.negative);
    expect(lines.single.text, startsWith('Fotos iguais'));
  });

  test("edits in the seller's favour name what the ad showed before", () {
    final listing = Listing(
      id: '1',
      source: 'olx',
      url: 'https://example.com/1',
      brand: 'Yamaha',
      model: 'MT-07',
      status: ListingStatus.active,
      sellerType: SellerType.private,
      images: const [],
      dealScore: 60,
      year: 2021,
      mileage: 13000,
      mileageMaxSeen: 31000,
      yearFirstSeen: 2020,
      scoreBreakdown: const {
        'risk_reasons': ['mileage_lowered', 'year_raised'],
      },
    );
    final lines = ScoreExplainer.explain(listing)!.lines;

    expect(lines.map((l) => l.tone), everyElement(ExplanationTone.negative));
    expect(
      lines.map((l) => l.text),
      containsAll([
        contains(
          'de ${Formatters.mileage(31000)} para ${Formatters.mileage(13000)}',
        ),
        contains('de 2020 para 2021'),
      ]),
    );
    expect(
      factEditLine('year_raised', listing, language: AppLanguage.english)!.text,
      contains('from 2020 to 2021'),
    );
  });

  test('edits without the earlier values still read as negatives', () {
    final lines = ScoreExplainer.explain(
      listingWith(['mileage_lowered', 'year_raised']),
    )!.lines;

    expect(lines, hasLength(2));
    expect(lines.first.text, startsWith('O vendedor baixou os km'));
    expect(lines.last.text, startsWith('O ano do anúncio passou a ser'));
    expect(factEditLine('photos_reused', listingWith(const [])), isNull);
  });

  test('contradictions between the text and the ad read as negatives', () {
    for (final code in [
      'text_year_mismatch',
      'text_mileage_mismatch',
      'text_origin_mismatch',
      'text_service_book_mismatch',
    ]) {
      final lines = ScoreExplainer.explain(listingWith([code]))!.lines;

      expect(lines, hasLength(1), reason: code);
      expect(lines.single.tone, ExplanationTone.negative);
      expect(lines.single.text, matches(RegExp('^[OA] ')));
    }
  });

  test('an A2 version reads as a negative', () {
    for (final code in ['a2_limited', 'a2_unlocked']) {
      final lines = ScoreExplainer.explain(listingWith([code]))!.lines;

      expect(lines, hasLength(1), reason: code);
      expect(lines.single.tone, ExplanationTone.negative);
      expect(lines.single.text, startsWith('Versão A2'));
    }
  });

  test('damage in the description reads as a negative', () {
    for (final (code, word) in [
      ('possible_accident', 'acidente'),
      ('needs_repair', 'reparações'),
      ('cosmetic_damage', 'riscos'),
    ]) {
      final lines = ScoreExplainer.explain(listingWith([code]))!.lines;

      expect(lines, hasLength(1), reason: code);
      expect(lines.single.tone, ExplanationTone.negative);
      expect(lines.single.text, contains(word));
    }
  });

  test('unknown reason codes are ignored', () {
    final lines = ScoreExplainer.explain(listingWith(['something_new']))!.lines;

    expect(lines, isEmpty);
  });
}
