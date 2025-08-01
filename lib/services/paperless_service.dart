import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:paperless_ngx_android_uploader/models/tag.dart';
import 'package:paperless_ngx_android_uploader/models/connection_status.dart';

class PaperlessService {
  final String baseUrl;
  final String username;
  final String password;

  PaperlessService({
    required this.baseUrl,
    required this.username,
    required this.password,
  });

  String get _authHeader {
    final credentials = base64Encode(utf8.encode('$username:$password'));
    return 'Basic $credentials';
  }

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

  Future<List<Tag>> fetchTags() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/tags/'),
        headers: {
          'Authorization': _authHeader,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final tags = (data['results'] as List)
            .map((tag) => Tag.fromJson(tag))
            .toList();
        return tags;
      } else {
        throw Exception('Failed to fetch tags: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to fetch tags: $e');
    }
  }

  Future<Map<String, dynamic>> uploadDocument({
    required String filePath,
    required String fileName,
    List<int> tagIds = const [],
  }) async {
    try {
      final file = File(filePath);
      final bytes = await file.readAsBytes();

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/api/documents/post_document/'),
      );

      request.headers['Authorization'] = _authHeader;
      request.files.add(
        http.MultipartFile.fromBytes(
          'document',
          bytes,
          filename: fileName,
        ),
      );

      if (tagIds.isNotEmpty) {
        request.fields['tags'] = tagIds.join(',');
      }

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true,
          'message': 'Document uploaded successfully',
          'data': jsonDecode(responseBody),
        };
      } else {
        return {
          'success': false,
          'message': 'Upload failed: ${response.statusCode} - $responseBody',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Upload error: $e',
      };
    }
  }
}