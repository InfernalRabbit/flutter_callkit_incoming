import 'callkit_desktop_controller.dart';

/// Plugin entry point for the Dart-only macOS, Windows and Linux
/// implementations.
///
/// Flutter generates a call to [registerWith] for each desktop platform
/// declared in `pubspec.yaml` (`dartPluginClass: FlutterCallkitIncomingDesktop`).
/// The public API in `flutter_callkit_incoming.dart` then routes the
/// MethodChannel/EventChannel calls to [CallkitDesktopController] instead of
/// the native Android/iOS handlers.
///
/// Applications do not need to call [registerWith] manually: the generated
/// `dart_plugin_registrant.dart` does it before `main()` runs.
class FlutterCallkitIncomingDesktop {
  const FlutterCallkitIncomingDesktop._();

  /// Registers the Dart desktop implementation with the plugin registry.
  static void registerWith() {
    CallkitDesktopController.instance.register();
  }
}
