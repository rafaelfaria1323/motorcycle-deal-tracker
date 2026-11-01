import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/di/injection.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../core/localization/localizations.dart';
import '../../../../core/widgets/show_message.dart';
import '../compare_text.dart';
import '../cubit/compare_cubit.dart';

/// Adds the listing to the comparison or takes it out; offers to open the
/// comparison once there are two or more.
class const CompareButton({required final String listingId, super.key})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cubit = getIt<CompareCubit>();
    return BlocBuilder<CompareCubit, List<String>>(
      bloc: cubit,
      builder: (context, compared) {
        final added = compared.contains(listingId);
        return IconButton(
          tooltip: added
              ? context.strings.removeFromComparison
              : context.strings.compare,
          isSelected: added,
          icon: const Icon(Icons.compare_arrows),
          onPressed: () {
            final messenger = ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar();
            if (!cubit.toggle(listingId)) {
              showMessage(
                messenger,
                context.strings.compareFull(
                  maxCompared: (maxCompared).toString(),
                ),
              );
              return;
            }
            final now = cubit.state;
            if (added) {
              showMessage(messenger, context.strings.removedFromComparison);
            } else if (now.length < 2) {
              showMessage(messenger, context.strings.compareAddedChooseAnother);
            } else {
              messenger.showSnackBar(
                SnackBar(
                  content: Text(
                    context.strings.inComparison(length: now.length.toString()),
                  ),
                  action: SnackBarAction(
                    label: context.strings.compare,
                    onPressed: () => context.push(AppRoutes.compare(now)),
                  ),
                ),
              );
            }
          },
        );
      },
    );
  }
}
