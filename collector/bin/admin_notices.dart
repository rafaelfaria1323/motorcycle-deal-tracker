import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:collector/collector.dart';

/// The database's warnings to the admins (`admin_notices`, N.114): pushes
/// those waiting to every admin's devices (notices.yml, started by the
/// database when it keeps one). With `--add`, keeps one first (the tax
/// table check, tax-tables.yml), which starts notices.yml to send it.
Future<void> main(List<String> args) async {
  final options = readCommandLine(
    ArgParser()
      ..addOption(
        'add',
        allowed: adminNoticeKinds,
        help: 'Keep a notice of this kind instead of sending.',
      )
      ..addOption('details', defaultsTo: '{}', help: 'Its details (JSON).')
      ..addOption(
        'quiet-days',
        defaultsTo: '0',
        help: 'Not when the same notice was kept in these days.',
      ),
    args,
    atLeast: {'quiet-days': 0},
    usage: 'Usage: dart run bin/admin_notices.dart [options]',
  );
  if (options == null) return;

  await withServiceClient((client) async {
    final store = PushStore(client);
    if (options.option('add') case final kind?) {
      final details = jsonDecode(options.option('details')!);
      final days = int.parse(options.option('quiet-days')!);
      final id = await store.addAdminNotice(
        kind,
        (details as Map).cast<String, Object?>(),
        quietFor: days > 0 ? Duration(days: days) : null,
      );
      stdout.writeln(
        id == null ? 'Already told within $days day(s).' : 'Notice $id kept.',
      );
      return;
    }
    final push = WebPushSender(
      await store.pushKeys(),
      fcm: FcmSender.fromEnvironment(),
    );
    final result = await sendAdminNotices(store, push);
    stdout.writeln(
      '${result.notices} admin notice(s) done, sent to ${result.sent} '
      'device(s).',
    );
  });
}
