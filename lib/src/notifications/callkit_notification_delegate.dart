import 'dart:async';

/// A call that the host application should present as a notification.
class CallkitNotificationCall {
  const CallkitNotificationCall({
    required this.callId,
    required this.callerName,
    this.handle,
    this.appName = defaultAppName,
    this.isVideo = false,
    this.extra = const <String, dynamic>{},
  });

  /// Fallback application name used when [CallKitParams.appName] is empty.
  static const String defaultAppName = 'Доступ';

  final String callId;
  final String callerName;
  final String? handle;
  final String appName;
  final bool isVideo;
  final Map<String, dynamic> extra;
}

/// User action performed on a call notification.
enum CallkitNotificationActionType { accept, decline, end, click }

class CallkitNotificationAction {
  const CallkitNotificationAction({
    required this.callId,
    required this.type,
  });

  final String callId;
  final CallkitNotificationActionType type;
}

/// Notification presentation is owned by the host application.
///
/// On macOS, Windows, Linux and the web the plugin never creates notification
/// channels or asks for permissions itself. Every call notification operation
/// is forwarded to the delegate installed with
/// `FlutterCallkitIncoming.setNotificationDelegate()`. Implement it with
/// flutter_local_notifications (or any other notification stack).
///
/// Android and iOS keep using their native notification implementations and
/// ignore this delegate. When no delegate is installed on desktop/web, calls
/// are still tracked and events are still emitted, but no OS notification is
/// shown.
abstract class CallkitNotificationDelegate {
  /// Shows a ringing incoming-call notification.
  Future<void> showIncoming(CallkitNotificationCall call);

  /// Shows a missed-call notification (optional; host may ignore it).
  Future<void> showMissed(CallkitNotificationCall call);

  /// Removes the notification for [callId].
  Future<void> cancel(String callId);

  /// Removes every call notification created by the plugin.
  Future<void> cancelAll();

  /// Actions from the notification UI (click/accept/decline/end).
  ///
  /// Return a broadcast stream: the plugin subscribes to it when the delegate
  /// is installed. Emit [CallkitNotificationActionType.accept],
  /// [CallkitNotificationActionType.decline] and
  /// [CallkitNotificationActionType.end] for the corresponding notification
  /// buttons; they become the regular ACTION_CALL_ACCEPT,
  /// ACTION_CALL_DECLINE and ACTION_CALL_ENDED plugin events.
  Stream<CallkitNotificationAction> get actions;
}
