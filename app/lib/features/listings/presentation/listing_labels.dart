import '../../../core/formatting/formatters.dart';
import '../domain/entities/listing.dart';
import '../domain/entities/listing_card_preferences.dart';
import '../domain/entities/listing_sort.dart';
import 'cubit/listing_card_preferences_cubit.dart';
import '../../../core/localization/localizations.dart';

extension ListingSortLabel on ListingSort {
  String label({AppLanguage language = .portuguese}) => switch (this) {
    ListingSort.dealScoreDesc => language.messages.bestScore,
    ListingSort.newest => language.messages.newest,
    ListingSort.priceAsc => language.messages.lowestPrice,
    ListingSort.priceDesc => language.messages.highestPrice,
    ListingSort.nearest => language.messages.nearest,
  };
}

extension ListingPriceLabel on Listing {
  /// The asking price, or "Preço por consultar" for a placeholder (under
  /// [minRealPrice]: "1 €" written only to publish the ad).
  String priceLabel({AppLanguage language = .portuguese}) => hasPlaceholderPrice
      ? language.messages.priceOnRequest
      : Formatters.price(price, language: language);
}

extension ListingStatusLabel on ListingStatus {
  String label({AppLanguage language = .portuguese}) => switch (this) {
    ListingStatus.active => language.messages.active,
    ListingStatus.priceChanged => language.messages.priceChangedListingLabels,
    ListingStatus.removed => language.messages.removed,
    ListingStatus.sold => language.messages.sold,
    ListingStatus.unknown => language.messages.unknown,
  };
}

extension SellerTypeLabel on SellerType {
  String label({AppLanguage language = .portuguese}) => switch (this) {
    SellerType.private => language.messages.private,
    SellerType.dealer => language.messages.dealerListingLabels,
    SellerType.unknown => language.messages.unknown,
  };
}

extension ListingCardFieldLabel on ListingCardField {
  String label({AppLanguage language = .portuguese}) => switch (this) {
    ListingCardField.source => language.messages.sourceSite,
    ListingCardField.dealScore => language.messages.dealScore,
    ListingCardField.priceChange => language.messages.priceChange,
    ListingCardField.marketPosition => language.messages.marketPositionField,
    ListingCardField.year => language.messages.yearLabel,
    ListingCardField.mileage => language.messages.mileage,
    ListingCardField.location => language.messages.locationAndDistance,
    ListingCardField.preferredColour =>
      language.messages.preferredColourIndicator,
    ListingCardField.riskScore => language.messages.riskScore,
    ListingCardField.sellerType => language.messages.sellerType,
    ListingCardField.firstSeenAt => language.messages.whenItWasFound,
    ListingCardField.colour => language.messages.colourLabel,
    ListingCardField.registrations => language.messages.ownersFirstOwner,
    ListingCardField.serviceBook => language.messages.serviceBook,
    ListingCardField.origin => language.messages.origin,
    ListingCardField.warrantyUntil => language.messages.factoryWarranty,
    ListingCardField.dealerWarrantyMonths => language.messages.sellerWarranty,
    ListingCardField.sellerName => language.messages.dealerName,
    ListingCardField.publishedAt => language.messages.publicationDate,
    ListingCardField.siteRefreshedAt => language.messages.renewalOnSite,
    ListingCardField.status => language.messages.listingStatus,
  };
}

String cardPreferencesErrorText(
  ListingCardPreferencesFailure failure, {
  AppLanguage language = .portuguese,
}) => switch (failure) {
  ListingCardPreferencesFailure.load =>
    language.messages.cardPreferencesLoadError,
  ListingCardPreferencesFailure.accountRequired =>
    language.messages.cardPreferencesAccountRequired,
  ListingCardPreferencesFailure.notLoaded =>
    language.messages.cardPreferencesMustLoad,
  ListingCardPreferencesFailure.save =>
    language.messages.cardPreferencesSaveError,
};

/// The site a listing comes from, as people know it.
String sourceLabel(String source, {AppLanguage language = .portuguese}) =>
    switch (source) {
      'standvirtual' => 'Standvirtual',
      'olx' => 'OLX',
      'manual' => language.messages.manualImport,
      _ => source,
    };
