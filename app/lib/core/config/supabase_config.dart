/// The database's address and publishable key, given at build time
/// (`--dart-define`s, `app/env/*.json`). The publishable key is public: the
/// web app sends it with every request.
library;

const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabasePublishableKey = String.fromEnvironment(
  'SUPABASE_PUBLISHABLE_KEY',
);
