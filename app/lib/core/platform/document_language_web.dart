import 'dart:js_interop';

@JS('document.documentElement.lang')
external set _documentLanguage(JSString language);

@JS('document.getElementById')
external _DocumentElement? _getElementById(JSString id);

extension type _DocumentElement(JSObject _) implements JSObject {
  external void setAttribute(JSString name, JSString value);
}

void setDocumentLanguage(String languageTag, String loadingLabel) {
  _documentLanguage = languageTag.toJS;
  _getElementById(
    'splash'.toJS,
  )?.setAttribute('aria-label'.toJS, loadingLabel.toJS);
}
