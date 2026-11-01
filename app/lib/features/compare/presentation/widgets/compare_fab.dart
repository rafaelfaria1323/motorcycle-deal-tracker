import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/di/injection.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../core/localization/localizations.dart';
import '../../../../core/widgets/show_message.dart';
import '../cubit/compare_cubit.dart';

/// "Comparar (N)" over Ofertas once an ad is picked: opens the comparison
/// from two, else says to pick another.
class const CompareFab({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => BlocBuilder<CompareCubit, List<String>>(
    bloc: getIt<CompareCubit>(),
    builder: (context, compared) {
      if (compared.isEmpty) return const SizedBox.shrink();
      return FloatingActionButton.extended(
        icon: const Icon(Icons.compare_arrows),
        label: Text(
          context.strings.compareCount(length: compared.length.toString()),
        ),
        onPressed: () {
          if (compared.length >= 2) {
            context.push(AppRoutes.compare(compared));
            return;
          }
          final messenger = ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar();
          showMessage(
            messenger,
            context.strings.tapCompareOnAnotherListingToAddIt,
          );
        },
      );
    },
  );
}
