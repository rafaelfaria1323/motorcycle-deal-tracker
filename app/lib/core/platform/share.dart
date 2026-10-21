import 'share_stub.dart' if (dart.library.js_interop) 'share_web.dart' as impl;

/// What happened to a [shareLink].
enum ShareOutcome {
  /// The phone's share sheet opened (and was used or closed).
  shared,

  /// No share sheet here (most desktop browsers): copy the link instead.
  unavailable,
}

/// Opens the device's share sheet (WhatsApp, Mensagens, Mail…) with [text]
/// and [url]. Call it straight from a tap: Safari opens it only then.
Future<ShareOutcome> shareLink({
  required String title,
  required String text,
  required String url,
}) => impl.shareLink(title: title, text: text, url: url);
