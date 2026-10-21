import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/di/injection.dart';
import '../domain/workflows_repository.dart';
import 'workflows_text.dart';

/// Starts [workflow] now (with [kind], the example `push-test.yml` sends);
/// returns what to tell the user (started, or why not).
Future<String> startWorkflow(AppWorkflow workflow, {PushTestKind? kind}) async {
  try {
    await getIt<WorkflowsRepository>().start(workflow, kind: kind);
    return workflowText(workflow).started;
  } on PostgrestException catch (e) {
    return startErrorText(e.code);
  } on Exception {
    return startErrorText(null);
  }
}
