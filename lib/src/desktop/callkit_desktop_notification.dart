import 'package:flutter/foundation.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:local_notifier/local_notifier.dart';

/// Which kind of desktop notification to display.
enum CallkitDesktopNotificationKind {
  /// A ringing/incoming call.
  incoming,

  /// A missed-call notification.
  missedCall,
}

/// Thin seam over the OS notification implementation.
///
/// The controller only depends on this interface, which keeps the call
/// registry and event stream testable without a running platform plugin.
abstract class CallkitDesktopNotification {
  /// Called when the user activates (clicks) a notification.
  set onTap(void Function(String callId)? handler);

  /// Shows (or replaces) the notification for [params.id].
  Future<void> show(
    String callId,
    CallKitParams params, {
    required CallkitDesktopNotificationKind kind,
  });

  /// Removes the notification for [callId], if one is displayed.
  Future<void> hide(String callId);

  /// Removes every notification shown by this instance.
  Future<void> hideAll();

  /// Releases the notifications/listeners held by this instance.
  Future<void> dispose();
}

/// Best-effort OS notifications for macOS, Windows and Linux.
///
/// Uses the [local_notifier] plugin, which is implemented natively on all
/// three desktop platforms (NSUserNotification on macOS, WinToast on Windows,
/// libnotify on Linux).
///
/// Notifications are strictly advisory: if the native side is missing or
/// rejects a request (for example when the app is not allowed to post
/// notifications) the failure is logged once and the in-memory call registry
/// keeps working.
class LocalNotifierCallkitDesktopNotification
    implements CallkitDesktopNotification {
  /// Prefix keeps our identifiers from colliding with notifications shown by
  /// the host app through the same local_notifier channel.
  static const String _identifierPrefix = 'flutter_callkit_incoming:';

  static const String _fallbackAppName = 'Flutter Callkit Incoming';

  final Map<String, LocalNotification> _notifications =
      <String, LocalNotification>{};

  void Function(String callId)? _onTap;

  bool _initialized = false;
  bool _unavailable = false;
  String? _appName;

  @override
  set onTap(void Function(String callId)? handler) => _onTap = handler;

  Future<void> _ensureInitialized(String appName) async {
    if (_initialized || _unavailable) {
      return;
    }
    try {
      await LocalNotifier.instance.setup(
        appName: appName,
        // Windows needs an AppUserModelID backed by a Start Menu shortcut for
        // toasts to appear; requireCreate creates it on first use. This flag
        // is ignored on macOS and Linux.
        shortcutPolicy: ShortcutPolicy.requireCreate,
      );
      _appName = appName;
      _initialized = true;
    } catch (error) {
      _unavailable = true;
      debugPrint(
        '[flutter_callkit_incoming] desktop notifications are unavailable: '
        '$error',
      );
    }
  }

  @override
  Future<void> show(
    String callId,
    CallKitParams params, {
    required CallkitDesktopNotificationKind kind,
  }) async {
    if (_unavailable) {
      return;
    }

    final appName = _resolveAppName(params);
    await _ensureInitialized(appName);
    if (_unavailable) {
      return;
    }

    // A call may be re-shown with the same id (for example after a reconnect):
    // drop the previous banner first so the user does not see duplicates.
    await hide(callId);

    LocalNotification? notification;
    try {
      notification = LocalNotification(
        identifier: '$_identifierPrefix$callId',
        title: _title(params, kind),
        subtitle: params.appName,
        body: _body(params, kind),
      );
      notification.onClick = () => _onTap?.call(callId);
      _notifications[callId] = notification;
      await notification.show();
    } catch (error) {
      _unavailable = true;
      _notifications.remove(callId);
      debugPrint(
        '[flutter_callkit_incoming] failed to show desktop notification: '
        '$error',
      );
      await _destroyQuietly(notification);
    }
  }

  @override
  Future<void> hide(String callId) async {
    final notification = _notifications.remove(callId);
    if (notification != null) {
      await _destroyQuietly(notification);
    }
  }

  @override
  Future<void> hideAll() async {
    final notifications = _notifications.values.toList(growable: false);
    _notifications.clear();
    for (final notification in notifications) {
      await _destroyQuietly(notification);
    }
  }

  @override
  Future<void> dispose() => hideAll();

  String _resolveAppName(CallKitParams params) {
    if (_appName != null) {
      return _appName!;
    }
    final appName = params.appName?.trim();
    if (appName != null && appName.isNotEmpty) {
      return appName;
    }
    return _fallbackAppName;
  }

  String _title(CallKitParams params, CallkitDesktopNotificationKind kind) {
    final caller = params.nameCaller?.trim();
    if (caller != null && caller.isNotEmpty) {
      return caller;
    }
    final handle = params.handle?.trim();
    if (handle != null && handle.isNotEmpty) {
      return handle;
    }
    return kind == CallkitDesktopNotificationKind.missedCall
        ? 'Missed call'
        : 'Incoming call';
  }

  String _body(CallKitParams params, CallkitDesktopNotificationKind kind) {
    final handle = params.handle?.trim();
    final hasHandle = handle != null && handle.isNotEmpty;
    if (kind == CallkitDesktopNotificationKind.missedCall) {
      return hasHandle ? 'Missed call - $handle' : 'Missed call';
    }
    if (hasHandle) {
      return handle;
    }
    return params.type == 1 ? 'Video call' : 'Incoming call';
  }

  Future<void> _destroyQuietly(LocalNotification? notification) async {
    if (notification == null) {
      return;
    }
    try {
      await notification.destroy();
    } catch (error) {
      // The platform plugin may already be gone (for example during engine
      // shutdown); there is nothing useful left to do here.
      debugPrint(
        '[flutter_callkit_incoming] failed to close desktop notification: '
        '$error',
      );
    }
  }
}
