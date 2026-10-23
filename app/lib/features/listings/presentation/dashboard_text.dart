String listingsResultsText(int count, {required bool hasMore}) {
  final noun = count == 1 ? 'anúncio' : 'anúncios';
  final loaded = count == 1 ? 'carregado' : 'carregados';
  return '$count $noun${hasMore ? ' $loaded' : ''}';
}
