import 'package:collector/src/catalog/catalog.dart';
import 'package:collector/src/catalog/model_resolver.dart';
import 'package:test/test.dart';

/// The catalog with the models added in 9.8, with the rules from the
/// migration that adds them.
final full = Catalog([
  ...Catalog.mvp().entries,
  const CatalogEntry(
    slug: 'yamaha-tracer-7',
    brand: 'Yamaha',
    model: 'Tracer 7',
    minYear: 2023,
    aliases: ['Tracer 700', 'Tracer 07'],
    engineCcMin: 680,
    engineCcMax: 710,
  ),
  const CatalogEntry(
    slug: 'yamaha-r1',
    brand: 'Yamaha',
    model: 'R1',
    minYear: 2023,
    aliases: ['R1M'],
    engineCcMin: 990,
    engineCcMax: 1000,
  ),
  const CatalogEntry(
    slug: 'yamaha-r3',
    brand: 'Yamaha',
    model: 'R3',
    minYear: 2023,
    engineCcMin: 315,
    engineCcMax: 330,
  ),
  const CatalogEntry(
    slug: 'yamaha-r9',
    brand: 'Yamaha',
    model: 'R9',
    minYear: 2023,
    engineCcMin: 880,
    engineCcMax: 900,
  ),
  const CatalogEntry(
    slug: 'honda-cb125r',
    brand: 'Honda',
    model: 'CB125R',
    minYear: 2023,
    excludedWords: ['125f'],
    engineCcMin: 120,
    engineCcMax: 130,
  ),
  const CatalogEntry(
    slug: 'honda-cb300r',
    brand: 'Honda',
    model: 'CB300R',
    minYear: 2023,
    excludedWords: ['300f'],
    engineCcMin: 280,
    engineCcMax: 290,
  ),
  const CatalogEntry(
    slug: 'honda-cbr500r',
    brand: 'Honda',
    model: 'CBR500R',
    minYear: 2023,
    engineCcMin: 465,
    engineCcMax: 475,
  ),
  const CatalogEntry(
    slug: 'honda-cb750-hornet',
    brand: 'Honda',
    model: 'CB750 Hornet',
    minYear: 2023,
    aliases: ['Hornet 750'],
    engineCcMin: 750,
    engineCcMax: 760,
  ),
  const CatalogEntry(
    slug: 'honda-cbr600rr',
    brand: 'Honda',
    model: 'CBR600RR',
    minYear: 2023,
    engineCcMin: 595,
    engineCcMax: 600,
  ),
]);

/// What the OLX mapper passes: the site's family, then the title without
/// the brand.
String? slugOf(Catalog catalog, String brand, String family, String title) =>
    ModelResolver(
      catalog,
    ).resolve(brand: brand, family: family, text: '$family $title')?.slug;

void main() {
  group('titles from the OLX run of 2026-10-19', () {
    final cases = <(String, String, String), String?>{
      ('Yamaha', 'mt-07', 'MT-07 35kw'): 'yamaha-mt-07',
      ('Yamaha', 'mt-07', 'Tracer 7 GT 2024 – 11 121 km'): 'yamaha-tracer-7',
      ('Yamaha', 'mt-07', 'tracer7 2024'): 'yamaha-tracer-7',
      ('Yamaha', 'mt-07', 'tracer 700'): 'yamaha-tracer-7',
      ('Yamaha', 'mt-07', 'tracer 07'): 'yamaha-tracer-7',
      ('Yamaha', 'yzf', 'YZF-R1 2024 | Extras'): 'yamaha-r1',
      ('Yamaha', 'r', 'R1(último modelo2024)'): 'yamaha-r1',
      ('Yamaha', 'yzf', 'YZF R1M'): 'yamaha-r1',
      ('Yamaha', 'r', 'R3 2025 Como Nova'): 'yamaha-r3',
      ('Yamaha', 'yzf', 'YZF-R9 2026 — Impecável'): 'yamaha-r9',
      ('Yamaha', 'yzf', 'YZF-R7 [2024]'): 'yamaha-r7',
      ('Yamaha', 'yzf', 'yzf r125 2025'): null,
      ('Honda', 'cb', 'CB125R 2024 - 7000kms APENAS'): 'honda-cb125r',
      ('Honda', 'cb', 'cb125 f , de 2024'): null,
      ('Honda', 'cb', 'CB 125f 2023 Preta'): null,
      ('Honda', 'cb', 'CB300r 2023'): 'honda-cb300r',
      ('Honda', 'cbr', 'CBR500R 2024 – Estado Irrepreensível'): 'honda-cbr500r',
      ('Honda', 'cbr', 'CBR 500r 2024 35kw'): 'honda-cbr500r',
      ('Honda', 'cb', 'CB 500 XA'): null,
      ('Honda', 'cb', 'Hornet 750 • 2023 • 3.500 km'): 'honda-cb750-hornet',
      ('Honda', 'cb', 'CB Hornet 750'): 'honda-cb750-hornet',
      ('Honda', 'cb', 'hornet CB750'): 'honda-cb750-hornet',
      ('Honda', 'cb', 'Vendo CB750 Hornet'): 'honda-cb750-hornet',
      ('Honda', 'cbr', 'CBR 600 RR'): 'honda-cbr600rr',
      ('Honda', 'cbr', 'CBR600RR 2024 + Extras'): 'honda-cbr600rr',
      ('Honda', 'cb', 'CB650R E-Clutch'): 'honda-cb650r',
      ('Honda', 'cb', 'Cb650 F 2023'): null,
    };

    for (final MapEntry(key: (brand, family, title), value: slug)
        in cases.entries) {
      test('$brand "$title" -> $slug', () {
        expect(slugOf(full, brand, family, title), slug);
      });
    }
  });

  test('a model left out of the catalog is not matched as another', () {
    expect(
      slugOf(Catalog.mvp(), 'Yamaha', 'mt-07', 'Tracer 7 GT 2024'),
      isNull,
    );
    expect(slugOf(Catalog.mvp(), 'Honda', 'cb', 'CB750 Hornet'), isNull);
  });

  test('the engine size picks the model within a family', () {
    final resolver = ModelResolver(full);

    expect(
      resolver
          .resolve(brand: 'Yamaha', family: 'R', text: 'R', engineCc: 321)
          ?.slug,
      'yamaha-r3',
    );
    expect(
      resolver
          .resolve(brand: 'Yamaha', family: 'R', text: 'R', engineCc: 689)
          ?.slug,
      'yamaha-r7',
    );
  });

  test('a model without engine limits is never picked by engine size', () {
    // Added in the app: no engine range. Standvirtual's model field says
    // only "Forza" and the engine is 125 cc.
    final added = ModelResolver(
      Catalog(const [
        CatalogEntry(
          slug: 'honda-forza-350',
          brand: 'Honda',
          model: 'Forza 350',
          minYear: 2021,
        ),
      ]),
    );

    expect(
      added.resolve(
        brand: 'Honda',
        family: 'Forza',
        text: 'Forza 125 ABS',
        engineCc: 125,
      ),
      isNull,
    );
    expect(
      added
          .resolve(
            brand: 'Honda',
            family: 'Forza',
            text: 'Forza 350 ABS',
            engineCc: 330,
          )
          ?.model,
      'Forza 350',
    );
  });

  group('a Forza 350 with the engine limits its name gives (315-385 cc)', () {
    final resolver = ModelResolver(
      Catalog(const [
        CatalogEntry(
          slug: 'honda-forza-350',
          brand: 'Honda',
          model: 'Forza 350',
          minYear: 2021,
          engineCcMin: 315,
          engineCcMax: 385,
        ),
        CatalogEntry(
          slug: 'honda-adv-350',
          brand: 'Honda',
          model: 'ADV 350',
          minYear: 2024,
          engineCcMin: 315,
          engineCcMax: 385,
        ),
      ]),
    );

    test('an ad named only "Forza" is picked by its 330 cc', () {
      String? forza(int cc) => resolver
          .resolve(brand: 'Honda', family: 'Forza', text: 'Forza', engineCc: cc)
          ?.slug;
      expect(forza(330), 'honda-forza-350');
      expect(forza(125), isNull);
      expect(forza(745), isNull);
    });

    test('"350cc" names the size', () {
      expect(
        resolver
            .resolve(brand: 'Honda', family: '', text: 'modelo ADV 350cc')
            ?.slug,
        'honda-adv-350',
      );
    });
  });

  group('boundaries', () {
    final resolver = ModelResolver(Catalog.mvp());

    test('an engine exactly at the limits fits, one cc outside does not', () {
      String? at(int cc) => resolver
          .resolve(brand: 'Honda', family: 'CB', text: 'CB650R', engineCc: cc)
          ?.slug;

      expect(at(640), 'honda-cb650r');
      expect(at(660), 'honda-cb650r');
      expect(at(639), isNull);
      expect(at(661), isNull);
    });

    test('the model counts only when it starts in the first three words', () {
      expect(slugOf(Catalog.mvp(), 'Honda', '', 'a b CB650R'), 'honda-cb650r');
      expect(slugOf(Catalog.mvp(), 'Honda', '', 'a b c CB650R'), isNull);
    });

    test('a model spread over four words is found', () {
      expect(slugOf(Catalog.mvp(), 'Honda', '', 'C B 6 50R'), 'honda-cb650r');
    });

    test('two models of the family fitting the engine stay unmatched', () {
      final two = ModelResolver(
        Catalog(const [
          CatalogEntry(
            slug: 'x-x1',
            brand: 'X',
            model: 'X1',
            minYear: 2023,
            engineCcMin: 100,
            engineCcMax: 200,
          ),
          CatalogEntry(
            slug: 'x-x2',
            brand: 'X',
            model: 'X2',
            minYear: 2023,
            engineCcMin: 100,
            engineCcMax: 200,
          ),
        ]),
      );

      expect(
        two.resolve(brand: 'X', family: 'X', text: 'X', engineCc: 150),
        isNull,
      );
    });

    test('a text naming two catalog models is unmatched', () {
      expect(slugOf(Catalog.mvp(), 'Honda', '', 'CB650R CBR650R'), isNull);
    });
  });
}
