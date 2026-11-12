import 'package:flutter_test/flutter_test.dart';
import 'package:motorcycle_deal_tracker/core/formatting/formatters.dart';
import 'package:motorcycle_deal_tracker/features/favourites/domain/entities/favourite.dart';
import 'package:motorcycle_deal_tracker/features/favourites/presentation/viewing_checklist.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/entities/bike_maintenance.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/entities/listing.dart';

const _ok = ChecklistEntry(mark: ChecklistMark.ok);
const _issue = ChecklistEntry(mark: ChecklistMark.issue);

Listing _bike({
  String model = 'MT-07',
  int? mileage,
  BikeMaintenance? maintenance,
  List<String> riskReasons = const [],
}) => Listing(
  id: 'a',
  source: 'olx',
  url: 'https://www.olx.pt/x',
  brand: 'Yamaha',
  model: model,
  status: ListingStatus.active,
  sellerType: SellerType.private,
  images: const [],
  mileage: mileage,
  maintenance: maintenance,
  riskReasons: riskReasons,
);

const _figures = BikeMaintenance(
  frontTyre: '120/70-17',
  rearTyre: '180/55-17',
  valveCheckKm: 40000,
);

void main() {
  test('every item has its own key, a title and a hint', () {
    final keys = viewingChecklistItems().map((i) => i.key).toList();
    expect(keys.toSet(), hasLength(keys.length));
    expect(keys, hasLength(12));
    for (final item in viewingChecklistItems()) {
      expect(item.key, matches(RegExp(r'^[a-z_]+$')));
      expect(item.title, isNotEmpty);
      expect(item.hint, endsWith('.'));
    }
  });

  group('checklistSummaryText', () {
    test('nothing seen yet says how many points there are', () {
      expect(checklistSummaryText({}), '12 pontos para ver na visita');
      // A note alone is not a mark.
      expect(
        checklistSummaryText({'tyres': const ChecklistEntry(note: 'x')}),
        '12 pontos para ver na visita',
      );
    });

    test('counts what was seen and the problems', () {
      expect(
        checklistSummaryText({'tyres': _ok, 'chain': _ok}),
        '2 de 12 vistos',
      );
      expect(
        checklistSummaryText({'tyres': _issue, 'chain': _ok, 'keys': _ok}),
        '3 de 12 vistos · 1 problema',
      );
      expect(
        checklistSummaryText({'tyres': _issue, 'chain': _issue}),
        '2 de 12 vistos · 2 problemas',
      );
    });

    test('everything seen, with or without problems', () {
      final all = {for (final i in viewingChecklistItems()) i.key: _ok};
      expect(checklistSummaryText(all), 'Tudo visto, sem problemas');
      expect(
        checklistSummaryText({...all, 'brakes': _issue}),
        'Tudo visto · 1 problema',
      );
    });

    test('items no longer on the list are ignored', () {
      expect(
        checklistSummaryText({'old_item': _issue, 'keys': _ok}),
        '1 de 12 vistos',
      );
    });
  });

  test('checklistIssuesText names the problems in list order', () {
    expect(checklistIssuesText({'tyres': _ok}), isNull);
    expect(checklistIssuesText({'tyres': _issue}), 'Problema: Pneus');
    expect(
      checklistIssuesText({'brakes': _issue, 'tyres': _issue, 'old': _issue}),
      'Problemas: Pneus, Travões e discos',
    );
  });

  group('the bike's own points (N.64)', () {
    List<String> keys(Listing listing) =>
        bikeChecklistItems(listing).map((i) => i.key).toList();

    test('a plain bike without figures adds nothing', () {
      expect(keys(_bike(mileage: 50000)), isEmpty);
      expect(viewingChecklist(listing: _bike()), hasLength(3));
    });

    test('the valve check only near or past the interval', () {
      const figures = BikeMaintenance(valveCheckKm: 40000);
      expect(keys(_bike(mileage: 31999, maintenance: figures)), isEmpty);
      expect(keys(_bike(mileage: 32000, maintenance: figures)), [
        'valve_check',
      ]);
      expect(keys(_bike(maintenance: figures)), isEmpty);
      final item = bikeChecklistItems(
        _bike(mileage: 41000, maintenance: figures),
      ).single;
      expect(item.hint, contains(Formatters.mileage(40000)));
      expect(item.hint, contains(Formatters.mileage(41000)));
    });

    test('tyre sizes need both sizes', () {
      expect(
        keys(_bike(maintenance: const BikeMaintenance(frontTyre: '120/70-17'))),
        isEmpty,
      );
      final item = bikeChecklistItems(_bike(maintenance: _figures)).single;
      expect(item.key, 'tyre_sizes');
      expect(item.hint, contains('120/70-17'));
      expect(item.hint, contains('180/55-17'));
    });

    test('fairings on sports bikes, papers from the risk reasons', () {
      expect(keys(_bike(model: 'R7')), ['fairings']);
      expect(keys(_bike(riskReasons: ['a2_unlocked'])), ['a2_version']);
      expect(keys(_bike(riskReasons: ['not_legalised'])), ['import_papers']);
      expect(keys(_bike(riskReasons: ['mileage_lowered'])), ['odometer']);
      expect(keys(_bike(riskReasons: ['no_service_book'])), isEmpty);
    });

    test('they join the list as their own section and count', () {
      final bike = _bike(
        model: 'R7',
        mileage: 36000,
        maintenance: _figures,
        riskReasons: const ['a2_limited', 'imported', 'suspicious_mileage'],
      );
      expect(keys(bike), [
        'valve_check',
        'tyre_sizes',
        'fairings',
        'a2_version',
        'import_papers',
        'odometer',
      ]);
      final sections = viewingChecklist(listing: bike);
      expect(sections, hasLength(4));
      expect(sections.last.title, 'Nesta mota');
      for (final item in bikeChecklistItems(bike)) {
        expect(item.hint, endsWith('.'));
      }
      expect(
        checklistSummaryText({}, listing: bike),
        '18 pontos para ver na visita',
      );
      // A mark on a point the bike no longer has is ignored.
      expect(
        checklistSummaryText({'fairings': _ok}, listing: _bike()),
        '12 pontos para ver na visita',
      );
      expect(
        checklistIssuesText({'odometer': _issue}, listing: bike),
        'Problema: Conta-quilómetros',
      );
    });
  });
}
