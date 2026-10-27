import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app/di/injection.dart';
import '../../app/theme/app_theme.dart';
import 'account_cubit.dart';

Future<void> showAccountSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => BlocProvider(
      create: (_) => getIt<AccountCubit>(),
      child: const _AccountSheet(),
    ),
  );
}

class _AccountSheet extends StatefulWidget {
  const _AccountSheet();

  @override
  State<_AccountSheet> createState() => _AccountSheetState();
}

class _AccountSheetState extends State<_AccountSheet> {
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<AccountCubit>();

    return BlocConsumer<AccountCubit, AccountState>(
      listenWhen: (a, b) => !a.done && b.done,
      listener: (context, state) {
        Navigator.of(context).pop();
      },
      builder: (context, state) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            0,
            24,
            24 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: cubit.hasAccount
                  ? _signedIn(context, cubit, state)
                  : _signIn(context, cubit, state),
            ),
          ),
        );
      },
    );
  }

  List<Widget> _signedIn(
    BuildContext context,
    AccountCubit cubit,
    AccountState s,
  ) {
    return [
      Text('A sua conta', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      Text('Sessão iniciada como ${cubit.currentEmail}.'),
      const SizedBox(height: 16),
      if (s.error != null) _error(context, s.error!),
      OutlinedButton(
        onPressed: s.busy ? null : cubit.signOut,
        child: const Text('Terminar sessão'),
      ),
    ];
  }

  List<Widget> _signIn(
    BuildContext context,
    AccountCubit cubit,
    AccountState s,
  ) {
    return [
      Text('Iniciar sessão', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      const Text(
        'Com a sua conta, as suas pesquisas e alertas ficam sincronizados '
        'em qualquer dispositivo ou browser.',
      ),
      const SizedBox(height: 16),
      TextField(
        controller: _email,
        keyboardType: TextInputType.emailAddress,
        autofillHints: const [AutofillHints.username],
        decoration: const InputDecoration(
          labelText: 'Email',
          border: OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _password,
        obscureText: true,
        autofillHints: const [AutofillHints.password],
        decoration: const InputDecoration(
          labelText: 'Palavra-passe',
          border: OutlineInputBorder(),
        ),
        onSubmitted: (_) => cubit.signIn(_email.text, _password.text),
      ),
      const SizedBox(height: 12),
      if (s.error != null) _error(context, s.error!),
      FilledButton(
        onPressed: s.busy
            ? null
            : () => cubit.signIn(_email.text, _password.text),
        child: Text(s.busy ? 'A entrar…' : 'Entrar'),
      ),
    ];
  }

  Widget _error(BuildContext context, String message) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(message, style: AppTheme.errorText(context)),
  );
}
