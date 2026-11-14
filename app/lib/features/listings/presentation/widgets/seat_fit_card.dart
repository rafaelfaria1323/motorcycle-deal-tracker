import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../../../app/di/injection.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/auth/session_cubit.dart';
import '../../../../core/localization/localizations.dart';
import '../../../../core/widgets/section_card.dart';
import '../../../../core/widgets/show_message.dart';
import '../../../valuation/domain/repositories/ownership_settings_repository.dart';
import '../bike_specs_text.dart';

/// "Cabe-me?" (N.75): the model's seat height against the signed-in
/// person's height (`ownership_settings.rider_height_cm`), or a button to
/// give it. Hidden for an anonymous session, without a seat height, or
/// when the settings can't be read.
class const SeatFitCard({required final int? seatHeightMm, super.key})
    extends StatefulWidget {
  @override
  State<SeatFitCard> createState() => _SeatFitCardState();
}

class _SeatFitCardState extends State<SeatFitCard> {
  /// The saved height (null: none given); the future fails when the
  /// settings can't be read.
  late final Future<int?> _saved = _load();
  int? _edited;
  bool _wasEdited = false;

  Future<int?> _load() async {
    final settings = await getIt<OwnershipSettingsRepository>().get();
    return settings.riderHeightCm;
  }

  Future<void> _edit(int? current) async {
    final strings = context.strings;
    final height = await showDialog<int>(
      context: context,
      builder: (_) => _HeightDialog(initial: current),
    );
    if (height == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    // Shown at once; kept on this page even if saving fails.
    setState(() {
      _edited = height;
      _wasEdited = true;
    });
    try {
      await getIt<OwnershipSettingsRepository>().saveRiderHeight(height);
    } catch (_) {
      showMessage(messenger, strings.couldNotSaveTryAgain);
    }
  }

  @override
  Widget build(BuildContext context) {
    final seat = widget.seatHeightMm;
    if (seat == null || !getIt<SessionCubit>().state.signedIn) {
      return const SizedBox.shrink();
    }
    return FutureBuilder<int?>(
      future: _saved,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done ||
            snapshot.hasError) {
          return const SizedBox.shrink();
        }
        final height = _wasEdited ? _edited : snapshot.data;
        final reach = seatReach(seat, height);
        final strings = context.strings;
        return SectionCard(
          title: strings.seatFitTitle,
          action: TextButton(
            onPressed: () => unawaited(_edit(height)),
            child: Text(
              height == null ? strings.seatFitSetHeight : strings.change,
            ),
          ),
          footnote: reach == null ? null : strings.seatFitFootnote,
          children: [
            Text(
              reach == null || height == null
                  ? strings.seatFitAskHeight
                  : seatReachText(reach, height, language: context.language),
            ),
          ],
        );
      },
    );
  }
}

class const _HeightDialog({required final int? initial})
    extends StatefulWidget {
  @override
  State<_HeightDialog> createState() => _HeightDialogState();
}

class _HeightDialogState extends State<_HeightDialog> {
  late final _height = TextEditingController(
    text: widget.initial?.toString() ?? '',
  );
  bool _invalid = false;

  @override
  void dispose() {
    _height.dispose();
    super.dispose();
  }

  void _save() {
    final height = parseRiderHeight(_height.text);
    if (height == null) {
      setState(() => _invalid = true);
      return;
    }
    Navigator.of(context).pop(height);
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return AlertDialog(
      title: Text(strings.riderHeightTitle),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _height,
              autofocus: true,
              keyboardType: TextInputType.number,
              onSubmitted: (_) => _save(),
              decoration: InputDecoration(
                labelText: strings.riderHeightLabel,
                suffixText: 'cm',
                border: const OutlineInputBorder(),
              ),
            ),
            if (_invalid) ...[
              const SizedBox(height: 8),
              Text(
                strings.riderHeightInvalid,
                style: AppTheme.errorText(context),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(strings.cancel),
        ),
        FilledButton(onPressed: _save, child: Text(strings.save)),
      ],
    );
  }
}
