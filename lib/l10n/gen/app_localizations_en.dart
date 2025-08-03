// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get dialog_title_paperless_configuration => 'Paperless-NGX Configuration';

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
    return 'Received file: $fileName';
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
  String get welcome_subtitle => 'Configure your Paperless-NGX server to start uploading documents';

  @override
  String get welcome_action_configure_server => 'Configure Server';

  @override
  String banner_type_warning(String mimeType) {
    return 'File type $mimeType may not be supported. Upload will be attempted anyway.';
  }

  @override
  String get panel_title_uploading_document => 'Uploading document';

  @override
  String panel_progress_percentage_with_bytes(String percent, String sentBytes, String totalBytes) {
    return '$percent% ($sentBytes/$totalBytes bytes)';
  }

  @override
  String panel_progress_percentage_only(String percent) {
    return '$percent%';
  }

  @override
  String get section_title_server_configuration => 'Server Configuration';

  @override
  String get server_not_configured => 'Not configured';

  @override
  String get section_title_global_tag_configuration => 'Global Tag Configuration';

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
  String get snackbar_configure_server_first => 'Please configure server connection first';
}
