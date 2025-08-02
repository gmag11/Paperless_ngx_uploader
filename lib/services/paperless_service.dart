import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:paperless_ngx_android_uploader/models/tag.dart';
import 'package:paperless_ngx_android_uploader/models/connection_status.dart';

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
      debugPrint('❌ Network error when fetching tags: $e');
      throw Exception('Network error when fetching tags: $e');
    } catch (e) {
      debugPrint('❌ Error fetching tags: $e');
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
      debugPrint('📤 Starting document upload process...');
      debugPrint('📄 File: $fileName (${filePath})');
      
      final file = File(filePath);
      if (!await file.exists()) {
        debugPrint('❌ File does not exist: $filePath');
        return UploadResult.error('File does not exist', 'FILE_NOT_FOUND');
      }
      
      debugPrint('📄 Reading file...');
      final startRead = DateTime.now();
      final bytes = await file.readAsBytes();
      final readDuration = DateTime.now().difference(startRead);
      debugPrint('📦 File size: ${(bytes.length / 1024).toStringAsFixed(2)} KB (read in ${readDuration.inMilliseconds}ms)');

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

      debugPrint('🔄 Sending request to ${request.url}');
      if (title != null) debugPrint('📝 Title: $title');
      if (tagIds.isNotEmpty) debugPrint('🏷️ Tags: $tagIds');

      debugPrint('🔄 Starting upload...');
      final startUpload = DateTime.now();
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      final uploadDuration = DateTime.now().difference(startUpload);

      debugPrint('📥 Response status: ${response.statusCode} (upload took ${uploadDuration.inSeconds}s)');
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('✅ Upload successful!');
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
    } on SocketException {
      return UploadResult.error(
        'Network connection error. Please check your internet connection.',
        'NETWORK_ERROR'
      );
    } on IOException {
      return UploadResult.error(
        'Error reading file. Please make sure the file exists and is accessible.',
        'FILE_ERROR'
      );
    } catch (e) {
      return UploadResult.error(
        'Unexpected error during upload: $e',
        'UNKNOWN_ERROR'
      );
    }
  }
}