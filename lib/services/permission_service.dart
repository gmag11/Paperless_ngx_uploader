import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../l10n/gen/app_localizations.dart';

class PermissionService {
  /// Checks and requests storage permissions based on Android version
  static Future<bool> checkAndRequestStoragePermissions(BuildContext context) async {
    // Determine which permissions to request based on Android version
    Map<Permission, PermissionStatus> permissions = {};

    // For Android 13+ (API 33+)
    if (await _isAndroid13OrAbove()) {
      permissions[Permission.photos] = await Permission.photos.status;
      permissions[Permission.videos] = await Permission.videos.status;
      permissions[Permission.audio] = await Permission.audio.status;
      permissions[Permission.mediaLibrary] = await Permission.mediaLibrary.status;
    } else {
      // For Android 12 and below
      permissions[Permission.storage] = await Permission.storage.status;
    }

    // Check if any permission is denied
    bool hasDenied = permissions.values.any((status) =>
        status.isDenied || status.isPermanentlyDenied);

    if (!hasDenied) {
      return true; // All permissions granted
    }

    // Request permissions that are not granted
    List<Permission> permissionsToRequest = [];
    for (var entry in permissions.entries) {
      if (entry.value.isDenied || entry.value.isPermanentlyDenied) {
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

    // Check if all permissions are now granted
    bool allGranted = results.values.every((status) => status.isGranted);

    if (!allGranted) {
      // Handle denied permissions
      bool hasPermanentlyDenied = results.values.any((status) => status.isPermanentlyDenied);
      
      if (hasPermanentlyDenied && context.mounted) {
        _showPermissionDeniedDialog(context);
      } else {
        Fluttertoast.showToast(
          msg: "Storage permissions are required to upload files",
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
    // This is a simplified check - in a real app, you might want to use
    // device_info_plus to get the actual Android version
    return true; // For now, assume Android 13+ behavior
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
      // For Android 13+, check all relevant media permissions
      bool photosGranted = await Permission.photos.isGranted;
      bool videosGranted = await Permission.videos.isGranted;
      bool audioGranted = await Permission.audio.isGranted;
      bool mediaLibraryGranted = await Permission.mediaLibrary.isGranted;
      
      // Check if documents permission is available and granted
      bool documentsGranted = true;
      try {
        documentsGranted = await Permission.documents.isGranted;
      } catch (e) {
        // Permission.documents might not be available on all devices
        documentsGranted = true;
      }
      
      return photosGranted && videosGranted && audioGranted &&
             mediaLibraryGranted && documentsGranted;
    } else {
      // For Android 12 and below
      return await Permission.storage.isGranted;
    }
  }
}