import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/di/injection.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../core/formatting/formatters.dart';
import '../../../../core/widgets/state_message.dart';
import '../../domain/entities/listing.dart';
import '../compare_text.dart';
import '../cubit/compare_cubit.dart';
import '../cubit/listing_detail_cubit.dart';
import '../cubit/listing_detail_state.dart';
import '../listing_dates_text.dart';
import '../listing_detail_text.dart';
import '../listing_labels.dart';
import '../widgets/also_listed_section.dart';
import '../widgets/deal_score_badge.dart';
import '../widgets/market_behaviour_section.dart';
import '../widgets/new_price_card.dart';
import '../widgets/photo_gallery.dart';
import '../widgets/price_change_tag.dart';
import '../widgets/price_history_section.dart';
import '../widgets/score_explanation_card.dart';

class ListingDetailPage extends StatelessWidget {
  const ListingDetailPage({required this.listingId, super.key});

  final String listingId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          onPressed: () =>
              context.canPop() ? context.pop() : context.go(AppRoutes.deals),
        ),
        title: const Text('Detalhe'),
        actions: [_CompareButton(listingId: listingId)],
      ),
      body: BlocBuilder<ListingDetailCubit, ListingDetailState>(
        builder: (context, state) {
          switch (state.status) {
            case ListingDetailStatus.loading:
              return const Center(child: CircularProgressIndicator());
            case ListingDetailStatus.notFound:
              return StateMessage(
                icon: Icons.search_off,
                title: 'Anúncio não encontrado',
                message: 'Pode ter sido removido ou o link está incorreto.',
                actionLabel: 'Ver ofertas',
                onAction: () => context.go(AppRoutes.deals),
              );
            case ListingDetailStatus.failure:
              return StateMessage(
                icon: Icons.cloud_off,
                title: 'Não foi possível carregar o anúncio',
                message: 'Verifique a ligação e tente novamente.',
                actionLabel: 'Tentar novamente',
                onAction: () =>
                    context.read<ListingDetailCubit>().load(listingId),
              );
            case ListingDetailStatus.success:
              return _Content(listing: state.listing!);
          }
        },
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.listing});

  final Listing listing;

  Future<void> _openOriginal(BuildContext context) async {
    final uri = Uri.tryParse(listing.url);
    // Only open web links, since the URL comes from an external source.
    final canOpen =
        uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
    final opened =
        canOpen && await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir o anúncio')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final description = listing.description;
    final lastSeenAt = listing.lastSeenAt;

    // Ordered by what matters for a decision: the bike and its price, the
    // score and its risks, then the facts, the seller's text, the market
    // and the history.
    return Column(
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  PhotoGallery(images: listing.images),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${listing.brand} ${listing.model}',
                          style: textTheme.headlineSmall,
                        ),
                      ),
                      if (listing.dealScore != null)
                        DealScoreBadge(score: listing.dealScore!),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        Formatters.price(listing.price),
                        style: textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      PriceChangeTag(listing: listing),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    keyFactsLine(listing),
                    style: textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (listing.isRemoved)
                    Card(
                      color: theme.colorScheme.errorContainer,
                      child: ListTile(
                        leading: const Icon(Icons.block),
                        title: const Text('Anúncio removido'),
                        subtitle: Text(
                          lastSeenAt == null
                              ? 'Este anúncio já não está disponível.'
                              : 'Este anúncio já não está disponível. '
                                    'Visto pela última vez ${Formatters.daysAgo(lastSeenAt)}.',
                        ),
                      ),
                    ),
                  if (listing.duplicateOf != null)
                    Card(
                      color: theme.colorScheme.secondaryContainer,
                      child: ListTile(
                        leading: const Icon(Icons.content_copy),
                        title: const Text('Anúncio repetido'),
                        subtitle: const Text(
                          'Este anúncio parece ser a mesma mota de outro anúncio. '
                          'Não conta para o mercado nem tem pontuação.',
                        ),
                        trailing: TextButton(
                          onPressed: () =>
                              context.go('/deals/${listing.duplicateOf}'),
                          child: const Text('Ver original'),
                        ),
                      ),
                    ),
                  if (relistText(listing) case final relist?)
                    Card(
                      color: theme.colorScheme.secondaryContainer,
                      child: ListTile(
                        leading: const Icon(Icons.history),
                        title: const Text('Anúncio publicado de novo'),
                        subtitle: Text(relist),
                        trailing: TextButton(
                          onPressed: () =>
                              context.go('/deals/${listing.relistedFrom}'),
                          child: const Text('Ver anterior'),
                        ),
                      ),
                    ),
                  ScoreExplanationCard(listing: listing),
                  AlsoListedSection(listing: listing),
                  NewPriceCard(listing: listing),
                  _FactsCard(
                    title: 'A mota',
                    rows: [
                      _FactRow('Ano', listing.year?.toString() ?? '—'),
                      _FactRow(
                        'Quilometragem',
                        Formatters.mileage(listing.mileage),
                      ),
                      if (listing.registrations != null)
                        _FactRow(
                          'Registos (donos)',
                          '${listing.registrations}',
                        ),
                      if (listing.serviceBook != null)
                        _FactRow(
                          'Livro de revisões',
                          listing.serviceBook! ? 'Completo' : 'Não',
                        ),
                      if (listing.origin != null)
                        _FactRow(
                          'Origem',
                          listing.origin == 'national'
                              ? 'Nacional'
                              : 'Importada',
                        ),
                      if (listing.warrantyUntil != null)
                        _FactRow(
                          'Garantia de fábrica até',
                          Formatters.date(listing.warrantyUntil!),
                        ),
                      if (listing.dealerWarrantyMonths != null)
                        _FactRow(
                          'Garantia do vendedor',
                          '${listing.dealerWarrantyMonths} meses',
                        ),
                    ],
                  ),
                  if (description != null && description.isNotEmpty)
                    _DescriptionCard(description: description),
                  MarketBehaviourSection(listing: listing),
                  PriceHistorySection(listing: listing),
                  _FactsCard(
                    title: 'O anúncio',
                    rows: [
                      _FactRow('Localização', listing.location ?? '—'),
                      _FactRow('Vendedor', listing.sellerName ?? '—'),
                      _FactRow('Tipo de vendedor', listing.sellerType.label),
                      _FactRow('Fonte', sourceLabel(listing.source)),
                      if (listing.publishedAt != null)
                        _FactRow(
                          'Publicado',
                          dateWithAge(listing.publishedAt!),
                        ),
                      if (renewalToShow(listing) case final renewed?)
                        _FactRow('Renovado no site', dateWithAge(renewed)),
                      _FactRow('Estado', listing.status.label),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        // Always in reach: the next step after reading is the seller's ad.
        // The tab bar's colour, which Safari's bottom toolbar is tinted with.
        Material(
          color: theme.colorScheme.surfaceContainerLowest,
          elevation: 3,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Center(
                heightFactor: 1,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 768),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => _openOriginal(context),
                      icon: const Icon(Icons.open_in_new),
                      label: Text(originalLinkLabel(listing.source)),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FactsCard extends StatelessWidget {
  const _FactsCard({required this.title, required this.rows});

  final String title;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            ...rows,
          ],
        ),
      ),
    );
  }
}

/// The seller's text, folded after a few lines: it is often long.
class _DescriptionCard extends StatefulWidget {
  const _DescriptionCard({required this.description});

  final String description;

  @override
  State<_DescriptionCard> createState() => _DescriptionCardState();
}

class _DescriptionCardState extends State<_DescriptionCard> {
  static const _foldedLines = 8;
  var _expanded = false;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final style = textTheme.bodyMedium;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final painter = TextPainter(
              text: TextSpan(text: widget.description, style: style),
              maxLines: _foldedLines,
              textDirection: Directionality.of(context),
              textScaler: MediaQuery.textScalerOf(context),
            )..layout(maxWidth: constraints.maxWidth);
            final foldable = painter.didExceedMaxLines;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Descrição', style: textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(
                  widget.description,
                  style: style,
                  maxLines: _expanded || !foldable ? null : _foldedLines,
                  overflow: _expanded || !foldable
                      ? null
                      : TextOverflow.ellipsis,
                ),
                if (foldable)
                  TextButton(
                    onPressed: () => setState(() => _expanded = !_expanded),
                    child: Text(_expanded ? 'Mostrar menos' : 'Mostrar tudo'),
                  )
                else
                  const SizedBox(height: 8),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _FactRow extends StatelessWidget {
  const _FactRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

/// Adds the listing to the comparison or takes it out; offers to open the
/// comparison once there are two or more.
class _CompareButton extends StatelessWidget {
  const _CompareButton({required this.listingId});

  final String listingId;

  @override
  Widget build(BuildContext context) {
    final cubit = getIt<CompareCubit>();
    return BlocBuilder<CompareCubit, List<String>>(
      bloc: cubit,
      builder: (context, compared) {
        final added = compared.contains(listingId);
        return IconButton(
          tooltip: added ? 'Retirar da comparação' : 'Comparar',
          isSelected: added,
          icon: const Icon(Icons.compare_arrows),
          onPressed: () {
            final messenger = ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar();
            if (!cubit.toggle(listingId)) {
              messenger.showSnackBar(
                const SnackBar(
                  content: Text(
                    'Já tem $maxCompared anúncios na comparação. '
                    'Retire um primeiro.',
                  ),
                ),
              );
              return;
            }
            final now = cubit.state;
            if (added) {
              messenger.showSnackBar(
                const SnackBar(content: Text('Retirado da comparação.')),
              );
            } else if (now.length < 2) {
              messenger.showSnackBar(
                const SnackBar(
                  content: Text(
                    'Na comparação. Escolha outro anúncio para comparar.',
                  ),
                ),
              );
            } else {
              messenger.showSnackBar(
                SnackBar(
                  content: Text('Na comparação (${now.length}).'),
                  action: SnackBarAction(
                    label: 'Comparar',
                    onPressed: () => context.push(AppRoutes.compare(now)),
                  ),
                ),
              );
            }
          },
        );
      },
    );
  }
}
