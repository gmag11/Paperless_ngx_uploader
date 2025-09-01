import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'screens/home_screen.dart';
import 'providers/app_config_provider.dart';
import 'providers/server_manager.dart';
import 'providers/upload_provider.dart';
import 'services/intent_handler.dart';
import 'services/legacy_migration_service.dart';
import 'l10n/gen/app_localizations.dart';
import 'dart:developer' as developer;
import 'dart:io' show Platform;

// Optional: only import window_size on desktop platforms
// ignore: uri_does_not_exist
import 'package:window_size/window_size.dart' as window_size;

void main() async {
  // Ensure bindings so we can initialize platform channels safely
  WidgetsFlutterBinding.ensureInitialized();

  // On desktop platforms, set a compact small window size similar to a
  // smartphone default. Use a conservative size that works on typical
  // desktop screens.
  try {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      const width = 420.0; // compact width
      const height = 620.0; // compact height
      final screen = await window_size.getCurrentScreen();
      if (screen != null) {
        final frame = screen.visibleFrame;
        final left = (frame.width - width) / 2 + frame.left;
        final top = (frame.height - height) / 2 + frame.top;
        window_size.setWindowFrame(Rect.fromLTWH(left, top, width, height));
        window_size.setWindowTitle('Paperless-NGX Uploader');
        window_size.setWindowMinSize(const Size(360, 600));
      }
    }
  } catch (e) {
    developer.log('Could not set desktop window size: $e', name: 'main');
  }

  // Initialize Android share intent handling
  IntentHandler.initialize();

  // Initialize and perform legacy migration if needed
  await _performLegacyMigration();
}

/// Performs legacy configuration migration before app initialization
Future<void> _performLegacyMigration() async {
  try {
    final hasLegacy = await LegacyMigrationService.hasLegacyConfiguration();
    if (hasLegacy) {
      developer.log('Legacy configuration detected, starting migration...', name: 'main');
      
      final summary = await LegacyMigrationService.getMigrationSummary();
      developer.log('Migration summary: $summary', name: 'main');
      
      final migratedConfig = await LegacyMigrationService.migrateLegacyConfiguration();
      if (migratedConfig != null) {
        // Create a temporary server manager to handle the migration
        final serverManager = ServerManager();
        await serverManager.refresh();
        
        // Add the migrated server
        await serverManager.addServer(migratedConfig);
        await serverManager.selectServer(migratedConfig.id);
        
        // Clean up legacy configuration
        await LegacyMigrationService.cleanupLegacyConfiguration();
        
        developer.log('Migration completed successfully', name: 'main');
      }
    } else {
      developer.log('No legacy configuration found, skipping migration', name: 'main');
    }
  } catch (e) {
    developer.log('Migration failed: $e', name: 'main', error: e);
    // Continue app startup even if migration fails
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ServerManager()),
        ChangeNotifierProxyProvider<ServerManager, AppConfigProvider>(
          create: (context) =>
              AppConfigProvider(
                Provider.of<ServerManager>(context, listen: false),
              ),
          update: (context, serverManager, previous) =>
              previous ?? AppConfigProvider(serverManager),
        ),
        ChangeNotifierProxyProvider<AppConfigProvider, UploadProvider>(
          create: (context) =>
              UploadProvider(
                appConfigProvider: Provider.of<AppConfigProvider>(context, listen: false),
                translate: (key) {
                  final l10n = AppLocalizations.of(context);
                  if (l10n == null) return key;
                  switch (key) {
                    case 'snackbar_configure_server_first':
                      return l10n.snackbar_configure_server_first;
                    case 'error_auth_failed':
                      return l10n.error_auth_failed;
                    case 'error_file_too_large':
                      return l10n.error_file_too_large;
                    case 'error_unsupported_type':
                      return l10n.error_unsupported_type;
                    case 'error_server':
                      return l10n.error_server;
                    case 'error_network':
                      return l10n.error_network;
                    case 'error_file_read':
                      return l10n.error_file_read;
                    case 'error_invalid_response':
                      return l10n.error_invalid_response;
                    default:
                      return key;
                  }
                },
              ),
          update: (context, appConfig, previous) =>
              previous ?? UploadProvider(
                appConfigProvider: appConfig,
                translate: (key) {
                  final l10n = AppLocalizations.of(context);
                  if (l10n == null) return key;
                  switch (key) {
                    case 'snackbar_configure_server_first':
                      return l10n.snackbar_configure_server_first;
                    case 'error_auth_failed':
                      return l10n.error_auth_failed;
                    case 'error_file_too_large':
                      return l10n.error_file_too_large;
                    case 'error_unsupported_type':
                      return l10n.error_unsupported_type;
                    case 'error_server':
                      return l10n.error_server;
                    case 'error_network':
                      return l10n.error_network;
                    case 'error_file_read':
                      return l10n.error_file_read;
                    case 'error_invalid_response':
                      return l10n.error_invalid_response;
                    default:
                      return key;
                  }
                },
              ),
        ),
      ],
      child: const PaperlessUploaderApp(),
    ),
  );
}

class PaperlessUploaderApp extends StatelessWidget {
  const PaperlessUploaderApp({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Paperless-NGX Uploader',
      // Localization configuration
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      // Remove hardcoded locale to follow device language (es will be picked on Spanish devices)
      // locale: const Locale('en'),
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const HomeScreen(),
      },
    );
  }
}
