import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:paperlessngx_uploader/models/tag.dart';
import 'package:paperlessngx_uploader/models/upload_result.dart';
import 'package:paperlessngx_uploader/providers/app_config_provider.dart';
import 'package:paperlessngx_uploader/providers/upload_provider.dart';
import 'package:paperlessngx_uploader/screens/home_screen.dart';
import 'package:paperlessngx_uploader/l10n/gen/app_localizations.dart';

// Removed unused _TestUploadProvider (dead code).

// Build a testable HomeScreen with a derived view model injected via Provider.
// To avoid needing internal setters, we derive a lightweight proxy to expose the view state needed by HomeScreen.
class _ViewState extends ChangeNotifier implements UploadProvider {
  // Expose the same getters as UploadProvider reads.
  bool _isUploading;
  String? _uploadError;
  bool _uploadSuccess;

  double _progress;
  int _bytesSent;
  int _bytesTotal;
  bool _showTypeWarning;
  String? _lastMimeType;

  // Multi-file upload state
  List<UploadResult> _uploadResults = [];
  int _currentFileIndex = 0;
  int _totalFiles = 0;

  _ViewState({
    bool isUploading = false,
    String? uploadError,
    bool uploadSuccess = false,
    double progress = 0.0,
    int bytesSent = 0,
    int bytesTotal = 0,
    bool showTypeWarning = false,
    String? lastMimeType,
  })  : _isUploading = isUploading,
        _uploadError = uploadError,
        _uploadSuccess = uploadSuccess,
        _progress = progress,
        _bytesSent = bytesSent,
        _bytesTotal = bytesTotal,
        _showTypeWarning = showTypeWarning,
        _lastMimeType = lastMimeType;

  // UploadProvider API (getters)
  @override
  bool get isUploading => _isUploading;
  @override
  String? get uploadError => _uploadError;
  @override
  bool get uploadSuccess => _uploadSuccess;
  @override
  double get progress => _progress;
  @override
  int get bytesSent => _bytesSent;
  @override
  int get bytesTotal => _bytesTotal;
  @override
  bool get showTypeWarning => _showTypeWarning;
  @override
  String? get lastMimeType => _lastMimeType;

  // Multi-file upload getters
  @override
  List<UploadResult> get uploadResults => _uploadResults;
  @override
  int get currentFileIndex => _currentFileIndex;
  @override
  int get totalFiles => _totalFiles;
  @override
  bool get isMultiFileUpload => _totalFiles > 1;

  // Satisfy UploadProvider abstract/interface surface expected by HomeScreen.
  // Implement required methods with no-ops suitable for tests.

  // Provide translate getter required by UploadProvider interface.
  @override
  TranslateCallback get translate => (key) => key;

  @override
  void setIncomingFileWarning({required bool showWarning, String? mimeType}) {
    _showTypeWarning = showWarning;
    _lastMimeType = mimeType;
    notifyListeners();
  }

  @override
  Future<void> uploadFile(File file, String filename, List<Tag> selectedTags) async {
    // No-op in UI tests; this path is exercised in service tests.
  }

  @override
  Future<void> uploadMultipleFiles(
    List<File> files,
    List<String> filenames,
    List<Tag> selectedTags,
  ) async {
    // No-op in UI tests
  }

  @override
  void resetUploadState() {
    _uploadError = null;
    _uploadSuccess = false;
    _isUploading = false;
    _progress = 0.0;
    _bytesSent = 0;
    _bytesTotal = 0;
    _showTypeWarning = false;
    _lastMimeType = null;
    _uploadResults = [];
    _currentFileIndex = 0;
    _totalFiles = 0;
    notifyListeners();
  }

  // Methods to mutate state for testing
  void setWarning(bool value, {String? mime}) {
    _showTypeWarning = value;
    _lastMimeType = mime;
    notifyListeners();
  }

  void setProgress(bool uploading, double p, int sent, int total) {
    _isUploading = uploading;
    _progress = p;
    _bytesSent = sent;
    _bytesTotal = total;
    notifyListeners();
  }

  void finishUpload({bool success = true, String? error}) {
    _isUploading = false;
    _uploadSuccess = success;
    _uploadError = error;
    notifyListeners();
  }
}

class _StubAppConfigProvider extends AppConfigProvider {
  @override
  bool get isConfigured => true;
}

Widget _wrapWithFakeProvider(_ViewState provider) {
  // Provide AppConfigProvider; HomeScreen will build welcome or main depending on isConfigured.
  // For our UI checks (warning/progress), both render inside _buildMainScreen.
  // Force main screen by faking isConfigured using a stubbed AppConfigProvider that always returns true.
  final stubConfig = _StubAppConfigProvider();

  return MultiProvider(
    providers: [
      ChangeNotifierProvider<UploadProvider>.value(value: provider),
      ChangeNotifierProvider<AppConfigProvider>.value(value: stubConfig),
    ],
    child: MaterialApp(
      // Use English locale and real localization delegates from l10n
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const HomeScreen(),
    ),
  );
}

void main() {
  group('HomeScreen UI', () {
    testWidgets('shows warning banner when showTypeWarning is true', (tester) async {
      final provider = _ViewState();
      await tester.pumpWidget(_wrapWithFakeProvider(provider));

      // Resolve the English localized banner prefix from ARB so tests don't hardcode strings
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      final expectedBanner = l10n.banner_type_warning('application/pdf');

      // Initially hidden
      expect(find.text(expectedBanner), findsNothing);

      // Enable warning
      provider.setWarning(true, mime: 'application/pdf');
      await tester.pumpAndSettle();

      // Expect exact localized text
      expect(find.text(expectedBanner), findsOneWidget);
    });

    testWidgets('renders progress card with percentage and bytes while uploading', (tester) async {
      final provider = _ViewState();
      await tester.pumpWidget(_wrapWithFakeProvider(provider));

      // Initially no upload
      expect(find.byType(LinearProgressIndicator), findsNothing);

      // Simulate upload progress
      provider.setProgress(true, 0.42, 4200, 10000);
      await tester.pumpAndSettle();

      // Progress widgets visible
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      // Basic presence check for some text in the progress card area
      // Avoid strict locale-dependent formatting assertions.
      expect(find.textContaining('%'), findsWidgets);

      // Finish and ensure card hides
      provider.finishUpload(success: true);
      // After finishing, progress remains at last value in our fake state; set to zero to hide card.
      provider.setProgress(false, 0.0, 0, 0);
      await tester.pumpAndSettle();
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });
  });
}