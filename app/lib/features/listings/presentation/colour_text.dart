import '../domain/entities/listing.dart';
import 'score_explanation.dart';
import '../../../core/localization/localizations.dart';

final _colourLabels = <AppLanguage, Map<String, String>>{};

Map<String, String> colourLabels({AppLanguage language = .portuguese}) =>
    _colourLabels.putIfAbsent(
      language,
      () => Map<String, String>.unmodifiable({
        'black': language.messages.black,
        'white': language.messages.white,
        'grey': language.messages.grey,
        'silver': language.messages.silver,
        'blue': language.messages.blue,
        'red': language.messages.red,
        'green': language.messages.green,
        'yellow': language.messages.yellow,
        'orange': language.messages.orange,
        'brown': language.messages.brown,
        'beige': language.messages.beige,
        'gold': language.messages.gold,
        'purple': language.messages.purple,
        'pink': language.messages.pink,
      }),
    );

/// "Azul" for a known code; null otherwise.
String? colourLabel(String? code, {AppLanguage language = .portuguese}) =>
    colourLabels(language: language)[code];

/// The person's colours for a model ("Preto, Azul", in the offered order),
/// or null when none is chosen.
String? favouriteColoursText(
  Iterable<String> codes, {
  AppLanguage language = .portuguese,
}) {
  final chosen = codes.toSet();
  final labels = [
    for (final MapEntry(:key, :value) in colourLabels(
      language: language,
    ).entries)
      if (chosen.contains(key)) value,
  ];
  return labels.isEmpty ? null : labels.join(', ');
}

/// The plus on the score card when the bike is in one of the person's
/// colours; it says it adds no points (an older bike or one with more km
/// must not win on colour).
ExplanationLine? favouriteColourLine(
  Listing listing, {
  AppLanguage language = .portuguese,
}) {
  if (!listing.myColour) return null;
  final label = colourLabel(listing.colour, language: language)?.toLowerCase();
  return ExplanationLine(
    ExplanationTone.positive,
    label == null
        ? language.messages.inOneOfYourPreferredColoursDoesNot
        : language.messages.inYourColour(label: label),
  );
}
