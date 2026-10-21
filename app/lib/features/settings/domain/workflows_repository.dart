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

abstract interface class WorkflowsRepository {
  /// Starts [workflow] on main now; returns when it was recorded.
  Future<DateTime> start(AppWorkflow workflow);
}
