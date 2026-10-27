import '../../../core/formatting/formatters.dart';
import '../domain/entities/listing.dart';
import 'listing_labels.dart';
import '../../../core/localization/localizations.dart';

/// A first message to the seller, ready to copy into the site's chat or a
/// text: interest, the questions the ad leaves open, and optionally an
/// offer ([offer], the suggested opening price).
String sellerMessage(
  Listing listing, {
  double? offer,
  AppLanguage language = AppLanguage.portuguese,
}) {
  final bike = [
    '${listing.brand} ${listing.model}',
    if (listing.year != null)
      language.messages.fromSellerMessageText(year: listing.year.toString()),
  ].join(' ');
  final site = switch (listing.source) {
    'olx' || 'standvirtual' => language.messages.onText(
      value: sourceLabel(listing.source, language: language),
    ),
    _ => '',
  };

  final questions = [
    language.messages.isItStillAvailable,
    if (listing.mileage == null) language.messages.whatIsItsMileage,
    if (listing.registrations == null) language.messages.howManyOwnersHasItHad,
    if (listing.serviceBook == null)
      language.messages.doesItHaveServiceBookWithItsServices,
    if (listing.origin == null)
      language.messages.wasItOriginallyRegisteredInPortugal,
    language.messages.hasItEverBeenDroppedOrInvolvedIn,
    if (listing.sellerType == SellerType.private)
      language.messages.isItRegisteredInYourName,
    language.messages.whenAndWhereCanISeeIt,
  ];

  return [
    language.messages.helloGoodAfternoon,
    '',
    language.messages.iSawYourListingForAndIAm(bike: bike, site: site),
    for (final q in questions) '- $q',
    if (offer != null) ...[
      '',
      language.messages.ifEverythingIsAsDescribedWouldYouAccept(
        price: Formatters.price(offer, language: language),
      ),
    ],
    '',
    language.messages.thankYou,
  ].join('\n');
}
