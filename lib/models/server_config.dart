// import 'dart:convert'; // Removed as it's not used

enum AuthMethod {
  usernamePassword,
  apiToken,
}

class ServerConfig {
  final String id;
  final String name;
  final String serverUrl;
  final AuthMethod authMethod;
  final String? username;
  final String? apiToken;
  final bool allowSelfSignedCertificates;
  final List<int> defaultTagIds;

  const ServerConfig({
    required this.id,
    required this.name,
    required this.serverUrl,
    required this.authMethod,
    this.username,
    this.apiToken,
    this.allowSelfSignedCertificates = false,
    this.defaultTagIds = const [],
  });

  bool get isValid {
    return serverUrl.isNotEmpty && 
           (authMethod == AuthMethod.apiToken ? apiToken != null : 
            authMethod == AuthMethod.usernamePassword ? username != null : false);
  }

  ServerConfig copyWith({
    String? id,
    String? name,
    String? serverUrl,
    AuthMethod? authMethod,
    String? username,
    String? apiToken,
    bool? allowSelfSignedCertificates,
    List<int>? defaultTagIds,
  }) {
    return ServerConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      serverUrl: serverUrl ?? this.serverUrl,
      authMethod: authMethod ?? this.authMethod,
      username: username ?? this.username,
      apiToken: apiToken ?? this.apiToken,
      allowSelfSignedCertificates: allowSelfSignedCertificates ?? this.allowSelfSignedCertificates,
      defaultTagIds: defaultTagIds ?? this.defaultTagIds,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'serverUrl': serverUrl,
      'authMethod': authMethod.name,
      'username': username,
      'apiToken': apiToken,
      'allowSelfSignedCertificates': allowSelfSignedCertificates,
      'defaultTagIds': defaultTagIds,
    };
  }

  factory ServerConfig.fromJson(Map<String, dynamic> json) {
    return ServerConfig(
      id: json['id'] as String,
      name: json['name'] as String,
      serverUrl: json['serverUrl'] as String,
      authMethod: AuthMethod.values.firstWhere(
        (e) => e.name == json['authMethod'],
        orElse: () => AuthMethod.usernamePassword,
      ),
      username: json['username'] as String?,
      apiToken: json['apiToken'] as String?,
      allowSelfSignedCertificates: json['allowSelfSignedCertificates'] as bool? ?? false,
      defaultTagIds: (json['defaultTagIds'] as List<dynamic>?)
          ?.map((id) => id as int)
          .toList() ?? [],
    );
  }

  static String generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ServerConfig &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'ServerConfig{id: $id, name: $name, serverUrl: $serverUrl, authMethod: $authMethod}';
  }
}