import 'package:flutter/material.dart';

import '../../../../core/localization/localizations.dart';
import '../../domain/entities/bike_value_request.dart';
import '../bike_value_text.dart';

/// The account's earlier requests, each answered or waiting; a tap shows
/// it again in the form.
class const BikeValueRequests({
  required final List<BikeValueRequest> requests,
  required final ValueChanged<BikeValueRequest> onTap,
  super.key,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        Text(
          context.strings.bikeValueRequests,
          style: theme.textTheme.titleSmall,
        ),
        for (final request in requests)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              request.waiting ? Icons.hourglass_top : Icons.euro,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            title: Text(request.name),
            subtitle: Text(
              bikeValueRequestLine(request, language: context.language),
            ),
            onTap: () => onTap(request),
          ),
      ],
    );
  }
}
