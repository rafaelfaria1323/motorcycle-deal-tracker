import '../domain/entities/listing.dart';
import '../../../core/localization/localizations.dart';

/// What a photo hint's code says; null for a code this build doesn't know
/// (the database may add one before the app has its words).
String? photoHintLabel(String code, {AppLanguage language = .portuguese}) {
  final m = language.messages;
  return switch (code) {
    'crashed' => m.photoHintCrashed,
    'fallen' => m.photoHintFallen,
    'scratches' => m.photoHintScratches,
    'broken_parts' => m.photoHintBrokenParts,
    'missing_parts' => m.photoHintMissingParts,
    'rust' => m.photoHintRust,
    'learned' => m.photoHintLearned,
    _ => null,
  };
}

/// The listing's photo hints that can be shown: what each says, which
/// photo it points at ("Foto 3") and that photo's index in the listing's
/// images; known codes only, and only photos the listing still has.
List<({String label, String photoLabel, int photo})> photoHintLines(
  Listing listing, {
  AppLanguage language = .portuguese,
}) => [
  for (final hint in listing.photoHints)
    if (photoHintLabel(hint.code, language: language) case final label?)
      if (hint.photo >= 0 && hint.photo < listing.images.length)
        (
          label: label,
          photoLabel: language.messages.photoNumber(
            number: '${hint.photo + 1}',
          ),
          photo: hint.photo,
        ),
];
