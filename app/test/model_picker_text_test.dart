import 'package:flutter_test/flutter_test.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/entities/site_model.dart';
import 'package:motorcycle_deal_tracker/features/listings/presentation/model_picker_text.dart';
import 'package:motorcycle_deal_tracker/features/listings/presentation/tracked_models_text.dart';

SiteModel sv(String id, String name, int ads) => SiteModel(
  source: 'standvirtual',
  makeId: 'honda',
  id: id,
  name: name,
  ads: ads,
);

SiteModel olx(String id, String name) =>
    SiteModel(source: 'olx', makeId: 'honda', id: id, name: name);

void main() {
  test('brands and models with the most ads come first', () {
    final makes = sortedMakes(const [
      SiteMake(id: 'ktm', name: 'KTM', ads: 87),
      SiteMake(id: 'bmw', name: 'BMW', ads: 549),
      SiteMake(id: 'aprilia', name: 'Aprilia', ads: 87),
    ]);
    expect([for (final m in makes) m.id], ['bmw', 'aprilia', 'ktm']);

    final models = pickerModels([
      sv('cb', 'CB', 52),
      olx('forza', 'Forza'),
      sv('forza', 'Forza', 32),
      sv('adv', 'ADV', 32),
    ]);
    expect([for (final m in models) m.id], ['cb', 'adv', 'forza']);
  });

  test('the ads label', () {
    expect(adsLabel('Forza', 32), 'Forza (32 anúncios)');
    expect(adsLabel('S01', 1), 'S01 (1 anúncio)');
    expect(adsLabel('Forza', null), 'Forza');
  });

  test('the engine size is optional', () {
    expect(parseEngineCc(''), (cc: null, error: null));
    expect(parseEngineCc(' 350 cc'), (cc: 350, error: null));
    expect(parseEngineCc('35').error, 'Cilindrada entre 50 e 2500 cc');
    expect(parseEngineCc('abc').error, isNotNull);
    expect(engineRange(350), (min: 315, max: 385));
    expect(engineRange(125), (min: 113, max: 138));
  });

  test('the engine size goes into the name unless it is there', () {
    expect(pickedModelName('Forza ', 350), 'Forza 350');
    expect(pickedModelName('Forza', null), 'Forza');
    expect(pickedModelName('PCX125', 125), 'PCX125');
    expect(pickedModelName('MT-125', 125), 'MT-125');
    expect(pickedModelName('CB', 650), 'CB 650');
    expect(pickedModelName('1250 GS', 125), '1250 GS 125');
  });

  test('the searches are built from the sites\' ids', () {
    expect(
      standvirtualSearchFor('honda', 'forza', 350),
      '${standvirtualSearchPrefix}honda/forza/q-350',
    );
    expect(
      standvirtualSearchFor('honda', 'africa-twin', null),
      '${standvirtualSearchPrefix}honda/africa-twin',
    );
    expect(
      olxSearchFor('honda', 'forza'),
      '${olxSearchPrefix}honda/?search%5Bfilter_enum_modelo%5D%5B0%5D=forza',
    );
  });

  test('OLX\'s model is found by id or by name', () {
    final models = [
      sv('forza', 'Forza', 32),
      olx('forza', 'Forza'),
      olx('tenere700', 'Ténéré 700'),
    ];

    expect(olxModelFor(models, sv('forza', 'Forza', 32))?.id, 'forza');
    expect(
      olxModelFor(models, sv('tenere-700', 'Ténéré 700', 3))?.id,
      'tenere700',
    );
    expect(olxModelFor(models, sv('tracer', 'Tracer', 49)), isNull);
    expect(
      olxModelFor([sv('forza', 'Forza', 32)], sv('forza', 'Forza', 32)),
      isNull,
    );
  });
}
