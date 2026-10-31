import '../domain/workflows_repository.dart';
import '../../../core/localization/localizations.dart';

/// What a run-now tile says, and asks before starting.
({String title, String subtitle, String started}) workflowText(
  AppWorkflow workflow, {
  AppLanguage language = .portuguese,
}) => switch (workflow) {
  AppWorkflow.collect => (
    title: language.messages.collectNow,
    subtitle: language.messages.collectNowSubtitle,
    started: language.messages.collectionStarted,
  ),
  AppWorkflow.weeklySummary => (
    title: language.messages.sendWeeklySummary,
    subtitle: language.messages.last7DaysForYourModelsNowOn,
    started: language.messages.summaryRequestedItShouldArriveIn1To,
  ),
  AppWorkflow.pushTest => (
    title: language.messages.sendTestNotification,
    subtitle: language.messages.chooseTypeToConfirmThatAlertsReachYour,
    started: language.messages.pushTestRequested,
  ),
};

/// How the test notification picker names each example.
String pushTestKindText(
  PushTestKind kind, {
  AppLanguage language = .portuguese,
}) => switch (kind) {
  PushTestKind.test => language.messages.simpleTestNotification,
  PushTestKind.newListing => language.messages.newListingWorkflowsText,
  PushTestKind.priceReduction => language.messages.priceDrop,
  PushTestKind.excellentOpportunity =>
    language.messages.excellentOpportunityWorkflowsText,
  PushTestKind.targetPriceReached =>
    language.messages.targetPriceReachedWorkflowsText,
  PushTestKind.listingRemoved =>
    language.messages.listingRemovedListingDetailPage,
  PushTestKind.backOnMarket => language.messages.backOnMarketWorkflowsText,
  PushTestKind.runFailed => language.messages.collectionFailedAdministrators,
  PushTestKind.runBlocked =>
    language.messages.siteRefusedCollectionAdministrators,
  PushTestKind.runRecovered =>
    language.messages.collectionRecoveredAdministrators,
};

/// Why `start_workflow` refused, from its error code.
String startErrorText(String? code, {AppLanguage language = .portuguese}) =>
    switch (code) {
      '55006' => language.messages.startWorkflowTooSoon,
      '55000' => language.messages.githubTokenIsMissingFromSupabaseVault,
      '58000' => language.messages.startWorkflowRejected,
      '42501' => language.messages.onlyAdministratorCanDoThis,
      _ => language.messages.couldNotStartTryAgain,
    };
