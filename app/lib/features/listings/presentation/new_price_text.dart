import '../../../core/formatting/formatters.dart';
import '../domain/entities/listing.dart';

/// A list price checked longer ago than this may have changed.
const newPriceStaleAfterDays = 180;

/// Below this discount a new bike, with its factory warranty, is worth
/// comparing.
const smallDiscountPct = 10;

/// Lines comparing the listing's price with a new bike of the same model;
/// empty when either price is unknown.
List<String> newPriceLines(Listing listing, {DateTime? now}) {
  final used = listing.price;
  final fresh = listing.newPrice;
  if (used == null || fresh == null || fresh <= 0) return const [];

  final difference = fresh - used;
  final pct = (difference.abs() / fresh * 100).round();
  final lines = ['Preço de uma nova: ${Formatters.price(fresh)}'];

  if (difference.abs() < 1) {
    lines.add('Custa o mesmo que uma nova');
  } else if (difference > 0) {
    lines.add('${Formatters.price(difference)} abaixo de uma nova ($pct%)');
    if (pct < smallDiscountPct) {
      lines.add(
        'Menos de $smallDiscountPct% abaixo de uma nova: compare com uma '
        'nova, que tem garantia de fábrica',
      );
    }
  } else {
    lines.add('${Formatters.price(-difference)} acima de uma nova ($pct%)');
  }
  if (difference < 1) {
    lines.add(
      'Não é mais barata do que uma nova: confirme os extras incluídos '
      'ou se o preço está certo',
    );
  }

  final checked = listing.newPriceCheckedAt;
  if (checked != null) {
    final age = (now ?? DateTime.now()).difference(checked).inDays;
    lines.add(
      'Preço de uma nova verificado em ${Formatters.date(checked)}'
      '${age > newPriceStaleAfterDays ? ': pode estar desatualizado' : ''}',
    );
  }
  return lines;
}
