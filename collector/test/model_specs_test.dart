import 'dart:convert';

import 'package:collector/collector.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

/// An entry as API Ninjas writes one: every figure text with its units.
Map<String, Object?> _entry({
  String model = 'MT-07',
  String year = '2023',
  String? power = '73.4 HP (53.6  kW)) @ 8750 RPM',
  String? displacement = '689.0 ccm (42.04 cubic inches)',
  String? weight = '184.0 kg (405.7 pounds)',
}) => {
  'make': 'Yamaha',
  'model': model,
  'year': year,
  'engine': 'Twin, four-stroke',
  'displacement': ?displacement,
  'power': ?power,
  'torque': '67.0 Nm (6.8 kgf-m or 49.4 ft.lbs) @ 6500 RPM',
  'front_tire': '120/70-ZR17 ',
  'rear_tire': '180/55-ZR17 ',
  'total_weight': ?weight,
  'seat_height': '805 mm (31.7 inches) If adjustable, lowest setting.',
  'fuel_capacity': '14.00 Litres (3.70 US gallons)',
  'fuel_consumption': '4.20 litres/100 km (23.8 km/l or 56.00 mpg)',
};

const _mt07 = SpecsModel(
  id: 'm1',
  brand: 'Yamaha',
  model: 'MT-07',
  excludedWords: ['tracer'],
  engineCcMin: 680,
  engineCcMax: 700,
);

void main() {
  group('specsFromEntry', () {
    test('reads each figure by its unit', () {
      final s = specsFromEntry(_entry());
      expect(s.powerKw, 53.6);
      expect(s.torqueNm, 67.0);
      expect(s.weightKg, 184.0);
      expect(s.seatHeightMm, 805);
      expect(s.tankLitres, 14.0);
      expect(s.fuelLPer100Km, 4.2);
      expect(s.frontTyre, '120/70-17');
      expect(s.rearTyre, '180/55-17');
      expect(s.cylinders, 2);
      expect(s.toJson(), hasLength(9));
    });

    test('takes horsepower when the kW are missing', () {
      expect(specsFromEntry(_entry(power: '73.4 HP @ 8750 RPM')).powerKw, 54.7);
    });

    test('what is missing or unreadable is unknown', () {
      final s = specsFromEntry({'model': 'X', 'power': 'n/a'});
      expect(s.isEmpty, isTrue);
      expect(s.toJson(), isEmpty);
    });
  });

  test('tyreSize keeps width, profile and rim', () {
    expect(tyreSize('120/70-ZR17 '), '120/70-17');
    expect(tyreSize('180/55 ZR 17'), '180/55-17');
    expect(tyreSize('110/70-R17 M/C 54H'), '110/70-17');
    expect(tyreSize('3.00-18'), isNull);
    expect(tyreSize(null), isNull);
  });

  test('cylindersOf reads the layout, not the stroke', () {
    expect(cylindersOf('In-line four, four-stroke'), 4);
    expect(cylindersOf('Single cylinder, four-stroke'), 1);
    expect(cylindersOf('V2, four-stroke'), 2);
    expect(cylindersOf('In-line three, four-stroke'), 3);
    expect(cylindersOf('four-stroke'), isNull);
    expect(cylindersOf(null), isNull);
  });

  group('matchSpecs', () {
    test('holds the name as whole words, without excluded words', () {
      final m = matchSpecs(_mt07, [
        _entry(model: 'MT-07 ABS', weight: null),
        _entry(model: 'MT-07 Tracer', year: '2024'),
        _entry(year: '2022', weight: '182 kg'),
      ])!;
      expect(m.name, 'MT-07', reason: 'named just the model: used alone');
      expect(m.year, 2022);
      expect(m.entries, 1);
      expect(m.specs.weightKg, 182);
    });

    test('without an entry named just the model, the newest has each', () {
      final m = matchSpecs(_mt07, [
        _entry(model: 'MT-07 ABS', weight: null),
        _entry(model: 'MT-07 Pure', year: '2022', weight: '182 kg'),
      ])!;
      expect(m.name, 'MT-07 ABS');
      expect(m.year, 2023);
      expect(m.entries, 2);
      expect(m.specs.weightKg, 182, reason: 'the newest year that has it');
    });

    test('another number of cylinders is another bike', () {
      const cbr = SpecsModel(
        id: 'c',
        brand: 'Honda',
        model: 'CBR500R',
        engineCcMin: 470,
        engineCcMax: 510,
        specs: ModelSpecs(cylinders: 2),
      );
      final four = Map.of(
        _entry(model: 'CBR 500 R Four', year: '2026', displacement: '499 ccm'),
      )..['engine'] = 'In-line four, four-stroke';
      final twin = _entry(
        model: 'CBR 500 R E-Clutch',
        year: '2025',
        displacement: '471 ccm',
      );
      expect(matchSpecs(cbr, [four, twin])?.name, 'CBR 500 R E-Clutch');
      expect(matchSpecs(cbr, [four]), isNull);
    });

    test('another model sharing letters is not the model', () {
      const r1 = SpecsModel(id: 'r1', brand: 'Yamaha', model: 'R1');
      expect(matchSpecs(r1, [_entry(model: 'YZF-R1M')]), isNull);
      expect(matchSpecs(r1, [_entry(model: 'YZF-R1')])?.name, 'YZF-R1');
      const cb = SpecsModel(id: 'c', brand: 'Honda', model: 'CB650R');
      expect(matchSpecs(cb, [_entry(model: 'CBR650R')]), isNull);
    });

    test('an engine outside the range (+-10 %) is another bike', () {
      expect(matchSpecs(_mt07, [_entry(displacement: '599.0 ccm')]), isNull);
      expect(matchSpecs(_mt07, [_entry(displacement: '750 ccm')]), isNotNull);
    });

    test('a generation over 6 years older fills nothing', () {
      final m = matchSpecs(_mt07, [
        _entry(year: '2024', weight: null),
        _entry(year: '2014', weight: '179 kg'),
      ])!;
      expect(m.specs.weightKg, isNull);
    });
  });

  test('specDifferences lists figures more than 10 % away', () {
    const typed = ModelSpecs(
      seatHeightMm: 805,
      weightKg: 184,
      frontTyre: '120/70-17',
      cylinders: 2,
    );
    const api = ModelSpecs(
      seatHeightMm: 900,
      weightKg: 190,
      frontTyre: '120/60-17',
      cylinders: 2,
      tankLitres: 14,
    );
    expect(specDifferences(typed, api), [
      'seat height mm 805 vs 900',
      'front tyre 120/70-17 vs 120/60-17',
    ]);
  });

  group('lookUpSpecs', () {
    test('tries the names in order and stores what it found', () async {
      final asked = <String>[];
      final stored = <String, Map<String, Object>>{};
      final out = await lookUpSpecs(
        [
          const SpecsModel(
            id: 'h',
            brand: 'Honda',
            model: 'CB750 Hornet',
            aliases: ['Hornet 750'],
          ),
          const SpecsModel(id: 'x', brand: 'Honda', model: 'Nothing'),
        ],
        ask: (make, model) async {
          asked.add('$make $model');
          return model == 'Hornet 750' ? [_entry(model: 'Hornet 750')] : [];
        },
        store: (id, specs) async {
          stored[id] = specs.toJson();
          return id == 'h' ? ['weight_kg'] : [];
        },
      );
      expect(asked, [
        'Honda CB750 Hornet',
        'Honda Hornet 750',
        'Honda Nothing',
      ]);
      expect(stored['h'], containsPair('weight_kg', 184.0));
      expect(stored['x'], isEmpty, reason: 'asked, nothing found');
      expect(out.first.filled, ['weight_kg']);
      expect(out.last.match, isNull);
      final report = specsReport(out);
      expect(report, contains('| Honda CB750 Hornet | Hornet 750 2023 '));
      expect(report, contains('| Honda Nothing | not found | - | - |'));
    });

    test('a refused key stops; another failure skips the model', () async {
      var calls = 0;
      final out = await lookUpSpecs(
        [
          const SpecsModel(id: 'a', brand: 'Y', model: 'A'),
          const SpecsModel(id: 'b', brand: 'Y', model: 'B'),
          const SpecsModel(id: 'c', brand: 'Y', model: 'C'),
        ],
        ask: (_, model) async {
          calls++;
          if (model == 'A') throw const ApiNinjasFailure('slow');
          throw const ApiNinjasFailure('HTTP 401', status: 401);
        },
        store: (_, _) async => fail('nothing is stored'),
      );
      expect(calls, 2);
      expect([for (final o in out) o.error], ['slow', 'HTTP 401']);
      expect(specsReport(out), contains('failed: HTTP 401'));
    });

    test('the report says when there was nothing to ask', () {
      expect(specsReport([]), contains('No model to look up'));
    });

    test('the report points at differences', () async {
      final out = await lookUpSpecs(
        [
          const SpecsModel(
            id: 'm',
            brand: 'Yamaha',
            model: 'MT-07',
            specs: ModelSpecs(seatHeightMm: 900),
          ),
        ],
        ask: (_, _) async => [_entry()],
        store: (_, _) async => [],
      );
      expect(out.single.differences, ['seat height mm 900 vs 805']);
      expect(specsReport(out), contains('1 model(s) differ'));
    });
  });

  group('ApiNinjasClient', () {
    test('asks with the key in a header, one request at a time', () async {
      late http.Request sent;
      final waits = <Duration>[];
      final api = ApiNinjasClient(
        apiKey: 'k',
        httpClient: MockClient((r) async {
          sent = r;
          return http.Response(jsonEncode([_entry(), 'junk']), 200);
        }),
        wait: (d) async => waits.add(d),
      );
      expect(await api.motorcycles('Yamaha', 'MT-07'), hasLength(1));
      expect(
        sent.url.toString(),
        'https://api.api-ninjas.com/v1/motorcycles?make=Yamaha&model=MT-07',
      );
      expect(sent.headers['X-Api-Key'], 'k');
      expect(waits, isEmpty);
      await api.motorcycles('Yamaha', 'R7');
      expect(waits, [const Duration(seconds: 1)]);
      expect(api.requests, 2);
    });

    test('a refusal says whether it stops the run', () async {
      Future<ApiNinjasFailure> failure(int status, [String body = '']) async {
        final api = ApiNinjasClient(
          apiKey: 'k',
          httpClient: MockClient((_) async => http.Response(body, status)),
        );
        try {
          await api.motorcycles('Y', 'M');
        } on ApiNinjasFailure catch (e) {
          return e;
        }
        fail('no failure');
      }

      expect((await failure(401)).stopsRun, isTrue);
      expect((await failure(429)).stopsRun, isTrue);
      expect((await failure(500)).stopsRun, isFalse);
      expect((await failure(200, 'oops')).message, 'not JSON for Y M');
      expect((await failure(200, '{}')).message, 'not a list for Y M');
    });

    test('a dropped connection is a failure', () async {
      final api = ApiNinjasClient(
        apiKey: 'k',
        httpClient: MockClient((_) async => throw http.ClientException('x')),
      );
      expect(() => api.motorcycles('Y', 'M'), throwsA(isA<ApiNinjasFailure>()));
      expect(api.requests, 1, reason: 'a failed request still counts');
    });
  });

  test('rows from the database', () {
    final m = SpecsModel.fromRow({
      'id': 'i',
      'brand': 'Honda',
      'model': 'CB650R',
      'aliases': ['CB 650 R'],
      'excluded_words': ['650f'],
      'engine_cc_min': 640,
      'engine_cc_max': 660,
      'power_kw': 70,
      'tank_l': '15.4',
      'cylinders': 4,
      'front_tyre': '120/70-17',
    });
    expect(m.names, ['CB650R', 'CB 650 R']);
    expect(m.excludedWords, ['650f']);
    expect(m.engineCcMax, 660);
    expect(m.specs.toJson(), {
      'power_kw': 70.0,
      'tank_l': 15.4,
      'front_tyre': '120/70-17',
      'cylinders': 4,
    });
  });
}
