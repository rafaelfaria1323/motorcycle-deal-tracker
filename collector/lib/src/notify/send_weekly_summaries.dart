import '../store/push_store.dart';
import '../store/summary_store.dart';
import 'push_test.dart';
import 'web_push.dart';
import 'weekly_summary.dart';

/// Each account's summary of the week before [until], over its own models
/// ([follows]: account -> catalog id -> first year). With [account], only
/// that account's (an account that follows nothing gets an empty week).
Map<String, WeeklySummary> summariesByAccount({
  required Map<String, Map<String, int>> follows,
  required List<SummaryListing> listings,
  required List<PricePoint> history,
  required DateTime until,
  String? account,
}) {
  final accounts = account == null
      ? follows
      : {account: follows[account] ?? const <String, int>{}};
  return {
    for (final MapEntry(key: user, value: models) in accounts.entries)
      user: buildWeeklySummary(
        listings: listingsFollowed(listings, models),
        history: history,
        until: until,
      ),
  };
}

/// Reads what the summaries need and makes them: every account's, or with
/// [account] only that one's. Only the followed models' listings are read
/// (of [bikeNames], catalog id to name), and the price history only of
/// those still live, so one account's summary reads one account's data.
Future<Map<String, WeeklySummary>> loadWeeklySummaries(
  SummaryStore store,
  Map<String, String> bikeNames, {
  required DateTime until,
  String? account,
}) async {
  final since = until.subtract(const Duration(days: 7));
  final follows = await store.followedModels(account: account);
  final followed = {for (final models in follows.values) ...models.keys};
  final listings = await store.summaryListings({
    for (final MapEntry(:key, :value) in bikeNames.entries)
      if (followed.contains(key)) key: value,
  }, since);
  final history = await store.priceHistoryChangedSince({
    for (final l in listings)
      if (l.isLive) l.id,
  }, since);
  return summariesByAccount(
    follows: follows,
    listings: listings,
    history: history,
    until: until,
    account: account,
  );
}

/// Keeps each summary for the app and sends it to the account's devices.
Future<({int accounts, int devices, int sent})> sendWeeklySummaries(
  SummaryStore store,
  PushStore pushes,
  WebPushSender push,
  Map<String, WeeklySummary> summaries,
) async {
  for (final MapEntry(key: user, value: summary) in summaries.entries) {
    await store.saveWeeklySummary(user, summary, weeklySummaryJson(summary));
  }
  final result = await pushToUsers(
    pushes,
    push,
    summaries.keys.toList(),
    (user, language) => weeklySummaryPush(summaries[user]!, language: language),
  );
  return (
    accounts: summaries.length,
    devices: result.devices,
    sent: result.sent,
  );
}
