import 'package:flutter/material.dart';

class const SwipeActions({
  required final String id,
  required final Future<void> Function() onDelete,
  required final Widget child,
  final Future<void> Function()? onEdit,
  super.key,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    Widget background({required bool edit}) => ColoredBox(
      color: edit ? scheme.primaryContainer : scheme.errorContainer,
      child: Align(
        alignment: edit
            ? AlignmentDirectional.centerStart
            : AlignmentDirectional.centerEnd,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Icon(
            edit ? Icons.edit_outlined : Icons.delete_outline,
            color: edit ? scheme.onPrimaryContainer : scheme.onErrorContainer,
          ),
        ),
      ),
    );

    return Dismissible(
      key: ValueKey('swipe-$id'),
      direction: onEdit == null
          ? DismissDirection.endToStart
          : DismissDirection.horizontal,
      background: background(edit: onEdit != null),
      secondaryBackground: onEdit == null ? null : background(edit: false),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          await onEdit?.call();
        } else {
          await onDelete();
        }
        // Persistence owns removal; cancelled edits and failed writes keep it.
        return false;
      },
      child: child,
    );
  }
}
