import 'dart:io' show Platform;
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../l10n/gen/app_localizations.dart';

class PermissionService {
  /// Checks and requests storage permissions based on Android version
  static Future<bool> checkAndRequestStoragePermissions(BuildContext context) async {
    developer.log('PermissionService.checkAndRequestStoragePermissions: start', name: 'PermissionService');
    final l10n = AppLocalizations.of(context)!;
    // Determine which permissions to request based on Android version
    Map<Permission, PermissionStatus> permissions = {};

    // For Android 13+ (API 33+)
    if (await _isAndroid13OrAbove()) {
      developer.log('PermissionService: Android 13+ detected, checking Permission.photos', name: 'PermissionService');
      permissions[Permission.photos] = await Permission.photos.status;
    } else {
      // For Android 12 and below
      developer.log('PermissionService: Android <=12 detected, checking Permission.storage', name: 'PermissionService');
      permissions[Permission.storage] = await Permission.storage.status;
    }

    // Check if any permission is denied
    bool hasDenied = permissions.values.any((status) =>
        status.isDenied || status.isPermanentlyDenied || status.isLimited);

    developer.log('PermissionService: hasDenied=$hasDenied', name: 'PermissionService');

    if (!hasDenied) {
      developer.log('PermissionService: all permissions granted', name: 'PermissionService');
      return true; // All permissions granted
    }

    // Request permissions that are not granted
    List<Permission> permissionsToRequest = [];
    for (var entry in permissions.entries) {
      if (entry.value.isDenied || entry.value.isPermanentlyDenied || entry.value.isLimited) {
        permissionsToRequest.add(entry.key);
      }
    }

    developer.log('PermissionService: permissionsToRequest=${permissionsToRequest.map((p) => p.toString()).toList()}', name: 'PermissionService');

    if (permissionsToRequest.isEmpty) {
      developer.log('PermissionService: nothing to request, returning true', name: 'PermissionService');
      return true;
    }

    // Request permissions
    Map<Permission, PermissionStatus> results = {};
    for (var permission in permissionsToRequest) {
      developer.log('PermissionService: requesting $permission', name: 'PermissionService');
      results[permission] = await permission.request();
      developer.log('PermissionService: $permission result=${results[permission]}', name: 'PermissionService');
    }

    // Check if all permissions are now granted or limited (acceptable for media)
    bool allGranted = results.values.every((status) =>
        status.isGranted || status.isLimited);

    developer.log('PermissionService: allGranted=$allGranted', name: 'PermissionService');

    if (!allGranted) {
      // Handle denied permissions
      bool hasPermanentlyDenied = results.values.any((status) => status.isPermanentlyDenied);
      developer.log('PermissionService: hasPermanentlyDenied=$hasPermanentlyDenied', name: 'PermissionService');
      
      if (hasPermanentlyDenied && context.mounted) {
        developer.log('PermissionService: showing permission denied dialog', name: 'PermissionService');
        _showPermissionDeniedDialog(context);
      } else {
        developer.log('PermissionService: showing toast for denied permission', name: 'PermissionService');
        Fluttertoast.showToast(
          msg: l10n.error_permission_denied,
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
    }

    developer.log('PermissionService.checkAndRequestStoragePermissions: end', name: 'PermissionService');
    return allGranted;
  }

  /// Checks if device is running Android 13 or above
  static Future<bool> _isAndroid13OrAbove() async {
    try {
      if (!Platform.isAndroid) return false;
      developer.log('PermissionService._isAndroid13OrAbove: checking Android version', name: 'PermissionService');
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      developer.log('PermissionService._isAndroid13OrAbove: sdkInt=${androidInfo.version.sdkInt}', name: 'PermissionService');
      return androidInfo.version.sdkInt >= 33;
    } catch (e) {
      developer.log('PermissionService._isAndroid13OrAbove: error $e', name: 'PermissionService', error: e);
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
    developer.log('PermissionService.hasStoragePermissions: start', name: 'PermissionService');
    if (await _isAndroid13OrAbove()) {
      developer.log('PermissionService.hasStoragePermissions: Android 13+, checking Permission.photos', name: 'PermissionService');
      // For Android 13+, we only need photo permission for documents/images
      return await Permission.photos.isGranted;
    } else {
      developer.log('PermissionService.hasStoragePermissions: Android <=12, checking Permission.storage', name: 'PermissionService');
      // For Android 12 and below
      return await Permission.storage.isGranted;
    }
  }
}