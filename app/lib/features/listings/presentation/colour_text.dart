import '../domain/entities/listing.dart';
import 'score_explanation.dart';

/// The colour codes of `listings.colour` and `user_models.colours`, in the
/// order they are offered, with their labels.
const colourLabels = {
  'black': 'Preto',
  'white': 'Branco',
  'grey': 'Cinzento',
  'silver': 'Prateado',
  'blue': 'Azul',
  'red': 'Vermelho',
  'green': 'Verde',
  'yellow': 'Amarelo',
  'orange': 'Laranja',
  'brown': 'Castanho',
  'beige': 'Bege',
  'gold': 'Dourado',
  'purple': 'Roxo',
  'pink': 'Rosa',
};

/// "Azul" for a known code; null otherwise.
String? colourLabel(String? code) => colourLabels[code];

/// The person's colours for a model ("Preto, Azul", in the offered order),
/// or null when none is chosen.
String? favouriteColoursText(Iterable<String> codes) {
  final chosen = codes.toSet();
  final labels = [
    for (final MapEntry(:key, :value) in colourLabels.entries)
      if (chosen.contains(key)) value,
  ];
  return labels.isEmpty ? null : labels.join(', ');
}

/// The plus on the score card when the bike is in one of the person's
/// colours; it says it adds no points (an older bike or one with more km
/// must not win on colour).
ExplanationLine? favouriteColourLine(Listing listing) {
  if (!listing.myColour) return null;
  final label = colourLabel(listing.colour)?.toLowerCase();
  return ExplanationLine(
    ExplanationTone.positive,
    label == null
        ? 'Numa das suas cores preferidas (não conta na pontuação)'
        : 'Numa das suas cores preferidas: $label (não conta na pontuação)',
  );
}
