import '../domain/workflows_repository.dart';
import '../../../core/localization/localizations.dart';

/// What a run-now tile says, and asks before starting.
({String title, String subtitle, String started}) workflowText(
  AppWorkflow workflow, {
  AppLanguage language = AppLanguage.portuguese,
}) => switch (workflow) {
  AppWorkflow.collect => (
    title: language.messages.collectNow,
    subtitle: language.messages.readSitesNowOutsideScheduleRequestsAppearIn,
    started: language.messages.collectionStartedNewListingsShouldAppearInAbout,
  ),
  AppWorkflow.weeklySummary => (
    title: language.messages.sendWeeklySummary,
    subtitle: language.messages.last7DaysForYourModelsNowOn,
    started: language.messages.summaryRequestedItShouldArriveIn1To,
  ),
  AppWorkflow.pushTest => (
    title: language.messages.sendTestNotification,
    subtitle: language.messages.chooseTypeToConfirmThatAlertsReachYour,
    started: language.messages.testNotificationRequestedItShouldArriveIn1,
  ),
};

/// How the test notification picker names each example.
String pushTestKindText(
  PushTestKind kind, {
  AppLanguage language = AppLanguage.portuguese,
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
String startErrorText(
  String? code, {
  AppLanguage language = AppLanguage.portuguese,
}) => switch (code) {
  '55006' => language.messages.thisWasRequestedRecentlyWaitMomentAndTry,
  '55000' => language.messages.githubTokenIsMissingFromSupabaseVault,
  '58000' => language.messages.githubRejectedRequestCheckGitHubTokenActionsRead,
  '42501' => language.messages.onlyAdministratorCanDoThis,
  _ => language.messages.couldNotStartTryAgain,
};
