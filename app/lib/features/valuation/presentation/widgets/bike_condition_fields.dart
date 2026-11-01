import 'package:flutter/material.dart';

import '../../../../core/localization/localizations.dart';
import '../../domain/entities/bike_condition.dart';

/// What the owner says of the bike (damage, owners, service book,
/// warranty); each answer adjusts the value shown at once.
class const BikeConditionFields({
  required final BikeCondition condition,
  required final ValueChanged<BikeCondition> onChanged,
  super.key,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(strings.bikeValueCondition, style: theme.textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(
          strings.bikeValueConditionHint,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        _ConditionChoice(
          label: strings.bikeValueDamage,
          value: condition.damage,
          options: {
            BikeDamage.none: strings.bikeValueDamageNone,
            BikeDamage.dropped: strings.bikeValueDamageDropped,
            BikeDamage.accident: strings.bikeValueDamageAccident,
          },
          onChanged: (damage) => onChanged(condition.copyWith(damage: damage)),
        ),
        const SizedBox(height: 12),
        _ConditionChoice(
          label: strings.bikeValueOwners,
          value: condition.owners,
          options: {
            BikeOwners.unknown: strings.bikeValueUnknown,
            BikeOwners.one: strings.bikeValueOwnersOne,
            BikeOwners.two: strings.bikeValueOwnersTwo,
            BikeOwners.threeOrMore: strings.bikeValueOwnersMore,
          },
          onChanged: (owners) => onChanged(condition.copyWith(owners: owners)),
        ),
        const SizedBox(height: 12),
        _ConditionChoice(
          label: strings.bikeValueServiceBook,
          value: condition.serviceBook,
          options: {
            BikeServiceBook.unknown: strings.bikeValueUnknown,
            BikeServiceBook.yes: strings.bikeValueServiceBookYes,
            BikeServiceBook.no: strings.bikeValueServiceBookNo,
          },
          onChanged: (book) => onChanged(condition.copyWith(serviceBook: book)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(strings.bikeValueWarranty),
          value: condition.warranty,
          onChanged: (warranty) =>
              onChanged(condition.copyWith(warranty: warranty)),
        ),
      ],
    );
  }
}

/// One of the condition's answers, as a dropdown.
class const _ConditionChoice<T>({
  required final String label,
  required final T value,
  required final Map<T, String> options,
  required final ValueChanged<T> onChanged,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => DropdownButtonFormField<T>(
    initialValue: value,
    isExpanded: true,
    decoration: InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
    ),
    items: [
      for (final MapEntry(:key, value: text) in options.entries)
        DropdownMenuItem(value: key, child: Text(text)),
    ],
    onChanged: (picked) {
      if (picked != null) onChanged(picked);
    },
  );
}
