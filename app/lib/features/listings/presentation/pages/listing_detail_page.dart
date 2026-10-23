import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/di/injection.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../core/formatting/formatters.dart';
import '../../../../core/widgets/page_back_button.dart';
import '../../../../core/widgets/section_card.dart';
import '../../../../core/widgets/show_message.dart';
import '../../../../core/widgets/state_message.dart';
import '../../domain/entities/listing.dart';
import '../compare_text.dart';
import '../cubit/compare_cubit.dart';
import '../cubit/listing_detail_cubit.dart';
import '../cubit/listing_detail_state.dart';
import '../listing_dates_text.dart';
import '../listing_detail_text.dart';
import '../listing_labels.dart';
import '../score_explanation.dart';
import '../widgets/also_listed_section.dart';
import '../widgets/deal_score_badge.dart';
import '../widgets/dealer_card.dart';
import '../widgets/facts_card.dart';
import '../widgets/favourite_widgets.dart';
import '../widgets/market_behaviour_section.dart';
import '../widgets/new_price_card.dart';
import '../widgets/offer_card.dart';
import '../widgets/ownership_cost_card.dart';
import '../widgets/photo_gallery.dart';
import '../widgets/price_change_tag.dart';
import '../widgets/price_history_section.dart';
import '../widgets/score_explanation_card.dart';
import '../widgets/seller_message_card.dart';
import '../widgets/viewing_checklist_card.dart';

class ListingDetailPage extends StatelessWidget {
  const ListingDetailPage({required this.listingId, super.key});

  final String listingId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          onPressed: () => goBack(context, fallback: AppRoutes.deals),
        ),
        title: const Text('O anúncio'),
        actions: [
          // The star needs the listing (the favourites page shows it).
          BlocBuilder<ListingDetailCubit, ListingDetailState>(
            builder: (context, state) => state.listing == null
                ? const SizedBox.shrink()
                : FavouriteButton(listing: state.listing!),
          ),
          _CompareButton(listingId: listingId),
        ],
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

/// The four parts of the page, picked at the top so the page stays short:
/// the verdict, the ad's own details, the market and negotiating.
enum _Section {
  verdict('Avaliação'),
  details('Detalhes'),
  market('Mercado'),
  negotiate('Negociar');

  const _Section(this.label);

  final String label;
}

class _Content extends StatefulWidget {
  const _Content({required this.listing});

  final Listing listing;

  @override
  State<_Content> createState() => _ContentState();
}

class _ContentState extends State<_Content> {
  // Kept while the app runs, so going from one listing to the next opens
  // the part that was being compared.
  static var _lastSection = _Section.verdict;

  var _section = _lastSection;
  // Parts are built when first opened and then kept (offstage), so a
  // counter-offer being typed or a loaded chart survives switching.
  final _opened = {_lastSection};

  Listing get listing => widget.listing;

  void _select(_Section section) => setState(() {
    _section = section;
    _lastSection = section;
    _opened.add(section);
  });

  Future<void> _openOriginal(BuildContext context) async {
    final uri = Uri.tryParse(listing.url);
    // Only open web links, since the URL comes from an external source.
    final canOpen =
        uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
    final opened =
        canOpen && await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!opened && context.mounted) {
      showMessage(
        ScaffoldMessenger.of(context),
        'Não foi possível abrir o anúncio',
      );
    }
  }

  List<Widget> _cards(_Section section) {
    final description = listing.description;
    return switch (section) {
      _Section.verdict => [
        if (listing.dealScore == null)
          const SectionCard(
            title: 'Porquê esta pontuação',
            children: [Text('Este anúncio ainda não tem pontuação.')],
          )
        else
          ScoreExplanationCard(listing: listing),
        AlsoListedSection(listing: listing),
        DealerCard(listing: listing),
      ],
      _Section.negotiate => [
        OfferCard(listing: listing),
        SellerMessageCard(listing: listing),
        ViewingChecklistCard(listingId: listing.id),
      ],
      _Section.market => [
        MarketBehaviourSection(listing: listing),
        PriceHistorySection(listing: listing),
        NewPriceCard(listing: listing),
        OwnershipCostCard(listing: listing),
      ],
      _Section.details => [
        FactsCard(title: 'A mota', facts: bikeFacts(listing)),
        if (description != null && description.isNotEmpty)
          _DescriptionCard(description: description),
        FactsCard(title: 'O anúncio', facts: adFacts(listing)),
      ],
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1040),
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final photo = PhotoGallery(
                        listingId: listing.id,
                        images: listing.images,
                      );
                      final summary = Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _Header(listing: listing),
                          const SizedBox(height: 16),
                          ..._statusCards(context),
                          FavouriteNoteCard(listingId: listing.id),
                        ],
                      );
                      if (constraints.maxWidth >= 800) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 5, child: photo),
                            const SizedBox(width: 28),
                            Expanded(flex: 4, child: summary),
                          ],
                        );
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [photo, const SizedBox(height: 24), summary],
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  DefaultTabController(
                    length: _Section.values.length,
                    initialIndex: _section.index,
                    child: TabBar(
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      tabs: [
                        for (final section in _Section.values)
                          Tab(text: section.label),
                      ],
                      onTap: (index) => _select(_Section.values[index]),
                    ),
                  ),
                  const SizedBox(height: 20),
                  for (final section in _Section.values)
                    if (_opened.contains(section))
                      Offstage(
                        offstage: section != _section,
                        child: TickerMode(
                          enabled: section == _section,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: _cards(section),
                          ),
                        ),
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
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: theme.colorScheme.outlineVariant),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                child: Center(
                  heightFactor: 1,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1000),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final button = FilledButton.icon(
                          onPressed: () => _openOriginal(context),
                          icon: const Icon(Icons.open_in_new),
                          label: Text(originalLinkLabel(listing.source)),
                        );
                        if (constraints.maxWidth < 600) {
                          return SizedBox(
                            width: double.infinity,
                            child: button,
                          );
                        }
                        return Row(
                          children: [
                            Expanded(
                              child: Text(
                                Formatters.price(listing.price),
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                            ),
                            button,
                          ],
                        );
                      },
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

  /// Removed, duplicate, relisted: shown before anything else, since they
  /// change how the rest reads.
  List<Widget> _statusCards(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final lastSeenAt = listing.lastSeenAt;
    final duplicateOf = listing.duplicateOf;
    return [
      if (listing.isRemoved)
        _StatusCard(
          color: scheme.errorContainer,
          icon: Icons.block,
          title: 'Anúncio removido',
          text: lastSeenAt == null
              ? 'Este anúncio já não está disponível.'
              : 'Este anúncio já não está disponível. '
                    'Visto pela última vez ${Formatters.daysAgo(lastSeenAt)}.',
        ),
      if (duplicateOf != null)
        _StatusCard(
          color: scheme.secondaryContainer,
          icon: Icons.content_copy,
          title: 'Anúncio duplicado',
          text:
              'Parece ser a mesma mota de outro anúncio. '
              'Não conta para o mercado nem tem pontuação.',
          actionLabel: 'Ver original',
          onAction: () => context.push(AppRoutes.listingDetail(duplicateOf)),
        ),
      if (relistText(listing) case final relist?)
        _StatusCard(
          color: scheme.secondaryContainer,
          icon: Icons.history,
          title: 'Anúncio publicado de novo',
          text: relist,
          actionLabel: 'Ver anterior',
          onAction: () =>
              context.push(AppRoutes.listingDetail(listing.relistedFrom!)),
        ),
    ];
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.listing});

  final Listing listing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final score = listing.dealScore;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          sourceLabel(listing.source).toUpperCase(),
          style: textTheme.labelSmall?.copyWith(
            letterSpacing: 1.5,
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${listing.brand} ${listing.model}',
          style: textTheme.headlineLarge?.copyWith(height: 1.05),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              Formatters.price(listing.price),
              style: textTheme.displaySmall?.copyWith(
                fontSize: 42,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            PriceChangeTag(listing: listing),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          keyFactsLine(listing),
          style: textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (score != null) ...[
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Row(
              children: [
                DealScoreBadge(score: score, large: true),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ScoreExplainer.label(score),
                        style: textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Deal Score · 0 a 100',
                        style: textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.color,
    required this.icon,
    required this.title,
    required this.text,
    this.actionLabel,
    this.onAction,
  });

  final Color color;
  final IconData icon;
  final String title;
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final actionLabel = this.actionLabel;
    return Card(
      color: color,
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(text),
        trailing: actionLabel == null
            ? null
            : TextButton(onPressed: onAction, child: Text(actionLabel)),
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
    final style = Theme.of(context).textTheme.bodyMedium;

    return SectionCard(
      title: 'Descrição',
      children: [
        LayoutBuilder(
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
                  ),
              ],
            );
          },
        ),
      ],
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
              showMessage(
                messenger,
                'Já tem $maxCompared anúncios na comparação. '
                'Retire um primeiro.',
              );
              return;
            }
            final now = cubit.state;
            if (added) {
              showMessage(messenger, 'Retirado da comparação');
            } else if (now.length < 2) {
              showMessage(
                messenger,
                'Na comparação. Escolha outro anúncio para comparar.',
              );
            } else {
              messenger.showSnackBar(
                SnackBar(
                  content: Text('Na comparação (${now.length})'),
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
