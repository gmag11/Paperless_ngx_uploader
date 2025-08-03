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
              UploadProvider(appConfigProvider: Provider.of<AppConfigProvider>(context, listen: false)),
          update: (context, appConfig, previous) =>
              previous ?? UploadProvider(appConfigProvider: appConfig),
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
