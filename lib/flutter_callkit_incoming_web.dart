import 'package:flutter/foundation.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';

import 'src/web/browser_callkit_web_notification_bridge.dart';
import 'src/web/callkit_web_channel_host.dart';
import 'src/web/callkit_web_engine.dart';
import 'src/web/callkit_web_notification_bridge.dart';

/// Web implementation of flutter_callkit_incoming.
///
/// The Flutter tool generates web_plugin_registrant.dart from the web platform
/// entry in pubspec.yaml and calls [registerWith] before the application
/// starts. Registration installs handlers for the flutter_callkit_incoming
/// method channel and the flutter_callkit_incoming_events event channel, so the
/// public Dart API in lib/flutter_callkit_incoming.dart keeps working unchanged
/// on the web.
///
/// The web implementation is a browser-based approximation of the native
/// plugins: calls are tracked in memory and surfaced through the browser
/// Notification API. It does **not** provide CallKit/ConnectionService
/// integration, background ringing or VoIP push notifications.
///
/// Ask for the notification permission from a user gesture, for example in an
/// onPressed callback:
///
///     final bool granted = await FlutterCallkitIncoming
///         .requestNotificationPermission(<String, dynamic>{});
class FlutterCallkitIncomingWeb {
  FlutterCallkitIncomingWeb._();

  static CallkitWebChannelHost? _host;
  static CallkitWebNotificationBridge? _bridge;

  /// Registers the web implementation.
  ///
  /// Called by the generated web_plugin_registrant.dart; applications do not
  /// need to call this method themselves.
  static void registerWith(Registrar registrar) {
    registerWithBridge(registrar,
        bridge: BrowserCallkitWebNotificationBridge());
  }

  /// Registers the web implementation with a custom notification [bridge].
  ///
  /// Exposed for tests and for applications that want to replace the browser
  /// notification integration (for example with a custom in-app overlay).
  @visibleForTesting
  static void registerWithBridge(
    Registrar registrar, {
    required CallkitWebNotificationBridge bridge,
  }) {
    if (_host != null) {
      return;
    }
    final CallkitWebChannelHost host = CallkitWebChannelHost(
      messenger: registrar,
      engine: CallkitWebEngine(notificationBridge: bridge),
    );
    host.register();
    _host = host;
    _bridge = bridge;
  }

  /// Whether the web implementation has been registered.
  static bool get isRegistered => _host != null;

  /// Whether the browser exposes the Notification API.
  static bool get isNotificationSupported => _bridge?.isSupported ?? false;

  /// Whether the page runs in a secure context (HTTPS or localhost).
  static bool get isSecureContext => _bridge?.isSecureContext ?? false;

  /// Current browser notification permission.
  ///
  /// One of granted, denied, default or unsupported.
  static String get notificationPermission =>
      _bridge?.permission ?? 'unsupported';

  /// Asks the browser for the notification permission.
  ///
  /// Returns the resulting permission string. Most browsers require this to be
  /// called from a user gesture.
  static Future<String> requestNotificationPermission() async {
    final CallkitWebNotificationBridge? bridge = _bridge;
    if (bridge == null) {
      return 'unsupported';
    }
    return bridge.requestPermission();
  }
}
