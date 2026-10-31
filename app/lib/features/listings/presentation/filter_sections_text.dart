import '../../../core/localization/localizations.dart';

/// What a closed section of the filters says it holds: [none] ("Todos",
/// "Qualquer") when nothing is chosen, up to two choices by name, else
/// how many ("5 escolhidos").
String chosenSummary(
  List<String> labels, {
  required String none,
  AppLanguage language = .portuguese,
}) => switch (labels.length) {
  0 => none,
  1 || 2 => labels.join(' · '),
  final count => language.messages.chosenCount(count: count),
};
