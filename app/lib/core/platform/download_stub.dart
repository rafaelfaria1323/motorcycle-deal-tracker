/// No download outside the browser.
Future<bool> downloadText(
  String name,
  String text, {
  required String type,
}) async => false;
