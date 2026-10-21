import 'share.dart';

Future<ShareOutcome> shareLink({
  required String title,
  required String text,
  required String url,
}) async => ShareOutcome.unavailable;
