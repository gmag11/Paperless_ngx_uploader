import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Files allowed to construct a `PaperlessService` directly:
/// the service itself and the factory (the single construction point).
const _allowedConstructionSites = {
  'lib/services/paperless_service.dart',
  'lib/services/paperless_service_factory.dart',
};

/// Matches a `PaperlessService(` construction but not identifiers that merely
/// end with the same suffix, such as `getPaperlessService()`.
final _construction = RegExp(r'(^|[^\w$])(?:paperless\.)?PaperlessService\s*\(');

void main() {
  test('PaperlessService is constructed only by the factory', () {
    final libDir = Directory('lib');
    expect(libDir.existsSync(), isTrue,
        reason: 'Run this test from the project root.');

    final offenders = <String>[];
    for (final entity in libDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path.replaceAll('\\', '/');
      if (_allowedConstructionSites.contains(path)) continue;
      if (_construction.hasMatch(entity.readAsStringSync())) {
        offenders.add(path);
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'Construct PaperlessService only in the factory. '
          'Offending files: $offenders',
    );
  });
}
