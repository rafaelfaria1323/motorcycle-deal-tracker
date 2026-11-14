import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../app/di/injection.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../core/auth/session_cubit.dart';
import '../../../../core/localization/localizations.dart';
import '../../../../core/widgets/page_back_button.dart';
import '../../../../core/widgets/state_message.dart';
import '../../domain/repositories/favourite_shares_repository.dart';

/// A shared list's link (16.11, `/#/share?code=…`, opened from a
/// message): signed in, the list opens for this account and the link is
/// used up; otherwise it asks to sign in first (Mais › Conta), the link
/// still waiting.
class const AcceptSharePage({required final String code, super.key})
    extends StatefulWidget {
  @override
  State<AcceptSharePage> createState() => _AcceptSharePageState();
}

class _AcceptSharePageState extends State<AcceptSharePage> {
  String? _account;
  Future<String>? _accepted;

  void _follow(SessionState session) {
    final account = session.signedIn ? session.userId : null;
    if (account == null || account == _account) return;
    _account = account;
    final accepted = getIt<FavouriteSharesRepository>().accept(
      widget.code.trim(),
    );
    _accepted = accepted;
    // A failure shows through the FutureBuilder below.
    unawaited(
      accepted.then((owner) {
        if (mounted && account == _account) {
          context.go(AppRoutes.sharedFavourites(owner));
        }
      }, onError: (Object _) {}),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: const PageBackButton(fallback: AppRoutes.favourites),
      title: Text(context.strings.sharedListTitle),
    ),
    body: BlocBuilder<SessionCubit, SessionState>(
      bloc: getIt<SessionCubit>(),
      builder: (context, session) {
        _follow(session);
        final accepted = _accepted;
        if (!session.signedIn || accepted == null) {
          return StateMessage(
            icon: Icons.account_circle_outlined,
            title: context.strings.signInToSeeSharedList,
            actionLabel: context.strings.signIn,
            onAction: () => context.go(AppRoutes.more),
          );
        }
        return FutureBuilder<String>(
          future: accepted,
          builder: (context, snapshot) {
            if (snapshot.error case final error?) {
              return StateMessage(
                icon: Icons.link_off,
                title: switch (error) {
                  PostgrestException(code: '22023') =>
                    context.strings.shareLinkOwn,
                  PostgrestException(code: 'P0002') =>
                    context.strings.shareLinkUnavailable,
                  _ => context.strings.couldNotLoadSharedList,
                },
                actionLabel: context.strings.openApp,
                onAction: () => context.go(AppRoutes.favourites),
              );
            }
            return const Center(child: CircularProgressIndicator());
          },
        );
      },
    ),
  );
}
