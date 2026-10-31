import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/di/injection.dart';
import '../../../core/auth/session_cubit.dart';
import '../domain/collector_run.dart';
import 'collection_text.dart';
import 'collector_status_cubit.dart';
import '../../../core/localization/localizations.dart';

class const CollectorStatusBanner({super.key}) extends StatefulWidget {
  @override
  State<CollectorStatusBanner> createState() => _CollectorStatusBannerState();
}

class _CollectorStatusBannerState extends State<CollectorStatusBanner> {
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
      child: _status(),
    );
  }

  Widget _status() {
    return BlocBuilder<CollectorStatusCubit, CollectorStatusState>(
      bloc: _cubit,
      builder: (context, state) {
        final run = state.run;
        final scheme = Theme.of(context).colorScheme;

        switch (collectorHealth(run, DateTime.now())) {
          case CollectorHealth.unknown:
          case CollectorHealth.ok:
            // All is well: the time of the last run is in the details.
            return const SizedBox.shrink();
          case CollectorHealth.stale:
            return _card(
              color: scheme.tertiaryContainer,
              icon: Icons.schedule,
              title: context.strings.noRecentUpdates,
              text: context.strings.bannerStale(
                ago: agoText(run!.finishedAt, language: context.language),
              ),
            );
          case CollectorHealth.blocked:
            return _card(
              color: scheme.errorContainer,
              icon: Icons.block,
              title: context.strings.collectionBlockedBySite,
              text: context.strings.bannerSiteBlocked(
                ago: agoText(run!.finishedAt, language: context.language),
              ),
            );
          case CollectorHealth.failed:
            return _card(
              color: scheme.errorContainer,
              icon: Icons.error_outline,
              title: context.strings.lastCollectionFailed,
              text: context.strings.bannerFailed(
                ago: capitalize(
                  agoText(run!.finishedAt, language: context.language),
                ),
              ),
            );
        }
      },
    );
  }

  Widget _card({
    required Color color,
    required IconData icon,
    required String title,
    required String text,
  }) => Card(
    color: color,
    margin: const EdgeInsets.only(bottom: 12),
    child: ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(text),
    ),
  );
}
