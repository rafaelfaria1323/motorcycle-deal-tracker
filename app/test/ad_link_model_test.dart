import 'package:flutter_test/flutter_test.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/entities/site_model.dart';
import 'package:motorcycle_deal_tracker/features/valuation/presentation/ad_link_model.dart';

typedef _Model = ({String brand, String model});

const _catalog = <_Model>[
  (brand: 'Yamaha', model: 'MT-07'),
  (brand: 'Yamaha', model: 'Tracer 7'),
  (brand: 'Yamaha', model: 'R7'),
  (brand: 'Honda', model: 'CB650R'),
  (brand: 'Honda', model: 'CBR650R'),
  (brand: 'Honda', model: 'CB750 Hornet'),
];

_Model? _guess(String link) => modelInWords(
  adLinkWords(link),
  _catalog,
  brand: (m) => m.brand,
  model: (m) => m.model,
);

void main() {
  test('the title words of both sites\' links, without the ad code', () {
    expect(
      adLinkWords(
        'https://www.olx.pt/d/anuncio/kawasaki-z650-como-nova-IDHk3aB.html',
      ),
      ['kawasaki', 'z650', 'como', 'nova'],
    );
    expect(
      adLinkWords(
        'https://www.standvirtual.com/motos/anuncio/honda-cbr-650-r-ID8Q1m16.html',
      ),
      ['honda', 'cbr', '650', 'r'],
    );
    expect(adLinkWords('nothing'), isEmpty);
  });

  group('modelInWords', () {
    test('the model in one to three words, with or without the brand', () {
      expect(
        _guess('https://www.olx.pt/d/anuncio/yamaha-mt-07-abs-IDa.html'),
        _catalog[0],
      );
      expect(
        _guess('https://www.olx.pt/d/anuncio/vendo-mt07-impecavel-IDa.html'),
        _catalog[0],
      );
      expect(
        _guess(
          'https://www.standvirtual.com/motos/anuncio/honda-cbr-650-r-ID8Q.html',
        ),
        _catalog[4],
      );
      expect(
        _guess('https://www.olx.pt/d/anuncio/honda-cb750-hornet-IDa.html'),
        _catalog[5],
      );
    });

    test('a name without its closing letters, when only one fits', () {
      expect(
        _guess('https://www.olx.pt/d/anuncio/honda-cbr-650-2021-IDa.html'),
        _catalog[4],
      );
      expect(
        _guess('https://www.olx.pt/d/anuncio/honda-cb-650-IDa.html'),
        _catalog[3],
      );
    });

    test('a short name needs its brand', () {
      expect(
        _guess('https://www.olx.pt/d/anuncio/yamaha-r7-IDa.html'),
        _catalog[2],
      );
      expect(_guess('https://www.olx.pt/d/anuncio/r7-IDa.html'), isNull);
    });

    test('another brand named, nothing fits or two fit: no guess', () {
      expect(
        _guess('https://www.olx.pt/d/anuncio/yamaha-tracer-7-gt-IDa.html'),
        _catalog[1],
      );
      expect(
        _guess('https://www.olx.pt/d/anuncio/kawasaki-mt07-IDa.html'),
        _catalog[0],
        reason: 'a brand outside the list does not filter',
      );
      expect(
        _guess('https://www.olx.pt/d/anuncio/honda-mt07-IDa.html'),
        isNull,
        reason: 'Honda named: only its models',
      );
      expect(
        _guess('https://www.olx.pt/d/anuncio/mota-como-nova-IDa.html'),
        isNull,
      );
      expect(
        _guess(
          'https://www.olx.pt/d/anuncio/troco-mt07-por-r7-yamaha-IDa.html',
        ),
        isNull,
      );
    });
  });

  group('the sites\' lists', () {
    const kawasaki = SiteMake(id: 'kawasaki', name: 'Kawasaki', ads: 40);
    const harley = SiteMake(
      id: 'harley-davidson',
      name: 'Harley-Davidson',
      ads: 9,
    );
    const models = [
      SiteModel(
        source: 'standvirtual',
        makeId: 'kawasaki',
        id: 'z-650',
        name: 'Z 650',
      ),
      SiteModel(
        source: 'standvirtual',
        makeId: 'kawasaki',
        id: 'z-900',
        name: 'Z 900',
      ),
      SiteModel(source: 'olx', makeId: 'kawasaki', id: 'z650', name: 'Z650'),
    ];
    const link =
        'https://www.olx.pt/d/anuncio/kawasaki-z650-como-nova-IDHk3aB.html';

    test('the brand named in the link, the longest first', () {
      expect(makeInWords(adLinkWords(link), [harley, kawasaki]), kawasaki);
      expect(
        makeInWords(
          adLinkWords(
            'https://www.olx.pt/d/anuncio/harley-davidson-iron-883-IDa.html',
          ),
          [const SiteMake(id: 'harley', name: 'Harley', ads: 1), harley],
        ),
        harley,
      );
      expect(makeInWords(adLinkWords(link), [harley]), isNull);
    });

    test('the model and both searches, as the picker makes them', () {
      final guess = siteModelInWords(adLinkWords(link), kawasaki, models);
      expect(guess?.brand, 'Kawasaki');
      expect(guess?.model, 'Z 650');
      expect(guess?.standvirtualSearch, endsWith('kawasaki/z-650'));
      expect(guess?.olxSearch, contains('z650'));
      expect(
        siteModelInWords(
          adLinkWords('https://www.olx.pt/d/anuncio/kawasaki-ninja-IDa.html'),
          kawasaki,
          models,
        ),
        isNull,
      );
    });
  });
}
