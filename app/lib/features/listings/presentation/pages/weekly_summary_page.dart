import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/di/injection.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../core/auth/session_cubit.dart';
import '../../../../core/widgets/page_back_button.dart';
import '../../../../core/widgets/section_card.dart';
import '../../../../core/widgets/show_message.dart';
import '../../../../core/widgets/state_message.dart';
import '../../../settings/domain/workflows_repository.dart';
import '../../../settings/presentation/start_workflow.dart';
import '../../../settings/presentation/workflows_text.dart';
import '../../domain/entities/weekly_summary.dart';
import '../../domain/repositories/weekly_summary_repository.dart';
import '../weekly_summary_text.dart';
import '../../../../core/localization/localizations.dart';

/// "Resumo da semana" (from Mais, or a tap on the Monday notification):
/// the account's latest weekly summary, each listing opening its page, and
/// asking for a new one now.
class const WeeklySummaryPage({super.key}) extends StatefulWidget {
  @override
  State<WeeklySummaryPage> createState() => _WeeklySummaryPageState();
}

class _WeeklySummaryPageState extends State<WeeklySummaryPage> {
  final _signedIn = getIt<SessionCubit>().state.signedIn;
  late Future<WeeklySummary?> _summary;
  bool _asking = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() => _summary = _signedIn
      ? getIt<WeeklySummaryRepository>().getLatest()
      : Future.value();

  Future<void> _reload() async {
    setState(_load);
    await _summary.then<void>((_) {}, onError: (Object _) {});
  }

  Future<void> _ask() async {
    final messageLanguage = context.language;

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _asking = true);
    final message = await startWorkflow(
      AppWorkflow.weeklySummary,
      language: messageLanguage,
    );
    if (!mounted) return;
    setState(() => _asking = false);
    showMessage(messenger, message);
  }

  @override
  Widget build(BuildContext context) {
    final ask = workflowText(
      AppWorkflow.weeklySummary,
      language: context.language,
    );
    return Scaffold(
      appBar: AppBar(
        leading: const PageBackButton(),
        title: Text(context.strings.weeklySummary),
        actions: [
          if (_signedIn)
            IconButton(
              tooltip: ask.title,
              onPressed: _asking ? null : _ask,
              icon: _asking
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_outlined),
            ),
        ],
      ),
      body: FutureBuilder<WeeklySummary?>(
        future: _summary,
        builder: (context, snapshot) {
          if (!_signedIn) {
            return StateMessage(
              icon: Icons.lock_outline,
              title: context.strings.availableWhenSignedIn,
              message: context.strings.weeklySummaryScope,
            );
          }
          if (snapshot.hasError) {
            return StateMessage(
              icon: Icons.cloud_off,
              title: context.strings.couldNotLoadSummary,
              actionLabel: context.strings.retry,
              onAction: () => unawaited(_reload()),
            );
          }
          if (snapshot.connectionState != .done) {
            return const Center(child: CircularProgressIndicator());
          }
          final summary = snapshot.data;
          if (summary == null) {
            return StateMessage(
              icon: Icons.summarize_outlined,
              title: context.strings.noSummaryYet,
              message: context.strings.weeklySummaryNoneYet,
              actionLabel: _asking ? null : ask.title,
              onAction: () => unawaited(_ask()),
            );
          }
          return RefreshIndicator(
            onRefresh: _reload,
            child: _SummaryView(summary: summary),
          );
        },
      ),
    );
  }
}

class const _SummaryView({required final WeeklySummary summary})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final byModel = newByModelText(summary);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SectionCard(
          title: summaryPeriodText(summary, language: context.language),
          footnote: summaryMadeText(summary, language: context.language),
          children: [
            for (final line in summaryCountLines(
              summary,
              language: context.language,
            ))
              BulletLine(line),
            if (byModel != null)
              BulletLine(context.strings.newText(byModel: byModel)),
          ],
        ),
        if (summary.bestDeals.isNotEmpty) ...[
          const SizedBox(height: 12),
          SectionCard(
            title: context.strings.bestDeals,
            footnote: context.strings.activeListingsWithRiskBelow50OrderedBy,
            children: [
              for (final d in summary.bestDeals)
                _DealTile(
                  deal: d,
                  subtitle: bestDealText(d, language: context.language),
                ),
            ],
          ),
        ],
        if (summary.biggestDrops.isNotEmpty) ...[
          const SizedBox(height: 12),
          SectionCard(
            title: context.strings.largestDrops,
            children: [
              for (final d in summary.biggestDrops)
                _DealTile(
                  deal: d,
                  subtitle: priceDropText(d, language: context.language),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class const _DealTile({
  required final SummaryDeal deal,
  required final String subtitle,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(summaryDealTitle(deal)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push(AppRoutes.listingDetail(deal.listingId)),
    );
  }
}
