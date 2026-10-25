import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/di/injection.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/auth/session_cubit.dart';
import '../../../core/widgets/show_message.dart';
import '../../listings/domain/entities/listing_card_preferences.dart';
import '../../listings/presentation/cubit/listing_card_preferences_cubit.dart';
import '../../listings/presentation/listing_labels.dart';

Future<void> showListingCardPreferences(BuildContext context) async {
  if (!getIt<SessionCubit>().state.signedIn) {
    showMessage(
      ScaffoldMessenger.of(context),
      'Inicie sessão para personalizar os cartões dos anúncios.',
    );
    return;
  }
  final saved = await showDialog<bool>(
    context: context,
    builder: (_) =>
        _CardPreferencesDialog(cubit: getIt<ListingCardPreferencesCubit>()),
  );
  if (saved == true && context.mounted) {
    showMessage(ScaffoldMessenger.of(context), 'Cartões atualizados');
  }
}

class ListingCardPreferencesTile extends StatelessWidget {
  const ListingCardPreferencesTile({required this.signedIn, super.key});

  final bool signedIn;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: const Icon(Icons.view_agenda_outlined),
    title: const Text('Cartões dos anúncios'),
    subtitle: Text(
      signedIn
          ? 'Escolha os detalhes apresentados em Ofertas e Favoritos'
          : 'Disponível com sessão iniciada',
    ),
    trailing: const Icon(Icons.chevron_right),
    enabled: signedIn,
    onTap: () => showListingCardPreferences(context),
  );
}

class _CardPreferencesDialog extends StatefulWidget {
  const _CardPreferencesDialog({required this.cubit});

  final ListingCardPreferencesCubit cubit;

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
    if (saved && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocConsumer<ListingCardPreferencesCubit, ListingCardPreferencesState>(
    bloc: widget.cubit,
    listener: (context, state) {
      if (state.userId != _userId) Navigator.of(context).pop();
    },
    builder: (context, state) {
      final preferences = _draft ?? state.preferences;
      final ready = state.status == ListingCardPreferencesStatus.success;
      return AlertDialog(
        scrollable: true,
        title: const Text('Cartões dos anúncios'),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Escolha os detalhes apresentados em Ofertas e Favoritos, '
                'quando disponíveis. As escolhas ficam guardadas na sua '
                'conta, em todos os dispositivos.',
              ),
              const SizedBox(height: 12),
              const Text(
                'A fotografia, o modelo, o preço, o estado e as ações '
                'ficam sempre visíveis.',
              ),
              const SizedBox(height: 12),
              if (state.status == ListingCardPreferencesStatus.loading)
                const Center(child: CircularProgressIndicator())
              else if (ready) ...[
                for (final field in ListingCardField.values)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(field.label),
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
                  child: const Text('Repor predefinições'),
                ),
              ],
              if (state.error case final error?) ...[
                const SizedBox(height: 8),
                Text(error, style: AppTheme.errorText(context)),
                if (state.status == ListingCardPreferencesStatus.failure)
                  TextButton(
                    onPressed: widget.cubit.load,
                    child: const Text('Tentar novamente'),
                  ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: state.saving ? null : () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: ready && !state.saving ? _save : null,
            child: Text(state.saving ? 'A guardar…' : 'Guardar'),
          ),
        ],
      );
    },
  );
}
