import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/formatting/formatters.dart';
import '../../domain/entities/listing.dart';
import '../cubit/listing_detail_cubit.dart';
import '../cubit/listing_detail_state.dart';
import '../listing_labels.dart';
import '../widgets/deal_score_badge.dart';
import '../widgets/listing_photo.dart';

class ListingDetailPage extends StatelessWidget {
  const ListingDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // Falls back to the dashboard when opened directly from a URL.
        leading: BackButton(onPressed: () => context.canPop() ? context.pop() : context.go(AppRoutes.deals)),
        title: const Text('Detalhe'),
      ),
      body: BlocBuilder<ListingDetailCubit, ListingDetailState>(
        builder: (context, state) {
          switch (state.status) {
            case ListingDetailStatus.loading:
              return const Center(child: CircularProgressIndicator());
            case ListingDetailStatus.notFound:
              return const Center(child: Text('Anúncio não encontrado'));
            case ListingDetailStatus.failure:
              return const Center(child: Text('Erro ao carregar anúncio'));
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
    final canOpen = uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
    final opened = canOpen && await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Não foi possível abrir o anúncio')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final description = listing.description;

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: ListingPhoto(url: listing.images.isEmpty ? null : listing.images.first),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: Text('${listing.brand} ${listing.model}', style: textTheme.headlineSmall)),
                if (listing.dealScore != null) DealScoreBadge(score: listing.dealScore!),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              Formatters.price(listing.price),
              style: textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: [
                    _FactRow('Ano', listing.year?.toString() ?? '—'),
                    _FactRow('Quilometragem', Formatters.mileage(listing.mileage)),
                    _FactRow('Localização', listing.location ?? '—'),
                    _FactRow('Vendedor', listing.sellerName ?? '—'),
                    _FactRow('Tipo de vendedor', listing.sellerType.label),
                    _FactRow('Fonte', listing.source),
                    _FactRow('Estado', listing.status.label),
                    _FactRow(
                      'Visto pela 1.ª vez',
                      '${Formatters.date(listing.firstSeenAt)}'
                          ' (${Formatters.daysAgo(listing.firstSeenAt)})',
                    ),
                    _FactRow('Última vez visto', Formatters.date(listing.lastSeenAt)),
                  ],
                ),
              ),
            ),
            if (description != null && description.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Descrição', style: textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(description, style: textTheme.bodyMedium),
            ],
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => _openOriginal(context),
              icon: const Icon(Icons.open_in_new),
              label: const Text('Ver anúncio original'),
            ),
          ],
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
              style: textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Text(value, textAlign: TextAlign.end, style: textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
