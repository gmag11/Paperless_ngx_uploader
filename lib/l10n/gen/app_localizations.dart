import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';

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
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

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
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es')
  ];

  /// Title for the dialog where the user configures the Paperless-NGX server URL and credentials.
  ///
  /// In en, this message translates to:
  /// **'Paperless-NGX Configuration'**
  String get dialog_title_paperless_configuration;

  /// Label for the input field where the user enters the Paperless-NGX server URL.
  ///
  /// In en, this message translates to:
  /// **'Server URL'**
  String get field_label_server_url;

  /// Hint text showing an example of a valid Paperless-NGX server URL.
  ///
  /// In en, this message translates to:
  /// **'https://paperless.example.com'**
  String get field_hint_server_url_example;

  /// Validation message shown when the server URL is empty.
  ///
  /// In en, this message translates to:
  /// **'Please enter server URL'**
  String get validation_enter_server_url;

  /// Validation message shown when the server URL format is invalid.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid URL'**
  String get validation_enter_valid_url;

  /// Label for the username input field.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get field_label_username;

  /// Validation message shown when the username is empty.
  ///
  /// In en, this message translates to:
  /// **'Please enter username'**
  String get validation_enter_username;

  /// Label for the password input field.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get field_label_password;

  /// Validation message shown when the password is empty.
  ///
  /// In en, this message translates to:
  /// **'Please enter password'**
  String get validation_enter_password;

  /// Button label to cancel the current operation.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get action_cancel;

  /// Button label to save server settings and test the connection.
  ///
  /// In en, this message translates to:
  /// **'Save & Test'**
  String get action_save_and_test;

  /// Title of the dialog used to select default/global tags.
  ///
  /// In en, this message translates to:
  /// **'Select Tags'**
  String get tag_dialog_title_select_tags;

  /// Generic error title used in error banners or dialogs.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get common_error;

  /// Button label to try the previous operation again.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get action_retry;

  /// Button label to apply selected options.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get action_apply;

  /// Label or hint for the tag search input.
  ///
  /// In en, this message translates to:
  /// **'Search tags'**
  String get search_label_search_tags;

  /// Button to open the tag selection dialog for default tags.
  ///
  /// In en, this message translates to:
  /// **'Select Default Tags'**
  String get action_select_default_tags;

  /// Shown when a file is received from the Android share intent
  ///
  /// In en, this message translates to:
  /// **'Received file: {fileName}'**
  String snackbar_received_file_prefix(String fileName);

  /// Snackbar message shown when a file uploads successfully.
  ///
  /// In en, this message translates to:
  /// **'File uploaded'**
  String get snackbar_file_uploaded;

  /// Shown when upload fails with an error message
  ///
  /// In en, this message translates to:
  /// **'Upload error: {error}'**
  String snackbar_upload_error_prefix(String error);

  /// Title shown in the AppBar on the home screen.
  ///
  /// In en, this message translates to:
  /// **'Paperless-NGX Uploader'**
  String get appbar_title_home;

  /// Title text on the welcome section of the home screen.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Paperless-NGX Uploader'**
  String get welcome_title;

  /// Subtitle guiding the user to configure the server before using the app.
  ///
  /// In en, this message translates to:
  /// **'Configure your Paperless-NGX server to start uploading documents'**
  String get welcome_subtitle;

  /// Button label that opens the configuration dialog from the welcome section.
  ///
  /// In en, this message translates to:
  /// **'Configure Server'**
  String get welcome_action_configure_server;

  /// Non-blocking warning shown for potentially unsupported mime types
  ///
  /// In en, this message translates to:
  /// **'File type {mimeType} may not be supported. Upload will be attempted anyway.'**
  String banner_type_warning(String mimeType);

  /// Panel title displayed while a document is being uploaded.
  ///
  /// In en, this message translates to:
  /// **'Uploading document'**
  String get panel_title_uploading_document;

  /// Progress text with sent and total bytes
  ///
  /// In en, this message translates to:
  /// **'{percent}% ({sentBytes}/{totalBytes} bytes)'**
  String panel_progress_percentage_with_bytes(
      String percent, String sentBytes, String totalBytes);

  /// Progress text only percentage
  ///
  /// In en, this message translates to:
  /// **'{percent}%'**
  String panel_progress_percentage_only(String percent);

  /// Section header for server configuration block.
  ///
  /// In en, this message translates to:
  /// **'Server Configuration'**
  String get section_title_server_configuration;

  /// Text indicating the server is not yet configured.
  ///
  /// In en, this message translates to:
  /// **'Not configured'**
  String get server_not_configured;

  /// Section header for global/default tags configuration.
  ///
  /// In en, this message translates to:
  /// **'Global Tag Configuration'**
  String get section_title_global_tag_configuration;

  /// Tooltip shown on the control to edit the selected tags.
  ///
  /// In en, this message translates to:
  /// **'Edit tags'**
  String get tooltip_edit_tags;

  /// Title text shown when there are no tags selected.
  ///
  /// In en, this message translates to:
  /// **'No tags selected'**
  String get empty_tags_title;

  /// Subtitle prompting the user to open tag selection when none are selected.
  ///
  /// In en, this message translates to:
  /// **'Tap \"Select Tags\" to configure'**
  String get empty_tags_subtitle;

  /// Shows how many tags are configured, plural suffix is '' for 1 and 's' otherwise in current implementation.
  ///
  /// In en, this message translates to:
  /// **'{count} tag{pluralSuffix} configured'**
  String tags_configured_count(String count, String pluralSuffix);

  /// Header for the quick start instructions.
  ///
  /// In en, this message translates to:
  /// **'How to use:'**
  String get howto_title;

  /// First step of the quick start instructions.
  ///
  /// In en, this message translates to:
  /// **'1. Share a document from any app'**
  String get howto_step_1;

  /// Second step of the quick start instructions.
  ///
  /// In en, this message translates to:
  /// **'2. Select \"Paperless-NGX Uploader\"'**
  String get howto_step_2;

  /// Third step of the quick start instructions.
  ///
  /// In en, this message translates to:
  /// **'3. Upload will happen immediately'**
  String get howto_step_3;

  /// Snackbar shown when an action requires server configuration beforehand.
  ///
  /// In en, this message translates to:
  /// **'Please configure server connection first'**
  String get snackbar_configure_server_first;

  /// Error message shown when authentication fails.
  ///
  /// In en, this message translates to:
  /// **'Authentication failed. Check username and password.'**
  String get error_auth_failed;

  /// Error message shown when uploaded file exceeds server size limits.
  ///
  /// In en, this message translates to:
  /// **'The file is too large for the server.'**
  String get error_file_too_large;

  /// Error message shown when file type is not accepted by server.
  ///
  /// In en, this message translates to:
  /// **'File type not supported by the server.'**
  String get error_unsupported_type;

  /// Generic server error message.
  ///
  /// In en, this message translates to:
  /// **'Server error. Try again later.'**
  String get error_server;

  /// Error message shown when network connection fails.
  ///
  /// In en, this message translates to:
  /// **'Network error. Check your connection.'**
  String get error_network;

  /// Error message shown when local file cannot be read.
  ///
  /// In en, this message translates to:
  /// **'Error reading the local file.'**
  String get error_file_read;

  /// Error message shown when server response is malformed or unexpected.
  ///
  /// In en, this message translates to:
  /// **'Invalid server response.'**
  String get error_invalid_response;

  /// Label for the dropdown where user selects authentication method.
  ///
  /// In en, this message translates to:
  /// **'Authentication Method'**
  String get field_label_auth_method;

  /// Option in authentication method dropdown for username/password authentication.
  ///
  /// In en, this message translates to:
  /// **'Username / Password'**
  String get field_option_auth_user_pass;

  /// Option in authentication method dropdown for API token authentication.
  ///
  /// In en, this message translates to:
  /// **'API Token'**
  String get field_option_auth_token;

  /// Label for the API token input field.
  ///
  /// In en, this message translates to:
  /// **'API Token'**
  String get field_label_api_token;

  /// Validation message shown when the API token is empty.
  ///
  /// In en, this message translates to:
  /// **'Please enter API token'**
  String get validation_enter_token;

  /// Error message shown when the provided API token is invalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid token'**
  String get error_invalid_token;

  /// Error message shown when the provided username/password combination is invalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid username or password'**
  String get error_invalid_credentials;

  /// Error message shown when the server cannot be reached.
  ///
  /// In en, this message translates to:
  /// **'Server is unreachable'**
  String get error_server_unreachable;

  /// Error message shown when the URL is not a valid Paperless-NGX server.
  ///
  /// In en, this message translates to:
  /// **'Invalid server URL or not a Paperless-NGX server'**
  String get error_invalid_server;

  /// Error message shown when there is an SSL certificate validation error.
  ///
  /// In en, this message translates to:
  /// **'SSL certificate error'**
  String get error_ssl;

  /// Generic error message shown when an unspecified connection error occurs.
  ///
  /// In en, this message translates to:
  /// **'Unknown connection error occurred'**
  String get error_unknown;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
