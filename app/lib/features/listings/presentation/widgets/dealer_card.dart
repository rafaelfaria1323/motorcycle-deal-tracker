import 'package:flutter/material.dart';

import '../../../../app/di/injection.dart';
import '../../../../core/widgets/section_card.dart';
import '../../domain/entities/dealer_reliability.dart';
import '../../domain/entities/listing.dart';
import '../../domain/repositories/dealer_repository.dart';
import '../dealer_text.dart';

/// "O stand": what we have seen of the dealer's ads on both sites. Only for
/// dealers (private sellers' names are never stored); hidden while loading
/// or on any error.
class DealerCard extends StatefulWidget {
  const DealerCard({required this.listing, super.key});

  final Listing listing;

  @override
  State<DealerCard> createState() => _DealerCardState();
}

class _DealerCardState extends State<DealerCard> {
  Future<DealerReliability?>? _future;

  @override
  void initState() {
    super.initState();
    final name = widget.listing.sellerName?.trim();
    if (widget.listing.sellerType == SellerType.dealer &&
        name != null &&
        name.isNotEmpty) {
      _future = getIt<DealerRepository>()
          .getByName(name)
          .catchError((Object _) => null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final future = _future;
    if (future == null) return const SizedBox.shrink();

    return FutureBuilder<DealerReliability?>(
      future: future,
      builder: (context, snapshot) {
        final dealer = snapshot.data;
        if (dealer == null) return const SizedBox.shrink();

        return SectionCard(
          title: 'O stand',
          footnote:
              'Dos anúncios deste stand que acompanhamos (só dos modelos '
              'seguidos), nos dois sites.',
          children: [
            Text(dealerHeadline(dealer)),
            const SizedBox(height: 8),
            for (final line in dealerLines(dealer)) BulletLine(line),
          ],
        );
      },
    );
  }
}
