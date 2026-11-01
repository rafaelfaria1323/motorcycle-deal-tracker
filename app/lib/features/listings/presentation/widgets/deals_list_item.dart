import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/di/injection.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../core/localization/localizations.dart';
import '../../../../core/widgets/show_message.dart';
import '../../../compare/presentation/compare_text.dart';
import '../../../compare/presentation/cubit/compare_cubit.dart';
import '../../../favourites/presentation/cubit/favourites_cubit.dart';
import '../../../favourites/presentation/cubit/favourites_state.dart';
import '../../domain/entities/listing.dart';
import '../../domain/entities/listing_card_preferences.dart';
import 'listing_card.dart';

/// One ad of Ofertas: its card with the star and the comparison pick,
/// each rebuilt only when this ad's own changes. A tap opens the ad, a
/// long press adds it to the comparison.
class const DealsListItem({
  required final Listing listing,
  required final ListingCardPreferences preferences,
  super.key,
}) extends StatelessWidget {
  void _toggleCompare(BuildContext context, String id) {
    if (!getIt<CompareCubit>().toggle(id)) {
      final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
      showMessage(
        messenger,
        context.strings.compareFull(maxCompared: (maxCompared).toString()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FavouritesCubit, FavouritesState>(
      bloc: getIt<FavouritesCubit>(),
      buildWhen: (previous, current) =>
          previous.isFavourite(listing.id) != current.isFavourite(listing.id),
      builder: (context, favourites) =>
          // Only this card's pick: another card's doesn't rebuild it.
          BlocSelector<CompareCubit, List<String>, bool>(
            bloc: getIt<CompareCubit>(),
            selector: (compared) => compared.contains(listing.id),
            builder: (context, selected) => ListingCard(
              listing: listing,
              preferences: preferences,
              selected: selected,
              favourite: favourites.isFavourite(listing.id),
              onTap: () => context.push(
                AppRoutes.listingDetail(listing.id),
                extra: AppRoutes.fromList,
              ),
              onLongPress: () => _toggleCompare(context, listing.id),
            ),
          ),
    );
  }
}
