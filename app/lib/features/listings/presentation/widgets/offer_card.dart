import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/di/injection.dart';
import '../../../../core/formatting/formatters.dart';
import '../../../../core/widgets/section_card.dart';
import '../../../../core/widgets/show_message.dart';
import '../../domain/entities/favourite.dart';
import '../../domain/entities/listing.dart';
import '../../domain/entities/market_behaviour.dart';
import '../../domain/repositories/listings_repository.dart';
import '../../domain/repositories/market_behaviour_repository.dart';
import '../cubit/favourites_cubit.dart';
import '../cubit/favourites_state.dart';
import '../negotiation_text.dart';
import '../offer_text.dart';

/// "Quanto oferecer": the offers to make in turn (each with its message),
/// what to say to justify them, what to answer to the seller's
/// counter-offer, and, for a favourite, the price to be alerted at. After
/// the visit, the problems marked in the checklist come off the offer.
/// Hidden when the listing has no estimated value.
class OfferCard extends StatefulWidget {
  const OfferCard({required this.listing, super.key});

  final Listing listing;

  @override
  State<OfferCard> createState() => _OfferCardState();
}

class _OfferCardState extends State<OfferCard> {
  late final Future<(MarketBehaviour?, List<Listing>)> _data = _load();
  final _counter = TextEditingController();
  var _showReasons = false;

  @override
  void dispose() {
    _counter.dispose();
    super.dispose();
  }

  Future<(MarketBehaviour?, List<Listing>)> _load() async {
    final listing = widget.listing;
    final id = listing.motorcycleId;
    // The suggestion and the arguments still work without either.
    final market = id == null
        ? Future<MarketBehaviour?>.value()
        : getIt<MarketBehaviourRepository>()
              .getForModel(id)
              .then<MarketBehaviour?>((m) => m, onError: (Object _) => null);
    final cheaper = getIt<ListingsRepository>()
        .getCheaperSimilar(listing)
        .then((l) => l, onError: (Object _) => const <Listing>[]);
    return (await market, await cheaper);
  }

  Future<void> _copy(String text) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await Clipboard.setData(ClipboardData(text: text));
      showMessage(messenger, 'Mensagem copiada');
    } catch (_) {
      showMessage(messenger, 'Não foi possível copiar. Selecione o texto.');
    }
  }

  Future<void> _editTarget(Favourite favourite, double suggested) async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await showDialog<_TargetResult>(
      context: context,
      builder: (_) => _TargetDialog(
        initial: favourite.targetPrice ?? suggested,
        canClear: favourite.targetPrice != null,
      ),
    );
    if (result == null) return;
    final saved = await getIt<FavouritesCubit>().saveTargetPrice(
      favourite.listingId,
      result.price,
    );
    if (!saved) showMessage(messenger, 'Não foi possível guardar o preço');
  }

  @override
  Widget build(BuildContext context) {
    final listing = widget.listing;
    // Nothing to load for a listing that gets no suggestion anyway.
    if (suggestOffer(listing) == null) return const SizedBox.shrink();

    return FutureBuilder<(MarketBehaviour?, List<Listing>)>(
      future: _data,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox.shrink();
        }
        final (market, cheaper) = snapshot.data ?? (null, const <Listing>[]);
        return BlocBuilder<FavouritesCubit, FavouritesState>(
          bloc: getIt<FavouritesCubit>(),
          builder: (context, favourites) {
            final favourite = favourites.favouriteOf(listing.id);
            final days = daysOnSale(listing);
            final planned = suggestOffer(
              listing,
              market: market,
              daysListed: days,
            );
            if (planned == null) return const SizedBox.shrink();
            final visit = visitFindings(
              favourite?.checklist ?? const {},
              engineCc: listing.engineCc,
            );
            final arguments = negotiationArguments(
              listing,
              market: market,
              daysListed: days,
              cheaper: cheaper,
              visit: visit,
            );
            return _content(
              context,
              afterVisit(planned, visit),
              visit,
              arguments,
              favourite,
              sellerUrgency(listing, market: market, daysListed: days),
            );
          },
        );
      },
    );
  }

  Widget _content(
    BuildContext context,
    OfferSuggestion offer,
    VisitFindings visit,
    List<String> arguments,
    Favourite? favourite,
    SellerUrgency urgency,
  ) {
    final listing = widget.listing;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    final counter = parseCounterOffer(_counter.text);
    final reply = counter == null ? null : offer.reply(counter);
    final target = favourite?.targetPrice;

    return SectionCard(
      title: 'Quanto oferecer',
      footnote:
          'Estimativa a partir dos preços pedidos, não de vendas. '
          'Veja a mota antes de fechar negócio.',
      children: [
        Text(
          offer.headline,
          style: theme.textTheme.titleMedium?.copyWith(color: scheme.primary),
        ),
        const SizedBox(height: 4),
        BulletLine(urgency.text, icon: Icons.speed),
        if (visit.blockers.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Antes de propor: resolva ${visit.blockers.join(', ')}. '
            'Não é uma questão de preço.',
            style: theme.textTheme.bodyMedium?.copyWith(color: scheme.error),
          ),
        ],
        const SizedBox(height: 12),
        for (final (i, step) in offer.steps.indexed)
          _StepRow(
            number: i + 1,
            step: step,
            onCopy: () => _copy(step.message),
          ),
        if (arguments.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Argumentos', style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          for (final argument in arguments)
            BulletLine(argument, icon: Icons.chat_bubble_outline),
        ],
        if (listing.sellerType == SellerType.dealer) ...[
          const SizedBox(height: 16),
          Text('Num stand, peça também', style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          for (final ask in dealerAsks(listing))
            BulletLine(ask, icon: Icons.add_task),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _copy(dealerMessage(listing, offer.opening)),
              icon: const Icon(Icons.copy, size: 18),
              label: const Text('Copiar mensagem para o stand'),
            ),
          ),
        ],
        const SizedBox(height: 16),
        TextField(
          controller: _counter,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'O vendedor pediu',
            suffixText: '€',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: (_) => setState(() {}),
        ),
        if (reply != null) ...[
          const SizedBox(height: 8),
          Text(
            reply.advice,
            style: theme.textTheme.bodyMedium?.copyWith(color: scheme.primary),
          ),
          const SizedBox(height: 8),
          _MessageBox(text: reply.message, onCopy: () => _copy(reply.message)),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => _copy(walkAwayMessage),
              child: const Text('Copiar mensagem para desistir'),
            ),
          ),
        ],
        const SizedBox(height: 8),
        if (favourite == null)
          Text(
            'Junte aos favoritos (estrela) para definir o seu preço e ser '
            'avisado quando o anúncio chegar lá.',
            style: muted,
          )
        else
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            leading: const Icon(Icons.flag_outlined),
            title: Text(
              target == null
                  ? 'O seu preço'
                  : 'O seu preço: ${Formatters.price(target)}',
            ),
            subtitle: Text(
              target == null
                  ? 'Avisamos quando o preço baixar até ao valor que '
                        'escolher.'
                  : 'Avisamos quando o anúncio custar isto ou menos.',
            ),
            trailing: TextButton(
              onPressed: () => _editTarget(favourite, offer.opening),
              child: Text(target == null ? 'Definir' : 'Alterar'),
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () => setState(() => _showReasons = !_showReasons),
            child: Text(
              _showReasons ? 'Esconder o cálculo' : 'Como foi calculado',
            ),
          ),
        ),
        if (_showReasons)
          for (final reason in offer.reasons) BulletLine(reason),
      ],
    );
  }
}

/// "1  Primeira proposta ........ 7 950 €  [copiar]": one offer of the plan.
class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.number,
    required this.step,
    required this.onCopy,
  });

  final int number;
  final OfferStep step;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        CircleAvatar(
          radius: 11,
          backgroundColor: theme.colorScheme.surfaceContainerHighest,
          child: Text('$number', style: theme.textTheme.labelSmall),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(step.label)),
        Text(Formatters.price(step.price), style: theme.textTheme.titleSmall),
        IconButton(
          tooltip: 'Copiar a mensagem',
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.copy, size: 18),
          onPressed: onCopy,
        ),
      ],
    );
  }
}

/// The message to send, with a button to copy it.
class _MessageBox extends StatelessWidget {
  const _MessageBox({required this.text, required this.onCopy});

  final String text;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(child: SelectableText(text)),
          IconButton(
            tooltip: 'Copiar a mensagem',
            icon: const Icon(Icons.copy, size: 18),
            onPressed: onCopy,
          ),
        ],
      ),
    );
  }
}

/// The dialog's answer: a price, or null to clear it.
class _TargetResult {
  const _TargetResult(this.price);

  final double? price;
}

class _TargetDialog extends StatefulWidget {
  const _TargetDialog({required this.initial, required this.canClear});

  final double initial;
  final bool canClear;

  @override
  State<_TargetDialog> createState() => _TargetDialogState();
}

class _TargetDialogState extends State<_TargetDialog> {
  late final _controller = TextEditingController(
    text: widget.initial.round().toString(),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final price = parseCounterOffer(_controller.text);
    return AlertDialog(
      title: const Text('O seu preço'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          labelText: 'Avise-me quando custar até',
          suffixText: '€',
        ),
        onChanged: (_) => setState(() {}),
      ),
      actions: [
        if (widget.canClear)
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(const _TargetResult(null)),
            child: const Text('Remover'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: price == null
              ? null
              : () => Navigator.of(context).pop(_TargetResult(price)),
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
