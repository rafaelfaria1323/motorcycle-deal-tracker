import '../store/listing_store.dart';
import 'pending_alert.dart';
import 'run_health.dart';
import 'web_push.dart';

/// The workflow that sends a test notification (`push-test.yml`), as
/// `start_workflow` records it.
const pushTestWorkflow = 'push-test.yml';

/// The test notification: says the device receives them; a tap opens Mais.
const Map<String, Object?> testPushMessage = {
  'title': 'Notificação de teste',
  'body':
      'As notificações chegam a este aparelho. Os alertas aparecem assim '
      'depois de cada recolha.',
  'url': '/#/more',
  'tag': 'push-test',
};

/// The kinds of notification the app can ask for an example of
/// (`start_workflow` checks the same list): the test one, an alert of each
/// type and the collection's health.
const pushTestKinds = {
  'test',
  'new_listing',
  'price_reduction',
  'excellent_opportunity',
  'listing_removed',
  'back_on_market',
  'target_price_reached',
  'run_failed',
  'run_blocked',
  'run_recovered',
};

/// An example of the [kind] notification, built as the real one is (so it
/// looks the same and a tap opens the same page), with one line saying it
/// is a test. Alerts show [listing] (a live listing, `ListingStore.
/// sampleListing`) with made-up price changes; without one, an example
/// bike that opens Ofertas.
Map<String, Object?> samplePushMessage(
  String kind,
  Map<String, dynamic>? listing,
) {
  const note = 'Exemplo de teste: nada mudou.';
  Map<String, Object?> withNote(Map<String, Object?> m) => {
    ...m,
    'body': [?m['body'] as String?, note].where((l) => l != '').join('\n'),
    'tag': 'push-test',
  };
  const ok = (status: 'ok', problems: <String>[]);
  // The usual failure: the same site's timeout in two runs in a row.
  const timedOut = (
    status: 'partial',
    problems: ['olx: Failed: TimeoutException (exemplo)'],
  );
  final health = switch (kind) {
    'run_failed' => runHealthMessage([timedOut, timedOut, ok]),
    'run_blocked' => runHealthMessage([
      (
        status: 'blocked',
        problems: [
          'standvirtual: Stopped, the site pushed back: 429 (exemplo)',
        ],
      ),
      ok,
    ]),
    'run_recovered' => runHealthMessage([ok, timedOut, timedOut]),
    _ => null,
  };
  if (health != null) return withNote(health);
  if (kind == 'test' || !pushTestKinds.contains(kind)) return testPushMessage;

  final bike = listing == null
      ? const PendingAlert(
          alertId: 'push-test',
          type: '',
          brand: 'Yamaha',
          model: 'MT-07',
          url: '/#/deals',
          year: 2021,
          mileage: 12000,
          price: 6500,
          dealScore: 78,
          location: 'Lisboa',
        )
      : PendingAlert.fromRow({...listing, 'alert_id': 'push-test', 'type': ''});
  final price = bike.price ?? 6500;
  // Made-up figures around the asking price, rounded to 50 €.
  double near(double factor) => (price * factor / 50).round() * 50;
  final (double? oldPrice, double? newPrice) = switch (kind) {
    'price_reduction' => (near(1.06), price),
    'back_on_market' => (near(1.08), price),
    'target_price_reached' => (near(1.02), price),
    _ => (null, null),
  };
  return withNote(
    pushMessage(
      PendingAlert(
        alertId: 'push-test',
        type: kind,
        brand: bike.brand,
        model: bike.model,
        url: bike.url,
        listingId: listing?['id'] as String?,
        oldPrice: oldPrice,
        newPrice: newPrice,
        year: bike.year,
        mileage: bike.mileage,
        price: price,
        dealScore: bike.dealScore,
        location: bike.location,
      ),
    ),
  );
}

/// Sends an example of the [kind] notification ([samplePushMessage]) to the
/// devices of [account] (who asked in the app; the workflow's input), else
/// of the account that last asked for one in the last 30 minutes, else
/// (GitHub's "Run workflow") to every admin's devices.
Future<({int devices, int sent})> sendTestPush(
  ListingStore store,
  WebPushSender push, {
  String? account,
  String kind = 'test',
  DateTime? now,
}) async {
  final since = (now ?? DateTime.now().toUtc()).subtract(
    const Duration(minutes: 30),
  );
  final requester = account != null && account.isNotEmpty
      ? account
      : await store.lastWorkflowStarter(pushTestWorkflow, since);
  final users = requester == null ? await store.adminIds() : [requester];
  final isAlert = !kind.startsWith('run_') && kind != 'test';
  final listing = isAlert ? await store.sampleListing(requester) : null;
  return pushToUsers(store, push, users, samplePushMessage(kind, listing));
}

/// Sends [message] to every device of [users]; forgets devices that no
/// longer exist and stamps the ones reached.
Future<({int devices, int sent})> pushToUsers(
  ListingStore store,
  WebPushSender push,
  List<String> users,
  Map<String, Object?> message,
) async {
  final byUser = await store.pushTargets();
  final devices = [for (final u in users) ...?byUser[u]];

  final reached = <String>[];
  final gone = <String>[];
  for (final device in devices) {
    switch (await push.send(device, message)) {
      case PushResult.sent:
        reached.add(device.endpoint);
      case PushResult.gone:
        gone.add(device.endpoint);
      case PushResult.failed:
        break;
    }
  }
  await store.forgetPushTargets(gone);
  await store.markPushTargetsUsed(reached);
  return (devices: devices.length, sent: reached.length);
}
