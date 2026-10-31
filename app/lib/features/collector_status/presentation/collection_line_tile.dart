import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/di/injection.dart';
import '../../../app/router/app_routes.dart';
import '../../../core/auth/session_cubit.dart';
import 'collection_text.dart';
import 'collector_status_cubit.dart';
import '../../../core/localization/localizations.dart';

/// Mais' "Recolha de dados" (F.5): one line for everyone, the last run and
/// the next, tinted when the last run went wrong or is old. Admins tap it
/// for "Estado da recolha", where the runs and the data quality are.
class const CollectionLineTile({required final bool admin, super.key})
    extends StatefulWidget {
  @override
  State<CollectionLineTile> createState() => _CollectionLineTileState();
}

class _CollectionLineTileState extends State<CollectionLineTile> {
  final _cubit = getIt<CollectorStatusCubit>();

  @override
  void initState() {
    super.initState();
    _cubit.load();
  }

  @override
  Widget build(BuildContext context) {
    // Signing in or out changes what this session may read.
    return BlocListener<SessionCubit, SessionState>(
      bloc: getIt<SessionCubit>(),
      listener: (context, _) => _cubit.load(),
      child: BlocBuilder<CollectorStatusCubit, CollectorStatusState>(
        bloc: _cubit,
        builder: (context, state) {
          final line = collectionLine(
            state.run,
            DateTime.now(),
            language: context.language,
          );
          final scheme = Theme.of(context).colorScheme;
          final (icon, background, foreground) = switch (line.health) {
            .unknown || .ok => (Icons.event_outlined, null, null),
            .stale => (
              Icons.schedule,
              scheme.tertiaryContainer,
              scheme.onTertiaryContainer,
            ),
            .blocked => (
              Icons.block,
              scheme.errorContainer,
              scheme.onErrorContainer,
            ),
            .failed => (
              Icons.error_outline,
              scheme.errorContainer,
              scheme.onErrorContainer,
            ),
          };
          final subtitle = line.subtitle;
          return ListTile(
            tileColor: background,
            textColor: foreground,
            iconColor: foreground,
            leading: Icon(icon),
            title: Text(line.title),
            subtitle: subtitle == null ? null : Text(subtitle),
            trailing: widget.admin ? const Icon(Icons.chevron_right) : null,
            onTap: widget.admin
                ? () => context.push(AppRoutes.collectionStatus)
                : null,
          );
        },
      ),
    );
  }
}
