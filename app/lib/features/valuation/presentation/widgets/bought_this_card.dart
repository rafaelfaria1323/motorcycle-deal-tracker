import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/di/injection.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../core/auth/session_cubit.dart';
import '../../../../core/localization/localizations.dart';
import '../../../../core/widgets/section_card.dart';
import '../../../../core/widgets/show_message.dart';
import '../../../listings/domain/entities/listing.dart';
import '../../domain/entities/owned_bike.dart';
import '../cubit/owned_bikes_cubit.dart';
import 'owned_bike_form.dart';

/// "Comprei esta" on the ad's Negociar (N.67): keeps the bike in "A minha
/// mota" with what was paid; once kept, opens that page. Only for an
/// account and an ad of a catalog model (the value needs the model).
class const BoughtThisCard({required final Listing listing, super.key})
    extends StatelessWidget {
  Future<void> _buy(BuildContext context) async {
    final strings = context.strings;
    final messenger = ScaffoldMessenger.of(context);
    final id = listing.motorcycleId!;
    final asking = listing.askingPrice;
    final now = DateTime.now();
    final bike = await showOwnedBikeForm(
      context,
      model: (id: id, name: '${listing.brand} ${listing.model}'),
      listingId: listing.id,
      initial: OwnedBikeDraft(
        motorcycleId: id,
        listingId: listing.id,
        year: listing.year ?? now.year,
        pricePaid: asking?.round(),
        mileageAtPurchase: listing.mileage,
        boughtOn: DateTime(now.year, now.month, now.day),
      ),
    );
    if (bike == null) return;
    final saved = await getIt<OwnedBikesCubit>().add(bike);
    showMessage(
      messenger,
      saved ? strings.myBikeSaved : strings.couldNotSaveTryAgain,
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = getIt<SessionCubit>().state;
    if (!session.signedIn || listing.motorcycleId == null) {
      return const SizedBox.shrink();
    }
    final cubit = getIt<OwnedBikesCubit>();
    if (cubit.state.status == .initial) cubit.load();
    return BlocBuilder<OwnedBikesCubit, OwnedBikesState>(
      bloc: cubit,
      builder: (context, state) {
        final kept = state.boughtFrom(listing.id);
        // Laid out as the cards above it (title, text, button under it):
        // a list tile squeezed the text between the icon and the button.
        return SectionCard(
          title: kept == null
              ? context.strings.boughtThis
              : context.strings.boughtThisKept,
          children: [
            Text(
              kept == null
                  ? context.strings.boughtThisHint
                  : context.strings.boughtThisKeptHint,
            ),
            const SizedBox(height: 12),
            if (kept == null)
              FilledButton.tonalIcon(
                onPressed: () => _buy(context),
                icon: const Icon(Icons.key_outlined),
                label: Text(context.strings.boughtThisAction),
              )
            else
              FilledButton.tonalIcon(
                onPressed: () => context.push(AppRoutes.myBike),
                icon: const Icon(Icons.key),
                label: Text(context.strings.myBike),
              ),
          ],
        );
      },
    );
  }
}
