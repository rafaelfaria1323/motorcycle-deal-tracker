import 'package:flutter_test/flutter_test.dart';
import 'package:motorcycle_deal_tracker/core/formatting/formatters.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/entities/listing.dart';
import 'package:motorcycle_deal_tracker/features/listings/presentation/seller_message_text.dart';

Listing _listing({
  String source = 'olx',
  SellerType sellerType = SellerType.private,
  int? year = 2021,
  int? mileage,
  int? registrations,
  bool? serviceBook,
  String? origin,
}) => Listing(
  id: 'l1',
  source: source,
  url: 'https://www.olx.pt/d/anuncio/x.html',
  brand: 'Yamaha',
  model: 'MT-07',
  status: ListingStatus.active,
  sellerType: sellerType,
  images: const [],
  year: year,
  mileage: mileage,
  registrations: registrations,
  serviceBook: serviceBook,
  origin: origin,
);

void main() {
  test('asks what the ad leaves open', () {
    expect(
      sellerMessage(_listing()),
      'Olá, boa tarde.\n'
      '\n'
      'Vi o seu anúncio da Yamaha MT-07 de 2021 no OLX e tenho interesse. '
      'Tenho algumas perguntas:\n'
      '- Ainda está disponível?\n'
      '- Quantos quilómetros tem?\n'
      '- Quantos donos teve?\n'
      '- Tem livro de revisões, com as revisões feitas?\n'
      '- É de origem nacional?\n'
      '- Já teve alguma queda ou acidente?\n'
      '- O registo está em seu nome?\n'
      '- Quando e onde a posso ver?\n'
      '\n'
      'Obrigado.',
    );
  });

  test(
    'a dealer ad with every fact filled in gets only the usual questions',
    () {
      final message = sellerMessage(
        _listing(
          source: 'standvirtual',
          sellerType: SellerType.dealer,
          mileage: 12000,
          registrations: 1,
          serviceBook: true,
          origin: 'national',
        ),
      );
      expect(message, contains('no Standvirtual e tenho interesse'));
      expect(message.split('\n').where((l) => l.startsWith('- ')).toList(), [
        '- Ainda está disponível?',
        '- Já teve alguma queda ou acidente?',
        '- Quando e onde a posso ver?',
      ]);
    },
  );

  test('with an offer, and without a year or a known site', () {
    final message = sellerMessage(
      _listing(source: 'manual', year: null),
      offer: 6500,
    );
    expect(
      message,
      contains('Vi o seu anúncio da Yamaha MT-07 e tenho interesse.'),
    );
    expect(
      message,
      contains(
        '\n\nSe estiver tudo como descrito, aceitaria '
        '${Formatters.price(6500)}?\n\nObrigado.',
      ),
    );
  });
}
