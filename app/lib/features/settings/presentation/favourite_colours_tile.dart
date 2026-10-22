import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/di/injection.dart';
import '../../../core/widgets/show_message.dart';
import '../../listings/presentation/colour_text.dart';
import '../../listings/presentation/cubit/favourites_cubit.dart';
import '../../listings/presentation/cubit/listings_cubit.dart';
import '../domain/colour_repository.dart';

/// "Cores preferidas" in Mais: listings in these colours are marked as a
/// plus. The Deal Score never counts them.
class FavouriteColoursTile extends StatefulWidget {
  const FavouriteColoursTile({super.key});

  @override
  State<FavouriteColoursTile> createState() => _FavouriteColoursTileState();
}

class _FavouriteColoursTileState extends State<FavouriteColoursTile> {
  late Future<List<String>> _colours = _load();

  Future<List<String>> _load() => getIt<ColourRepository>()
      .getColours()
      .catchError((Object _) => const <String>[]);

  Future<void> _pick(List<String> current) async {
    final messenger = ScaffoldMessenger.of(context);
    final codes = await showDialog<List<String>>(
      context: context,
      builder: (_) => _ColoursDialog(initial: current.toSet()),
    );
    if (codes == null) return;
    try {
      await getIt<ColourRepository>().saveColours(codes);
    } catch (_) {
      showMessage(messenger, 'Não foi possível guardar. Tente novamente.');
      return;
    }
    if (!mounted) return;
    setState(() => _colours = Future.value(codes));
    // The marks come with the listings: load them again.
    unawaited(getIt<ListingsCubit>().load());
    unawaited(getIt<FavouritesCubit>().load());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<String>>(
      future: _colours,
      builder: (context, snapshot) {
        final colours = snapshot.data ?? const <String>[];
        final chosen = favouriteColoursText(colours);
        return ListTile(
          leading: const Icon(Icons.palette_outlined),
          title: Text(chosen ?? 'Cores preferidas'),
          subtitle: Text(
            chosen == null
                ? 'Indique-as para ver que motas são das suas cores '
                      '(não contam na pontuação)'
                : 'As suas cores preferidas: marcadas nos anúncios, sem '
                      'contar na pontuação',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: snapshot.connectionState == ConnectionState.done
              ? () => _pick(colours)
              : null,
        );
      },
    );
  }
}

class _ColoursDialog extends StatefulWidget {
  const _ColoursDialog({required this.initial});

  final Set<String> initial;

  @override
  State<_ColoursDialog> createState() => _ColoursDialogState();
}

class _ColoursDialogState extends State<_ColoursDialog> {
  late final Set<String> _chosen = {...widget.initial};

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Cores preferidas'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Os anúncios nestas cores ficam marcados. A cor não '
                'conta na pontuação: uma mota mais antiga ou com mais '
                'quilómetros não passa à frente por ser da sua cor.',
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final MapEntry(:key, :value) in colourLabels.entries)
                    FilterChip(
                      label: Text(value),
                      selected: _chosen.contains(key),
                      onSelected: (on) => setState(
                        () => on ? _chosen.add(key) : _chosen.remove(key),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          // In the offered order, so the list reads the same everywhere.
          onPressed: () => Navigator.of(context).pop([
            for (final code in colourLabels.keys)
              if (_chosen.contains(code)) code,
          ]),
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
