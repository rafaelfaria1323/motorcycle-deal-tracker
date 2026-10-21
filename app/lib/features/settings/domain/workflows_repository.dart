/// The GitHub workflows an admin can start from the app.
enum AppWorkflow {
  collect('collect.yml'),
  weeklySummary('weekly-summary.yml');

  const AppWorkflow(this.file);

  /// The workflow's file name, as `start_workflow` knows it.
  final String file;
}

abstract interface class WorkflowsRepository {
  /// Starts [workflow] on main now (admins only); returns when it was
  /// recorded.
  Future<DateTime> start(AppWorkflow workflow);
}
