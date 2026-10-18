import 'dart:io';

class ConfigException implements Exception {
  ConfigException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Connection settings, read from environment variables only.
class SupabaseConfig {
  const SupabaseConfig({required this.url, required this.serviceKey});

  factory SupabaseConfig.fromEnvironment([Map<String, String>? environment]) {
    final env = environment ?? Platform.environment;
    final url = env['SUPABASE_URL']?.trim() ?? '';
    final key = env['SUPABASE_SERVICE_ROLE_KEY']?.trim() ?? '';

    if (url.isEmpty || key.isEmpty) {
      throw ConfigException(
        'Set SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY in the environment.',
      );
    }
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !(uri.scheme == 'http' || uri.scheme == 'https') ||
        uri.host.isEmpty) {
      throw ConfigException('SUPABASE_URL must be an http(s) address.');
    }
    return SupabaseConfig(url: url, serviceKey: key);
  }

  final String url;
  final String serviceKey;

  // The key is deliberately left out so it can never end up in a log.
  @override
  String toString() => 'SupabaseConfig(url: $url)';
}
