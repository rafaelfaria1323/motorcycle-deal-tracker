import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/di/injection.dart';
import '../../../core/widgets/show_message.dart';
import '../../listings/presentation/cubit/favourites_cubit.dart';
import '../../listings/presentation/cubit/listings_cubit.dart';
import '../domain/home_repository.dart';
import '../domain/place.dart';
import '../../../core/localization/localizations.dart';

/// "A sua localidade" in Mais: the home the distance of each listing is
/// measured from. Tapping it opens a search of Portugal's towns.
class HomePlaceTile extends StatefulWidget {
  const HomePlaceTile({super.key});

  @override
  State<HomePlaceTile> createState() => _HomePlaceTileState();
}

class _HomePlaceTileState extends State<HomePlaceTile> {
  late Future<Place?> _home = _load();

  Future<Place?> _load() =>
      getIt<HomeRepository>().getHome().catchError((Object _) => null);

  Future<void> _pick() async {
    final messageStrings = context.strings;

    final messenger = ScaffoldMessenger.of(context);
    final place = await showDialog<Place>(
      context: context,
      builder: (_) => const _PlaceSearchDialog(),
    );
    if (place == null) return;
    try {
      await getIt<HomeRepository>().saveHome(place);
    } catch (_) {
      showMessage(messenger, messageStrings.couldNotSaveTryAgain);
      return;
    }
    if (!mounted) return;
    setState(() => _home = Future.value(place));
    // Distances come with the listings: load them again.
    unawaited(getIt<ListingsCubit>().load());
    unawaited(getIt<FavouritesCubit>().load());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Place?>(
      future: _home,
      builder: (context, snapshot) {
        final home = snapshot.data;
        return ListTile(
          leading: const Icon(Icons.home_outlined),
          title: Text(
            home == null ? context.strings.yourHomeLocation : home.name,
          ),
          subtitle: Text(
            home == null
                ? context.strings.setItToSeeHowFarAwayEach
                : context
                      .strings
                      .yourHomeLocationDistancesToListingsAreMeasured,
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: snapshot.connectionState == ConnectionState.done
              ? _pick
              : null,
        );
      },
    );
  }
}

class _PlaceSearchDialog extends StatefulWidget {
  const _PlaceSearchDialog();

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
