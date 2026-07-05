import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

class UIHelper {
  /// Show a short user-visible message. On mobile it uses Fluttertoast; on
  /// desktop it also shows a SnackBar via the provided context.
  static void showMessage(BuildContext? context, String message, {bool success = true}) {
    // On mobile platforms (Android/iOS), show a native toast via Fluttertoast.
    // On desktop, Fluttertoast has no platform handler and would hang the app.
    if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) {
      try {
        Fluttertoast.showToast(
          msg: message,
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: success ? Colors.green : Colors.red,
          textColor: Colors.white,
          fontSize: 16.0,
        );
      } catch (_) {}
    }

    // On desktop platforms, show a SnackBar so the message is visible.
    // On mobile, also show a SnackBar as a fallback/extra visibility.
    try {
      if (context != null) {
        final messenger = ScaffoldMessenger.maybeOf(context);
        messenger?.hideCurrentSnackBar();
        messenger?.showSnackBar(SnackBar(
          content: Text(message),
          backgroundColor: success ? Colors.green : Colors.red,
          duration: const Duration(seconds: 3),
        ));
      }
    } catch (_) {}
  }
}
