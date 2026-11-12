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

  test(
    'automatic catalog searches plan both sites with the same safeguards',
    () {
      const olx =
          'https://www.olx.pt/carros-motos-e-barcos/motociclos-scooters/';
      const standvirtual = 'https://www.standvirtual.com/motos/';
      final catalog = catalogFromRows([
        {
          'id': 'id-1',
          'slug': 'honda-forza-350',
          'brand': 'Honda',
          'model': 'Forza 350',
          'min_year': 2022,
          'engine_cc_min': 315,
          'engine_cc_max': 385,
          'olx_search': '${olx}honda/q-forza-350/',
          'standvirtual_search': '${standvirtual}honda/forza/q-350',
        },
        {
          'id': 'id-2',
          'slug': 'norton-v4-sv',
          'brand': 'Norton',
          'model': 'V4 SV',
          'min_year': 2020,
          'olx_search': '${olx}q-norton-v4-sv/',
          'standvirtual_search': '${standvirtual}q-norton-v4-sv',
        },
        {
          'id': 'id-3',
          'slug': 'yamaha-tenere-700',
          'brand': 'Yamaha',
          'model': 'Ténéré 700',
          'min_year': 2021,
          'olx_search': '${olx}q-yamaha-ténéré-700/',
          'standvirtual_search': '${standvirtual}q-yamaha-ténéré-700',
        },
      ]);

      for (final site in [FetchSite.olx, FetchSite.standvirtual]) {
        final plan = planSearches(catalog, site);
        // Standvirtual's word search inside the Forza filter is followed by
        // its engine-size search.
        final wordSearches = site == FetchSite.olx
            ? plan.searches
            : [plan.searches[0], ...plan.searches.skip(2)];
        expect(plan.problems, isEmpty);
        expect(plan.searches, hasLength(site == FetchSite.olx ? 3 : 4));
        expect(wordSearches.map((search) => search.models), [
          ['Honda Forza 350'],
          ['Norton V4 SV'],
          ['Yamaha Ténéré 700'],
        ]);
        final yearKey = site == FetchSite.olx
            ? olxYearFrom
            : standvirtualYearFrom;
        expect(
          wordSearches.map((search) => search.url.queryParameters[yearKey]),
          ['2022', '2020', '2021'],
        );
        for (final search in plan.searches) {
          expect(urlProblem(search.url, site: site), isNull);
        }
        expect(
          plan.searches.last.url.toString(),
          contains('t%C3%A9n%C3%A9r%C3%A9-700'),
        );
        if (site == FetchSite.olx) {
          expect(
            plan.searches.first.url.queryParameters[olxEngineSize],
            '126-500-cc',
          );
        } else {
          expect(plan.searches.first.url.path, '/motos/honda/forza/q-350');
          final engine = plan.searches[1];
          expect(engine.url.path, '/motos/honda/forza');
          expect(engine.url.queryParameters, {
            standvirtualEngineFrom: '315',
            standvirtualEngineTo: '385',
            standvirtualYearFrom: '2022',
          });
          expect(engine.models, ['Honda Forza 350']);
        }
      }
    },
  );

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

    test('a band holds models from its first cc to its last', () {
      String? band(int min, int max) => olxEngineBand([
        CatalogEntry(
          slug: 'x',
          brand: 'Yamaha',
          model: 'X',
          minYear: 2024,
          engineCcMin: min,
          engineCcMax: max,
        ),
      ]);

      expect(band(0, 50), 'ate-50-cc');
      expect(band(51, 125), '51-125-cc');
      expect(band(126, 500), '126-500-cc');
      expect(band(501, 1000), '501-1000-cc');
      expect(band(1001, 1300), 'mais-de-1000-cc');
      expect(band(40, 125), isNull, reason: '40-125 cc spans two bands');
    });

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

    test('a Standvirtual word search in a model filter also reads the '
        'engine size', () {
      // Many CBR650R ads are "Honda CBR" with the version empty: "q-650"
      // misses them, the engine size doesn't (and misses those without one).
      final plan = planSearches(
        Catalog([
          model(
            'R7',
            2024,
            standvirtual: 'https://www.standvirtual.com/motos/yamaha/r/q-7',
            cc: 690,
          ),
          model(
            'R7 GYTR',
            2022,
            standvirtual: 'https://www.standvirtual.com/motos/yamaha/r/q-7',
            cc: 700,
          ),
        ]),
        FetchSite.standvirtual,
      );

      expect(plan.searches, hasLength(2));
      final [word, engine] = plan.searches;
      expect(word.url.path, '/motos/yamaha/r/q-7');
      expect(word.url.queryParameters, {standvirtualYearFrom: '2022'});
      expect(
        engine.url.toString(),
        startsWith('https://www.standvirtual.com/motos/yamaha/r?'),
      );
      expect(engine.url.queryParameters, {
        standvirtualYearFrom: '2022',
        standvirtualEngineFrom: '680',
        standvirtualEngineTo: '720',
      });
      expect(engine.models, ['Yamaha R7', 'Yamaha R7 GYTR']);
      expect(urlProblem(engine.url, site: FetchSite.standvirtual), isNull);
    });

    test('no engine-size search without engine limits or a model filter', () {
      final plan = planSearches(
        Catalog([
          model(
            'R7',
            2024,
            standvirtual: 'https://www.standvirtual.com/motos/yamaha/r/q-7',
          ),
          model(
            'MT-07',
            2023,
            standvirtual: 'https://www.standvirtual.com/motos/yamaha/q-mt-07',
            cc: 690,
          ),
          model(
            'MT-09',
            2023,
            standvirtual: 'https://www.standvirtual.com/motos/yamaha/mt-09',
            cc: 890,
          ),
        ]),
        FetchSite.standvirtual,
      );

      expect(plan.searches.map((s) => s.url.path), [
        '/motos/yamaha/r/q-7',
        '/motos/yamaha/q-mt-07',
        '/motos/yamaha/mt-09',
      ]);
    });

    test('engine-size searches that repeat each other are read once', () {
      final plan = planSearches(
        Catalog([
          model(
            'CB650R',
            2023,
            standvirtual: 'https://www.standvirtual.com/motos/yamaha/cb/q-650',
            cc: 650,
          ),
          model(
            'CB650R E-Clutch',
            2023,
            standvirtual:
                'https://www.standvirtual.com/motos/yamaha/cb/q-650-e-clutch',
            cc: 650,
          ),
        ]),
        FetchSite.standvirtual,
      );

      expect(plan.searches, hasLength(3));
      expect(plan.searches[1].models, [
        'Yamaha CB650R',
        'Yamaha CB650R E-Clutch',
      ]);
    });
  });
}
