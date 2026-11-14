import 'package:flutter_test/flutter_test.dart';
import 'package:motorcycle_deal_tracker/core/localization/app_language.dart';
import 'package:motorcycle_deal_tracker/features/favourites/domain/entities/favourite.dart';
import 'package:motorcycle_deal_tracker/features/favourites/domain/entities/favourite_share.dart';
import 'package:motorcycle_deal_tracker/features/favourites/presentation/favourite_share_text.dart';
import 'package:motorcycle_deal_tracker/features/listings/data/models/listing_model.dart';

Favourite _favourite(
  String id, {
  String? note,
  DateTime? visitAt,
  Map<String, dynamic> listing = const {},
}) => Favourite(
  listingId: id,
  createdAt: DateTime(2026, 10, 15),
  note: note,
  visitAt: visitAt,
  listing: ListingModel.fromJson({
    'id': id,
    'source': 'olx',
    'url': 'https://www.olx.pt/d/anuncio/$id',
    'brand': 'Yamaha',
    'model': 'MT-07',
    'year': 2021,
    'mileage': 12000,
    'price': 6500.4,
    'seller_type': 'private',
    'status': 'active',
    'location': 'Braga',
    'deal_score': 82,
    'risk_score': 10,
    'images': <String>[],
    'first_seen_at': '2026-10-10T10:00:00Z',
    'last_seen_at': '2026-10-18T10:00:00Z',
    ...listing,
  }),
);

const _origin = 'https://app.example';

void main() {
  test('the link opens the share page with the code', () {
    expect(
      favouriteShareLink(_origin, 'a b'),
      'https://app.example/#/share?code=a+b',
    );
  });

  group('favouriteShareStateText', () {
    test('not shared', () {
      expect(
        favouriteShareStateText(FavouriteShare.none),
        'A sua lista não está partilhada.',
      );
      expect(
        favouriteShareStateText(
          FavouriteShare.none,
          language: AppLanguage.english,
        ),
        isNot(contains('A sua')),
      );
    });

    test('seen by an account, with a link waiting', () {
      final text = favouriteShareStateText(
        FavouriteShare(
          viewerEmail: 'ana@example.com',
          code: 'c',
          codeExpiresAt: DateTime(2026, 11, 28, 12),
        ),
      );
      expect(text, contains('Vê a sua lista: ana@example.com'));
      expect(text, contains('28/11/2026'));
      expect(text.split('\n'), hasLength(2));
    });

    test('an expiry without a code says nothing of a link', () {
      expect(
        favouriteShareStateText(
          FavouriteShare(
            viewerEmail: 'ana@example.com',
            codeExpiresAt: DateTime(2026, 11, 28),
          ),
        ),
        'Vê a sua lista: ana@example.com',
      );
    });
  });

  group('favouritesCsv', () {
    test('Portuguese: byte order mark, ";" and CRLF lines', () {
      final csv = favouritesCsv([_favourite('l1')], origin: _origin);
      expect(csv, startsWith('﻿Mota;Ano;Km;Preço (€);'));
      expect(csv, endsWith('\r\n'));
      final lines = csv.substring(1).split('\r\n');
      expect(lines, hasLength(3));
      expect(lines.last, isEmpty);
      final cells = lines[1].split(';');
      expect(cells.sublist(0, 6), [
        'Yamaha MT-07',
        '2021',
        '12000',
        '6500',
        '82',
        '10',
      ]);
      expect(cells[7], 'Braga');
      expect(cells[11], 'https://www.olx.pt/d/anuncio/l1');
      expect(cells[12], 'https://app.example/#/deals/l1');
      expect(cells, hasLength(13));
    });

    test('English uses ","', () {
      final csv = favouritesCsv(
        [_favourite('l1')],
        origin: _origin,
        language: AppLanguage.english,
      );
      expect(csv, startsWith('﻿Bike,Year,'));
      expect(csv.split('\r\n')[1], startsWith('Yamaha MT-07,2021,12000,'));
    });

    test('quotes separators, quotes and line breaks', () {
      final csv = favouritesCsv([
        _favourite('l1', note: 'Liguei; disse "talvez"\nvolto amanhã'),
      ], origin: _origin);
      expect(csv, contains(';"Liguei; disse ""talvez""\nvolto amanhã";'));
    });

    test('a cell that would start a formula gets an apostrophe', () {
      final csv = favouritesCsv([
        _favourite('l1', note: '=HYPERLINK("x")'),
        _favourite('l2', note: '-5 %'),
        _favourite('l3', note: '@a'),
      ], origin: _origin);
      expect(csv, contains(';"\'=HYPERLINK(""x"")";'));
      expect(csv, contains(";'-5 %;"));
      expect(csv, contains(";'@a;"));
    });

    test('the visit with its time, empty cells for what is unknown', () {
      final csv = favouritesCsv([
        _favourite(
          'l1',
          visitAt: DateTime(2026, 11, 20, 18, 30),
          listing: {
            'year': null,
            'mileage': null,
            'deal_score': null,
            'risk_score': null,
            'location': null,
          },
        ),
      ], origin: _origin);
      final cells = csv.split('\r\n')[1].split(';');
      expect(cells.sublist(1, 3), ['', '']);
      expect(cells.sublist(4, 6), ['', '']);
      expect(cells[7], '');
      expect(cells[9], '20/11/2026 18:30');
      expect(cells[10], '');
    });

    test('a placeholder price leaves the price empty', () {
      final csv = favouritesCsv([
        _favourite('l1', listing: {'price': 1}),
      ], origin: _origin);
      expect(csv.split('\r\n')[1].split(';')[3], '');
    });

    test('favourites without their listing are left out', () {
      final csv = favouritesCsv([
        Favourite(listingId: 'gone', createdAt: DateTime(2026)),
      ], origin: _origin);
      expect(csv.split('\r\n'), hasLength(2));
    });
  });
}
