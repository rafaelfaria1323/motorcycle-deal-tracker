import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../app/di/injection.dart';
import '../../../../app/router/app_routes.dart';
import '../../domain/entities/catalog_model.dart';
import '../../domain/entities/shared_listing_draft.dart';
import '../../domain/repositories/catalog_repository.dart';
import '../../domain/repositories/shared_listings_repository.dart';
import '../cubit/listings_cubit.dart';
import '../share_script.dart';
import '../shared_listing_text.dart';

/// Saves an ad from a site the collector does not read (Facebook
/// Marketplace, CustoJusto, any other). Opened from Mais, or by the iPhone
/// share button with the ad's details in the address ([query]).
class AddListingPage extends StatefulWidget {
  const AddListingPage({this.query = const {}, super.key});

  final Map<String, String> query;

  @override
  State<AddListingPage> createState() => _AddListingPageState();
}

class _AddListingPageState extends State<AddListingPage> {
  late final SharedPrefill _prefill = sharedPrefill(widget.query);
  late final _link = TextEditingController(text: _prefill.link);
  late final _price = TextEditingController(
    text: _prefill.price?.round().toString() ?? '',
  );
  late final _year = TextEditingController(
    text: _prefill.year?.toString() ?? '',
  );
  late final _mileage = TextEditingController(
    text: _prefill.mileage?.toString() ?? '',
  );
  late final _location = TextEditingController(text: _prefill.location);
  late final _description = TextEditingController(text: _prefill.description);

  List<CatalogModel>? _models;
  bool _modelsFailed = false;
  String? _modelId;
  String _sellerType = 'unknown';
  Map<String, String> _problems = const {};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadModels();
  }

  Future<void> _loadModels() async {
    try {
      final all = await getIt<CatalogRepository>().getModels();
      final tracked =
          [
            for (final m in all)
              if (m.isTracked) m,
          ]..sort(
            (a, b) =>
                '${a.brand} ${a.model}'.compareTo('${b.brand} ${b.model}'),
          );
      if (!mounted) return;
      setState(() {
        _models = tracked;
        _modelId =
            (guessModel(_prefill.title, tracked) ??
                    guessModel(_prefill.description, tracked))
                ?.id;
      });
    } on Object {
      if (mounted) setState(() => _modelsFailed = true);
    }
  }

  @override
  void dispose() {
    for (final c in [_link, _price, _year, _mileage, _location, _description]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final problems = sharedListingProblems(
      link: _link.text,
      modelId: _modelId,
      price: _price.text,
      year: _year.text,
      mileage: _mileage.text,
    );
    setState(() => _problems = problems);
    if (problems.isNotEmpty) return;

    final source = sharedSource(_link.text)!;
    String? optional(TextEditingController c) =>
        c.text.trim().isEmpty ? null : c.text.trim();
    final draft = SharedListingDraft(
      source: source.source,
      sourceListingId: source.sourceListingId,
      url: source.url,
      motorcycleId: _modelId!,
      price: parseAmount(_price.text)!,
      year: int.tryParse(_year.text.trim()),
      mileage: int.tryParse(
        _mileage.text.trim().replaceAll(RegExp(r'[ .]'), ''),
      ),
      location: optional(_location),
      sellerType: _sellerType,
      description: optional(_description),
      images: [?_prefill.image],
    );

    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final id = await getIt<SharedListingsRepository>().save(draft);
      // Ofertas shows it at once.
      getIt<ListingsCubit>().load();
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Anúncio guardado.')),
      );
      context.go(AppRoutes.listingDetail(id));
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            sharedSaveErrorText(e is PostgrestException ? e.code : null),
          ),
        ),
      );
    }
  }

  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.deals);
    }
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    String? problemKey,
    String? helper,
    TextInputType? keyboard,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: keyboard,
        maxLines: maxLines,
        minLines: 1,
        decoration: InputDecoration(
          labelText: label,
          helperText: helper,
          helperMaxLines: 3,
          errorText: problemKey == null ? null : _problems[problemKey],
          errorMaxLines: 3,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final signedIn = user != null && !user.isAnonymous;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Adicionar anúncio'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Fechar',
          onPressed: _close,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!signedIn)
            const Card(
              child: ListTile(
                leading: Icon(Icons.lock_outline),
                title: Text('Inicie sessão para guardar anúncios'),
                subtitle: Text(
                  'Em Mais › Conta. No Safari, a sessão é separada da app '
                  'do ecrã principal: inicie-a uma vez aqui também.',
                ),
              ),
            ),
          if (_prefill.title.isNotEmpty) ...[
            Text(_prefill.title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
          ],
          Text(
            'Para anúncios do Facebook Marketplace, do CustoJusto ou de outro '
            'site. Confirme os dados: o anúncio passa a ter pontuação e '
            'aparece nas Ofertas.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          _field(
            _link,
            'Endereço do anúncio',
            problemKey: 'link',
            keyboard: TextInputType.url,
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _modelsFailed
                ? Text(
                    'Não foi possível carregar os modelos. Tente novamente.',
                    style: TextStyle(color: theme.colorScheme.error),
                  )
                // Built once the models are in, so the guessed model shows.
                : _models == null
                ? const LinearProgressIndicator()
                : DropdownButtonFormField<String>(
                    initialValue: _modelId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Modelo',
                      errorText: _problems['model'],
                      helperText: 'Só modelos acompanhados.',
                    ),
                    items: [
                      for (final m in _models!)
                        DropdownMenuItem(
                          value: m.id,
                          child: Text('${m.brand} ${m.model}'),
                        ),
                    ],
                    onChanged: (id) => setState(() => _modelId = id),
                  ),
          ),
          _field(
            _price,
            'Preço (€)',
            problemKey: 'price',
            keyboard: TextInputType.number,
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _field(
                  _year,
                  'Ano',
                  problemKey: 'year',
                  keyboard: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _field(
                  _mileage,
                  'Km',
                  problemKey: 'mileage',
                  keyboard: TextInputType.number,
                ),
              ),
            ],
          ),
          _field(_location, 'Localização'),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'private', label: Text('Particular')),
                ButtonSegment(value: 'dealer', label: Text('Profissional')),
                ButtonSegment(value: 'unknown', label: Text('Não sei')),
              ],
              selected: {_sellerType},
              onSelectionChanged: (s) => setState(() => _sellerType = s.first),
            ),
          ),
          _field(
            _description,
            'Descrição',
            helper: 'Ajuda o Risk Score (acidentes, revisões, donos).',
            maxLines: 8,
          ),
          const SizedBox(height: 4),
          FilledButton(
            onPressed: signedIn && !_saving ? _save : null,
            child: Text(_saving ? 'A guardar…' : 'Guardar'),
          ),
          const SizedBox(height: 24),
          const _ShareButtonHelp(),
        ],
      ),
    );
  }
}

/// How to make the iPhone share button that opens this page filled in.
class _ShareButtonHelp extends StatelessWidget {
  const _ShareButtonHelp();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const steps = [
      'No iPhone, abra a app Atalhos e toque em + para criar um atalho.',
      'Adicione a ação "Executar JavaScript na página web" e cole o script '
          '(botão abaixo).',
      'Adicione a ação "Abrir URL", que usa o resultado do script.',
      'Nos detalhes do atalho, ative "Mostrar na folha de partilha", deixe '
          'só "Páginas web do Safari" e chame-lhe "Guardar no Deal Tracker".',
      'Em Definições › Apps › Atalhos › Avançado, ative a execução de '
          'scripts.',
    ];

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: const Icon(Icons.ios_share),
        title: const Text('Botão de partilha no iPhone'),
        subtitle: const Text('Guardar um anúncio a partir do Safari'),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (i, step) in steps.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text('${i + 1}. $step'),
            ),
          const SizedBox(height: 4),
          Text(
            'Depois: abra o anúncio no Safari (no Facebook, "Copiar link" e '
            'abrir no Safari), toque em Partilhar › Guardar no Deal Tracker. '
            'Esta página abre preenchida com o título, o preço, a descrição, '
            'o local e a foto; o nome do vendedor nunca é lido.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.copy),
            label: const Text('Copiar script'),
            onPressed: () async {
              await Clipboard.setData(
                ClipboardData(text: shareScript(Uri.base.origin)),
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Script copiado.')),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}
