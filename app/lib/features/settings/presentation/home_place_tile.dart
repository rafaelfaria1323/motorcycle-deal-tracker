import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/di/injection.dart';
import '../../../core/widgets/show_message.dart';
import '../../favourites/presentation/cubit/favourites_cubit.dart';
import '../../listings/presentation/cubit/listings_cubit.dart';
import '../domain/home_repository.dart';
import '../domain/place.dart';
import 'home_place_cubit.dart';
import '../../../core/localization/localizations.dart';

/// Opens the town search and saves the chosen place as the account's
/// home. True once a home was saved. Mais, the sort menu and the filters
/// use it, so the distance can be set where it is missing.
Future<bool> pickHomePlace(BuildContext context) async {
  final messageStrings = context.strings;
  final messenger = ScaffoldMessenger.of(context);
  final place = await showDialog<Place>(
    context: context,
    builder: (_) => const _PlaceSearchDialog(),
  );
  if (place == null) return false;
  try {
    await getIt<HomePlaceCubit>().save(place);
  } catch (_) {
    showMessage(messenger, messageStrings.couldNotSaveTryAgain);
    return false;
  }
  // Distances come with the listings: load them again.
  unawaited(getIt<ListingsCubit>().load());
  unawaited(getIt<FavouritesCubit>().load());
  return true;
}

/// "A sua localidade" in Mais: the home the distance of each listing is
/// measured from. Tapping it opens a search of Portugal's towns.
class const HomePlaceTile({super.key}) extends StatefulWidget {
  @override
  State<HomePlaceTile> createState() => _HomePlaceTileState();
}

class _HomePlaceTileState extends State<HomePlaceTile> {
  final _cubit = getIt<HomePlaceCubit>();

  @override
  void initState() {
    super.initState();
    // The shell reads it at start; again here only if that failed.
    if (_cubit.state.status case .initial || .failure) {
      unawaited(_cubit.load());
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HomePlaceCubit, HomePlaceState>(
      bloc: _cubit,
      builder: (context, state) {
        final home = state.home;
        return ListTile(
          leading: const Icon(Icons.home_outlined),
          title: Text(
            home == null ? context.strings.yourHomeLocation : home.name,
          ),
          subtitle: Text(
            home == null
                ? context.strings.setItToSeeHowFarAwayEach
                : context.strings.homePlaceHelp,
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: state.status == .loading
              ? null
              : () => unawaited(pickHomePlace(context)),
        );
      },
    );
  }
}

class const _PlaceSearchDialog() extends StatefulWidget {
  @override
  State<_PlaceSearchDialog> createState() => _PlaceSearchDialogState();
}

class _PlaceSearchDialogState extends State<_PlaceSearchDialog> {
  final _controller = TextEditingController();
  Timer? _debounce;
  List<Place> _results = const [];
  String? _resultsFor;
  bool _failed = false;
  int _searchId = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () => _search(text));
  }

  Future<void> _search(String text) async {
    final id = ++_searchId;
    try {
      final results = await getIt<HomeRepository>().search(text);
      // Only the latest search counts.
      if (!mounted || id != _searchId) return;
      setState(() {
        _results = results;
        _resultsFor = text;
        _failed = false;
      });
    } catch (_) {
      if (!mounted || id != _searchId) return;
      setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    // "None found" only once the search for what is typed has answered.
    final noneFound =
        _controller.text.trim().isNotEmpty &&
        _resultsFor == _controller.text &&
        _results.isEmpty;
    return AlertDialog(
      title: Text(context.strings.yourHomeLocation),
      content: SizedBox(
        width: 400,
        height: 360,
        child: Column(
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                hintText: context.strings.enterCityOrTown,
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
              ),
              onChanged: _onChanged,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _failed
                  ? Center(child: Text(context.strings.couldNotSearchTryAgain))
                  : noneFound
                  ? Center(child: Text(context.strings.noPlacesFound))
                  : ListView(
                      children: [
                        for (final place in _results)
                          ListTile(
                            title: Text(place.name),
                            onTap: () => Navigator.of(context).pop(place),
                          ),
                      ],
                    ),
            ),
            // GeoNames' licence (CC BY 4.0) asks for credit.
            Text(
              context.strings.placesGeoNamesGeonamesOrgCCBY40,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.strings.cancel),
        ),
      ],
    );
  }
}
