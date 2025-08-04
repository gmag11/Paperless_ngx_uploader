import 'dart:convert';
import 'dart:io';
import 'dart:developer' as developer;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:paperless_ngx_android_uploader/models/connection_status.dart';
import 'package:paperless_ngx_android_uploader/models/tag.dart';

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

  // Authentication method: if true, use API token in "Authorization: Token <token>"
  // If false, use HTTP Basic with username/password.
  final bool useApiToken;

  // When useApiToken is true, the API token value (without the "Token " prefix)
  final String? apiToken;

  // Shared Dio client configured for streaming, timeouts, and retries
  late final Dio _dio;

  PaperlessService({
    required String baseUrl,
    required this.username,
    required this.password,
    this.useApiToken = false,
    this.apiToken,
  })  : baseUrl = _normalizeBaseUrl(baseUrl) {
    _dio = Dio(BaseOptions(
      baseUrl: this.baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 60),
      sendTimeout: const Duration(minutes: 10),
      headers: _defaultHeaders(
        username: username,
        password: password,
        useApiToken: useApiToken,
        apiToken: apiToken,
      ),
      followRedirects: true,
      validateStatus: (code) => code != null && code >= 200 && code < 600,
    ));

    // Simple logging (debug only)
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (kDebugMode) {
          developer.log('➡️ ${options.method} ${options.uri}',
              name: 'PaperlessService.Dio');
        }
        handler.next(options);
      },
      onResponse: (response, handler) {
        if (kDebugMode) {
          developer.log('⬅️ ${response.statusCode} ${response.requestOptions.uri}',
              name: 'PaperlessService.Dio');
        }
        handler.next(response);
      },
      onError: (e, handler) {
        if (kDebugMode) {
          developer.log('❌ Dio error: ${e.message}',
              name: 'PaperlessService.Dio', error: e);
        }
        handler.next(e);
      },
    ));
  }

  static String _normalizeBaseUrl(String url) {
    // Trim and remove trailing slash
    final trimmed = url.trim();
    if (trimmed.endsWith('/')) {
      return trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }

  static Map<String, dynamic> _defaultHeaders({
    required String username,
    required String password,
    required bool useApiToken,
    String? apiToken,
  }) {
    if (useApiToken) {
      final token = (apiToken ?? '').trim();
      return {
        HttpHeaders.authorizationHeader: 'Token $token',
      };
    } else {
      final credentials = base64Encode(utf8.encode('$username:$password'));
      return {
        HttpHeaders.authorizationHeader: 'Basic $credentials',
      };
    }
  }

  String get _authHeader {
    if (useApiToken) {
      final token = (apiToken ?? '').trim();
      return 'Token $token';
    }
    final credentials = base64Encode(utf8.encode('$username:$password'));
    return 'Basic $credentials';
  }

  Future<ConnectionStatus> testConnection() async {
    try {
      final resp = await _dio.get('/api/status/',
          options: Options(
            headers: {HttpHeaders.authorizationHeader: _authHeader},
            responseType: ResponseType.json,
          ));

      switch (resp.statusCode) {
        case 200:
          return ConnectionStatus.connected;
        case 401:
          return ConnectionStatus.invalidCredentials;
        case 404:
          return ConnectionStatus.invalidServerUrl;
        default:
          return ConnectionStatus.unknownError;
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionError) {
        return ConnectionStatus.serverUnreachable;
      }
      if (e.error is HandshakeException) {
        return ConnectionStatus.sslError;
      }
      return ConnectionStatus.unknownError;
    } catch (_) {
      return ConnectionStatus.unknownError;
    }
  }

  Future<List<Tag>> fetchTags() async {
    try {
      final List<Tag> all = [];
      String? nextPath = '/api/tags/?page_size=100';

      while (nextPath != null) {
        final resp = await _dio.get(nextPath,
            options: Options(
              headers: {HttpHeaders.authorizationHeader: _authHeader},
              responseType: ResponseType.json,
            ));
        if (resp.statusCode == 200) {
          final data = resp.data;
          final results = (data['results'] as List)
              .map((j) => Tag.fromJson(j))
              .toList();
          all.addAll(results);
          nextPath = data['next'] as String?;
          // If absolute URL returned in "next", strip base (normalized)
          if (nextPath != null && nextPath.startsWith(baseUrl)) {
            nextPath = nextPath.substring(baseUrl.length);
          }
        } else {
          throw Exception('Failed to fetch tags: ${resp.statusCode}');
        }
      }

      return all;
    } on DioException catch (e) {
      if (kDebugMode) {
        developer.log('❌ Network error when fetching tags: $e',
            name: 'PaperlessService.fetchTags', error: e);
      }
      throw Exception('Network error when fetching tags: $e');
    } catch (e) {
      if (kDebugMode) {
        developer.log('❌ Error fetching tags: $e',
            name: 'PaperlessService.fetchTags', error: e);
      }
      throw Exception('Failed to fetch tags: $e');
    }
  }

  // Basic retry with exponential backoff for idempotent-ish upload attempts
  Future<Response<dynamic>> _withRetry(Future<Response<dynamic>> Function() run,
      {int maxAttempts = 3}) async {
    int attempt = 0;
    DioException? lastErr;
    while (attempt < maxAttempts) {
      try {
        return await run();
      } on DioException catch (e) {
        lastErr = e;
        // Retry only on transient errors
        final transient = e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.sendTimeout ||
            e.type == DioExceptionType.receiveTimeout ||
            e.type == DioExceptionType.connectionError ||
            (e.response?.statusCode != null &&
                e.response!.statusCode! >= 500 &&
                e.response!.statusCode! < 600);
        attempt++;
        if (!transient || attempt >= maxAttempts) {
          rethrow;
        }
        final delay = Duration(milliseconds: 500 * (1 << (attempt - 1)));
        await Future.delayed(delay);
      }
    }
    throw lastErr!;
  }

  Future<UploadResult> uploadDocument({
    required String filePath,
    required String fileName,
    String? title,
    List<int> tagIds = const [],
    void Function(int sent, int total)? onProgress,
    String? idempotencyKey,
  }) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        if (kDebugMode) {
          developer.log('❌ File does not exist: $filePath',
              name: 'PaperlessService.uploadDocument');
        }
        return UploadResult.error('File does not exist', 'FILE_NOT_FOUND');
      }

      final docField = await MultipartFile.fromFile(
        filePath,
        filename: fileName,
      );

      final form = FormData();
      form.files.add(MapEntry('document', docField));
      if (title != null && title.isNotEmpty) {
        form.fields.add(MapEntry('title', title));
      }
      // Paperless expects repeated multipart fields for tags
      for (final id in tagIds) {
        form.fields.add(MapEntry('tags', id.toString()));
      }

      final headers = {
        HttpHeaders.authorizationHeader: _authHeader,
        if (idempotencyKey != null) 'X-Idempotency-Key': idempotencyKey,
      };

      final Response resp = await _withRetry(() {
        return _dio.post(
          '/api/documents/post_document/',
          data: form,
          options: Options(
            headers: headers,
            contentType: 'multipart/form-data',
            sendTimeout: const Duration(minutes: 10),
            receiveTimeout: const Duration(seconds: 60),
          ),
          onSendProgress: onProgress,
        );
      });

      final status = resp.statusCode ?? 0;
      final body = resp.data;

      if (status == 200 || status == 201) {
        Map<String, dynamic> normalized;
        try {
          if (body is Map<String, dynamic>) {
            normalized = body;
          } else if (body is String) {
            normalized = {'id': body};
          } else {
            normalized = {'value': body};
          }
        } catch (_) {
          normalized = {'value': body?.toString()};
        }
        return UploadResult.success(normalized);
      } else {
        String errorMessage;
        String? errorCode;

        switch (status) {
          case 401:
            errorMessage =
                'Authentication failed. Please check your credentials.';
            errorCode = 'AUTH_ERROR';
            break;
          case 413:
            errorMessage = 'File is too large for the server to accept.';
            errorCode = 'FILE_TOO_LARGE';
            break;
          case 415:
            errorMessage = 'File type is not supported.';
            errorCode = 'UNSUPPORTED_TYPE';
            break;
          default:
            if (status >= 500) {
              errorMessage =
                  'Server error ($status). Please try again later.';
              errorCode = 'SERVER_ERROR';
            } else {
              errorMessage = 'Upload failed: $status - ${body.toString()}';
              errorCode = 'UPLOAD_FAILED';
            }
        }
        return UploadResult.error(errorMessage, errorCode);
      }
    } on DioException catch (e) {
      if (kDebugMode) {
        developer.log('❌ Upload Dio error: ${e.message}',
            name: 'PaperlessService.uploadDocument', error: e);
      }
      final type = e.type;
      if (type == DioExceptionType.connectionTimeout ||
          type == DioExceptionType.sendTimeout ||
          type == DioExceptionType.receiveTimeout ||
          type == DioExceptionType.connectionError) {
        return UploadResult.error(
            'Network connection error. Please check your internet connection.',
            'NETWORK_ERROR');
      }
      if (e.type == DioExceptionType.badResponse) {
        final status = e.response?.statusCode ?? 0;
        return UploadResult.error(
            'Upload failed with status $status', 'BAD_RESPONSE');
      }
      return UploadResult.error('Unexpected error during upload: ${e.message}',
          'UNKNOWN_ERROR');
    } on IOException catch (e) {
      if (kDebugMode) {
        developer.log('❌ File I/O error: ${e.toString()}',
            name: 'PaperlessService.uploadDocument');
      }
      return UploadResult.error(
          'Error reading file. Please make sure the file exists and is accessible.',
          'FILE_ERROR');
    } catch (e) {
      if (kDebugMode) {
        developer.log('❌ Unexpected error during upload: ${e.toString()}',
            name: 'PaperlessService.uploadDocument');
        developer.log('📄 Stack trace: ${StackTrace.current}',
            name: 'PaperlessService.uploadDocument');
      }
      return UploadResult.error('Unexpected error during upload: $e',
          'UNKNOWN_ERROR');
    }
  }
}