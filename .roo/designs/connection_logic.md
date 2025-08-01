# Connection Logic Design

## 1. Connection Status Model

```dart
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
```

## 2. Authentication Implementation

Keep the existing Basic Auth implementation from PaperlessService:

```dart
String get _authHeader {
  final credentials = base64Encode(utf8.encode('$username:$password'));
  return 'Basic $credentials';
}
```

## 3. Status Endpoint Integration

Replace the current `/api/documents/` check with `/api/status/`:

```dart
Future<ConnectionStatus> testConnection() async {
  try {
    final response = await http.get(
      Uri.parse('$baseUrl/api/status/'),
      headers: {
        'Authorization': _authHeader,
      },
    );

    switch (response.statusCode) {
      case 200:
        return ConnectionStatus.connected;
      case 401:
        return ConnectionStatus.invalidCredentials;
      case 404:
        return ConnectionStatus.invalidServerUrl;
      default:
        return ConnectionStatus.unknownError;
    }
  } on SocketException {
    return ConnectionStatus.serverUnreachable;
  } on HandshakeException {
    return ConnectionStatus.sslError;
  } catch (e) {
    return ConnectionStatus.unknownError;
  }
}
```

## 4. Error Handling in AppConfigProvider

Enhance AppConfigProvider to handle the new connection status:

```dart
class AppConfigProvider extends ChangeNotifier {
  ConnectionStatus _connectionStatus = ConnectionStatus.notConfigured;
  String? _connectionError;

  ConnectionStatus get connectionStatus => _connectionStatus;

  Future<void> testConnection() async {
    _connectionStatus = ConnectionStatus.connecting;
    _connectionError = null;
    notifyListeners();

    try {
      final service = PaperlessService(
        baseUrl: _serverUrl!,
        username: _username!,
        password: _password!
      );

      _connectionStatus = await service.testConnection();
      
      _connectionError = switch (_connectionStatus) {
        ConnectionStatus.connected => null,
        ConnectionStatus.invalidCredentials => 'Invalid username or password',
        ConnectionStatus.serverUnreachable => 'Server is unreachable',
        ConnectionStatus.invalidServerUrl => 'Invalid server URL or not a Paperless-NGX server',
        ConnectionStatus.sslError => 'SSL certificate error',
        ConnectionStatus.unknownError => 'Unknown connection error occurred',
        _ => 'Unexpected error'
      };
    } catch (e) {
      _connectionStatus = ConnectionStatus.unknownError;
      _connectionError = e.toString();
    }
    
    notifyListeners();
  }
}
```

## 5. Integration Requirements

1. **File Changes Required:**
   - Update `lib/services/paperless_service.dart` to implement new connection status endpoint
   - Update `lib/providers/app_config_provider.dart` to handle new connection states
   - Create new enum in a separate file `lib/models/connection_status.dart`

2. **Dependencies:**
   - No new dependencies required, using existing `http` package

3. **Testing Considerations:**
   - Test each connection failure scenario
   - Verify SSL certificate handling
   - Test malformed URLs
   - Test timeout handling

## 6. Security Considerations

1. SSL certificate validation remains enabled for secure connections
2. Credentials continue to be stored securely using FlutterSecureStorage
3. Basic Auth header is only sent to configured server URL
4. Connection status does not expose sensitive information in error messages

## 7. Error Message Localization

Error messages should be moved to a localization file for future translation support:

```dart
const Map<ConnectionStatus, String> connectionMessages = {
  ConnectionStatus.invalidCredentials: 'Invalid username or password',
  ConnectionStatus.serverUnreachable: 'Server is unreachable',
  ConnectionStatus.invalidServerUrl: 'Invalid server URL or not a Paperless-NGX server',
  ConnectionStatus.sslError: 'SSL certificate error',
  ConnectionStatus.unknownError: 'Unknown connection error occurred',
};