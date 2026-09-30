import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:paperlessngx_uploader/models/server_config.dart';
import 'package:paperlessngx_uploader/services/client_certificate.dart';

void main() {
  test('decodes pasted PEM text into its UTF-8 bytes', () {
    const pem = '-----BEGIN CERTIFICATE-----\nABC\n-----END CERTIFICATE-----';
    final bytes = decodePastedCertificate(pem, ClientCertificateFormat.pem);
    expect(utf8.decode(bytes), pem);
  });

  test('rejects non-PEM text for the PEM format', () {
    expect(
      () => decodePastedCertificate('not a certificate', ClientCertificateFormat.pem),
      throwsA(isA<PastedCertificateException>()),
    );
  });

  test('decodes base64 PKCS#12, ignoring whitespace', () {
    final bytes =
        decodePastedCertificate('AAEC\nAwQF', ClientCertificateFormat.pkcs12);
    expect(bytes, [0, 1, 2, 3, 4, 5]);
  });

  test('rejects invalid base64 for the PKCS#12 format', () {
    expect(
      () => decodePastedCertificate('not base64!!!', ClientCertificateFormat.pkcs12),
      throwsA(isA<PastedCertificateException>()),
    );
  });

  test('rejects empty input', () {
    expect(
      () => decodePastedCertificate('   ', ClientCertificateFormat.pem),
      throwsA(isA<PastedCertificateException>()),
    );
  });
}
