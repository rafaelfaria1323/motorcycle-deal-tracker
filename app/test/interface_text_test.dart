import 'package:flutter_test/flutter_test.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/entities/listing_filters.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/entities/saved_search.dart';
import 'package:motorcycle_deal_tracker/features/listings/presentation/alerts_text.dart';
import 'package:motorcycle_deal_tracker/features/listings/presentation/dashboard_text.dart';
import 'package:motorcycle_deal_tracker/features/listings/presentation/saved_search_summary.dart';

void main() {
  test('loaded listings are not presented as the entire market', () {
    expect(listingsResultsText(0, hasMore: false), '0 anúncios');
    expect(listingsResultsText(1, hasMore: false), '1 anúncio');
    expect(listingsResultsText(12, hasMore: false), '12 anúncios');
    expect(listingsResultsText(1, hasMore: true), '1 anúncio carregado');
    expect(listingsResultsText(40, hasMore: true), '40 anúncios carregados');
  });

  test('unread alerts have a clear zero and singular state', () {
    expect(unreadAlertsText(0), 'Tudo lido');
    expect(unreadAlertsText(1), '1 alerta por ler');
    expect(unreadAlertsText(3), '3 alertas por ler');
  });

  test('search matches describe listings, not guaranteed good deals', () {
    expect(searchMatchesText(0), '0 anúncios encontrados');
    expect(searchMatchesText(1), '1 anúncio encontrado');
    expect(searchMatchesText(12), '12 anúncios encontrados');
  });

  test('search notification summary reflects every preference', () {
    final search = SavedSearch(
      id: 'one',
      filters: ListingFilters.empty,
      createdAt: DateTime(2026),
    );
    expect(searchNotificationText(search), 'Novos anúncios · Baixas de preço');
    expect(
      searchNotificationText(
        search.copyWith(notifyExcellentDeal: true, notifyListingRemoved: true),
      ),
      'Novos anúncios · Baixas de preço · Oportunidades · Anúncios removidos',
    );
    expect(
      searchNotificationText(
        search.copyWith(notifyNewListing: false, notifyPriceReduction: false),
      ),
      'Sem alertas automáticos',
    );
    expect(
      searchNotificationText(
        search.copyWith(
          notifyNewListing: false,
          notifyPriceReduction: false,
          notifyExcellentDeal: true,
        ),
      ),
      'Oportunidades',
    );
  });
}
