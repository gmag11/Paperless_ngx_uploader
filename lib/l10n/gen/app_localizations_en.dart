// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get action_select_none => 'Select none';

  @override
  String get connectionSuccess => 'Connection successful';

  @override
  String get dialog_title_paperless_configuration =>
      'Paperless-NGX Configuration';

  @override
  String get field_label_server_url => 'Server URL';

  @override
  String get field_hint_server_url_example => 'https://paperless.example.com';

  @override
  String get validation_enter_server_url => 'Please enter server URL';

  @override
  String get validation_enter_valid_url => 'Please enter a valid URL';

  @override
  String get field_label_username => 'Username';

  @override
  String get validation_enter_username => 'Please enter username';

  @override
  String get field_label_password => 'Password';

  @override
  String get validation_enter_password => 'Please enter password';

  @override
  String get action_cancel => 'Cancel';

  @override
  String get action_save_and_test => 'Save & Test';

  @override
  String get tag_dialog_title_select_tags => 'Select Tags';

  @override
  String get common_error => 'Error';

  @override
  String get action_retry => 'Retry';

  @override
  String get action_apply => 'Apply';

  @override
  String get search_label_search_tags => 'Search tags';

  @override
  String get action_select_default_tags => 'Select Default Tags';

  @override
  String snackbar_received_file_prefix(String fileName) {
    return 'File: $fileName';
  }

  @override
  String get snackbar_file_uploaded => 'File uploaded';

  @override
  String snackbar_upload_error_prefix(String error) {
    return 'Upload error: $error';
  }

  @override
  String get appbar_title_home => 'Paperless-NGX Uploader';

  @override
  String get welcome_title => 'Welcome to Paperless-NGX Uploader';

  @override
  String get welcome_subtitle =>
      'Configure your Paperless-NGX server to start uploading documents';

  @override
  String get welcome_action_configure_server => 'Configure Server';

  @override
  String banner_type_warning(String mimeType) {
    return 'File type $mimeType may not be supported. Upload will be attempted anyway.';
  }

  @override
  String get panel_title_uploading_document => 'Uploading document';

  @override
  String panel_progress_percentage_with_bytes(
      String percent, String sentBytes, String totalBytes) {
    return '$percent% ($sentBytes/$totalBytes bytes)';
  }

  @override
  String panel_progress_percentage_only(String percent) {
    return '$percent%';
  }

  @override
  String get section_title_server_configuration => 'Paperless-ngx server';

  @override
  String get server_not_configured => 'Not configured';

  @override
  String get section_title_tag_configuration => 'Tag Configuration';

  @override
  String get tooltip_edit_tags => 'Edit tags';

  @override
  String get empty_tags_title => 'No tags selected';

  @override
  String get empty_tags_subtitle => 'Tap \"Select Tags\" to configure';

  @override
  String tags_configured_count(String count, String pluralSuffix) {
    return '$count tag$pluralSuffix configured';
  }

  @override
  String get howto_title => 'How to use:';

  @override
  String get howto_step_1 => '1. Share a document from any app';

  @override
  String get howto_step_2 => '2. Select \"Paperless-NGX Uploader\"';

  @override
  String get howto_step_3 => '3. Upload will happen immediately';

  @override
  String get snackbar_configure_server_first =>
      'Please configure server connection first';

  @override
  String get error_auth_failed =>
      'Authentication failed. Check username and password.';

  @override
  String get error_file_too_large => 'The file is too large for the server.';

  @override
  String get error_unsupported_type => 'File type not supported by the server.';

  @override
  String get error_server => 'Server error. Try again later.';

  @override
  String get error_network => 'Network error. Check your connection.';

  @override
  String get error_file_read => 'Error reading the local file.';

  @override
  String get error_invalid_response => 'Invalid server response.';

  @override
  String get field_label_auth_method => 'Authentication Method';

  @override
  String get field_option_auth_user_pass => 'Username / Password';

  @override
  String get field_option_auth_token => 'API Token';

  @override
  String get field_label_api_token => 'API Token';

  @override
  String get validation_enter_token => 'Please enter API token';

  @override
  String get error_invalid_token => 'Invalid token';

  @override
  String get error_invalid_credentials => 'Invalid username or password';

  @override
  String get error_server_unreachable => 'Server is unreachable';

  @override
  String get error_invalid_server =>
      'Invalid server URL or not a Paperless-NGX server';

  @override
  String get error_ssl => 'SSL certificate error';

  @override
  String get error_unknown => 'Unknown connection error occurred';

  @override
  String get update_available_title => 'Update Available';

  @override
  String update_available_message(String version) {
    return 'A new version $version is available. Would you like to download it?';
  }

  @override
  String get action_download => 'Download';

  @override
  String get action_later => 'Later';
}
