// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get action_select_none => 'Borrar todo';

  @override
  String get dialog_title_paperless_configuration =>
      'Configuración de Paperless-NGX';

  @override
  String get field_label_server_url => 'URL del servidor';

  @override
  String get field_hint_server_url_example => 'https://paperless.ejemplo.com';

  @override
  String get validation_enter_server_url =>
      'Por favor, introduce la URL del servidor';

  @override
  String get validation_enter_valid_url =>
      'Por favor, introduce una URL válida';

  @override
  String get field_label_username => 'Usuario';

  @override
  String get validation_enter_username => 'Por favor, introduce el usuario';

  @override
  String get field_label_password => 'Contraseña';

  @override
  String get validation_enter_password => 'Por favor, introduce la contraseña';

  @override
  String get action_cancel => 'Cancelar';

  @override
  String get action_save_and_test => 'Guardar y Probar';

  @override
  String get tag_dialog_title_select_tags => 'Seleccionar etiquetas';

  @override
  String get common_error => 'Error';

  @override
  String get action_retry => 'Reintentar';

  @override
  String get action_apply => 'Aplicar';

  @override
  String get search_label_search_tags => 'Buscar etiquetas';

  @override
  String get action_select_default_tags => 'Seleccionar etiquetas por defecto';

  @override
  String snackbar_received_file_prefix(String fileName) {
    return 'Archivo: $fileName';
  }

  @override
  String get snackbar_file_uploaded => 'Archivo subido';

  @override
  String snackbar_upload_error_prefix(String error) {
    return 'Error de subida: $error';
  }

  @override
  String get appbar_title_home => 'Paperless-NGX Uploader';

  @override
  String get welcome_title => 'Bienvenido a Paperless-NGX Uploader';

  @override
  String get welcome_subtitle =>
      'Configura tu servidor Paperless‑NGX para comenzar a subir documentos';

  @override
  String get welcome_action_configure_server => 'Configurar servidor';

  @override
  String banner_type_warning(String mimeType) {
    return 'El tipo de archivo $mimeType puede no estar soportado. Se intentará la subida igualmente.';
  }

  @override
  String get panel_title_uploading_document => 'Subiendo documento';

  @override
  String panel_progress_percentage_with_bytes(
    String percent,
    String sentBytes,
    String totalBytes,
  ) {
    return '$percent% ($sentBytes/$totalBytes bytes)';
  }

  @override
  String panel_progress_percentage_only(String percent) {
    return '$percent%';
  }

  @override
  String get section_title_server_configuration => 'Configuración del servidor';

  @override
  String get server_not_configured => 'Sin configurar';

  @override
  String get section_title_global_tag_configuration =>
      'Configuración de etiquetas';

  @override
  String get tooltip_edit_tags => 'Editar etiquetas';

  @override
  String get empty_tags_title => 'No hay etiquetas seleccionadas';

  @override
  String get empty_tags_subtitle =>
      'Pulsa \"Seleccionar etiquetas\" para configurar';

  @override
  String tags_configured_count(String count, String pluralSuffix) {
    return '$count etiqueta$pluralSuffix configurada$pluralSuffix';
  }

  @override
  String get howto_title => 'Cómo usar:';

  @override
  String get howto_step_1 => '1. Comparte un documento desde cualquier app';

  @override
  String get howto_step_2 => '2. Selecciona \"Paperless-NGX Uploader\"';

  @override
  String get howto_step_3 => '3. La subida se realizará inmediatamente';

  @override
  String get snackbar_configure_server_first =>
      'Por favor, configura primero la conexión con el servidor';

  @override
  String get error_auth_failed =>
      'Autenticación fallida. Revisa el usuario y la contraseña.';

  @override
  String get error_file_too_large =>
      'El archivo es demasiado grande para el servidor.';

  @override
  String get error_unsupported_type =>
      'Tipo de archivo no soportado por el servidor.';

  @override
  String get error_server =>
      'Error del servidor. Inténtalo de nuevo más tarde.';

  @override
  String get error_network => 'Error de red. Revisa tu conexión.';

  @override
  String get error_file_read => 'Error al leer el archivo local.';

  @override
  String get error_invalid_response => 'Respuesta del servidor no válida.';

  @override
  String get field_label_auth_method => 'Método de autenticación';

  @override
  String get field_option_auth_user_pass => 'Usuario / Contraseña';

  @override
  String get field_option_auth_token => 'Token API';

  @override
  String get field_label_api_token => 'Token API';

  @override
  String get validation_enter_token => 'Por favor, introduce el token API';

  @override
  String get error_invalid_token => 'Token no válido';

  @override
  String get error_invalid_credentials => 'Usuario o contraseña no válidos';

  @override
  String get error_server_unreachable => 'El servidor no está accesible';

  @override
  String get error_invalid_server =>
      'URL de servidor no válida o no es un servidor Paperless-NGX';

  @override
  String get error_ssl => 'Error de certificado SSL';

  @override
  String get error_unknown =>
      'Se ha producido un error de conexión desconocido';
}
