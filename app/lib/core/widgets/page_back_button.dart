import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/app_routes.dart';
import '../platform/browser_back.dart';

/// The back arrow of a full page outside the shell (`/summary`,
/// `/collection-status`, ...). Pushed from a tab it pops; opened from a
/// notification or a typed address there is nothing beneath it, so it goes
/// to [fallback] instead (an AppBar shows no arrow at all then).
class const PageBackButton({
  /// Where to go when there is nothing to pop.
  final String fallback = AppRoutes.more,
  super.key,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      BackButton(onPressed: () => goBack(context, fallback: fallback));
}

/// What every in-app back arrow does: pops, or goes to [fallback] when
/// there is nothing beneath. In the browser it steps back in the browser's
/// history instead, so the phone's back gesture afterwards doesn't reopen
/// the page just closed; on the first entry the app made (nothing of the
/// app behind it) the screen it shows takes that entry's place.
void goBack(BuildContext context, {required String fallback}) {
  if (browserBack()) return;
  Router.neglect(
    context,
    () => context.canPop() ? context.pop() : context.go(fallback),
  );
}
