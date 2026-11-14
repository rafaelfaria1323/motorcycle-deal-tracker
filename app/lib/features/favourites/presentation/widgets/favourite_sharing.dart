import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/di/injection.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../core/auth/session_cubit.dart';
import '../../../../core/localization/localizations.dart';
import '../../../../core/platform/app_build.dart';
import '../../../../core/platform/download.dart';
import '../../../../core/widgets/share_or_copy.dart';
import '../../../../core/widgets/show_message.dart';
import '../../domain/entities/favourite.dart';
import '../../domain/entities/favourite_share.dart';
import '../../domain/repositories/favourite_shares_repository.dart';
import '../favourite_share_text.dart';

enum _MenuAction { share, export }

/// Favoritos' menu (16.11): "Partilhar a lista" (accounts only) and
/// "Exportar (CSV)".
class const FavouritesMenu({
  required final List<Favourite> favourites,
  super.key,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      BlocBuilder<SessionCubit, SessionState>(
        bloc: getIt<SessionCubit>(),
        builder: (context, session) => PopupMenuButton<_MenuAction>(
          onSelected: (action) => switch (action) {
            .share => showFavouriteSharing(context),
            .export => exportFavouritesCsv(context, favourites),
          },
          itemBuilder: (context) => [
            if (session.signedIn)
              PopupMenuItem(
                value: _MenuAction.share,
                child: ListTile(
                  leading: const Icon(Icons.group_add_outlined),
                  title: Text(context.strings.shareFavouritesList),
                ),
              ),
            PopupMenuItem(
              value: _MenuAction.export,
              enabled: favourites.isNotEmpty,
              child: ListTile(
                leading: const Icon(Icons.table_view_outlined),
                title: Text(context.strings.exportFavouritesCsv),
              ),
            ),
          ],
        ),
      );
}

/// The favourites as a CSV file: downloaded in the browser; elsewhere
/// (the Android app) the text is copied, to paste into a spreadsheet.
Future<void> exportFavouritesCsv(
  BuildContext context,
  List<Favourite> favourites,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final language = context.language;
  final m = language.messages;
  final text = favouritesCsv(
    favourites,
    origin: webOrigin,
    language: language,
  );
  if (await downloadText(m.csvFileName, text, type: 'text/csv;charset=utf-8')) {
    showMessage(messenger, m.csvDownloaded(file: m.csvFileName));
    return;
  }
  await Clipboard.setData(ClipboardData(text: text));
  showMessage(messenger, m.csvCopied);
}

/// "Partilhar a lista": who sees it, a link to send (made by one tap,
/// sent by another: the share sheet opens only straight after a tap) and
/// "Deixar de partilhar".
Future<void> showFavouriteSharing(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _SharingSheet(),
    );

class const _SharingSheet() extends StatefulWidget {
  @override
  State<_SharingSheet> createState() => _SharingSheetState();
}

class _SharingSheetState extends State<_SharingSheet> {
  final _repository = getIt<FavouriteSharesRepository>();
  late Future<FavouriteShare> _share = _repository.mine();
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    final messenger = ScaffoldMessenger.of(context);
    final failed = context.strings.couldNotShareFavourites;
    setState(() => _busy = true);
    try {
      await action();
    } catch (_) {
      showMessage(messenger, failed);
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _share = _repository.mine();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: FutureBuilder<FavouriteShare>(
          future: _share,
          builder: (context, snapshot) {
            final share = snapshot.data;
            final failed = snapshot.hasError;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.strings.shareFavouritesList,
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(context.strings.shareFavouritesBody),
                const SizedBox(height: 16),
                if (share == null && !failed)
                  const Center(child: CircularProgressIndicator())
                else ...[
                  Text(
                    failed
                        ? context.strings.couldNotShareFavourites
                        : favouriteShareStateText(
                            share!,
                            language: context.language,
                          ),
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (share?.code case final code?)
                        FilledButton.icon(
                          icon: const Icon(Icons.ios_share),
                          label: Text(context.strings.sendShareLink),
                          onPressed: () => shareOrCopy(
                            ScaffoldMessenger.of(context),
                            title: appName,
                            text: context.strings.favouritesShareText(
                              app: appName,
                            ),
                            url: favouriteShareLink(webOrigin, code),
                            language: context.language,
                          ),
                        ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.link),
                        label: Text(
                          share?.waiting ?? false
                              ? context.strings.newShareLink
                              : context.strings.createShareLink,
                        ),
                        onPressed: _busy
                            ? null
                            : () => _run(_repository.share),
                      ),
                      if (share?.viewerEmail != null ||
                          (share?.waiting ?? false))
                        TextButton.icon(
                          icon: const Icon(Icons.link_off),
                          label: Text(context.strings.stopSharing),
                          onPressed: _busy
                              ? null
                              : () => _run(_repository.stop),
                        ),
                    ],
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

/// The lists other accounts share with this one, beside Favoritos' menu:
/// nothing without any; a tap opens the one, or picks among several.
class const SharedListsButton({super.key}) extends StatefulWidget {
  @override
  State<SharedListsButton> createState() => _SharedListsButtonState();
}

class _SharedListsButtonState extends State<SharedListsButton> {
  List<SharedList> _lists = const [];
  String? _account;

  @override
  void initState() {
    super.initState();
    _follow(getIt<SessionCubit>().state);
  }

  void _follow(SessionState session) {
    final account = session.signedIn ? session.userId : null;
    if (account == _account && account != null) return;
    _account = account;
    _reload();
  }

  Future<void> _reload() async {
    final account = _account;
    if (account == null) {
      if (_lists.isNotEmpty) setState(() => _lists = const []);
      return;
    }
    try {
      final lists = await getIt<FavouriteSharesRepository>().sharedWithMe();
      // A later account's answer wins.
      if (mounted && account == _account) setState(() => _lists = lists);
    } catch (_) {
      // Only an extra: the button stays as it was.
    }
  }

  Future<void> _open(String ownerId) async {
    await context.push(AppRoutes.sharedFavourites(ownerId));
    // The list may have been left there.
    await _reload();
  }

  Future<void> _pick() async {
    if (_lists case [final only]) {
      await _open(only.ownerId);
      return;
    }
    final owner = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final list in _lists)
              ListTile(
                leading: const Icon(Icons.people_outline),
                title: Text(list.ownerEmail),
                onTap: () => Navigator.of(sheetContext).pop(list.ownerId),
              ),
          ],
        ),
      ),
    );
    if (owner != null) await _open(owner);
  }

  @override
  Widget build(BuildContext context) =>
      BlocListener<SessionCubit, SessionState>(
        bloc: getIt<SessionCubit>(),
        listener: (context, session) => _follow(session),
        child: _lists.isEmpty
            ? const SizedBox.shrink()
            : IconButton(
                icon: const Icon(Icons.people_outline),
                tooltip: context.strings.sharedListsWithYou,
                onPressed: _pick,
              ),
      );
}
