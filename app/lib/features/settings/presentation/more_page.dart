import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/di/injection.dart';
import '../../../app/router/app_routes.dart';
import '../../../core/auth/account_sheet.dart';
import '../../../core/auth/session_cubit.dart';
import '../../collector_status/presentation/collection_details.dart';
import '../../collector_status/presentation/collector_status_banner.dart';
import '../../collector_status/presentation/data_quality_details.dart';
import 'home_place_tile.dart';
import 'push_tile.dart';
import 'run_now_tiles.dart';
import 'share_tiles.dart';

/// Everything that is not a list of offers: the account, the tracked
/// models and how the data collection is doing.
class MorePage extends StatelessWidget {
  const MorePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mais')),
      // Rebuilt on sign-in and sign-out.
      body: BlocBuilder<SessionCubit, SessionState>(
        bloc: getIt<SessionCubit>(),
        builder: (context, session) {
          final signedIn = session.signedIn;

          return ListView(
            children: [
              const _Header('Conta'),
              _Group(
                child: ListTile(
                  leading: const Icon(Icons.account_circle_outlined),
                  title: Text(
                    signedIn
                        ? session.email ?? 'Sessão iniciada'
                        : 'Sem sessão',
                  ),
                  subtitle: Text(
                    signedIn
                        ? 'Toque para terminar a sessão'
                        : 'Inicie sessão para ter as pesquisas e os alertas '
                              'em qualquer dispositivo',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => showAccountSheet(context),
                ),
              ),
              const _Header('Partilhar'),
              _Group(
                child: ShareTiles(
                  // Asked again after sign-in or sign-out.
                  key: ValueKey(signedIn),
                  signedIn: signedIn,
                ),
              ),
              const _Header('Notificações'),
              _Group(
                child: PushTile(
                  // A new state after sign-in or sign-out.
                  key: ValueKey(signedIn),
                  signedIn: signedIn,
                ),
              ),
              const _Header('Mercado'),
              _Group(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.star_border),
                      title: const Text('Favoritos'),
                      subtitle: const Text(
                        'Os anúncios que está a considerar, com as suas notas',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push(AppRoutes.favourites),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.summarize_outlined),
                      title: const Text('Resumo da semana'),
                      subtitle: Text(
                        signedIn
                            ? 'Novos anúncios, baixas de preço e os melhores '
                                  'negócios dos últimos 7 dias'
                            : 'Disponível com sessão iniciada',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      enabled: signedIn,
                      onTap: () => context.push(AppRoutes.summary),
                    ),
                    const Divider(height: 1),
                    const HomePlaceTile(),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.two_wheeler),
                      title: const Text('Modelos acompanhados'),
                      subtitle: Text(
                        signedIn
                            ? 'Que modelos recolher, desde que ano e o preço '
                                  'de uma nova'
                            : 'Disponível com sessão iniciada',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      enabled: signedIn,
                      onTap: () => context.push(AppRoutes.models),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.leaderboard_outlined),
                      title: const Text('Comparar modelos'),
                      subtitle: const Text(
                        'Preços pedidos, tempo até sair do mercado e '
                        'desvalorização dos modelos acompanhados',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push(AppRoutes.modelMarket),
                    ),
                  ],
                ),
              ),
              const _Header('Recolha de dados'),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: CollectorStatusBanner(),
              ),
              _Group(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    children: [
                      CollectionDetails(signedIn: signedIn),
                      RunNowTiles(
                        // Asked again after sign-in or sign-out.
                        key: ValueKey(signedIn),
                        signedIn: signedIn,
                      ),
                      if (!signedIn)
                        const Padding(
                          padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: Text(
                            'O estado e a duração das recolhas aparecem com '
                            'sessão iniciada.',
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const _Header('Qualidade dos dados'),
              const _Group(child: DataQualityDetails()),
              const SizedBox(height: 24),
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

/// One rounded card per section, as in the iPhone's settings.
class _Group extends StatelessWidget {
  const _Group({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}
