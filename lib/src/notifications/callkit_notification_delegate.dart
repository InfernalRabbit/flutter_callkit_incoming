import 'dart:async';

/// A call that the host application should present as a notification.
class CallkitNotificationCall {
  const CallkitNotificationCall({
    required this.callId,
    required this.callerName,
    this.handle,
    this.appName = 'Доступ',
    this.isVideo = false,
    this.extra = const <String, dynamic>{},
  });

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
/// The plugin never creates notification channels or asks for permissions
/// itself. Implement this delegate with flutter_local_notifications (or any
/// other notification stack) and install it with
/// FlutterCallkitIncoming.setNotificationDelegate().
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
  Stream<CallkitNotificationAction> get actions;
}
