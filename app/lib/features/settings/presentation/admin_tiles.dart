import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../core/widgets/show_message.dart';
import '../domain/workflows_repository.dart';
import 'start_workflow.dart';
import 'workflows_text.dart';
import '../../../core/localization/localizations.dart';

/// "Administração" in Mais, shown to admins only: the accounts and
/// invites, the "Estado da recolha" page and starting the collection now.
class const AdminTiles({super.key}) extends StatefulWidget {
  @override
  State<AdminTiles> createState() => _AdminTilesState();
}

class _AdminTilesState extends State<AdminTiles> {
  bool _starting = false;

  Future<void> _start() async {
    final messageLanguage = context.language;

    const workflow = AppWorkflow.collect;
    final text = workflowText(workflow, language: messageLanguage);
    final ok =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text('${text.title}?'),
            content: Text('${text.subtitle}.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(dialogContext.strings.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(dialogContext.strings.start),
              ),
            ],
          ),
        ) ??
        false;
    if (!ok || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _starting = true);
    final message = await startWorkflow(workflow, language: messageLanguage);
    if (!mounted) return;
    setState(() => _starting = false);
    showMessage(messenger, message);
  }

  @override
  Widget build(BuildContext context) {
    final collect = workflowText(
      AppWorkflow.collect,
      language: context.language,
    );
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.group_outlined),
          title: Text(context.strings.accountsAndInvites),
          subtitle: Text(context.strings.invitePeopleWithLinkAndSeeWhoHas),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push(AppRoutes.accounts),
        ),
        const Divider(height: 1),
        ListTile(
          leading: const Icon(Icons.monitor_heart_outlined),
          title: Text(context.strings.collectionStatus),
          subtitle: Text(context.strings.collectionStatusSubtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push(AppRoutes.collectionStatus),
        ),
        const Divider(height: 1),
        ListTile(
          leading: const Icon(Icons.play_circle_outline),
          title: Text(collect.title),
          subtitle: Text(collect.subtitle),
          trailing: _starting
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : null,
          enabled: !_starting,
          onTap: _start,
        ),
      ],
    );
  }
}
