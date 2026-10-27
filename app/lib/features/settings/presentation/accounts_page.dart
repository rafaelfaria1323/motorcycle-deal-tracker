import 'package:flutter/material.dart';

import '../../../app/di/injection.dart';
import '../../../core/platform/app_build.dart';
import '../../../core/widgets/page_back_button.dart';
import '../../../core/widgets/show_message.dart';
import '../../../core/widgets/state_message.dart';
import '../domain/accounts_repository.dart';
import 'accounts_text.dart';
import 'share_link.dart';
import '../../../core/localization/localizations.dart';

/// "Contas e convites" (admins): invite someone with a link, see the
/// accounts, make other admins, remove an account.
class AccountsPage extends StatefulWidget {
  const AccountsPage({super.key});

  @override
  State<AccountsPage> createState() => _AccountsPageState();
}

typedef _Data = ({List<Invite> invites, List<Account> accounts});

class _AccountsPageState extends State<AccountsPage> {
  final _repository = getIt<AccountsRepository>();
  late Future<_Data> _data = _load();
  bool _busy = false;

  Future<_Data> _load() async {
    final (invites, accounts) = await (
      _repository.invites(),
      _repository.accounts(),
    ).wait;
    return (invites: invites, accounts: accounts);
  }

  void _reload() => setState(() => _data = _load());

  Future<void> _run(Future<void> Function() action, String failure) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await action();
    } catch (_) {
      showMessage(messenger, failure);
    }
    if (!mounted) return;
    setState(() => _busy = false);
    _reload();
  }

  Future<void> _newInvite() async {
    final messageStrings = context.strings;

    final note = await showDialog<String>(
      context: context,
      builder: (_) => const _NoteDialog(),
    );
    if (note == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    String? code;
    try {
      code = await _repository.createInvite(note);
    } catch (_) {
      showMessage(messenger, messageStrings.couldNotCreateInvite);
    }
    if (!mounted) return;
    setState(() => _busy = false);
    _reload();
    // A new tap shares it: the share sheet opens only straight after one.
    if (code != null) await _showLink(code);
  }

  Future<void> _showLink(String code) {
    final link = inviteLink(webOrigin, code);
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.strings.inviteReady),
        content: Text(
          dialogContext.strings.sendThisLinkToPersonYouWantTo(link: link),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(dialogContext.strings.close),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.ios_share),
            label: Text(dialogContext.strings.share),
            onPressed: () => shareOrCopy(
              ScaffoldMessenger.of(context),
              title: appName,
              text: inviteShareText(language: dialogContext.language),
              url: link,
              language: dialogContext.language,
            ),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirm(String title, String message, String action) async =>
      await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(dialogContext.strings.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(action),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _removeAccount(Account account) async {
    final messageStrings = context.strings;

    final ok = await _confirm(
      messageStrings.removeAccountsPage(email: account.email),
      messageStrings.accountWillLoseAccessAndItsSearchesAlerts,
      messageStrings.removeOfferCard,
    );
    if (!ok || !mounted) return;
    await _run(
      () => _repository.removeAccount(account.id),
      messageStrings.couldNotRemoveAccount,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const PageBackButton(),
        title: Text(context.strings.accountsAndInvites),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _busy ? null : _newInvite,
        icon: const Icon(Icons.person_add_alt),
        label: Text(context.strings.invite),
      ),
      body: FutureBuilder<_Data>(
        future: _data,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return StateMessage(
              icon: Icons.error_outline,
              title: context.strings.couldNotLoad,
              message: context.strings.checkYourConnectionAndTryAgain,
              actionLabel: context.strings.retry,
              onAction: _reload,
            );
          }
          final data = snapshot.data;
          if (data == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final now = DateTime.now();
          final emails = {for (final a in data.accounts) a.id: a.email};
          return ListView(
            padding: const EdgeInsets.only(bottom: 96),
            children: [
              _Header(context.strings.invites),
              if (data.invites.isEmpty)
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text(context.strings.thereAreNoInvitesYetTapInviteTo),
                ),
              for (final invite in data.invites)
                ListTile(
                  leading: Icon(
                    invitePending(invite, now)
                        ? Icons.mail_outline
                        : Icons.drafts_outlined,
                  ),
                  title: Text(
                    invite.note ?? context.strings.inviteAccountsPage,
                  ),
                  subtitle: Text(
                    inviteSubtitle(
                      invite,
                      now: now,
                      emails: emails,
                      language: context.language,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (invitePending(invite, now))
                        IconButton(
                          tooltip: context.strings.share,
                          icon: const Icon(Icons.ios_share),
                          onPressed: () => shareOrCopy(
                            ScaffoldMessenger.of(context),
                            title: appName,
                            text: inviteShareText(language: context.language),
                            url: inviteLink(webOrigin, invite.code),
                            language: context.language,
                          ),
                        ),
                      IconButton(
                        tooltip: invitePending(invite, now)
                            ? context.strings.cancelInvite
                            : context.strings.deleteFromList,
                        icon: const Icon(Icons.delete_outline),
                        onPressed: _busy
                            ? null
                            : () => _run(
                                () => _repository.deleteInvite(invite.code),
                                context.strings.couldNotDeleteInvite,
                              ),
                      ),
                    ],
                  ),
                ),
              _Header(context.strings.accounts),
              for (final account in data.accounts)
                ListTile(
                  leading: Icon(
                    account.isAdmin
                        ? Icons.admin_panel_settings_outlined
                        : Icons.person_outline,
                  ),
                  title: Text(
                    account.isMe
                        ? context.strings.you(email: account.email)
                        : account.email,
                  ),
                  subtitle: Text(
                    accountSubtitle(account, language: context.language),
                  ),
                  trailing: account.isMe
                      ? null
                      : PopupMenuButton<String>(
                          enabled: !_busy,
                          onSelected: (choice) => choice == 'remove'
                              ? _removeAccount(account)
                              : _run(
                                  () => _repository.setAdmin(
                                    account.id,
                                    admin: !account.isAdmin,
                                  ),
                                  context.strings.couldNotChangeAccess,
                                ),
                          itemBuilder: (localizationContext) => [
                            PopupMenuItem(
                              value: 'admin',
                              child: Text(
                                account.isAdmin
                                    ? localizationContext
                                          .strings
                                          .removeAdministratorAccess
                                    : localizationContext
                                          .strings
                                          .makeAdministrator,
                              ),
                            ),
                            PopupMenuItem(
                              value: 'remove',
                              child: Text(
                                localizationContext.strings.removeAccount,
                              ),
                            ),
                          ],
                        ),
                ),
              Padding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Text(
                  context.strings.eachAccountChoosesItsModelsSearchesAndAlerts,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: Text(
        text.toUpperCase(),
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

/// Who the invite is for (optional, only for the list).
class _NoteDialog extends StatefulWidget {
  const _NoteDialog();

  @override
  State<_NoteDialog> createState() => _NoteDialogState();
}

class _NoteDialogState extends State<_NoteDialog> {
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.strings.newInvite),
      content: TextField(
        controller: _note,
        autofocus: true,
        maxLength: 80,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          labelText: context.strings.forWhomOptional,
          helperText: context.strings.onlyShownInThisList,
          border: OutlineInputBorder(),
        ),
        onSubmitted: (text) => Navigator.of(context).pop(text),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.strings.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_note.text),
          child: Text(context.strings.createInvite),
        ),
      ],
    );
  }
}
