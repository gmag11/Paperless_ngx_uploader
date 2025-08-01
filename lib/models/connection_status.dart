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
  unknownError,         // Other unspecified errors
}