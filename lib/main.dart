import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'screens/home_screen.dart';
import 'providers/app_config_provider.dart';
import 'providers/upload_provider.dart';
import 'services/intent_handler.dart';
import 'l10n/gen/app_localizations.dart';

void main() {
  // Ensure bindings so we can initialize platform channels safely
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Android share intent handling
  IntentHandler.initialize();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppConfigProvider()),
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
  const PaperlessUploaderApp({super.key});

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
      locale: const Locale('en'),
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
