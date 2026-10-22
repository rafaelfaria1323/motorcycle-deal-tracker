import 'package:flutter_test/flutter_test.dart';
import 'package:motorcycle_deal_tracker/features/listings/domain/entities/listing.dart';
import 'package:motorcycle_deal_tracker/features/listings/presentation/colour_text.dart';
import 'package:motorcycle_deal_tracker/features/listings/presentation/listing_detail_text.dart';
import 'package:motorcycle_deal_tracker/features/listings/presentation/score_explanation.dart';

Listing _listing({String? colour, bool myColour = false}) => Listing(
  id: 'c1',
  source: 'standvirtual',
  url: 'https://www.standvirtual.com/motos/anuncio/x.html',
  brand: 'Yamaha',
  model: 'MT-07',
  status: ListingStatus.active,
  sellerType: SellerType.dealer,
  images: const [],
  dealScore: 75,
  colour: colour,
  myColour: myColour,
);

void main() {
  test('the codes match the database check', () {
    // As user_colours' check and colour_code() in the database.
    expect(colourLabels.keys, [
      'black',
      'white',
      'grey',
      'silver',
      'blue',
      'red',
      'green',
      'yellow',
      'orange',
      'brown',
      'beige',
      'gold',
      'purple',
      'pink',
    ]);
    expect(colourLabel('blue'), 'Azul');
    expect(colourLabel('teal'), isNull);
    expect(colourLabel(null), isNull);
  });

  test('the chosen colours read in the offered order', () {
    expect(
      favouriteColoursText(['red', 'black', 'unknown']),
      'Preto, Vermelho',
    );
    expect(favouriteColoursText(const []), isNull);
  });

  test('a favourite colour is a plus that adds no points', () {
    expect(favouriteColourLine(_listing(colour: 'blue')), isNull);
    expect(
      favouriteColourLine(_listing(colour: 'blue', myColour: true)),
      const ExplanationLine(
        ExplanationTone.positive,
        'Numa das suas cores preferidas: azul (não conta na pontuação)',
      ),
    );
    expect(
      ScoreExplainer.explain(_listing(colour: 'red', myColour: true))!.lines,
      contains(favouriteColourLine(_listing(colour: 'red', myColour: true))),
    );
    expect(ScoreExplainer.explain(_listing(colour: 'red'))!.lines, isEmpty);
  });

  test('the bike facts show the colour when known', () {
    expect(bikeFacts(_listing()).map((f) => f.$1), isNot(contains('Cor')));
    expect(bikeFacts(_listing(colour: 'grey')), contains(('Cor', 'Cinzento')));
    expect(
      bikeFacts(_listing(colour: 'grey', myColour: true)),
      contains(('Cor', 'Cinzento (uma das suas preferidas)')),
    );
  });
}
