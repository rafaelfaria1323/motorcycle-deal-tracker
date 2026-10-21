/// The GitHub workflows the app can start: the collection (admins), a test
/// notification and the weekly summary (any signed-in account, for
/// itself).
enum AppWorkflow {
  collect('collect.yml'),
  weeklySummary('weekly-summary.yml'),
  pushTest('push-test.yml');

  const AppWorkflow(this.file);

  /// The workflow's file name, as `start_workflow` knows it.
  final String file;
}

/// The notifications `push-test.yml` can send as an example (its input
/// `kind`; the collector's `pushTestKinds`).
enum PushTestKind {
  test('test'),
  newListing('new_listing'),
  priceReduction('price_reduction'),
  excellentOpportunity('excellent_opportunity'),
  targetPriceReached('target_price_reached'),
  listingRemoved('listing_removed'),
  backOnMarket('back_on_market'),
  runFailed('run_failed'),
  runBlocked('run_blocked'),
  runRecovered('run_recovered');

  const PushTestKind(this.code);

  /// The code `start_workflow` and the workflow know it by.
  final String code;
}

abstract interface class WorkflowsRepository {
  /// Starts [workflow] on main now; returns when it was recorded. [kind]
  /// picks the example `push-test.yml` sends (only there).
  Future<DateTime> start(AppWorkflow workflow, {PushTestKind? kind});
}
