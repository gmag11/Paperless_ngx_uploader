import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:paperless_ngx_android_uploader/models/tag.dart';
import 'package:paperless_ngx_android_uploader/models/connection_status.dart';
import 'dart:developer' as developer;

class UploadResult {
  final bool success;
  final String message;
  final Map<String, dynamic>? data;
  final String? errorCode;

  const UploadResult({
    required this.success,
    required this.message,
    this.data,
    this.errorCode,
  });

  factory UploadResult.success(Map<String, dynamic> data) {
    return UploadResult(
      success: true,
      message: 'Document uploaded successfully',
      data: data,
    );
  }

  factory UploadResult.error(String message, [String? errorCode]) {
    return UploadResult(
      success: false,
      message: message,
      errorCode: errorCode,
    );
  }
}

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
      List<Tag> allTags = [];
      String? nextUrl = '$baseUrl/api/tags/?page_size=100'; // Start with large page size
      
      while (nextUrl != null) {
        final response = await http.get(
          Uri.parse(nextUrl),
          headers: {
            'Authorization': _authHeader,
          },
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final tags = (data['results'] as List)
              .map((tag) => Tag.fromJson(tag))
              .toList();
          allTags.addAll(tags);
          
          // Get next page URL if it exists
          nextUrl = data['next'] as String?;
        } else {
          throw Exception('Failed to fetch tags: ${response.statusCode}');
        }
      }
      
      return allTags;
    } on SocketException catch (e) {
      developer.log('❌ Network error when fetching tags: $e',
                    name: 'PaperlessService.fetchTags',
                    error: e);
      throw Exception('Network error when fetching tags: $e');
    } catch (e) {
      developer.log('❌ Error fetching tags: $e',
                    name: 'PaperlessService.fetchTags',
                    error: e);
      throw Exception('Failed to fetch tags: $e');
    }
  }

  Future<UploadResult> uploadDocument({
    required String filePath,
    required String fileName,
    String? title,
    List<int> tagIds = const [],
  }) async {
    try {
      developer.log('📤 Starting document upload process...',
                    name: 'PaperlessService.uploadDocument');
      developer.log('📄 File: $fileName ($filePath)',
                    name: 'PaperlessService.uploadDocument');
      developer.log('📄 Upload parameters: title=$title, tags=$tagIds',
                    name: 'PaperlessService.uploadDocument');

      final file = File(filePath);
      if (!await file.exists()) {
        developer.log('❌ File does not exist: $filePath',
                      name: 'PaperlessService.uploadDocument');
        return UploadResult.error('File does not exist', 'FILE_NOT_FOUND');
      }

      developer.log('📄 Reading file...',
                    name: 'PaperlessService.uploadDocument');
      final startRead = DateTime.now();
      final bytes = await file.readAsBytes();
      final readDuration = DateTime.now().difference(startRead);
      developer.log('📦 File size: ${(bytes.length / 1024).toStringAsFixed(2)} KB (read in ${readDuration.inMilliseconds}ms)',
                    name: 'PaperlessService.uploadDocument');

      developer.log('🔄 Preparing HTTP request to $baseUrl/api/documents/post_document/',
                    name: 'PaperlessService.uploadDocument');
      developer.log('🔄 Request headers: Authorization: Basic ********',
                    name: 'PaperlessService.uploadDocument');
      developer.log('🔄 Request fields: title=$title, tags=${jsonEncode(tagIds)}',
                    name: 'PaperlessService.uploadDocument');

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

      // Add title if provided
      if (title != null && title.isNotEmpty) {
        request.fields['title'] = title;
      }

      // Add tags as JSON array string
      if (tagIds.isNotEmpty) {
        request.fields['tags'] = jsonEncode(tagIds);
      }

      developer.log('🔄 Sending request to ${request.url}',
                    name: 'PaperlessService.uploadDocument');
      if (title != null) {
        developer.log('📝 Title: $title',
                      name: 'PaperlessService.uploadDocument');
      }
      if (tagIds.isNotEmpty) {
        developer.log('🏷️ Tags: $tagIds',
                      name: 'PaperlessService.uploadDocument');
      }
      developer.log('🔄 Request size: ${bytes.length} bytes',
                    name: 'PaperlessService.uploadDocument');

      developer.log('🔄 Starting upload...',
                    name: 'PaperlessService.uploadDocument');
      developer.log('🔄 Starting upload at ${DateTime.now()}',
                    name: 'PaperlessService.uploadDocument');
      final startUpload = DateTime.now();
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      final uploadDuration = DateTime.now().difference(startUpload);
      developer.log('🔄 Upload completed in ${uploadDuration.inMilliseconds}ms',
                    name: 'PaperlessService.uploadDocument');

      developer.log('📥 Response status: ${response.statusCode} (upload took ${uploadDuration.inMilliseconds}ms)',
                    name: 'PaperlessService.uploadDocument');
      developer.log('📥 Response body: $responseBody',
                    name: 'PaperlessService.uploadDocument');

      if (response.statusCode == 200 || response.statusCode == 201) {
        developer.log('✅ Upload successful!',
                      name: 'PaperlessService.uploadDocument');
        return UploadResult.success(jsonDecode(responseBody));
      } else {
        String errorMessage;
        String? errorCode;
        
        switch (response.statusCode) {
          case 401:
            errorMessage = 'Authentication failed. Please check your credentials.';
            errorCode = 'AUTH_ERROR';
          case 413:
            errorMessage = 'File is too large for the server to accept.';
            errorCode = 'FILE_TOO_LARGE';
          case 415:
            errorMessage = 'File type is not supported.';
            errorCode = 'UNSUPPORTED_TYPE';
          case 500:
            errorMessage = 'Server encountered an error while processing the upload.';
            errorCode = 'SERVER_ERROR';
          default:
            errorMessage = 'Upload failed: ${response.statusCode} - $responseBody';
            errorCode = 'UPLOAD_FAILED';
        }
        return UploadResult.error(errorMessage, errorCode);
      }
    } on SocketException catch (e) {
      developer.log('❌ Network connection error: ${e.toString()}',
                    name: 'PaperlessService.uploadDocument');
      return UploadResult.error(
        'Network connection error. Please check your internet connection.',
        'NETWORK_ERROR'
      );
    } on IOException catch (e) {
      developer.log('❌ File I/O error: ${e.toString()}',
                    name: 'PaperlessService.uploadDocument');
      return UploadResult.error(
        'Error reading file. Please make sure the file exists and is accessible.',
        'FILE_ERROR'
      );
    } catch (e) {
      developer.log('❌ Unexpected error during upload: ${e.toString()}',
                    name: 'PaperlessService.uploadDocument');
      developer.log('📄 Stack trace: ${StackTrace.current}',
                    name: 'PaperlessService.uploadDocument');
      return UploadResult.error(
        'Unexpected error during upload: $e',
        'UNKNOWN_ERROR'
      );
    }
  }
}