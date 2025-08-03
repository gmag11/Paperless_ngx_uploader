import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en')
  ];

  /// No description provided for @dialog_title_paperless_configuration.
  ///
  /// In en, this message translates to:
  /// **'Paperless-NGX Configuration'**
  String get dialog_title_paperless_configuration;

  /// No description provided for @field_label_server_url.
  ///
  /// In en, this message translates to:
  /// **'Server URL'**
  String get field_label_server_url;

  /// No description provided for @field_hint_server_url_example.
  ///
  /// In en, this message translates to:
  /// **'https://paperless.example.com'**
  String get field_hint_server_url_example;

  /// No description provided for @validation_enter_server_url.
  ///
  /// In en, this message translates to:
  /// **'Please enter server URL'**
  String get validation_enter_server_url;

  /// No description provided for @validation_enter_valid_url.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid URL'**
  String get validation_enter_valid_url;

  /// No description provided for @field_label_username.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get field_label_username;

  /// No description provided for @validation_enter_username.
  ///
  /// In en, this message translates to:
  /// **'Please enter username'**
  String get validation_enter_username;

  /// No description provided for @field_label_password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get field_label_password;

  /// No description provided for @validation_enter_password.
  ///
  /// In en, this message translates to:
  /// **'Please enter password'**
  String get validation_enter_password;

  /// No description provided for @action_cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get action_cancel;

  /// No description provided for @action_save_and_test.
  ///
  /// In en, this message translates to:
  /// **'Save & Test'**
  String get action_save_and_test;

  /// No description provided for @tag_dialog_title_select_tags.
  ///
  /// In en, this message translates to:
  /// **'Select Tags'**
  String get tag_dialog_title_select_tags;

  /// No description provided for @common_error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get common_error;

  /// No description provided for @action_retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get action_retry;

  /// No description provided for @action_apply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get action_apply;

  /// No description provided for @search_label_search_tags.
  ///
  /// In en, this message translates to:
  /// **'Search tags'**
  String get search_label_search_tags;

  /// No description provided for @action_select_default_tags.
  ///
  /// In en, this message translates to:
  /// **'Select Default Tags'**
  String get action_select_default_tags;

  /// Shown when a file is received from the Android share intent
  ///
  /// In en, this message translates to:
  /// **'Received file: {fileName}'**
  String snackbar_received_file_prefix(String fileName);

  /// No description provided for @snackbar_file_uploaded.
  ///
  /// In en, this message translates to:
  /// **'File uploaded'**
  String get snackbar_file_uploaded;

  /// Shown when upload fails with an error message
  ///
  /// In en, this message translates to:
  /// **'Upload error: {error}'**
  String snackbar_upload_error_prefix(String error);

  /// No description provided for @appbar_title_home.
  ///
  /// In en, this message translates to:
  /// **'Paperless-NGX Uploader'**
  String get appbar_title_home;

  /// No description provided for @welcome_title.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Paperless-NGX Uploader'**
  String get welcome_title;

  /// No description provided for @welcome_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Configure your Paperless-NGX server to start uploading documents'**
  String get welcome_subtitle;

  /// No description provided for @welcome_action_configure_server.
  ///
  /// In en, this message translates to:
  /// **'Configure Server'**
  String get welcome_action_configure_server;

  /// Non-blocking warning shown for potentially unsupported mime types
  ///
  /// In en, this message translates to:
  /// **'File type {mimeType} may not be supported. Upload will be attempted anyway.'**
  String banner_type_warning(String mimeType);

  /// No description provided for @panel_title_uploading_document.
  ///
  /// In en, this message translates to:
  /// **'Uploading document'**
  String get panel_title_uploading_document;

  /// Progress text with sent and total bytes
  ///
  /// In en, this message translates to:
  /// **'{percent}% ({sentBytes}/{totalBytes} bytes)'**
  String panel_progress_percentage_with_bytes(String percent, String sentBytes, String totalBytes);

  /// Progress text only percentage
  ///
  /// In en, this message translates to:
  /// **'{percent}%'**
  String panel_progress_percentage_only(String percent);

  /// No description provided for @section_title_server_configuration.
  ///
  /// In en, this message translates to:
  /// **'Server Configuration'**
  String get section_title_server_configuration;

  /// No description provided for @server_not_configured.
  ///
  /// In en, this message translates to:
  /// **'Not configured'**
  String get server_not_configured;

  /// No description provided for @section_title_global_tag_configuration.
  ///
  /// In en, this message translates to:
  /// **'Global Tag Configuration'**
  String get section_title_global_tag_configuration;

  /// No description provided for @tooltip_edit_tags.
  ///
  /// In en, this message translates to:
  /// **'Edit tags'**
  String get tooltip_edit_tags;

  /// No description provided for @empty_tags_title.
  ///
  /// In en, this message translates to:
  /// **'No tags selected'**
  String get empty_tags_title;

  /// No description provided for @empty_tags_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Tap \"Select Tags\" to configure'**
  String get empty_tags_subtitle;

  /// Shows how many tags are configured, plural suffix is '' for 1 and 's' otherwise in current implementation.
  ///
  /// In en, this message translates to:
  /// **'{count} tag{pluralSuffix} configured'**
  String tags_configured_count(String count, String pluralSuffix);

  /// No description provided for @howto_title.
  ///
  /// In en, this message translates to:
  /// **'How to use:'**
  String get howto_title;

  /// No description provided for @howto_step_1.
  ///
  /// In en, this message translates to:
  /// **'1. Share a document from any app'**
  String get howto_step_1;

  /// No description provided for @howto_step_2.
  ///
  /// In en, this message translates to:
  /// **'2. Select \"Paperless-NGX Uploader\"'**
  String get howto_step_2;

  /// No description provided for @howto_step_3.
  ///
  /// In en, this message translates to:
  /// **'3. Upload will happen immediately'**
  String get howto_step_3;

  /// No description provided for @snackbar_configure_server_first.
  ///
  /// In en, this message translates to:
  /// **'Please configure server connection first'**
  String get snackbar_configure_server_first;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en': return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
