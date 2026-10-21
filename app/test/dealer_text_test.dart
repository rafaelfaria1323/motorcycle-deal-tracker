import 'package:flutter_test/flutter_test.dart';
import 'package:motorcycle_deal_tracker/core/formatting/formatters.dart';
import 'package:motorcycle_deal_tracker/features/listings/data/models/dealer_reliability_model.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/entities/dealer_reliability.dart';
import 'package:motorcycle_deal_tracker/features/listings/presentation/dealer_text.dart';

DealerReliability _dealer({
  int bikes = 12,
  int live = 5,
  int relisted = 0,
  int sharpChanges = 0,
  int missingMileage = 0,
  int repeated = 0,
  int dropped = 0,
  DateTime? firstSeenAt,
}) => DealerReliability(
  name: 'Motos Lda',
  bikes: bikes,
  live: live,
  relisted: relisted,
  sharpChanges: sharpChanges,
  missingMileage: missingMileage,
  repeated: repeated,
  dropped: dropped,
  firstSeenAt: firstSeenAt,
);

void main() {
  group('dealerHeadline', () {
    test('bikes seen, since when, and how many are for sale', () {
      final since = DateTime.utc(2026, 8, 21, 12);
      expect(
        dealerHeadline(_dealer(firstSeenAt: since)),
        'Motos Lda: 12 motas vistas desde ${Formatters.date(since)} '
        '(5 à venda)',
      );
    });

    test('one bike, no date', () {
      expect(
        dealerHeadline(_dealer(bikes: 1, live: 1)),
        'Motos Lda: 1 mota vista (1 à venda)',
      );
    });
  });

  group('dealerLines', () {
    test('no warning signs', () {
      expect(dealerLines(_dealer()), [
        'Sem sinais de alerta nos anúncios deste stand',
        'Ainda não baixou o preço de nenhuma mota',
      ]);
    });

    test('every warning sign, out of the bikes seen', () {
      expect(
        dealerLines(
          _dealer(
            relisted: 2,
            sharpChanges: 1,
            missingMileage: 3,
            repeated: 1,
            dropped: 4,
          ),
        ),
        [
          '2 de 12 publicadas de novo depois de o anúncio sair',
          '1 de 12 com mudanças de preço bruscas (50 % ou mais de uma vez)',
          '3 de 12 sem quilómetros',
          '1 anúncio repetido da mesma mota usada no mesmo site',
          'Baixou o preço de 4 de 12',
        ],
      );
      expect(
        dealerLines(_dealer(repeated: 2))[0],
        '2 anúncios repetidos da mesma mota usada no mesmo site',
      );
    });

    test('says when there is little data', () {
      expect(
        dealerLines(_dealer(bikes: 4)).last,
        'Ainda poucos dados sobre este stand (menos de 5 motas)',
      );
      expect(dealerLines(_dealer(bikes: 5)).last, isNot(contains('poucos')));
    });
  });

  group('model', () {
    test('reads the view row', () {
      expect(
        dealerFromJson({
          'dealer_key': 'motos lda',
          'seller_name': 'Motos Lda',
          'bikes': 4,
          'live': 3,
          'relisted': 1,
          'sharp_changes': 1,
          'missing_mileage': 1,
          'repeated': 1,
          'dropped': 2,
          'first_seen_at': '2026-08-21T12:00:00+00:00',
        }),
        DealerReliability(
          name: 'Motos Lda',
          bikes: 4,
          live: 3,
          relisted: 1,
          sharpChanges: 1,
          missingMileage: 1,
          repeated: 1,
          dropped: 2,
          firstSeenAt: DateTime.utc(2026, 8, 21, 12),
        ),
      );
    });

    test('the key matches the view (trimmed, lower case)', () {
      expect(dealerKey('  MOTOS Lda '), 'motos lda');
    });
  });
}
