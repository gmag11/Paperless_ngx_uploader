import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'installer_source_service.dart';

/// Service for checking if a new version of the app is available on GitHub.
///
/// This service:
/// - Checks GitHub releases API for the latest version
/// - Compares with current app version
/// - Limits checks to once per day using persistent storage
/// - Returns structured information about version availability
///
/// Usage:
/// ```dart
/// final versionCheck = VersionCheckService();
/// final result = await versionCheck.checkForUpdates();
/// if (result.hasUpdate) {
///   print('New version available: ${result.latestVersion}');
///   print('Download URL: ${result.releaseUrl}');
/// }
/// ```
class VersionCheckService {
  /// GitHub API endpoint for releases
  static const String _githubApiUrl =
      'https://api.github.com/repos/gmag11/Paperless_ngx_uploader/releases';

  /// SharedPreferences key for storing last check timestamp
  static const String _lastCheckKey = 'last_version_check_timestamp';

  /// Duration between version checks (24 hours)
  static const Duration _checkInterval = Duration(hours: 24);

  /// Checks if a new version is available from GitHub releases.
  ///
  /// This method:
  /// 1. Checks if 24 hours have passed since last check
  /// 2. Fetches latest release info from GitHub API
  /// 3. Compares with current app version
  /// 4. Returns [VersionCheckResult] with update information
  ///
  /// Returns cached result if check was performed within 24 hours.
  Future<VersionCheckResult> checkForUpdates() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();

    // Skip version checks if installed from Play Store or F-Droid
    final isFromStore = await InstallerSourceService.isFromStore();
    if (isFromStore) {
      return VersionCheckResult(
        hasUpdate: false,
        latestVersion: null,
        releaseUrl: null,
        skipped: true,
        lastCheck: now,
      );
    }

    // Check if we should skip the API call due to rate limiting
    final lastCheckTimestamp = prefs.getInt(_lastCheckKey);
    if (lastCheckTimestamp != null) {
      final lastCheck = DateTime.fromMillisecondsSinceEpoch(lastCheckTimestamp);
      if (now.difference(lastCheck) < _checkInterval) {
        return VersionCheckResult(
          hasUpdate: false,
          latestVersion: null,
          releaseUrl: null,
          skipped: true,
          lastCheck: lastCheck,
        );
      }
    }

    try {
      // Get current app version
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      // Fetch latest release from GitHub
      final response = await http.get(
        Uri.parse(_githubApiUrl),
        headers: {
          'Accept': 'application/vnd.github.v3+json',
          'User-Agent': 'PaperlessNGXUploader/${packageInfo.version}',
        },
      );

      if (response.statusCode != 200) {
        throw Exception(
            'GitHub API request failed: ${response.statusCode} ${response.reasonPhrase}');
      }

      final List<dynamic> releases = json.decode(response.body);
      if (releases.isEmpty) {
        throw Exception('No releases found');
      }

      // Get the latest release (first in the list)
      final latestRelease = releases.first;
      final latestVersion = latestRelease['tag_name'] as String;
      final releaseUrl = latestRelease['html_url'] as String;

      // Update last check timestamp
      await prefs.setInt(_lastCheckKey, now.millisecondsSinceEpoch);

      // Compare versions (simple string comparison for semantic versioning)
      final hasUpdate = _isNewerVersion(latestVersion, currentVersion);

      return VersionCheckResult(
        hasUpdate: hasUpdate,
        latestVersion: latestVersion,
        releaseUrl: releaseUrl,
        skipped: false,
        lastCheck: now,
      );
    } catch (e) {
      // Return error state
      return VersionCheckResult(
        hasUpdate: false,
        latestVersion: null,
        releaseUrl: null,
        skipped: false,
        lastCheck: now,
        error: e.toString(),
      );
    }
  }

  /// Compares two version strings to determine if [newVersion] is newer than [currentVersion].
  ///
  /// Supports semantic versioning (e.g., "v1.2.3", "1.2.3", "1.2.3-beta").
  /// Returns true if newVersion > currentVersion.
  bool _isNewerVersion(String newVersion, String currentVersion) {
    // Remove 'v' prefix if present
    final cleanNew = newVersion.replaceFirst('v', '');
    final cleanCurrent = currentVersion.replaceFirst('v', '');

    // Split into version parts
    final newParts = cleanNew.split('.').map((e) {
      // Handle pre-release tags (e.g., "3-beta" -> 3)
      return int.tryParse(e.split('-').first) ?? 0;
    }).toList();

    final currentParts = cleanCurrent.split('.').map((e) {
      return int.tryParse(e.split('-').first) ?? 0;
    }).toList();

    // Ensure both have 3 parts (major.minor.patch)
    while (newParts.length < 3) {
      newParts.add(0);
    }
    while (currentParts.length < 3) {
      currentParts.add(0);
    }

    // Compare major, minor, patch versions
    for (var i = 0; i < 3; i++) {
      if (newParts[i] > currentParts[i]) return true;
      if (newParts[i] < currentParts[i]) return false;
    }

    // If all parts are equal, check for pre-release tags
    final newHasPreRelease = cleanNew.contains('-');
    final currentHasPreRelease = cleanCurrent.contains('-');

    if (!newHasPreRelease && currentHasPreRelease) return true;
    if (newHasPreRelease && !currentHasPreRelease) return false;

    return false;
  }

  /// Manually resets the last check timestamp to allow immediate re-check.
  ///
  /// Useful for testing or when user explicitly requests a version check.
  Future<void> resetLastCheckTimestamp() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastCheckKey);
  }

  /// Gets the timestamp of the last version check.
  ///
  /// Returns null if no check has been performed yet.
  Future<DateTime?> getLastCheckTimestamp() async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getInt(_lastCheckKey);
    return timestamp != null
        ? DateTime.fromMillisecondsSinceEpoch(timestamp)
        : null;
  }
}

/// Result of a version check operation.
///
/// Contains information about whether an update is available,
/// along with relevant metadata.
class VersionCheckResult {
  /// Whether a newer version is available
  final bool hasUpdate;

  /// The latest version string from GitHub (e.g., "v1.5.0")
  final String? latestVersion;

  /// URL to the GitHub release page
  final String? releaseUrl;

  /// Whether the check was skipped due to rate limiting
  final bool skipped;

  /// Timestamp of the last check attempt
  final DateTime lastCheck;

  /// Error message if the check failed
  final String? error;

  const VersionCheckResult({
    required this.hasUpdate,
    required this.latestVersion,
    required this.releaseUrl,
    required this.skipped,
    required this.lastCheck,
    this.error,
  });

  @override
  String toString() {
    if (skipped) {
      return 'Version check skipped (checked within last 24h)';
    }
    if (error != null) {
      return 'Version check failed: $error';
    }
    if (hasUpdate) {
      return 'Update available: $latestVersion at $releaseUrl';
    }
    return 'No updates available (latest: $latestVersion)';
  }
}