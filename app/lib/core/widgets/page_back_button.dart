import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/app_routes.dart';

/// The back arrow of a full page outside the shell (`/summary`,
/// `/collection-status`, ...). Pushed from a tab it pops; opened from a
/// notification or a typed address there is nothing beneath it, so it goes
/// to [fallback] instead (an AppBar shows no arrow at all then).
class PageBackButton extends StatelessWidget {
  const PageBackButton({this.fallback = AppRoutes.more, super.key});

  /// Where to go when there is nothing to pop.
  final String fallback;

  @override
  Widget build(BuildContext context) => BackButton(
    onPressed: () => context.canPop() ? context.pop() : context.go(fallback),
  );
}
