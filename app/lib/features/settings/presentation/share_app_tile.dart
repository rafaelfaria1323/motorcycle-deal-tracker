import 'package:flutter/material.dart';

import '../../../core/platform/app_build.dart';
import 'accounts_text.dart';
import 'share_link.dart';
import '../../../core/localization/localizations.dart';

/// "Partilhar a app" in Mais: the app's link, for anyone. Admins invite
/// people from "Administração" instead, so their line doesn't send them
/// to an admin.
class const ShareAppTile({required final bool admin, super.key})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.ios_share),
      title: Text(context.strings.shareApp),
      subtitle: Text(
        admin
            ? context.strings.linkToViewListingsWithoutAccount
            : context.strings.viewLinkHelp,
      ),
      onTap: () => shareOrCopy(
        ScaffoldMessenger.of(context),
        title: appName,
        text: appShareText(language: context.language),
        url: appLink(webOrigin),
        language: context.language,
      ),
    );
  }
}
