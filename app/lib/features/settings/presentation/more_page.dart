import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/di/injection.dart';
import '../../../app/router/app_routes.dart';
import '../../../core/auth/account_sheet.dart';
import '../../../core/auth/session_cubit.dart';
import '../../../core/widgets/page_intro.dart';
import '../../collector_status/presentation/collection_line_tile.dart';
import '../domain/accounts_repository.dart';
import 'admin_tiles.dart';
import 'android_app_tile.dart';
import 'home_place_tile.dart';
import 'language_tile.dart';
import 'listing_card_preferences_tile.dart';
import 'push_tile.dart';
import 'share_app_tile.dart';
import '../../../core/localization/localizations.dart';

/// Everything that is not a list of offers: the account, the person's own
/// lists and settings, the tools, notifications, the app, one line on the
/// data collection and, for admins only, "Administração".
class const MorePage({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.strings.more)),
      // Rebuilt on sign-in and sign-out; another account asks again
      // whether it is an admin.
      body: BlocBuilder<SessionCubit, SessionState>(
        bloc: getIt<SessionCubit>(),
        builder: (context, session) => _MoreBody(
          key: ValueKey((session.userId, session.signedIn)),
          session: session,
        ),
      ),
    );
  }
}

class const _MoreBody({required final SessionState session, super.key})
    extends StatefulWidget {
  @override
  State<_MoreBody> createState() => _MoreBodyState();
}

class _MoreBodyState extends State<_MoreBody> {
  late final Future<bool> _admin = widget.session.signedIn
      ? getIt<AccountsRepository>().isAdmin().catchError((Object _) => false)
      : Future.value(false);

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final signedIn = session.signedIn;

    return FutureBuilder<bool>(
      future: _admin,
      builder: (context, snapshot) {
        final admin = snapshot.data ?? false;
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 880),
            child: ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                  child: PageIntro(
                    eyebrow: context.strings.more,
                    title: context.strings.yourGarage,
                    description:
                        context.strings.yourAccountModelsYouFollowAndToolsTo,
                  ),
                ),
                _Header(context.strings.account),
                _Group(
                  children: [
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(context)
                            .colorScheme
                            .primaryContainer,
                        foregroundColor: Theme.of(context)
                            .colorScheme
                            .onPrimaryContainer,
                        child: const Icon(Icons.person_outline),
                      ),
                      title: Text(
                        signedIn
                            ? session.email ?? context.strings.signedIn
                            : context.strings.notSignedIn,
                      ),
                      subtitle: Text(
                        signedIn
                            ? context.strings.accountAndSignIn
                            : context
                                  .strings
                                  .signInToAccessYourSearchesAndAlerts,
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => showAccountSheet(context),
                    ),
                    const LanguageTile(),
                  ],
                ),
                _Header(context.strings.personal),
                _Group(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.star_border),
                      title: Text(context.strings.favourites),
                      subtitle: Text(
                        context.strings.listingsYouAreConsideringWithYourNotes,
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push(AppRoutes.favourites),
                    ),
                    ListTile(
                      leading: const Icon(Icons.two_wheeler),
                      title: Text(context.strings.followedModels),
                      subtitle: Text(
                        signedIn
                            ? context
                                  .strings
                                  .whichModelsToCollectFromWhichYearYour
                            : context.strings.availableWhenSignedIn,
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      enabled: signedIn,
                      onTap: () => context.push(AppRoutes.models),
                    ),
                    ListTile(
                      leading: const Icon(Icons.summarize_outlined),
                      title: Text(context.strings.weeklySummary),
                      subtitle: Text(
                        signedIn
                            ? context
                                  .strings
                                  .newListingsPriceDropsAndBestDealsFrom
                            : context.strings.availableWhenSignedIn,
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      enabled: signedIn,
                      onTap: () => context.push(AppRoutes.summary),
                    ),
                    const HomePlaceTile(),
                    ListingCardPreferencesTile(signedIn: signedIn),
                  ],
                ),
                _Header(context.strings.tools),
                _Group(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.leaderboard_outlined),
                      title: Text(context.strings.marketByModel),
                      subtitle: Text(context.strings.marketPageSubtitle),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push(AppRoutes.modelMarket),
                    ),
                    ListTile(
                      leading: const Icon(Icons.price_check),
                      title: Text(context.strings.bikeValueTitle),
                      subtitle: Text(context.strings.bikeValueSubtitle),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push(AppRoutes.bikeValue),
                    ),
                    ListTile(
                      leading: const Icon(Icons.local_shipping_outlined),
                      title: Text(context.strings.importPageTitle),
                      subtitle: Text(context.strings.importPageSubtitle),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push(AppRoutes.importBike),
                    ),
                  ],
                ),
                _Header(context.strings.notifications),
                _Group(children: [PushTile(signedIn: signedIn)]),
                _Header(context.strings.theApp),
                _Group(
                  children: [
                    ShareAppTile(admin: admin),
                    if (AndroidAppTile.shown) const AndroidAppTile(),
                  ],
                ),
                _Header(context.strings.dataCollection),
                _Group(children: [CollectionLineTile(admin: admin)]),
                if (admin) ...[
                  _Header(context.strings.administration),
                  const _Group(children: [AdminTiles()]),
                ],
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }
}

class const _Header(final String text) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: Text(text, style: theme.textTheme.titleLarge),
    );
  }
}

/// One rounded card per section, as in the iPhone's settings, with a
/// hairline between its rows.
class const _Group({required final List<Widget> children})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (final (i, child) in children.indexed) ...[
            if (i > 0) const Divider(height: 1),
            child,
          ],
        ],
      ),
    );
  }
}
