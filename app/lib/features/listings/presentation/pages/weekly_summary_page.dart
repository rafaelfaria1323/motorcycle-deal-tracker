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

/// "Resumo da semana" (from Mais, or a tap on the Monday notification):
/// the account's latest weekly summary, each listing opening its page, and
/// asking for a new one now.
class WeeklySummaryPage extends StatefulWidget {
  const WeeklySummaryPage({super.key});

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
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _asking = true);
    final message = await startWorkflow(AppWorkflow.weeklySummary);
    if (!mounted) return;
    setState(() => _asking = false);
    showMessage(messenger, message);
  }

  @override
  Widget build(BuildContext context) {
    final ask = workflowText(AppWorkflow.weeklySummary);
    return Scaffold(
      appBar: AppBar(
        leading: const PageBackButton(),
        title: const Text('Resumo da semana'),
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
            return const StateMessage(
              icon: Icons.lock_outline,
              title: 'Disponível com sessão iniciada',
              message:
                  'O resumo é feito com os modelos que a sua conta '
                  'acompanha.',
            );
          }
          if (snapshot.hasError) {
            return StateMessage(
              icon: Icons.cloud_off,
              title: 'Não foi possível carregar o resumo',
              actionLabel: 'Tentar novamente',
              onAction: () => unawaited(_reload()),
            );
          }
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final summary = snapshot.data;
          if (summary == null) {
            return StateMessage(
              icon: Icons.summarize_outlined,
              title: 'Ainda sem resumo',
              message:
                  'O primeiro chega na segunda-feira de manhã. Pode '
                  'pedir um já.',
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

class _SummaryView extends StatelessWidget {
  const _SummaryView({required this.summary});

  final WeeklySummary summary;

  @override
  Widget build(BuildContext context) {
    final byModel = newByModelText(summary);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SectionCard(
          title: summaryPeriodText(summary),
          footnote: summaryMadeText(summary),
          children: [
            for (final line in summaryCountLines(summary)) BulletLine(line),
            if (byModel != null) BulletLine('Novos: $byModel'),
          ],
        ),
        if (summary.bestDeals.isNotEmpty) ...[
          const SizedBox(height: 12),
          SectionCard(
            title: 'Melhores negócios',
            footnote:
                'Anúncios ativos com risco abaixo de 50, pela '
                'Pontuação.',
            children: [
              for (final d in summary.bestDeals)
                _DealTile(deal: d, subtitle: bestDealText(d)),
            ],
          ),
        ],
        if (summary.biggestDrops.isNotEmpty) ...[
          const SizedBox(height: 12),
          SectionCard(
            title: 'Maiores baixas',
            children: [
              for (final d in summary.biggestDrops)
                _DealTile(deal: d, subtitle: priceDropText(d)),
            ],
          ),
        ],
      ],
    );
  }
}

class _DealTile extends StatelessWidget {
  const _DealTile({required this.deal, required this.subtitle});

  final SummaryDeal deal;
  final String subtitle;

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
