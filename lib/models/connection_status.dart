enum ConnectionStatus {
  // Initial state before any connection attempt
  notConfigured,
  
  // Connection attempt in progress
  connecting,
  
  // Successfully connected to server
  connected,
  
  // Connection failures with specific reasons
  invalidCredentials,     // 401 Unauthorized
  serverUnreachable,     // Network/DNS errors
  invalidServerUrl,      // Malformed URL or non-Paperless server
  sslError,             // SSL certificate issues
  clientCertificateError,         // Client certificate rejected, expired or invalid
  clientCertificateRequired,      // Server requires a client certificate and none is configured
  clientCertificatePasswordError, // Wrong password for the client certificate
  unknownError,         // Other unspecified errors
}