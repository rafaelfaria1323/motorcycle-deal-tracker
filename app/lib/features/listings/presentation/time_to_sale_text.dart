import '../../../core/localization/localizations.dart';
import '../domain/entities/market_behaviour.dart';

/// The line about how much longer the listing is likely to stay on the
/// market (10.4). Null when there is nothing to say: too few ads of the
/// model left (the market lines already say so) or the listing is gone.
String? timeToSaleLine(
  TimeToSale t, {
  required bool live,
  AppLanguage language = AppLanguage.portuguese,
}) {
  if (!live || t.typicalDays == null) return null;
  final remaining = t.remainingDays;
  if (remaining == null) return language.messages.timeToSaleBeyondData;
  return language.messages.timeToSaleEstimate(
    days: remaining,
    band: t.band?.name ?? 'model',
    goneCount: t.goneCount,
    liveCount: t.liveCount,
  );
}
