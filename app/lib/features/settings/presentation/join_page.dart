import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/di/injection.dart';
import '../../../app/router/app_routes.dart';
import '../../../core/auth/account_cubit.dart';
import '../../../core/auth/session_cubit.dart';
import '../../../core/widgets/state_message.dart';
import '../domain/accounts_repository.dart';
import 'accounts_text.dart';
import '../../../core/localization/localizations.dart';

/// The page an invite link opens (`/join?code=…`): the visitor chooses an
/// email and a password, the account is made and signed in.
class const JoinPage({required final String code, super.key})
    extends StatefulWidget {
  @override
  State<JoinPage> createState() => _JoinPageState();
}

class _JoinPageState extends State<JoinPage> {
  final _repository = getIt<AccountsRepository>();
  late final Future<InviteStatus> _status = _repository
      .inviteStatus(widget.code)
      .catchError((Object _) => InviteStatus.unknown);
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final messageLanguage = context.language;

    final problem = joinFormProblem(
      _email.text,
      _password.text,
      _confirmation.text,
      language: messageLanguage,
    );
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _repository.redeemInvite(widget.code, _email.text, _password.text);
    } on PostgrestException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = redeemErrorText(e.code, language: context.language);
      });
      return;
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = redeemErrorText(null, language: context.language);
      });
      return;
    }
    if (mounted) context.go(AppRoutes.deals);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.strings.createYourAccount)),
      body: BlocBuilder<SessionCubit, SessionState>(
        bloc: getIt<SessionCubit>(),
        builder: (context, session) => FutureBuilder<InviteStatus>(
          future: _status,
          builder: (context, snapshot) {
            final status = snapshot.data;
            if (status == null) {
              return const Center(child: CircularProgressIndicator());
            }
            final problem = inviteStatusText(
              status,
              language: context.language,
            );
            if (problem != null) {
              return StateMessage(
                icon: Icons.link_off,
                title: context.strings.inviteUnavailable,
                message: problem,
                actionLabel: context.strings.openApp,
                onAction: () => context.go(AppRoutes.deals),
              );
            }
            if (session.signedIn && !_busy) {
              return StateMessage(
                icon: Icons.account_circle_outlined,
                title: context.strings.youAreAlreadySignedIn,
                message: context.strings.joinSignedInAs(
                  email: session.email ?? '',
                ),
                actionLabel: context.strings.signOut,
                onAction: () => getIt<AccountCubit>().signOut(),
              );
            }
            return _form(context);
          },
        ),
      ),
    );
  }

  Widget _form(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: ListView(
          padding: const EdgeInsets.all(24),
          shrinkWrap: true,
          children: [
            Text(context.strings.welcome, style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(context.strings.inviteShareText),
            const SizedBox(height: 20),
            AutofillGroup(
              child: Column(
                children: [
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: InputDecoration(
                      labelText: context.strings.email,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _password,
                    obscureText: true,
                    autofillHints: const [AutofillHints.newPassword],
                    decoration: InputDecoration(
                      labelText: context.strings.password,
                      helperText: context.strings.atLeast8Characters,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _confirmation,
                    obscureText: true,
                    autofillHints: const [AutofillHints.newPassword],
                    decoration: InputDecoration(
                      labelText: context.strings.repeatYourPassword,
                      border: const OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _busy ? null : _create(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  _error!,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            FilledButton(
              onPressed: _busy ? null : _create,
              child: Text(
                _busy
                    ? context.strings.creatingAccount
                    : context.strings.createAccount,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              context.strings.thenChooseBikesYouWantToFollowIn,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
