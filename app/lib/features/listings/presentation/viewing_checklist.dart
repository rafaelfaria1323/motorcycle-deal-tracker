import '../domain/entities/favourite.dart';
import '../../../core/localization/localizations.dart';

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

final _checklists = <AppLanguage, List<ChecklistSection>>{};
final _checklistItems = <AppLanguage, List<ChecklistItem>>{};

List<ChecklistSection> viewingChecklist({
  AppLanguage language = AppLanguage.portuguese,
}) => _checklists.putIfAbsent(
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
          language.messages.askForVehicleRegistrationCertificateItShowsLiens,
        ),
        ChecklistItem(
          'service',
          language.messages.servicing,
          language.messages.serviceBookStampsAndInvoicesMileageIsConsistent,
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
          language.messages.scratchedOrBentLeversFootrestsHandlebarEndsAnd,
        ),
        ChecklistItem(
          'tyres',
          language.messages.tyres,
          language.messages.treadAndManufactureDateDOTLastFourDigits,
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
          language.messages.headlightIndicatorsBrakeLightHornNoWarningLights,
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
  AppLanguage language = AppLanguage.portuguese,
}) => _checklistItems.putIfAbsent(
  language,
  () => List<ChecklistItem>.unmodifiable([
    for (final section in viewingChecklist(language: language))
      ...section.items,
  ]),
);

/// The marks of the items still on the list (keys of items taken out
/// later are ignored).
Iterable<ChecklistMark> _marks(
  Map<String, ChecklistEntry> checklist, {
  AppLanguage language = AppLanguage.portuguese,
}) => [
  for (final item in viewingChecklistItems(language: language))
    ?checklist[item.key]?.mark,
];

/// "12 pontos para ver na visita", "3 de 12 vistos · 1 problema",
/// "Tudo visto, sem problemas".
String checklistSummaryText(
  Map<String, ChecklistEntry> checklist, {
  AppLanguage language = AppLanguage.portuguese,
}) {
  final total = viewingChecklistItems(language: language).length;
  final marks = _marks(checklist, language: language).toList();
  if (marks.isEmpty) {
    return language.messages.pointsToCheckAtViewing(total: (total).toString());
  }
  final issues = marks.where((m) => m == ChecklistMark.issue).length;
  final issuesText = issues == 1
      ? language.messages.text1Problem
      : language.messages.problems(issues: (issues).toString());
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
  AppLanguage language = AppLanguage.portuguese,
}) {
  final titles = [
    for (final item in viewingChecklistItems(language: language))
      if (checklist[item.key]?.mark == ChecklistMark.issue) item.title,
  ];
  if (titles.isEmpty) return null;
  return '${titles.length == 1 ? language.messages.problem : language.messages.problemsViewingChecklist}: '
      '${titles.join(', ')}';
}
