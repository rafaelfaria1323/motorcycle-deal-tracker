import '../../../core/localization/localizations.dart';

String listingsResultsText(
  int count, {
  required bool hasMore,
  AppLanguage language = AppLanguage.portuguese,
}) => language.messages.listingsResultCount(
  count: count,
  hasMore: hasMore.toString(),
);
