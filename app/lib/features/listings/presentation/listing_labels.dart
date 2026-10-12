import '../domain/entities/listing.dart';

extension ListingStatusLabel on ListingStatus {
  String get label => switch (this) {
    ListingStatus.active => 'Ativo',
    ListingStatus.priceChanged => 'Preço alterado',
    ListingStatus.removed => 'Removido',
    ListingStatus.sold => 'Vendido',
    ListingStatus.unknown => 'Desconhecido',
  };
}

extension SellerTypeLabel on SellerType {
  String get label => switch (this) {
    SellerType.private => 'Particular',
    SellerType.dealer => 'Profissional',
    SellerType.unknown => 'Desconhecido',
  };
}
