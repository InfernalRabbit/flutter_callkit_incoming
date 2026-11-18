import 'package:flutter_web_plugins/flutter_web_plugins.dart';

import 'src/web/callkit_web_channel_host.dart';
import 'src/web/callkit_web_engine.dart';

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
/// plugins: calls are tracked in memory and call notification presentation is
/// delegated to the host application. Implement and install a
/// `CallkitNotificationDelegate` with
/// `FlutterCallkitIncoming.setNotificationDelegate()`; the plugin itself no
/// longer uses the browser Notification API. It does **not** provide
/// CallKit/ConnectionService integration, background ringing or VoIP push
/// notifications.
///
/// Without a delegate the call state machine and the event stream keep
/// working, but no system notification appears.
class FlutterCallkitIncomingWeb {
  FlutterCallkitIncomingWeb._();

  static CallkitWebChannelHost? _host;

  /// Registers the web implementation.
  ///
  /// Called by the generated web_plugin_registrant.dart; applications do not
  /// need to call this method themselves.
  static void registerWith(Registrar registrar) {
    if (_host != null) {
      return;
    }
    final CallkitWebChannelHost host = CallkitWebChannelHost(
      messenger: registrar,
      engine: CallkitWebEngine(),
    );
    host.register();
    _host = host;
  }

  /// Whether the web implementation has been registered.
  static bool get isRegistered => _host != null;
}
