import '../domain/entities/listing.dart';
import '../domain/entities/listing_sort.dart';

extension ListingSortLabel on ListingSort {
  String get label => switch (this) {
    ListingSort.dealScoreDesc => 'Melhor pontuação',
    ListingSort.newest => 'Mais recentes',
    ListingSort.priceAsc => 'Preço mais baixo',
    ListingSort.priceDesc => 'Preço mais alto',
    ListingSort.nearest => 'Mais perto',
  };
}

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

/// The site a listing comes from, as people know it.
String sourceLabel(String source) => switch (source) {
  'standvirtual' => 'Standvirtual',
  'olx' => 'OLX',
  'manual' => 'Importação manual',
  _ => source,
};
