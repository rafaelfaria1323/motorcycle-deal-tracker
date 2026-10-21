import '../../../core/formatting/formatters.dart';
import '../domain/entities/listing.dart';
import 'listing_labels.dart';

/// A first message to the seller, ready to copy into the site's chat or a
/// text: interest, the questions the ad leaves open, and optionally an
/// offer ([offer], the suggested opening price).
String sellerMessage(Listing listing, {double? offer}) {
  final bike = [
    '${listing.brand} ${listing.model}',
    if (listing.year != null) 'de ${listing.year}',
  ].join(' ');
  final site = switch (listing.source) {
    'olx' || 'standvirtual' => ' no ${sourceLabel(listing.source)}',
    _ => '',
  };

  final questions = [
    'Ainda está disponível?',
    if (listing.mileage == null) 'Quantos quilómetros tem?',
    if (listing.registrations == null) 'Quantos donos teve?',
    if (listing.serviceBook == null)
      'Tem livro de revisões, com as revisões feitas?',
    if (listing.origin == null) 'É de origem nacional?',
    'Já teve alguma queda ou acidente?',
    if (listing.sellerType == SellerType.private) 'O registo está em seu nome?',
    'Quando e onde a posso ver?',
  ];

  return [
    'Olá, boa tarde.',
    '',
    'Vi o seu anúncio da $bike$site e tenho interesse. '
        'Tenho algumas perguntas:',
    for (final q in questions) '- $q',
    if (offer != null) ...[
      '',
      'Se estiver tudo como descrito, aceitaria '
          '${Formatters.price(offer)}?',
    ],
    '',
    'Obrigado.',
  ].join('\n');
}
