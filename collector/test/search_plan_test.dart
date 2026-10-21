import 'package:collector/collector.dart';
import 'package:test/test.dart';

const olxYamaha =
    'https://www.olx.pt/carros-motos-e-barcos/motociclos-scooters/yamaha/';

CatalogEntry model(
  String name,
  int minYear, {
  String? olx,
  String? standvirtual,
  int? cc,
}) => CatalogEntry(
  slug: name.toLowerCase(),
  brand: 'Yamaha',
  model: name,
  minYear: minYear,
  olxSearch: olx,
  standvirtualSearch: standvirtual,
  engineCcMin: cc == null ? null : cc - 10,
  engineCcMax: cc == null ? null : cc + 20,
);

void main() {
  test('models with the same search share it, from the earliest year', () {
    const rSearch = '$olxYamaha?search%5Bfilter_enum_modelo%5D%5B0%5D=r';
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

  test('Standvirtual searches ask for the first tracked year', () {
    const url = 'https://www.standvirtual.com/motos/yamaha/mt-07';
    final plan = planSearches(
      Catalog([
        model('MT-07', 2023, olx: olxYamaha, standvirtual: '$url?page=2'),
      ]),
      FetchSite.standvirtual,
    );

    final search = plan.searches.single.url;
    expect(search.path, '/motos/yamaha/mt-07');
    expect(search.queryParameters, {standvirtualYearFrom: '2023'});
    expect(urlProblem(search, site: FetchSite.standvirtual), isNull);
  });

  test('an address the fetcher would refuse is reported, not used', () {
    final plan = planSearches(
      Catalog([model('MT-07', 2023, olx: 'https://www.olx.pt/imoveis/')]),
      FetchSite.olx,
    );

    expect(plan.searches, isEmpty);
    expect(plan.problems.single, startsWith('Yamaha MT-07'));
  });

  group('OLX engine-size band', () {
    const rSearch = '$olxYamaha?search%5Bfilter_enum_modelo%5D%5B0%5D=r';

    test('a family search asks only for the band of its models', () {
      final plan = planSearches(
        Catalog([
          model('R7', 2024, olx: rSearch, cc: 690),
          model('R1', 2021, olx: rSearch, cc: 980),
        ]),
        FetchSite.olx,
      );

      expect(plan.searches.single.url.queryParameters, {
        'search[filter_enum_modelo][0]': 'r',
        olxYearFrom: '2021',
        olxEngineSize: '501-1000-cc',
      });
    });

    test('every band of OLX\'s filter is used, keyword searches too', () {
      String? bandOf(int cc, {String olx = rSearch}) => planSearches(
        Catalog([model('X', 2024, olx: olx, cc: cc)]),
        FetchSite.olx,
      ).searches.single.url.queryParameters[olxEngineSize];

      expect(bandOf(30), 'ate-50-cc');
      expect(bandOf(100), '51-125-cc');
      expect(bandOf(330, olx: '${olxYamaha}q-xmax-300/'), '126-500-cc');
      expect(bandOf(690), '501-1000-cc');
      expect(bandOf(1100), 'mais-de-1000-cc');
      expect(bandOf(120), isNull, reason: '110-140 cc spans two bands');
    });

    test(
      'no band when a model has no engine size or the models span bands',
      () {
        String? bandOf(List<CatalogEntry> models) => planSearches(
          Catalog(models),
          FetchSite.olx,
        ).searches.single.url.queryParameters[olxEngineSize];

        expect(bandOf([model('R7', 2024, olx: rSearch)]), isNull);
        expect(
          bandOf([
            model('R7', 2024, olx: rSearch, cc: 690),
            model('R3', 2024, olx: rSearch, cc: 321),
          ]),
          isNull,
        );
      },
    );

    test('a band in the stored address is replaced, not kept', () {
      final plan = planSearches(
        Catalog([
          model(
            'R7',
            2024,
            olx:
                '$rSearch&search%5Bfilter_enum_cilindrada%5D%5B0%5D=126-250-cc',
            cc: 690,
          ),
          model('R1', 2021, olx: rSearch, cc: 980),
        ]),
        FetchSite.olx,
      );

      expect(plan.searches, hasLength(1));
      expect(
        plan.searches.single.url.queryParameters[olxEngineSize],
        '501-1000-cc',
      );
    });

    test('Standvirtual searches are left as they are', () {
      final plan = planSearches(
        Catalog([
          model(
            'R7',
            2024,
            standvirtual: 'https://www.standvirtual.com/motos/yamaha/r/q-7',
            cc: 690,
          ),
        ]),
        FetchSite.standvirtual,
      );

      expect(plan.searches.single.url.queryParameters.keys, [
        standvirtualYearFrom,
      ]);
    });
  });
}
