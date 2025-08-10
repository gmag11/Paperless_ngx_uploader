class UploadResult {
  final bool success;
  final String? error;
  final String filename;
  final String? errorCode;

  UploadResult({
    required this.success,
    this.error,
    required this.filename,
    this.errorCode,
  });
}