/// A place that keeps text under a key (the encrypted store, or the plain
/// one the session lived in before).
abstract interface class KeyValueStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

/// The saved session: from [secure], or, the first time, moved there from
/// [plain] (where builds before the encrypted store kept it), so updating
/// the app signs no one out. The plain copy is deleted once the encrypted
/// one is written; if writing fails, the session is still used now and
/// moving it is tried again on the next start.
Future<String?> loadSession({
  required KeyValueStore secure,
  required KeyValueStore plain,
  required String key,
}) async {
  final saved = await secure.read(key);
  if (saved != null) return saved;
  final old = await plain.read(key);
  if (old == null) return null;
  try {
    await secure.write(key, old);
  } on Object {
    return old;
  }
  await plain.delete(key);
  return old;
}
