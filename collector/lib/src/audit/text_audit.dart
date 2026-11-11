import '../catalog/catalog.dart';

/// The weekly description check (N.55): what the database's rules read from
/// an ad's text set against what an LLM reads, field by field. The
/// disagreements are a report for fixing the rules (each fix with a test);
/// nothing the LLM says reaches a score, a listing or an alert.

/// The extras the rules read (`listing_extras` codes, in its order of
/// rules), with what each means for the LLM. `text_audit_test.dart` checks
/// the codes against `supabase/schema.sql`.
const auditExtras = {
  'quickshifter': 'quickshifter or auto-blipper',
  'exhaust': 'aftermarket or sport exhaust (Akrapovič, Termignoni, ...)',
  'luggage': 'top case, side cases, panniers, tank bag or luggage rack',
  'heated_grips': 'heated grips',
  'protection':
      'crash pads/bars, frame sliders, radiator guard, engine or other '
      'protectors',
  'new_tyres': 'new or recently changed tyres',
  'tail_tidy': 'short or sport licence plate holder (tail tidy)',
  'screen': 'tinted, sport, touring or aftermarket windscreen',
  'levers': 'adjustable, short or aftermarket brake/clutch levers',
  'mirrors': 'bar-end mirrors',
  'phone_mount': 'phone/GPS mount or USB charger',
  'alarm': 'alarm or GPS tracker',
  'steering_damper': 'steering damper',
  'centre_stand': 'centre stand',
  'cruise_control': 'cruise control',
  'suspension': 'upgraded or tuned suspension (Öhlins, K-Tech, ...)',
  'led_indicators': 'LED indicators',
  'passenger_grips': 'passenger grab handles or rails',
  'original_parts': 'the original parts that were replaced come with it',
};

/// The A2 (35 kW) answers.
const powerValues = ['none', 'a2_limited', 'a2_unlocked'];

/// The legalisation answers; the last two are the rules' risk codes.
const legalisationValues = [
  'legalised',
  'not_legalised',
  'not_legalised_outside_eu',
];

/// An ad of the week with what the rules read (`text_audit_sample`).
class const AuditListing({
  required final String id,
  required final String url,
  final String? variant,
  required final String description,
  final List<String> signals = const [],
  final List<String> extras = const [],
  final int? mileageInText,
}) {
  factory AuditListing.fromRow(Map<String, dynamic> row) => AuditListing(
    id: row['id'] as String,
    url: row['url'] as String,
    variant: row['variant'] as String?,
    description: row['description'] as String? ?? '',
    signals: List<String>.from(row['signals'] as List? ?? const []),
    extras: List<String>.from(row['extras'] as List? ?? const []),
    mileageInText: (row['mileage_in_text'] as num?)?.toInt(),
  );

  /// What the rules read, as a [TextReading].
  TextReading get rules => TextReading(
    accident: signals.contains('possible_accident'),
    needsRepair: signals.contains('needs_repair'),
    cosmeticDamage: signals.contains('cosmetic_damage'),
    power: powerValues.firstWhere(signals.contains, orElse: () => 'none'),
    singleOwner: signals.contains('single_owner_in_text'),
    legalisation: legalisationValues.lastWhere(
      signals.contains,
      orElse: () => 'legalised',
    ),
    extras: extras.toSet(),
    mileageKm: mileageInText,
  );
}

/// What an ad's text says, as the rules or the LLM read it.
class const TextReading({
  required final bool accident,
  required final bool needsRepair,
  required final bool cosmeticDamage,
  required final String power,
  required final bool singleOwner,
  required final String legalisation,
  required final Set<String> extras,
  final int? mileageKm,

  /// The LLM's quotes, by field name ([Disagreement.field], or an extra's
  /// code).
  final Map<String, String> evidence = const {},
}) {
  /// One ad of the LLM's answer (see [descriptionSchema]); unknown values
  /// read as the plain answer, unknown extras are dropped.
  factory TextReading.fromJson(Map<String, Object?> json) {
    final evidence = <String, String>{};
    for (final Object? item in json['evidence'] as List? ?? const []) {
      if (item case {'field': final String f, 'quote': final String q}) {
        evidence[f] = q;
      }
    }
    final power = json['power'];
    final legalisation = json['legalisation'];
    return TextReading(
      accident: json['accident'] == true,
      needsRepair: json['needs_repair'] == true,
      cosmeticDamage: json['cosmetic_damage'] == true,
      power: powerValues.contains(power) ? power! as String : 'none',
      singleOwner: json['single_owner'] == true,
      legalisation: legalisationValues.contains(legalisation)
          ? legalisation! as String
          : 'legalised',
      extras: {
        for (final Object? e in json['extras'] as List? ?? const [])
          if (e is String && auditExtras.containsKey(e)) e,
      },
      mileageKm: switch (json['mileage_km']) {
        final num km when km > 0 => km.round(),
        _ => null,
      },
      evidence: evidence,
    );
  }
}

/// One field the rules and the LLM read differently. [missed]: the LLM read
/// something the rules didn't (for the mileage: a different number, or one
/// where the rules found none).
class const Disagreement({
  required final AuditListing listing,
  required final String field,
  required final String rules,
  required final String llm,
  required final bool missed,
  final String? quote,
});

/// The fields where [llm] differs from [listing]'s rules.
List<Disagreement> compareReadings(AuditListing listing, TextReading llm) {
  final rules = listing.rules;
  final found = <Disagreement>[];
  void add(String field, Object? r, Object? l, {required bool missed}) =>
      found.add(
        Disagreement(
          listing: listing,
          field: field,
          rules: '${r ?? '—'}',
          llm: '${l ?? '—'}',
          missed: missed,
          quote: llm.evidence[field],
        ),
      );
  void flag(String field, bool r, bool l) {
    if (r != l) add(field, r ? 'yes' : 'no', l ? 'yes' : 'no', missed: l);
  }

  flag('accident', rules.accident, llm.accident);
  flag('needs_repair', rules.needsRepair, llm.needsRepair);
  flag('cosmetic_damage', rules.cosmeticDamage, llm.cosmeticDamage);
  flag('single_owner', rules.singleOwner, llm.singleOwner);
  if (rules.power != llm.power) {
    add('power', rules.power, llm.power, missed: llm.power != 'none');
  }
  if (rules.legalisation != llm.legalisation) {
    add(
      'legalisation',
      rules.legalisation,
      llm.legalisation,
      missed: llm.legalisation != 'legalised',
    );
  }
  for (final code in auditExtras.keys) {
    final r = rules.extras.contains(code);
    final l = llm.extras.contains(code);
    if (r != l) {
      found.add(
        Disagreement(
          listing: listing,
          field: 'extra:$code',
          rules: r ? 'yes' : 'no',
          llm: l ? 'yes' : 'no',
          missed: l,
          quote: llm.evidence[code] ?? llm.evidence['extras'],
        ),
      );
    }
  }
  final (r, l) = (rules.mileageKm, llm.mileageKm);
  // Within 1 % ("12 000" read as 11 990 by a rounding seller) is the same.
  if (r != l && (r == null || l == null || (r - l).abs() > r * 0.01)) {
    add('mileage_km', r, l, missed: l != null);
  }
  return found;
}

/// The prompt for one batch of ads, numbered from 1 (the answer's ids).
String descriptionPrompt(List<AuditListing> listings) {
  final ads = StringBuffer();
  for (final (i, l) in listings.indexed) {
    ads
      ..writeln('--- Ad ${i + 1} ---')
      ..writeln('Title: ${l.variant ?? ''}')
      ..writeln('Description: ${l.description}');
  }
  final extras = [
    for (final MapEntry(:key, :value) in auditExtras.entries) '- $key: $value',
  ].join('\n');
  return '''
You read Portuguese used-motorcycle ads. For each ad below, say what its
title and description state about the bike being sold. Count only what the
seller states as a fact about this bike: denials ("nunca caiu", "sem
riscos"), possibilities ("pode ser limitada") and offers to do something
are not facts. Answer every ad, with its number as "id".

- accident: the bike had an accident, a fall or a knock.
- needs_repair: something needs repairing or replacing, is broken or
  missing, or the bike is sold for parts.
- cosmetic_damage: it has scratches, scuffs or dents.
- power: "a2_limited" if it is restricted to 35 kW (A2 licence) now,
  "a2_unlocked" if it was restricted and is now full power, else "none".
- single_owner: it has had only one owner (first or only owner).
- legalisation: "not_legalised" if it is not yet registered in Portugal
  (foreign plates not said to be legalised, "por legalizar"),
  "not_legalised_outside_eu" if so and it comes from outside the EU (UK,
  Switzerland, Norway, ...), else "legalised".
- extras: the equipment it comes with, only from this list:
$extras
- mileage_km: the bike's mileage in km stated in the description, or null
  if none or the description gives two different figures.
- evidence: for each item you answered yes, other than "none" or
  "legalised", or with a mileage, its field name (an extra by its code)
  and the words of the ad that say it, at most 15 words.

$ads''';
}

/// The answer's shape for [descriptionPrompt] (Gemini's `responseSchema`).
Map<String, Object?> get descriptionSchema => {
  'type': 'ARRAY',
  'items': {
    'type': 'OBJECT',
    'properties': {
      'id': {'type': 'INTEGER'},
      'accident': {'type': 'BOOLEAN'},
      'needs_repair': {'type': 'BOOLEAN'},
      'cosmetic_damage': {'type': 'BOOLEAN'},
      'power': {'type': 'STRING', 'enum': powerValues},
      'single_owner': {'type': 'BOOLEAN'},
      'legalisation': {'type': 'STRING', 'enum': legalisationValues},
      'extras': {
        'type': 'ARRAY',
        'items': {'type': 'STRING', 'enum': auditExtras.keys.toList()},
      },
      'mileage_km': {'type': 'INTEGER', 'nullable': true},
      'evidence': _evidenceSchema,
    },
    'required': [
      'id',
      'accident',
      'needs_repair',
      'cosmetic_damage',
      'power',
      'single_owner',
      'legalisation',
      'extras',
      'mileage_km',
      'evidence',
    ],
  },
};

const _evidenceSchema = {
  'type': 'ARRAY',
  'items': {
    'type': 'OBJECT',
    'properties': {
      'field': {'type': 'STRING'},
      'quote': {'type': 'STRING'},
    },
    'required': ['field', 'quote'],
  },
};

/// The answer to [descriptionPrompt] matched to [listings]: by number,
/// ads missing from it or answered twice left out.
Map<AuditListing, TextReading> readDescriptionAnswer(
  List<AuditListing> listings,
  Object? answer,
) {
  final byNumber = <int, Map<String, Object?>>{};
  final repeated = <int>{};
  for (final item in answer is List ? answer : const <Object?>[]) {
    if (item case {'id': final num id} when id == id.roundToDouble()) {
      final n = id.toInt();
      if (byNumber.containsKey(n)) repeated.add(n);
      byNumber[n] = Map<String, Object?>.from(item);
    }
  }
  return {
    for (final (i, l) in listings.indexed)
      if (byNumber[i + 1] case final json? when !repeated.contains(i + 1))
        l: TextReading.fromJson(json),
  };
}

/// An ad no model matched (`unmatched_title_sample`).
class const UnmatchedTitle({
  required final String id,
  required final String url,
  required final String brand,
  required final String model,
  final String? variant,
}) {
  factory UnmatchedTitle.fromRow(Map<String, dynamic> row) => UnmatchedTitle(
    id: row['id'] as String,
    url: row['url'] as String,
    brand: row['brand'] as String,
    model: row['model'] as String,
    variant: row['variant'] as String?,
  );

  String get title => [
    brand,
    model,
    if (variant case final v? when v.isNotEmpty) v,
  ].join(' · ');
}

/// The prompt for one batch of unmatched titles against [catalog]'s
/// followed models, by their slugs.
String titlesPrompt(List<UnmatchedTitle> titles, Catalog catalog) {
  final models = [
    for (final e in catalog.entries)
      '- ${e.slug}: ${e.brand} ${e.model}'
          '${e.engineCcMin == null ? '' : ' (${e.engineCcMin}-${e.engineCcMax} cc)'}',
  ].join('\n');
  final ads = [for (final (i, t) in titles.indexed) '${i + 1}. ${t.title}']
      .join('\n');
  return '''
Each line below is a used-motorcycle ad from a Portuguese site: the brand
and model the site filed it under, then the seller's title. Say which of
these models the bike is, by its code, or null when it is none of them
(another model of the same family, a different engine size, or unclear).
Answer every line, with its number as "id", and quote the words that decide
it ("evidence", at most 10 words).

Models:
$models

Ads:
$ads''';
}

/// The answer's shape for [titlesPrompt].
Map<String, Object?> get titlesSchema => {
  'type': 'ARRAY',
  'items': {
    'type': 'OBJECT',
    'properties': {
      'id': {'type': 'INTEGER'},
      'model': {'type': 'STRING', 'nullable': true},
      'evidence': {'type': 'STRING'},
    },
    'required': ['id', 'model', 'evidence'],
  },
};

/// A title the rules couldn't place that the LLM reads as a followed model.
class const TitleSuggestion({
  required final UnmatchedTitle title,
  required final CatalogEntry model,
  final String? quote,
});

/// The titles of [titles] the answer to [titlesPrompt] places in one of
/// [catalog]'s models (unknown codes and nulls left out).
List<TitleSuggestion> readTitlesAnswer(
  List<UnmatchedTitle> titles,
  Catalog catalog,
  Object? answer,
) {
  final bySlug = {for (final e in catalog.entries) e.slug: e};
  final found = <TitleSuggestion>[];
  final seen = <int>{};
  for (final item in answer is List ? answer : const <Object?>[]) {
    if (item case {'id': final num id, 'model': final String slug}) {
      final n = id.toInt();
      final model = bySlug[slug];
      if (n < 1 || n > titles.length || model == null || !seen.add(n)) {
        continue;
      }
      found.add(
        TitleSuggestion(
          title: titles[n - 1],
          model: model,
          quote: switch (item['evidence']) {
            final String q when q.isNotEmpty => q,
            _ => null,
          },
        ),
      );
    }
  }
  return found;
}

/// The check's report, Markdown for the run's summary: how much was read,
/// then the disagreements by kind and field, then the titles.
String auditReport({
  required String model,
  required int adsAsked,
  required int adsRead,
  required List<Disagreement> disagreements,
  required int titlesAsked,
  required List<TitleSuggestion> titles,
  List<String> problems = const [],
}) {
  final out = StringBuffer()
    ..writeln('# Description check (N.55)')
    ..writeln()
    ..writeln(
      'Model `$model`: $adsRead of $adsAsked ad(s) read, '
      '$titlesAsked unmatched title(s) asked. The LLM can be wrong too: '
      'each line is a case to look at, not a fix.',
    );
  for (final p in problems) {
    out.writeln('- Problem: ${_cell(p)}');
  }
  final counts = <String, int>{};
  for (final d in disagreements) {
    counts.update(d.field, (n) => n + 1, ifAbsent: () => 1);
  }
  if (counts.isNotEmpty) {
    final byCount = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    out
      ..writeln()
      ..writeln(
        'By field: ${[for (final e in byCount) '${e.key} ${e.value}'].join(', ')}.',
      );
  }
  void table(String heading, Iterable<Disagreement> rows) {
    final list = rows.toList()..sort((a, b) => a.field.compareTo(b.field));
    out
      ..writeln()
      ..writeln('## $heading (${list.length})')
      ..writeln();
    if (list.isEmpty) {
      out.writeln('None.');
      return;
    }
    out
      ..writeln('| Field | Ad | Rules | LLM | The ad says |')
      ..writeln('|---|---|---|---|---|');
    for (final d in list) {
      out.writeln(
        '| ${d.field} | [ad](${d.listing.url}) | ${_cell(d.rules)} '
        '| ${_cell(d.llm)} | ${_cell(d.quote ?? '')} |',
      );
    }
  }

  table(
    'The rules missed (the LLM read it)',
    disagreements.where((d) => d.missed),
  );
  table(
    'The rules read more (the LLM did not)',
    disagreements.where((d) => !d.missed),
  );
  out
    ..writeln()
    ..writeln('## Unmatched titles of a followed model (${titles.length})')
    ..writeln();
  if (titles.isEmpty) {
    out.writeln('None.');
  } else {
    out
      ..writeln('| Title | LLM says | The title says |')
      ..writeln('|---|---|---|');
    for (final t in titles) {
      out.writeln(
        '| [${_cell(t.title.title)}](${t.title.url}) '
        '| ${t.model.brand} ${t.model.model} | ${_cell(t.quote ?? '')} |',
      );
    }
  }
  return out.toString();
}

/// [text] fit for a Markdown table cell: one line, no pipes, at most 140
/// characters.
String _cell(String text) {
  final line = text.replaceAll(RegExp(r'\s+'), ' ').replaceAll('|', '/').trim();
  return line.length <= 140 ? line : '${line.substring(0, 140)}…';
}
