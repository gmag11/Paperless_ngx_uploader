/// Immutable bundle of the transport settings used for every request to a
/// Paperless-NGX server.
///
/// It exists so that a single place (the client factory) maps a server
/// configuration to transport settings, and every call path passes the same
/// bundle instead of each caller picking a subset of constructor arguments.
class ServerTransportConfig {
  /// Base URL of the Paperless-NGX server (normalized by the client).
  final String baseUrl;

  /// Username for HTTP Basic authentication (empty when using an API token).
  final String username;

  /// Password for HTTP Basic authentication (empty when using an API token).
  final String password;

  /// Whether authentication uses an API token instead of username/password.
  final bool useApiToken;

  /// API token value, without the `Token ` prefix.
  final String? apiToken;

  /// Whether SSL certificate validation is disabled for self-signed servers.
  final bool allowSelfSignedCertificates;

  /// Extra headers included in every request (e.g. proxy authentication).
  final Map<String, String>? customHeaders;

  const ServerTransportConfig({
    required this.baseUrl,
    this.username = '',
    this.password = '',
    this.useApiToken = false,
    this.apiToken,
    this.allowSelfSignedCertificates = false,
    this.customHeaders,
  });

  @override
  String toString() =>
      'ServerTransportConfig(baseUrl: $baseUrl, useApiToken: $useApiToken)';
}
