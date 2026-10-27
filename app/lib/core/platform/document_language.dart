import 'document_language_stub.dart'
    if (dart.library.js_interop) 'document_language_web.dart'
    as impl;

void setDocumentLanguage(String languageTag, String loadingLabel) =>
    impl.setDocumentLanguage(languageTag, loadingLabel);
