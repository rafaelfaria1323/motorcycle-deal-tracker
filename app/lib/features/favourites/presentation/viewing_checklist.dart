import '../domain/entities/favourite.dart';
import '../../../core/formatting/formatters.dart';
import '../../../core/localization/localizations.dart';
import '../../listings/domain/entities/listing.dart';
import '../../listings/presentation/recall_text.dart';
import '../../valuation/presentation/ownership_cost.dart';

/// One thing to look at when seeing a bike. [key] is what the database
/// stores (never change it; a new item gets a new key).
class const ChecklistItem(
  final String key,
  final String title,
  final String hint,
);

class const ChecklistSection(
  final String title,
  final List<ChecklistItem> items,
);

final _checklists = <AppLanguage, List<ChecklistSection>>{};
final _checklistItems = <AppLanguage, List<ChecklistItem>>{};

/// The checklist for [listing]: the same points for every bike, then
/// "Nesta mota" when the bike has points of its own
/// ([bikeChecklistItems], N.64).
List<ChecklistSection> viewingChecklist({
  AppLanguage language = .portuguese,
  Listing? listing,
}) {
  final own = listing == null
      ? const <ChecklistItem>[]
      : bikeChecklistItems(listing, language: language);
  final general = _generalChecklist(language);
  return own.isEmpty
      ? general
      : [...general, ChecklistSection(language.messages.onThisBike, own)];
}

List<ChecklistSection> _generalChecklist(AppLanguage language) =>
    _checklists.putIfAbsent(
      language,
      () => List<ChecklistSection>.unmodifiable([
        ChecklistSection(
          language.messages.documents,
          List<ChecklistItem>.unmodifiable([
            ChecklistItem(
              'documents',
              language.messages.vehicleRegistrationDocumentDUA,
              language.messages.bikeSFrameNumberVINAndRegistrationMatch,
            ),
            ChecklistItem(
              'registry',
              language.messages.registrationCertificate,
              language.messages.checklistRegistryHint,
            ),
            ChecklistItem(
              'service',
              language.messages.servicing,
              language.messages.checklistServiceHint,
            ),
            ChecklistItem(
              'keys',
              language.messages.keys,
              language.messages.allKeysIncludingSpare,
            ),
          ]),
        ),
        ChecklistSection(
          language.messages.bikeCondition,
          List<ChecklistItem>.unmodifiable([
            ChecklistItem(
              'fall',
              language.messages.signsOfFall,
              language.messages.checklistBodyworkHint,
            ),
            ChecklistItem(
              'tyres',
              language.messages.tyres,
              language.messages.checklistTyresHint,
            ),
            ChecklistItem(
              'chain',
              language.messages.chainAndSprockets,
              language.messages.correctSlackNoRustOrStiffLinksSprocket,
            ),
            ChecklistItem(
              'brakes',
              language.messages.brakesAndDiscs,
              language.messages.padsHaveMaterialLeftDiscsHaveNoDeep,
            ),
            ChecklistItem(
              'suspension',
              language.messages.suspension,
              language.messages.noOilOnForkLegsSealsAndNo,
            ),
          ]),
        ),
        ChecklistSection(
          language.messages.running,
          List<ChecklistItem>.unmodifiable([
            ChecklistItem(
              'cold_start',
              language.messages.coldStart,
              language.messages.askSellerNotToStartBikeBeforeYou,
            ),
            ChecklistItem(
              'electrics',
              language.messages.lightsAndElectrics,
              language.messages.checklistLightsHint,
            ),
            ChecklistItem(
              'test_ride',
              language.messages.testRide,
              language.messages.gearsEngageCleanlyClutchDoesNotSlipAnd,
            ),
          ]),
        ),
      ]),
    );

List<ChecklistItem> viewingChecklistItems({
  AppLanguage language = .portuguese,
  Listing? listing,
}) {
  final general = _checklistItems.putIfAbsent(
    language,
    () => List<ChecklistItem>.unmodifiable([
      for (final section in _generalChecklist(language)) ...section.items,
    ]),
  );
  final own = listing == null
      ? const <ChecklistItem>[]
      : bikeChecklistItems(listing, language: language);
  return own.isEmpty ? general : [...general, ...own];
}

/// The risk reasons that ask for the import's papers.
const _importReasons = {
  'imported',
  'not_legalised',
  'not_legalised_outside_eu',
};

/// The risk reasons that put the mileage in doubt.
const _mileageReasons = {
  'mileage_lowered',
  'suspicious_mileage',
  'text_mileage_mismatch',
};

/// The valve check is asked for from this share of the model's interval.
const valveCheckShare = 0.8;

/// The points of this bike alone (N.64), from its model's figures and what
/// its ad says, never from a list typed per model: the valve check when the
/// mileage reaches the model's interval, the model's tyre sizes, a sports
/// bike's fairings, the A2 version's papers, an import's papers and a
/// mileage in doubt, and each EU recall that can cover its year (N.86,
/// `recall:<case number>`). Keys never change, as the general items'.
List<ChecklistItem> bikeChecklistItems(
  Listing listing, {
  AppLanguage language = .portuguese,
}) {
  final m = language.messages;
  final reasons = listing.riskReasons.toSet();
  final maintenance = listing.maintenance;
  final valveKm = maintenance?.valveCheckKm;
  final mileage = listing.mileage;
  String km(int value) => Formatters.mileage(value, language: language);
  return [
    if ((valveKm, mileage) case (final every?, final now?)
        when now >= every * valveCheckShare)
      ChecklistItem(
        'valve_check',
        m.checklistValveCheck,
        m.checklistValveCheckHint(interval: km(every), mileage: km(now)),
      ),
    if ((maintenance?.frontTyre, maintenance?.rearTyre) case (
      final front?,
      final rear?,
    ))
      ChecklistItem(
        'tyre_sizes',
        m.checklistTyreSizes,
        m.checklistTyreSizesHint(front: front, rear: rear),
      ),
    if (isSportBike(brand: listing.brand, model: listing.model))
      ChecklistItem('fairings', m.checklistFairings, m.checklistFairingsHint),
    if (reasons.contains('a2_limited') || reasons.contains('a2_unlocked'))
      ChecklistItem(
        'a2_version',
        m.checklistA2Version,
        m.checklistA2VersionHint,
      ),
    if (reasons.any(_importReasons.contains))
      ChecklistItem(
        'import_papers',
        m.checklistImportPapers,
        m.checklistImportPapersHint,
      ),
    if (reasons.any(_mileageReasons.contains))
      ChecklistItem('odometer', m.checklistOdometer, m.checklistOdometerHint),
    for (final recall in listing.recalls)
      if (recall.applies)
        if (recallChecklistText(recall, language: language) case (
          :final title,
          :final hint,
        ))
          ChecklistItem('recall:${recall.caseNumber}', title, hint),
  ];
}

/// The marks of the items still on the list (keys of items taken out
/// later, or of a bike's points that no longer apply, are ignored).
Iterable<ChecklistMark> _marks(
  Map<String, ChecklistEntry> checklist, {
  AppLanguage language = .portuguese,
  Listing? listing,
}) => [
  for (final item in viewingChecklistItems(
    language: language,
    listing: listing,
  ))
    ?checklist[item.key]?.mark,
];

/// "12 pontos para ver na visita", "3 de 12 vistos · 1 problema",
/// "Tudo visto, sem problemas".
String checklistSummaryText(
  Map<String, ChecklistEntry> checklist, {
  AppLanguage language = .portuguese,
  Listing? listing,
}) {
  final total = viewingChecklistItems(
    language: language,
    listing: listing,
  ).length;
  final marks = _marks(
    checklist,
    language: language,
    listing: listing,
  ).toList();
  if (marks.isEmpty) {
    return language.messages.pointsToCheckAtViewing(total: (total).toString());
  }
  final issues = marks.where((m) => m == .issue).length;
  final issuesText = language.messages.problems(issues: issues);
  if (marks.length == total) {
    return issues == 0
        ? language.messages.everythingCheckedNoProblems
        : language.messages.everythingChecked(issuesText: issuesText);
  }
  final seen = language.messages.ofChecked(
    length: marks.length.toString(),
    total: (total).toString(),
  );
  return issues == 0 ? seen : '$seen · $issuesText';
}

/// The titles of the items marked as a problem, in list order, for the
/// Favoritos page: "Problemas: Pneus, Travões e discos". Null without any.
String? checklistIssuesText(
  Map<String, ChecklistEntry> checklist, {
  AppLanguage language = .portuguese,
  Listing? listing,
}) {
  final titles = [
    for (final item in viewingChecklistItems(
      language: language,
      listing: listing,
    ))
      if (checklist[item.key]?.mark == .issue) item.title,
  ];
  if (titles.isEmpty) return null;
  return '${language.messages.checklistIssuesHeading(count: titles.length)}: '
      '${titles.join(', ')}';
}
