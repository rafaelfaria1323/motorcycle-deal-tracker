import '../store/listing_store.dart';
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

/// Keeps each summary for the app and sends it to the account's devices.
Future<({int accounts, int devices, int sent})> sendWeeklySummaries(
  ListingStore store,
  WebPushSender push,
  Map<String, WeeklySummary> summaries,
) async {
  for (final MapEntry(key: user, value: summary) in summaries.entries) {
    await store.saveWeeklySummary(user, summary, weeklySummaryJson(summary));
  }
  final result = await pushToUsers(
    store,
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
