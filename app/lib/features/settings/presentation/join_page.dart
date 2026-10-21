import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/di/injection.dart';
import '../../../app/router/app_routes.dart';
import '../../../core/auth/account_cubit.dart';
import '../../../core/auth/session_cubit.dart';
import '../../../core/widgets/state_message.dart';
import '../../listings/presentation/cubit/alerts_cubit.dart';
import '../../listings/presentation/cubit/favourites_cubit.dart';
import '../../listings/presentation/cubit/listings_cubit.dart';
import '../../listings/presentation/cubit/saved_searches_cubit.dart';
import '../domain/accounts_repository.dart';
import 'accounts_text.dart';

/// The page an invite link opens (`/join?code=…`): the visitor chooses an
/// email and a password, the account is made and signed in.
class JoinPage extends StatefulWidget {
  const JoinPage({required this.code, super.key});

  final String code;

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
    final problem = joinFormProblem(
      _email.text,
      _password.text,
      _confirmation.text,
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
        _error = redeemErrorText(e.code);
      });
      return;
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = redeemErrorText(null);
      });
      return;
    }
    // The shared cubits hold the anonymous session's data: reload them.
    unawaited(getIt<ListingsCubit>().load(models: true));
    unawaited(getIt<SavedSearchesCubit>().load());
    unawaited(getIt<AlertsCubit>().load());
    unawaited(getIt<FavouritesCubit>().load(otherAccount: true));
    if (mounted) context.go(AppRoutes.deals);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Criar a sua conta')),
      body: BlocBuilder<SessionCubit, SessionState>(
        bloc: getIt<SessionCubit>(),
        builder: (context, session) => FutureBuilder<InviteStatus>(
          future: _status,
          builder: (context, snapshot) {
            final status = snapshot.data;
            if (status == null) {
              return const Center(child: CircularProgressIndicator());
            }
            final problem = inviteStatusText(status);
            if (problem != null) {
              return StateMessage(
                icon: Icons.link_off,
                title: 'Convite indisponível',
                message: problem,
                actionLabel: 'Abrir a app',
                onAction: () => context.go(AppRoutes.deals),
              );
            }
            if (session.signedIn && !_busy) {
              return StateMessage(
                icon: Icons.account_circle_outlined,
                title: 'Já tem sessão iniciada',
                message:
                    'Está com a conta ${session.email ?? ''}. Termine a '
                    'sessão para criar uma conta nova com este convite.',
                actionLabel: 'Terminar sessão',
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
            Text('Boas-vindas', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            const Text(
              'Recebeu um convite para o Motorcycle Deal Tracker: as motas usadas '
              'à venda em Portugal, com o preço justo e a pontuação de cada '
              'anúncio. Escolha o email e a palavra-passe com que vai entrar.',
            ),
            const SizedBox(height: 20),
            AutofillGroup(
              child: Column(
                children: [
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _password,
                    obscureText: true,
                    autofillHints: const [AutofillHints.newPassword],
                    decoration: const InputDecoration(
                      labelText: 'Palavra-passe',
                      helperText: 'Pelo menos 8 caracteres',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _confirmation,
                    obscureText: true,
                    autofillHints: const [AutofillHints.newPassword],
                    decoration: const InputDecoration(
                      labelText: 'Repita a palavra-passe',
                      border: OutlineInputBorder(),
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
              child: Text(_busy ? 'A criar a conta…' : 'Criar conta'),
            ),
            const SizedBox(height: 16),
            Text(
              'Depois, em Mais › Modelos acompanhados, escolha as motas que '
              'quer seguir.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
