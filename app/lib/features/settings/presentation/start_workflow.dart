import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/di/injection.dart';
import '../domain/workflows_repository.dart';
import 'workflows_text.dart';
import '../../../core/localization/localizations.dart';

/// Starts [workflow] now (with [kind], the example `push-test.yml` sends);
/// returns what to tell the user (started, or why not).
Future<String> startWorkflow(
  AppWorkflow workflow, {
  PushTestKind? kind,
  AppLanguage language = .portuguese,
}) async {
  try {
    await getIt<WorkflowsRepository>().start(workflow, kind: kind);
    return workflowText(workflow, language: language).started;
  } on PostgrestException catch (e) {
    return startErrorText(e.code, language: language);
  } on Exception {
    return startErrorText(null, language: language);
  }
}
