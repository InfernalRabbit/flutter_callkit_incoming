import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'callkit_web_notification_bridge.dart';

/// A [CallkitWebNotificationBridge] backed by the browser Notification API.
///
/// Uses `package:web` together with `dart:js_interop` only, so it compiles for
/// both the JavaScript and the WebAssembly Flutter web targets.
class BrowserCallkitWebNotificationBridge
    implements CallkitWebNotificationBridge {
  /// Creates a bridge that talks to the browser `Notification` API.
  BrowserCallkitWebNotificationBridge();

  final Map<String, web.Notification> _notifications =
      <String, web.Notification>{};

  @override
  bool get isSupported {
    try {
      // Reading the static property throws when the browser does not expose
      // the Notification API (insecure context, old browser, worker, ...).
      final String permission = web.Notification.permission;
      return permission == 'granted' ||
          permission == 'denied' ||
          permission == 'default';
    } catch (_) {
      return false;
    }
  }

  @override
  bool get isSecureContext {
    try {
      return web.window.isSecureContext;
    } catch (_) {
      return false;
    }
  }

  @override
  String get permission {
    if (!isSupported) {
      return 'unsupported';
    }
    try {
      return web.Notification.permission;
    } catch (_) {
      return 'unsupported';
    }
  }

  @override
  bool get isPermissionGranted => permission == 'granted';

  @override
  Future<String> requestPermission() async {
    if (!isSupported) {
      return 'unsupported';
    }
    try {
      final JSString result = await web.Notification.requestPermission().toDart;
      return result.toDart;
    } catch (_) {
      // Browsers may reject the promise when it is not triggered by a user
      // gesture. Report the current permission instead of throwing.
      return permission;
    }
  }

  @override
  Future<bool> show(
    CallkitWebNotification notification, {
    void Function()? onClick,
    void Function()? onDismiss,
  }) async {
    if (!isPermissionGranted) {
      return false;
    }
    try {
      await close(notification.id);

      final String? icon = notification.icon;
      final web.NotificationOptions options;
      if (icon == null || icon.isEmpty) {
        options = web.NotificationOptions(
          body: notification.body ?? '',
          tag: notification.tag ?? notification.id,
          requireInteraction: notification.requireInteraction,
          silent: notification.silent,
        );
      } else {
        options = web.NotificationOptions(
          body: notification.body ?? '',
          tag: notification.tag ?? notification.id,
          requireInteraction: notification.requireInteraction,
          silent: notification.silent,
          icon: icon,
        );
      }

      final web.Notification browserNotification =
          web.Notification(notification.title, options);

      browserNotification.onclick = ((web.Event event) {
        onClick?.call();
        try {
          web.window.focus();
        } catch (_) {
          // Focusing the window is best effort.
        }
      }).toJS;

      browserNotification.onclose = ((web.Event event) {
        onDismiss?.call();
      }).toJS;

      _notifications[notification.id] = browserNotification;
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> close(String id) async {
    final web.Notification? browserNotification = _notifications.remove(id);
    if (browserNotification == null) {
      return;
    }
    try {
      // Clear the callback first so that closing the notification from Dart is
      // not reported back as a user dismissal.
      browserNotification.onclose = null;
      browserNotification.close();
    } catch (_) {
      // The notification may already be gone.
    }
  }

  @override
  Future<void> closeAll() async {
    for (final String id in _notifications.keys.toList(growable: false)) {
      await close(id);
    }
  }
}
