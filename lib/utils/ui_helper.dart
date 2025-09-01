import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

class UIHelper {
  /// Show a short user-visible message. On mobile it uses Fluttertoast; on
  /// desktop it also shows a SnackBar via the provided context.
  static void showMessage(BuildContext? context, String message, {bool success = true}) {
    // Always show a toast where Fluttertoast works
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

    // On desktop platforms, ensure the message is visible via SnackBar
    try {
      if (context != null && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
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
