import 'dart:async';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/di/injection.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/formatting/formatters.dart';
import '../../../../core/localization/localizations.dart';
import '../../../../core/widgets/page_back_button.dart';
import '../../../../core/widgets/page_intro.dart';
import '../../../../core/widgets/section_card.dart';
import '../../../../core/widgets/show_message.dart';
import '../../../../core/widgets/state_message.dart';
import '../../domain/repositories/shared_ads_repository.dart';
import '../shortcut_script.dart';

/// Mais › "Atalho do iPhone" (N.110): the account's key for the shortcut
/// "Avaliar no Deal Tracker", the three values the shortcut needs, and how
/// to make it. The key is shown once, inside the script, when it is made:
/// only its fingerprint is kept.
class const AdShortcutPage({super.key}) extends StatefulWidget {
  @override
  State<AdShortcutPage> createState() => _AdShortcutPageState();
}

class _AdShortcutPageState extends State<AdShortcutPage> {
  final _repository = getIt<SharedAdsRepository>();
  late Future<DateTime?> _created = _repository.keyCreatedAt();

  /// The key just made, shown until the page closes.
  String? _key;
  bool _busy = false;

  Future<void> _createKey() async {
    final messenger = ScaffoldMessenger.of(context);
    final failed = context.strings.adShortcutCouldNotChange;
    setState(() => _busy = true);
    try {
      final key = await _repository.createKey();
      if (!mounted) return;
      setState(() {
        _key = key;
        _created = _repository.keyCreatedAt();
      });
    } catch (_) {
      showMessage(messenger, failed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _removeKey() async {
    final strings = context.strings;
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(strings.adShortcutRemoveConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(strings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(strings.adShortcutRemoveKey),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await _repository.removeKey();
      if (!mounted) return;
      setState(() {
        _key = null;
        _created = _repository.keyCreatedAt();
      });
    } catch (_) {
      showMessage(messenger, strings.adShortcutCouldNotChange);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return Scaffold(
      appBar: AppBar(leading: const PageBackButton()),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          PageIntro(
            eyebrow: strings.bikeValueTools,
            title: strings.adShortcutTitle,
            description: strings.adShortcutIntro,
          ),
          const SizedBox(height: 20),
          FutureBuilder<DateTime?>(
            future: _created,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return StateMessage(
                  icon: Icons.cloud_off_outlined,
                  title: strings.adShortcutCouldNotLoad,
                  actionLabel: strings.retry,
                  onAction: () =>
                      setState(() => _created = _repository.keyCreatedAt()),
                );
              }
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              return _keyCard(context, snapshot.data);
            },
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: strings.adShortcutStepsTitle,
            footnote: strings.adShortcutLimits,
            children: [
              for (final (index, step) in [
                strings.adShortcutStep1,
                strings.adShortcutStep2,
                strings.adShortcutStep3,
                strings.adShortcutStep4,
                strings.adShortcutStep5,
                strings.adShortcutStep6,
                strings.adShortcutStep7,
                strings.adShortcutStep8,
                strings.adShortcutStep9,
                strings.adShortcutStep10,
                strings.adShortcutStep11,
                strings.adShortcutStep12,
              ].indexed)
                _Step(number: index + 1, text: step),
              const SizedBox(height: 8),
              _Note(text: strings.adShortcutFacebookApp),
            ],
          ),
        ],
      ),
    );
  }

  Widget _keyCard(BuildContext context, DateTime? created) {
    final strings = context.strings;
    final key = _key;
    return SectionCard(
      title: strings.adShortcutKeyTitle,
      children: [
        if (key != null) ...[
          Text(strings.adShortcutKeyShown),
          const SizedBox(height: 12),
          _CopyField(
            label: strings.adShortcutScript,
            value: sharedAdScript(key),
            maxLines: 6,
          ),
          const SizedBox(height: 12),
          _CopyField(
            label: strings.adShortcutAddress,
            value: sharedAdReceiveUrl,
          ),
          const SizedBox(height: 12),
          _CopyField(label: strings.adShortcutApiKey, value: sharedAdApiKey),
        ] else if (created != null)
          Text(strings.adShortcutKeySince(date: Formatters.date(created)))
        else
          Text(strings.adShortcutNoKey),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: _busy ? null : () => unawaited(_createKey()),
              icon: const Icon(Icons.key),
              label: Text(
                created == null
                    ? strings.adShortcutCreateKey
                    : strings.adShortcutNewKey,
              ),
            ),
            if (created != null)
              OutlinedButton(
                onPressed: _busy ? null : () => unawaited(_removeKey()),
                child: Text(strings.adShortcutRemoveKey),
              ),
          ],
        ),
      ],
    );
  }
}

/// One value the shortcut needs, as read-only text with a copy button.
class const _CopyField({
  required final String label,
  required final String value,
  final int maxLines = 2,
}) extends StatelessWidget {
  Future<void> _copy(BuildContext context) async {
    final strings = context.strings;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await Clipboard.setData(ClipboardData(text: value));
      showMessage(messenger, strings.adShortcutCopied);
    } catch (_) {
      showMessage(messenger, strings.couldNotCopySelectTextInstead);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: theme.textTheme.titleSmall)),
            TextButton.icon(
              onPressed: () => unawaited(_copy(context)),
              icon: const Icon(Icons.copy),
              label: Text(context.strings.adShortcutCopy),
            ),
          ],
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: SelectableText(
              value,
              maxLines: maxLines,
              style: theme.textTheme.bodySmall,
            ),
          ),
        ),
      ],
    );
  }
}

/// A numbered step of the setup.
class const _Step({required final int number, required final String text})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '$number.',
              style: theme.textTheme.titleSmall?.copyWith(
                fontFeatures: AppTheme.tabularFigures,
              ),
            ),
          ),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

/// A note under the steps.
class const _Note({required final String text}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.info_outline,
          size: 20,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
