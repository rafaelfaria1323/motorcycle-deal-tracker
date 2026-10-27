import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/di/injection.dart';
import '../../../app/router/app_routes.dart';
import '../../../core/platform/app_build.dart';
import '../domain/accounts_repository.dart';
import 'accounts_text.dart';
import 'share_link.dart';
import '../../../core/localization/localizations.dart';

/// "Partilhar" in Mais: the app's link for anyone; for admins, the page to
/// invite people and manage the accounts.
class ShareTiles extends StatefulWidget {
  const ShareTiles({required this.signedIn, super.key});

  final bool signedIn;

  @override
  State<ShareTiles> createState() => _ShareTilesState();
}

class _ShareTilesState extends State<ShareTiles> {
  late final Future<bool> _admin = widget.signedIn
      ? getIt<AccountsRepository>().isAdmin().catchError((Object _) => false)
      : Future.value(false);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _admin,
      builder: (context, snapshot) => Column(
        children: [
          ListTile(
            leading: const Icon(Icons.ios_share),
            title: Text(context.strings.shareApp),
            subtitle: Text(
              snapshot.data == true
                  ? context.strings.linkToViewListingsWithoutAccount
                  : context.strings.linkToViewListingsAskAdministratorForInvite,
            ),
            onTap: () => shareOrCopy(
              ScaffoldMessenger.of(context),
              title: appName,
              text: appShareText(language: context.language),
              url: appLink(webOrigin),
              language: context.language,
            ),
          ),
          if (snapshot.data == true) ...[
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.group_outlined),
              title: Text(context.strings.accountsAndInvites),
              subtitle: Text(context.strings.invitePeopleWithLinkAndSeeWhoHas),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(AppRoutes.accounts),
            ),
          ],
        ],
      ),
    );
  }
}
