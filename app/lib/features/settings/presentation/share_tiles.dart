import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/di/injection.dart';
import '../../../app/router/app_routes.dart';
import '../domain/accounts_repository.dart';
import 'accounts_text.dart';
import 'share_link.dart';

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
            title: const Text('Partilhar a app'),
            subtitle: Text(
              snapshot.data == true
                  ? 'O link para ver os anúncios, sem conta'
                  : 'O link para ver os anúncios. Para ter conta, peça um '
                        'convite a um administrador',
            ),
            onTap: () => shareOrCopy(
              ScaffoldMessenger.of(context),
              title: appName,
              text: appShareText,
              url: appLink(Uri.base.origin),
            ),
          ),
          if (snapshot.data == true) ...[
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.group_outlined),
              title: const Text('Contas e convites'),
              subtitle: const Text(
                'Convide pessoas com um link e veja quem tem conta',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(AppRoutes.accounts),
            ),
          ],
        ],
      ),
    );
  }
}
