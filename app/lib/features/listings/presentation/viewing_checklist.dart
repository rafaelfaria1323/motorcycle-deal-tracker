import '../domain/entities/favourite.dart';

/// One thing to look at when seeing a bike. [key] is what the database
/// stores (never change it; a new item gets a new key).
class ChecklistItem {
  const ChecklistItem(this.key, this.title, this.hint);

  final String key;
  final String title;
  final String hint;
}

class ChecklistSection {
  const ChecklistSection(this.title, this.items);

  final String title;
  final List<ChecklistItem> items;
}

/// What to check when seeing a used bike, in the order it is usually done:
/// the papers, the bike standing, then running.
const viewingChecklist = [
  ChecklistSection('Documentos', [
    ChecklistItem(
      'documents',
      'Documento Único (DUA)',
      'O número de quadro (VIN) e a matrícula da mota são os do documento, '
          'e quem vende é o proprietário.',
    ),
    ChecklistItem(
      'registry',
      'Certidão de registo',
      'Peça a certidão de registo automóvel: mostra penhoras, reservas de '
          'propriedade e crédito por pagar.',
    ),
    ChecklistItem(
      'service',
      'Revisões',
      'Livro com carimbos e faturas das revisões; os quilómetros batem certo '
          'com as datas.',
    ),
    ChecklistItem('keys', 'Chaves', 'Todas as chaves, incluindo a de reserva.'),
  ]),
  ChecklistSection('Estado da mota', [
    ChecklistItem(
      'fall',
      'Sinais de queda',
      'Manetes, poisa-pés, pontas do guiador e espelhos riscados ou dobrados; '
          'depósito amolgado; carenagens de cores diferentes.',
    ),
    ChecklistItem(
      'tyres',
      'Pneus',
      'Piso e data de fabrico (DOT: os quatro últimos dígitos são a semana e '
          'o ano). Com mais de 5 anos, conte com trocá-los.',
    ),
    ChecklistItem(
      'chain',
      'Corrente e cremalheira',
      'Folga certa, sem ferrugem nem elos presos; dentes da cremalheira '
          'sem ponta.',
    ),
    ChecklistItem(
      'brakes',
      'Travões e discos',
      'Pastilhas com material, discos sem sulcos fundos, manete firme.',
    ),
    ChecklistItem(
      'suspension',
      'Suspensões',
      'Bainhas da forqueta sem óleo (retentores) e amortecedor traseiro '
          'sem fugas.',
    ),
  ]),
  ChecklistSection('A trabalhar', [
    ChecklistItem(
      'cold_start',
      'Arranque a frio',
      'Peça para não ligarem a mota antes de chegar e ponha a mão no motor. '
          'Arranca bem, sem fumo, ruídos estranhos nem ralenti instável.',
    ),
    ChecklistItem(
      'electrics',
      'Luzes e elétrica',
      'Farol, piscas, luz de travão, buzina; painel sem avisos acesos.',
    ),
    ChecklistItem(
      'test_ride',
      'Experimentar a andar',
      'As mudanças entram sem falhas, a embraiagem não patina e a direção '
          'não tem folgas nem puxa para um lado.',
    ),
  ]),
];

/// Every item, in order.
final viewingChecklistItems = [
  for (final section in viewingChecklist) ...section.items,
];

/// The marks of the items still on the list (keys of items taken out
/// later are ignored).
Iterable<ChecklistMark> _marks(Map<String, ChecklistEntry> checklist) => [
  for (final item in viewingChecklistItems)
    if (checklist[item.key]?.mark case final mark?) mark,
];

/// "12 pontos para ver na visita", "3 de 12 vistos · 1 problema",
/// "Tudo visto, sem problemas".
String checklistSummaryText(Map<String, ChecklistEntry> checklist) {
  final total = viewingChecklistItems.length;
  final marks = _marks(checklist).toList();
  if (marks.isEmpty) return '$total pontos para ver na visita';
  final issues = marks.where((m) => m == ChecklistMark.issue).length;
  final issuesText = issues == 1 ? '1 problema' : '$issues problemas';
  if (marks.length == total) {
    return issues == 0
        ? 'Tudo visto, sem problemas'
        : 'Tudo visto · $issuesText';
  }
  final seen = '${marks.length} de $total vistos';
  return issues == 0 ? seen : '$seen · $issuesText';
}

/// The titles of the items marked as a problem, in list order, for the
/// Favoritos page: "Problemas: Pneus, Travões e discos". Null without any.
String? checklistIssuesText(Map<String, ChecklistEntry> checklist) {
  final titles = [
    for (final item in viewingChecklistItems)
      if (checklist[item.key]?.mark == ChecklistMark.issue) item.title,
  ];
  if (titles.isEmpty) return null;
  return '${titles.length == 1 ? 'Problema' : 'Problemas'}: '
      '${titles.join(', ')}';
}
