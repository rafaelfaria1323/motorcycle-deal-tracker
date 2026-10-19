import 'package:collector/collector.dart';
import 'package:test/test.dart';

const olxYamaha =
    'https://www.olx.pt/carros-motos-e-barcos/motociclos-scooters/yamaha/';

CatalogEntry model(
  String name,
  int minYear, {
  String? olx,
  String? standvirtual,
}) => CatalogEntry(
  slug: name.toLowerCase(),
  brand: 'Yamaha',
  model: name,
  minYear: minYear,
  olxSearch: olx,
  standvirtualSearch: standvirtual,
);

void main() {
  test('models with the same search share it, from the earliest year', () {
    final rSearch = '$olxYamaha?search%5Bfilter_enum_modelo%5D%5B0%5D=r';
    final plan = planSearches(
      Catalog([
        model(
          'MT-07',
          2023,
          olx: '$olxYamaha?search%5Bfilter_enum_modelo%5D%5B0%5D=mt-07',
        ),
        model('R7', 2024, olx: rSearch),
        model('R1', 2021, olx: rSearch),
        model('R9', 2025),
      ]),
      FetchSite.olx,
    );

    expect(plan.problems, isEmpty);
    expect(plan.searches.map((s) => s.models), [
      ['Yamaha MT-07'],
      ['Yamaha R7', 'Yamaha R1'],
    ]);
    expect(plan.searches.last.url.queryParameters, {
      'search[filter_enum_modelo][0]': 'r',
      olxYearFrom: '2021',
    });
    expect(urlProblem(plan.searches.last.url, site: FetchSite.olx), isNull);
  });

  test('a stored year filter or page number is replaced', () {
    final plan = planSearches(
      Catalog([
        model(
          'MT-07',
          2023,
          olx:
              '$olxYamaha?search%5Bfilter_enum_modelo%5D%5B0%5D=mt-07'
              '&search%5Bfilter_float_year:from%5D=2019&page=3',
        ),
        model(
          'Tracer 7',
          2024,
          olx: '$olxYamaha?search%5Bfilter_enum_modelo%5D%5B0%5D=mt-07',
        ),
      ]),
      FetchSite.olx,
    );

    expect(plan.searches.single.models, ['Yamaha MT-07', 'Yamaha Tracer 7']);
    expect(plan.searches.single.url.queryParameters, {
      'search[filter_enum_modelo][0]': 'mt-07',
      olxYearFrom: '2023',
    });
  });

  test('Standvirtual searches are used as they are', () {
    const url = 'https://www.standvirtual.com/motos/yamaha/mt-07';
    final plan = planSearches(
      Catalog([model('MT-07', 2023, olx: olxYamaha, standvirtual: url)]),
      FetchSite.standvirtual,
    );

    expect(plan.searches.single.url.toString(), url);
  });

  test('an address the fetcher would refuse is reported, not used', () {
    final plan = planSearches(
      Catalog([model('MT-07', 2023, olx: 'https://www.olx.pt/imoveis/')]),
      FetchSite.olx,
    );

    expect(plan.searches, isEmpty);
    expect(plan.problems.single, startsWith('Yamaha MT-07'));
  });
}
