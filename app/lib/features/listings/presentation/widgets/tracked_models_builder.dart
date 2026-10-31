import 'package:flutter/material.dart';

import '../../../../core/localization/localizations.dart';
import '../../../../core/widgets/state_message.dart';
import '../../domain/entities/model_market.dart';

/// The followed models' market once [future] gives it: a spinner meanwhile,
/// the failure with "Tentar novamente" ([onRetry]), or a message when no
/// model is followed (unless [allowEmpty]: the page offers others).
class const TrackedModelsBuilder({
  required final Future<List<ModelMarket>> future,
  required final VoidCallback onRetry,
  required final Widget Function(BuildContext context, List<ModelMarket> models)
  builder,
  final bool allowEmpty = false,
  super.key,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ModelMarket>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return StateMessage(
            icon: Icons.cloud_off_outlined,
            title: context.strings.couldNotLoadModels,
            actionLabel: context.strings.retry,
            onAction: onRetry,
          );
        }
        final models = snapshot.data;
        if (models == null) {
          return const Center(child: CircularProgressIndicator());
        }
        if (models.isEmpty && !allowEmpty) {
          return StateMessage(
            icon: Icons.two_wheeler,
            title: context.strings.noFollowedModels,
            message: context.strings.chooseModelsInMoreFollowedModels,
          );
        }
        return builder(context, models);
      },
    );
  }
}
