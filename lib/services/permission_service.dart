import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../l10n/gen/app_localizations.dart';

class PermissionService {
  /// Checks and requests storage permissions based on Android version
  static Future<bool> checkAndRequestStoragePermissions(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    // Determine which permissions to request based on Android version
    Map<Permission, PermissionStatus> permissions = {};

    // Para Android 13+ (API 33+)
    if (await _isAndroid13OrAbove()) {
      permissions[Permission.photos] = await Permission.photos.status;
      permissions[Permission.videos] = await Permission.videos.status;
      permissions[Permission.audio] = await Permission.audio.status;
      // Si necesitas documentos, puedes agregar aquí lógica adicional
    } else {
      // Para Android 12 y anteriores
      permissions[Permission.storage] = await Permission.storage.status;
    }

    // Check if any permission is denied
    bool hasDenied = permissions.values.any((status) =>
        status.isDenied || status.isPermanentlyDenied || status.isLimited);

    if (!hasDenied) {
      return true; // All permissions granted
    }

    // Request permissions that are not granted
    List<Permission> permissionsToRequest = [];
    for (var entry in permissions.entries) {
      if (entry.value.isDenied || entry.value.isPermanentlyDenied || entry.value.isLimited) {
        permissionsToRequest.add(entry.key);
      }
    }

    if (permissionsToRequest.isEmpty) {
      return true;
    }

    // Request permissions
    Map<Permission, PermissionStatus> results = {};
    for (var permission in permissionsToRequest) {
      results[permission] = await permission.request();
    }

    // Check if all permissions are now granted or limited (acceptable for media)
    bool allGranted = results.values.every((status) =>
        status.isGranted || status.isLimited);

    if (!allGranted) {
      // Handle denied permissions
      bool hasPermanentlyDenied = results.values.any((status) => status.isPermanentlyDenied);
      
      if (hasPermanentlyDenied && context.mounted) {
        _showPermissionDeniedDialog(context);
      } else {
        Fluttertoast.showToast(
          msg: l10n.error_permission_denied,
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
    }

    return allGranted;
  }

  /// Checks if device is running Android 13 or above
  static Future<bool> _isAndroid13OrAbove() async {
    try {
      if (!Platform.isAndroid) return false;
      
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      return androidInfo.version.sdkInt >= 33;
    } catch (e) {
      debugPrint('Error checking Android version: $e');
      return false; // Default to Android 12 behavior
    }
  }

  /// Shows a dialog when permissions are permanently denied
  static void _showPermissionDeniedDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(l10n.permission_required_title),
          content: Text(l10n.permission_required_message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.action_cancel),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                openAppSettings();
              },
              child: Text(l10n.action_open_settings),
            ),
          ],
        );
      },
    );
  }

  /// Checks if storage permissions are granted without requesting
  static Future<bool> hasStoragePermissions() async {
    if (await _isAndroid13OrAbove()) {
      // Para Android 13+, revisa los permisos relevantes de media
      bool photosGranted = await Permission.photos.isGranted;
      bool videosGranted = await Permission.videos.isGranted;
      bool audioGranted = await Permission.audio.isGranted;
      // Considera concedido si al menos uno está concedido
      return photosGranted && videosGranted && audioGranted;
    } else {
      // Para Android 12 y anteriores
      return await Permission.storage.isGranted;
    }
  }
}