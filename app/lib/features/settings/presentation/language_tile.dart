import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/di/injection.dart';
import '../../../core/localization/localizations.dart';
import 'language_cubit.dart';

String _languageName(AppLanguage language, AppLocalizations strings) =>
    switch (language) {
      AppLanguage.portuguese => strings.languageNamePortuguese,
      AppLanguage.english => strings.languageNameEnglish,
    };

class LanguageTile extends StatelessWidget {
  const LanguageTile({super.key});

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<LanguageCubit, LanguageState>(
        bloc: getIt<LanguageCubit>(),
        builder: (context, state) {
          final strings = context.strings;
          return ListTile(
            leading: const Icon(Icons.language),
            title: Text(strings.languageTitle),
            subtitle: Text(
              state.failure == LanguageFailure.load
                  ? strings.languageLoadFailed
                  : _languageName(state.language, strings),
            ),
            trailing: state.loading || state.saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : state.failure == LanguageFailure.load
                ? IconButton(
                    tooltip: strings.retry,
                    icon: const Icon(Icons.refresh),
                    onPressed: getIt<LanguageCubit>().load,
                  )
                : const Icon(Icons.chevron_right),
            enabled: !state.loading && !state.saving,
            onTap: () => showDialog<void>(
              context: context,
              builder: (_) => const _LanguageDialog(),
            ),
          );
        },
      );
}

class _LanguageDialog extends StatelessWidget {
  const _LanguageDialog();

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<LanguageCubit, LanguageState>(
        bloc: getIt<LanguageCubit>(),
        builder: (context, state) {
          final strings = context.strings;
          final busy = state.loading || state.saving;
          return SimpleDialog(
            title: Text(strings.languageTitle),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(strings.languageHelp),
              ),
              RadioGroup<AppLanguage>(
                groupValue: state.language,
                onChanged: (language) async {
                  if (language == null || busy) return;
                  final saved = await getIt<LanguageCubit>().select(language);
                  if (saved && context.mounted) Navigator.of(context).pop();
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final language in AppLanguage.values)
                      RadioListTile<AppLanguage>(
                        value: language,
                        enabled: !busy,
                        title: Text(_languageName(language, strings)),
                      ),
                  ],
                ),
              ),
              if (busy) const Center(child: CircularProgressIndicator()),
              if (state.failure == LanguageFailure.save)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    strings.languageSaveFailed,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
            ],
          );
        },
      );
}
