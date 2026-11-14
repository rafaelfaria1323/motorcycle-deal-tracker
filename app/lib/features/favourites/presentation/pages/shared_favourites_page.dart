import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/di/injection.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../core/localization/localizations.dart';
import '../../../../core/widgets/page_back_button.dart';
import '../../../../core/widgets/show_message.dart';
import '../../../../core/widgets/state_message.dart';
import '../../../listings/presentation/cubit/listing_card_preferences_cubit.dart';
import '../../../listings/presentation/widgets/deals_list_item.dart';
import '../../domain/entities/favourite.dart';
import '../../domain/repositories/favourite_shares_repository.dart';
import '../widgets/favourite_sharing.dart';
import '../widgets/favourite_widgets.dart';

/// Another account's favourites, read only (16.11,
/// `/shared-favourites?owner=…`, pushed): each ad with its owner's note,
/// visit and checklist. The star on a card is this account's own, as on
/// every list of ads; "Deixar de ver" stops seeing the list.
class const SharedFavouritesPage({required final String ownerId, super.key})
    extends StatefulWidget {
  @override
  State<SharedFavouritesPage> createState() => _SharedFavouritesPageState();
}

typedef _SharedData = ({String? ownerEmail, List<Favourite> favourites});

class _SharedFavouritesPageState extends State<SharedFavouritesPage> {
  final _repository = getIt<FavouriteSharesRepository>();
  late Future<_SharedData> _future = _load();

  Future<_SharedData> _load() async {
    final (lists, favourites) = await (
      _repository.sharedWithMe(),
      _repository.favouritesOf(widget.ownerId),
    ).wait;
    final owner = lists.where((list) => list.ownerId == widget.ownerId);
    return (
      ownerEmail: owner.isEmpty ? null : owner.first.ownerEmail,
      favourites: [
        for (final f in favourites)
          if (f.listing != null) f,
      ],
    );
  }

  Future<void> _leave() async {
    final messenger = ScaffoldMessenger.of(context);
    final failed = context.strings.couldNotShareFavourites;
    try {
      await _repository.leave(widget.ownerId);
    } catch (_) {
      showMessage(messenger, failed);
      return;
    }
    if (mounted) goBack(context, fallback: AppRoutes.favourites);
  }

  Widget _body(BuildContext context, AsyncSnapshot<_SharedData> snapshot) {
    if (snapshot.hasError) {
      return StateMessage(
        icon: Icons.cloud_off,
        title: context.strings.couldNotLoadSharedList,
        message: context.strings.checkYourConnectionAndTryAgain,
        actionLabel: context.strings.retry,
        onAction: () => setState(() => _future = _load()),
      );
    }
    final data = snapshot.data;
    if (data == null) return const Center(child: CircularProgressIndicator());
    if (data.ownerEmail == null) {
      return StateMessage(
        icon: Icons.link_off,
        title: context.strings.sharedListUnavailable,
      );
    }
    if (data.favourites.isEmpty) {
      return StateMessage(
        icon: Icons.star_border,
        title: context.strings.sharedListEmpty,
      );
    }
    return _SharedList(favourites: data.favourites);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<_SharedData>(
    future: _future,
    builder: (context, snapshot) {
      final data = snapshot.data;
      final email = data?.ownerEmail;
      return Scaffold(
        appBar: AppBar(
          leading: const PageBackButton(fallback: AppRoutes.favourites),
          title: Text(
            email == null
                ? context.strings.sharedListTitle
                : context.strings.favouritesListOf(email: email),
          ),
          actions: [
            if (data != null && email != null) ...[
              if (data.favourites.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.table_view_outlined),
                  tooltip: context.strings.exportFavouritesCsv,
                  onPressed: () =>
                      exportFavouritesCsv(context, data.favourites),
                ),
              TextButton(
                onPressed: _leave,
                child: Text(context.strings.leaveSharedList),
              ),
            ],
          ],
        ),
        body: _body(context, snapshot),
      );
    },
  );
}

class const _SharedList({required final List<Favourite> favourites})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) => BlocBuilder<
    ListingCardPreferencesCubit,
    ListingCardPreferencesState
  >(
    bloc: getIt<ListingCardPreferencesCubit>(),
    builder: (context, cards) => Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final f in favourites) ...[
              DealsListItem(listing: f.listing!, preferences: cards.preferences),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 4, 24),
                child: FavouriteFacts(favourite: f),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
