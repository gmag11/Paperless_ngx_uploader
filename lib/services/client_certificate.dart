import 'dart:convert';
import 'dart:io';

import '../models/server_config.dart';

/// Thrown when pasted certificate material cannot be decoded.
class PastedCertificateException implements Exception {
  final String reason;

  const PastedCertificateException(this.reason);

  @override
  String toString() => 'PastedCertificateException($reason)';
}

/// Decodes pasted certificate material into bytes.
///
/// PEM material is used as its UTF-8 bytes; for a PKCS#12 container the text is
/// treated as base64 (whitespace is ignored). Throws
/// [PastedCertificateException] when the text is empty or does not look like the
/// expected format.
List<int> decodePastedCertificate(String text, ClientCertificateFormat format) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) {
    throw const PastedCertificateException('empty');
  }
  if (format == ClientCertificateFormat.pem) {
    if (!trimmed.contains('-----BEGIN')) {
      throw const PastedCertificateException('not_pem');
    }
    return utf8.encode(trimmed);
  }
  try {
    return base64Decode(trimmed.replaceAll(RegExp(r'\s+'), ''));
  } on FormatException {
    throw const PastedCertificateException('not_base64');
  }
}

/// Certificate material used to present a client certificate (mutual TLS) and,
/// optionally, to trust a private CA.
class ClientCertificateMaterial {
  /// Container format of [certificate].
  final ClientCertificateFormat format;

  /// PKCS#12 container bytes, or a PEM certificate chain. Null when only a
  /// custom CA is configured (no client certificate is presented).
  final List<int>? certificate;

  /// PEM private key bytes. Required for [ClientCertificateFormat.pem].
  final List<int>? privateKey;

  /// Password protecting the private key / PKCS#12 container.
  final String? password;

  /// Optional PEM CA certificate used to verify the server.
  final List<int>? customCa;

  const ClientCertificateMaterial({
    required this.format,
    this.certificate,
    this.privateKey,
    this.password,
    this.customCa,
  });

  /// Whether this material presents a client certificate (as opposed to only
  /// configuring a custom CA).
  bool get hasClientCertificate =>
      certificate != null && certificate!.isNotEmpty;
}

/// Builds a [SecurityContext] that presents [material]'s client certificate and
/// trusts its custom CA when provided.
///
/// Throws (e.g. [TlsException] or [ArgumentError]) when the material is invalid
/// or the password is wrong; callers surface that as a certificate error.
SecurityContext buildClientSecurityContext(ClientCertificateMaterial material) {
  final context = SecurityContext(withTrustedRoots: true);

  final certificate = material.certificate;
  if (certificate != null && certificate.isNotEmpty) {
    switch (material.format) {
      case ClientCertificateFormat.pkcs12:
        // On iOS `usePrivateKeyBytes` carries both key and chain; on the other
        // platforms both calls are needed.
        context.useCertificateChainBytes(certificate, password: material.password);
        context.usePrivateKeyBytes(certificate, password: material.password);
        break;
      case ClientCertificateFormat.pem:
        context.useCertificateChainBytes(certificate);
        final key = material.privateKey;
        if (key == null || key.isEmpty) {
          throw ArgumentError('A PEM client certificate requires a private key');
        }
        context.usePrivateKeyBytes(key, password: material.password);
        break;
    }
  }

  final ca = material.customCa;
  if (ca != null && ca.isNotEmpty) {
    context.setTrustedCertificatesBytes(ca);
  }

  return context;
}
