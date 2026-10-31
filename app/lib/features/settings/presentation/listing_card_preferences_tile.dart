import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/di/injection.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/auth/session_cubit.dart';
import '../../../core/widgets/show_message.dart';
import '../../listings/domain/entities/listing_card_preferences.dart';
import '../../listings/presentation/cubit/listing_card_preferences_cubit.dart';
import '../../listings/presentation/listing_labels.dart';
import '../../../core/localization/localizations.dart';

Future<void> showListingCardPreferences(BuildContext context) async {
  final messageStrings = context.strings;

  if (!getIt<SessionCubit>().state.signedIn) {
    showMessage(
      ScaffoldMessenger.of(context),
      messageStrings.signInToCustomiseListingCards,
    );
    return;
  }
  final saved = await showDialog<bool>(
    context: context,
    builder: (_) =>
        _CardPreferencesDialog(cubit: getIt<ListingCardPreferencesCubit>()),
  );
  if (saved == true && context.mounted) {
    showMessage(ScaffoldMessenger.of(context), messageStrings.cardsUpdated);
  }
}

/// Mais › "Cartões dos anúncios", the only way in to the card choices: a
/// preference set once, so it has no slot in Ofertas' toolbar (F.3). When
/// the choices could not be read, the tile says so; the dialog retries.
class const ListingCardPreferencesTile({
  required final bool signedIn,
  super.key,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      BlocBuilder<ListingCardPreferencesCubit, ListingCardPreferencesState>(
        bloc: getIt<ListingCardPreferencesCubit>(),
        builder: (context, cards) {
          final failed = signedIn && cards.status == .failure;
          return ListTile(
            leading: Icon(
              failed
                  ? Icons.warning_amber_outlined
                  : Icons.view_agenda_outlined,
            ),
            title: Text(context.strings.listingCards),
            subtitle: Text(
              !signedIn
                  ? context.strings.availableWhenSignedIn
                  : failed
                  ? context.strings.cardPreferencesLoadError
                  : context.strings.chooseDetailsShownInDealsAndFavourites,
            ),
            trailing: const Icon(Icons.chevron_right),
            enabled: signedIn,
            onTap: () => showListingCardPreferences(context),
          );
        },
      );
}

class const _CardPreferencesDialog({
  required final ListingCardPreferencesCubit cubit,
}) extends StatefulWidget {
  @override
  State<_CardPreferencesDialog> createState() => _CardPreferencesDialogState();
}

class _CardPreferencesDialogState extends State<_CardPreferencesDialog> {
  late final String? _userId;
  ListingCardPreferences? _draft;

  @override
  void initState() {
    super.initState();
    _userId = widget.cubit.state.userId;
  }

  Future<void> _save() async {
    final saved = await widget.cubit.save(
      _draft ?? widget.cubit.state.preferences,
    );
    if (saved && mounted && ModalRoute.of(context)?.isCurrent == true) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocConsumer<ListingCardPreferencesCubit, ListingCardPreferencesState>(
    bloc: widget.cubit,
    listener: (context, state) {
      if (state.userId != _userId &&
          ModalRoute.of(context)?.isCurrent == true) {
        Navigator.of(context).pop();
      }
    },
    builder: (context, state) {
      final preferences = _draft ?? state.preferences;
      final ready = state.status == .success;
      return AlertDialog(
        scrollable: true,
        title: Text(context.strings.listingCards),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.strings.cardDetailsIntro),
              const SizedBox(height: 12),
              Text(context.strings.cardAlwaysShown),
              const SizedBox(height: 12),
              if (state.status == .loading)
                const Center(child: CircularProgressIndicator())
              else if (ready) ...[
                for (final field in ListingCardField.values)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(field.label(language: context.language)),
                    value: preferences.shows(field),
                    onChanged: state.saving
                        ? null
                        : (visible) => setState(
                            () => _draft = (_draft ?? state.preferences)
                                .withField(field, visible ?? false),
                          ),
                  ),
                TextButton(
                  onPressed: state.saving
                      ? null
                      : () => setState(
                          () =>
                              _draft = const ListingCardPreferences.defaults(),
                        ),
                  child: Text(context.strings.restoreDefaults),
                ),
              ],
              if (state.error case final error?) ...[
                const SizedBox(height: 8),
                Text(
                  cardPreferencesErrorText(error, language: context.language),
                  style: AppTheme.errorText(context),
                ),
                if (state.status == .failure)
                  TextButton(
                    onPressed: widget.cubit.load,
                    child: Text(context.strings.retry),
                  ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: state.saving ? null : () => Navigator.of(context).pop(),
            child: Text(context.strings.cancel),
          ),
          FilledButton(
            onPressed: ready && !state.saving ? _save : null,
            child: Text(
              state.saving ? context.strings.saving : context.strings.save,
            ),
          ),
        ],
      );
    },
  );
}
