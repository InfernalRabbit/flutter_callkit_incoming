/// Platform-agnostic model of the browser notifications used by the web
/// implementation of `flutter_callkit_incoming`.
///
/// Nothing in this library imports web-only libraries, which keeps the call
/// state machine testable on the Dart VM (and inside `flutter test`).
library;

/// A notification that the web implementation asks the browser to display for
/// an incoming or missed call.
class CallkitWebNotification {
  /// Creates a notification description.
  const CallkitWebNotification({
    required this.id,
    required this.title,
    this.body,
    this.tag,
    this.icon,
    this.requireInteraction = true,
    this.silent = false,
  });

  /// Identifier of the call this notification belongs to.
  final String id;

  /// Notification title, usually the caller name.
  final String title;

  /// Optional notification body, usually the caller handle.
  final String? body;

  /// Browser notification tag.
  ///
  /// Notifications that share a tag replace each other inside the browser
  /// notification center, which mirrors how the Android implementation reuses
  /// one notification per call.
  final String? tag;

  /// Optional icon URL.
  final String? icon;

  /// Keeps the notification visible until the user interacts with it.
  ///
  /// Browsers are free to ignore this hint.
  final bool requireInteraction;

  /// Whether the notification should be silent.
  final bool silent;
}

/// Bridge to the browser `Notification` API.
///
/// The web implementation of the plugin only depends on this narrow interface.
/// That keeps the in-memory call state machine testable on the Dart VM and
/// allows browsers without the Notification API (or users that denied the
/// permission) to fall back to a no-op implementation.
abstract class CallkitWebNotificationBridge {
  /// Whether the browser exposes the Notification API.
  bool get isSupported;

  /// Whether the current document runs in a secure context.
  ///
  /// Browsers only allow notifications on `https://` or `localhost`.
  bool get isSecureContext;

  /// Current permission as reported by the browser.
  ///
  /// One of `granted`, `denied`, `default` or `unsupported`.
  String get permission;

  /// Whether the browser currently allows the page to show notifications.
  bool get isPermissionGranted => permission == 'granted';

  /// Asks the browser for the notification permission.
  ///
  /// Returns the resulting permission string. Must be called from a user
  /// gesture (for example a button press) in most browsers.
  Future<String> requestPermission();

  /// Shows [notification].
  ///
  /// [onClick] is invoked when the user clicks the notification and
  /// [onDismiss] is invoked when the user dismisses it. [onDismiss] is not
  /// invoked when the plugin closes the notification itself.
  ///
  /// Returns `true` when a notification was actually displayed.
  Future<bool> show(
    CallkitWebNotification notification, {
    void Function()? onClick,
    void Function()? onDismiss,
  });

  /// Closes the notification that belongs to [id], if any.
  Future<void> close(String id);

  /// Closes all notifications created by this bridge.
  Future<void> closeAll();
}

/// A [CallkitWebNotificationBridge] used when the browser cannot show
/// notifications.
///
/// The call state machine and the event stream keep working, the plugin just
/// cannot surface a system notification. This is the documented fallback for
/// browsers without the Notification API and for users that denied the
/// permission.
class UnsupportedCallkitWebNotificationBridge
    implements CallkitWebNotificationBridge {
  /// Creates a bridge that never shows notifications.
  const UnsupportedCallkitWebNotificationBridge();

  @override
  bool get isSupported => false;

  @override
  bool get isSecureContext => false;

  @override
  String get permission => 'unsupported';

  @override
  bool get isPermissionGranted => false;

  @override
  Future<String> requestPermission() async => 'unsupported';

  @override
  Future<bool> show(
    CallkitWebNotification notification, {
    void Function()? onClick,
    void Function()? onDismiss,
  }) async =>
      false;

  @override
  Future<void> close(String id) async {}

  @override
  Future<void> closeAll() async {}
}
