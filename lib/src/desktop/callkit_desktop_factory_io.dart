import 'dart:io';

import 'callkit_desktop_controller.dart';
import 'callkit_desktop_platform.dart';

/// Returns the Dart desktop backend on macOS/Windows/Linux, or `null` on
/// Android/iOS.
CallkitDesktopPlatform? callkitDesktopPlatform() {
  if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
    return CallkitDesktopController.instance;
  }
  return null;
}
