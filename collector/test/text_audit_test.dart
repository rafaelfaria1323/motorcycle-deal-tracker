import 'dart:io';

import 'package:collector/collector.dart';
import 'package:test/test.dart';

const _ad = AuditListing(
  id: 'a1',
  url: 'https://x/a1',
  variant: 'MT-07 ABS',
  description: 'Teve uma queda, punhos aquecidos.',
  signals: ['possible_accident', 'a2_limited', 'not_legalised'],
  extras: ['heated_grips'],
  mileageInText: 12000,
);

TextReading _llm({
  bool accident = true,
  bool needsRepair = false,
  bool cosmeticDamage = false,
  String power = 'a2_limited',
  bool singleOwner = false,
  String legalisation = 'not_legalised',
  Set<String> extras = const {'heated_grips'},
  int? mileageKm = 12000,
  Map<String, String> evidence = const {},
}) => TextReading(
  accident: accident,
  needsRepair: needsRepair,
  cosmeticDamage: cosmeticDamage,
  power: power,
  singleOwner: singleOwner,
  legalisation: legalisation,
  extras: extras,
  mileageKm: mileageKm,
  evidence: evidence,
);

void main() {
  test('the extras are the database rules\' codes, in their order', () {
    final schema = File('../supabase/schema.sql').readAsStringSync();
    final start = schema.indexOf('CREATE FUNCTION public.listing_extras(');
    final body = schema.substring(start, schema.indexOf(r'$$;', start));
    final codes = [
      for (final m in RegExp(
        r"^\s*\('([a-z_]+)',",
        multiLine: true,
      ).allMatches(body))
        m.group(1),
    ];
    expect(auditExtras.keys, codes);
  });

  test('the rules\' reading comes from the stored codes', () {
    final rules = _ad.rules;
    expect(rules.accident, isTrue);
    expect(rules.needsRepair, isFalse);
    expect(rules.power, 'a2_limited');
    expect(rules.legalisation, 'not_legalised');
    expect(rules.extras, {'heated_grips'});
    expect(rules.mileageKm, 12000);
    final plain = const AuditListing(id: 'b', url: 'u', description: 'd').rules;
    expect(plain.power, 'none');
    expect(plain.legalisation, 'legalised');
    expect(
      const AuditListing(
        id: 'c',
        url: 'u',
        description: 'd',
        signals: [
          'a2_unlocked',
          'not_legalised_outside_eu',
          'single_owner_in_text',
        ],
      ).rules,
      isA<TextReading>()
          .having((r) => r.power, 'power', 'a2_unlocked')
          .having(
            (r) => r.legalisation,
            'legalisation',
            'not_legalised_outside_eu',
          )
          .having((r) => r.singleOwner, 'single owner', isTrue),
    );
  });

  test('a row of text_audit_sample', () {
    final ad = AuditListing.fromRow({
      'id': 'x',
      'url': 'https://x',
      'variant': null,
      'description': 'Texto',
      'signals': ['needs_repair'],
      'extras': null,
      'mileage_in_text': 9000,
    });
    expect(ad.signals, ['needs_repair']);
    expect(ad.extras, isEmpty);
    expect(ad.mileageInText, 9000);
  });

  group('compareReadings', () {
    test('the same reading: nothing', () {
      expect(compareReadings(_ad, _llm()), isEmpty);
    });

    test(
      'a flag only the LLM read is missed, one only the rules read is not',
      () {
        final found = compareReadings(
          _ad,
          _llm(
            accident: false,
            cosmeticDamage: true,
            evidence: {'cosmetic_damage': 'tem uns riscos'},
          ),
        );
        expect(
          [for (final d in found) (d.field, d.rules, d.llm, d.missed, d.quote)],
          [
            ('accident', 'yes', 'no', false, null),
            ('cosmetic_damage', 'no', 'yes', true, 'tem uns riscos'),
          ],
        );
      },
    );

    test('needs repair and single owner are compared too', () {
      expect(
        [
          for (final d in compareReadings(
            _ad,
            _llm(needsRepair: true, singleOwner: true),
          ))
            d.field,
        ],
        ['needs_repair', 'single_owner'],
      );
    });

    test('power and legalisation: missed when the LLM read a risk', () {
      final found = compareReadings(
        _ad,
        _llm(power: 'none', legalisation: 'not_legalised_outside_eu'),
      );
      expect(
        [for (final d in found) (d.field, d.rules, d.llm, d.missed)],
        [
          ('power', 'a2_limited', 'none', false),
          ('legalisation', 'not_legalised', 'not_legalised_outside_eu', true),
        ],
      );
      expect(
        compareReadings(_ad, _llm(legalisation: 'legalised')).single.missed,
        isFalse,
      );
    });

    test('extras one by one, with the extra\'s quote', () {
      final found = compareReadings(
        _ad,
        _llm(
          extras: {'quickshifter'},
          evidence: {'quickshifter': 'com quickshifter'},
        ),
      );
      expect(
        [for (final d in found) (d.field, d.missed, d.quote)],
        [
          ('extra:quickshifter', true, 'com quickshifter'),
          ('extra:heated_grips', false, null),
        ],
      );
    });

    test('mileage: within 1 % is the same', () {
      expect(compareReadings(_ad, _llm(mileageKm: 12100)), isEmpty);
      final other = compareReadings(_ad, _llm(mileageKm: 12200)).single;
      expect(
        (other.field, other.rules, other.llm, other.missed),
        ('mileage_km', '12000', '12200', true),
      );
      final none = compareReadings(_ad, _llm(mileageKm: null)).single;
      expect((none.llm, none.missed), ('—', false));
      const noRule = AuditListing(id: 'n', url: 'u', description: 'd');
      expect(
        compareReadings(
          noRule,
          _llm(
            accident: false,
            power: 'none',
            legalisation: 'legalised',
            extras: const {},
            mileageKm: 8000,
          ),
        ).single,
        isA<Disagreement>()
            .having((d) => d.rules, 'rules', '—')
            .having((d) => d.missed, 'missed', isTrue),
      );
    });
  });

  group('the LLM\'s answers', () {
    test('a reading from JSON; unknown values read as plain', () {
      final r = TextReading.fromJson({
        'accident': true,
        'needs_repair': 'yes',
        'power': 'full',
        'legalisation': 'not_legalised',
        'extras': ['quickshifter', 'spoiler', 3],
        'mileage_km': 15000.4,
        'evidence': [
          {'field': 'accident', 'quote': 'caiu uma vez'},
          {'field': 'x'},
        ],
      });
      expect(r.accident, isTrue);
      expect(r.needsRepair, isFalse);
      expect(r.power, 'none');
      expect(r.legalisation, 'not_legalised');
      expect(r.extras, {'quickshifter'});
      expect(r.mileageKm, 15000);
      expect(r.evidence, {'accident': 'caiu uma vez'});
      expect(TextReading.fromJson({'mileage_km': 0}).mileageKm, isNull);
      expect(TextReading.fromJson({}).legalisation, 'legalised');
    });

    test('matched by number; missing, repeated and odd ids left out', () {
      const ads = [
        AuditListing(id: '1', url: 'u1', description: 'd'),
        AuditListing(id: '2', url: 'u2', description: 'd'),
        AuditListing(id: '3', url: 'u3', description: 'd'),
      ];
      final read = readDescriptionAnswer(ads, [
        {'id': 1, 'accident': true},
        {'id': 2},
        {'id': 2},
        {'id': 2.5},
        {'id': 9},
        'noise',
      ]);
      expect(read.keys.map((a) => a.id), ['1']);
      expect(read.values.single.accident, isTrue);
      expect(readDescriptionAnswer(ads, {'id': 1}), isEmpty);
    });

    test('the prompt numbers the ads and lists every extra', () {
      final prompt = descriptionPrompt([_ad, _ad]);
      expect(prompt, contains('--- Ad 1 ---\nTitle: MT-07 ABS'));
      expect(prompt, contains('--- Ad 2 ---'));
      for (final code in auditExtras.keys) {
        expect(prompt, contains('- $code: '));
      }
      final items = (descriptionSchema['items']! as Map)['properties'] as Map;
      expect(
        ((items['extras'] as Map)['items'] as Map)['enum'],
        auditExtras.keys.toList(),
      );
    });
  });

  group('unmatched titles', () {
    final catalog = Catalog.mvp();
    const titles = [
      UnmatchedTitle(
        id: 't1',
        url: 'u1',
        brand: 'Yamaha',
        model: 'MT',
        variant: 'MT07 ABS',
      ),
      UnmatchedTitle(
        id: 't2',
        url: 'u2',
        brand: 'Honda',
        model: 'CB',
        variant: '',
      ),
    ];

    test('a row and its title', () {
      final t = UnmatchedTitle.fromRow({
        'id': 'x',
        'url': 'u',
        'brand': 'Yamaha',
        'model': 'MT-09',
        'variant': 'Tracer 9',
      });
      expect(t.title, 'Yamaha · MT-09 · Tracer 9');
      expect(titles[1].title, 'Honda · CB');
    });

    test('the prompt lists the models by code with their engine sizes', () {
      final prompt = titlesPrompt(titles, catalog);
      expect(prompt, contains('- yamaha-mt-07: Yamaha MT-07 (680-710 cc)'));
      expect(prompt, contains('1. Yamaha · MT · MT07 ABS'));
      expect(prompt, contains('2. Honda · CB'));
      expect(
        titlesPrompt(
          titles,
          const Catalog([
            CatalogEntry(slug: 's', brand: 'B', model: 'M', minYear: 2020),
          ]),
        ),
        contains('- s: B M\n'),
      );
    });

    test('only known models, each title once', () {
      final found = readTitlesAnswer(titles, catalog, [
        {'id': 1, 'model': 'yamaha-mt-07', 'evidence': 'MT07'},
        {'id': 1, 'model': 'yamaha-r7', 'evidence': ''},
        {'id': 2, 'model': null, 'evidence': 'CB'},
        {'id': 2, 'model': 'honda-cb500f'},
        {'id': 3, 'model': 'yamaha-r7'},
        {'id': 0, 'model': 'yamaha-r7'},
      ]);
      expect(found.single.title.id, 't1');
      expect(found.single.model.model, 'MT-07');
      expect(found.single.quote, 'MT07');
      expect(
        readTitlesAnswer(titles, catalog, [
          {'id': 2, 'model': 'honda-cb650r', 'evidence': ''},
        ]).single.quote,
        isNull,
      );
      expect(readTitlesAnswer(titles, catalog, 'none'), isEmpty);
    });
  });

  test('the report: counts, both tables and the titles', () {
    final found = compareReadings(
      _ad,
      _llm(
        accident: false,
        extras: {'heated_grips', 'quickshifter'},
        evidence: {'quickshifter': 'com | quick\nshifter'},
      ),
    );
    final report = auditReport(
      model: 'gemini-x',
      adsAsked: 10,
      adsRead: 9,
      disagreements: found,
      titlesAsked: 2,
      titles: [
        TitleSuggestion(
          title: const UnmatchedTitle(
            id: 't',
            url: 'https://x/t',
            brand: 'Yamaha',
            model: 'MT',
            variant: 'MT07',
          ),
          model: Catalog.mvp().entries.first,
          quote: 'MT07',
        ),
      ],
      problems: ['ads 11-20: HTTP 429'],
    );
    expect(
      report,
      contains('Model `gemini-x`: 9 of 10 ad(s) read, 2 unmatched'),
    );
    expect(report, contains('- Problem: ads 11-20: HTTP 429'));
    expect(report, contains('By field: accident 1, extra:quickshifter 1.'));
    expect(report, contains('## The rules missed (the LLM read it) (1)'));
    expect(
      report,
      contains(
        '| extra:quickshifter | [ad](https://x/a1) | no | yes | com / quick shifter |',
      ),
    );
    expect(report, contains('## The rules read more (the LLM did not) (1)'));
    expect(report, contains('| accident | [ad](https://x/a1) | yes | no |  |'));
    expect(
      report,
      contains('| [Yamaha · MT · MT07](https://x/t) | Yamaha MT-07 | MT07 |'),
    );
    final empty = auditReport(
      model: 'm',
      adsAsked: 0,
      adsRead: 0,
      disagreements: const [],
      titlesAsked: 0,
      titles: const [],
    );
    expect('None.'.allMatches(empty).length, 3);
    expect(empty, isNot(contains('By field')));
    final long = auditReport(
      model: 'm',
      adsAsked: 1,
      adsRead: 1,
      disagreements: compareReadings(_ad, _llm(accident: false)),
      titlesAsked: 0,
      titles: const [],
      problems: ['x' * 200],
    );
    expect(long, contains('${'x' * 140}…'));
  });
}
