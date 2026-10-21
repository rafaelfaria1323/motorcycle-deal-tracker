import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/di/injection.dart';
import '../domain/workflows_repository.dart';
import 'workflows_text.dart';

/// Starts [workflow] now; returns what to tell the user (started, or why
/// not).
Future<String> startWorkflow(AppWorkflow workflow) async {
  try {
    await getIt<WorkflowsRepository>().start(workflow);
    return workflowText(workflow).started;
  } on PostgrestException catch (e) {
    return startErrorText(e.code);
  } on Exception {
    return startErrorText(null);
  }
}
