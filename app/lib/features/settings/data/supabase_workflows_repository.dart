import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/workflows_repository.dart';

class SupabaseWorkflowsRepository implements WorkflowsRepository {
  SupabaseWorkflowsRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<DateTime> start(
    AppWorkflow workflow, {
    PushTestKind? kind,
  }) async => DateTime.parse(
    await _client.rpc<Object?>(
      'start_workflow',
      params: {
        'p_workflow': workflow.file,
        if (kind != null) 'p_kind': kind.code,
      },
    ) as String,
  );
}
