# flutter_callkit_incoming_example

Demonstrates how to use the `flutter_callkit_incoming` plugin.

## Getting Started

```sh
flutter pub get
flutter run
```

## Notification delegate demo

The home page has a **Call notification delegate demo** entry that opens
[notifications_demo_page.dart](lib/notifications/notifications_demo_page.dart).
It uses
[flutter_local_notifications_callkit_delegate.dart](lib/notifications/flutter_local_notifications_callkit_delegate.dart),
a production-oriented implementation of the plugin's
`CallkitNotificationDelegate` contract backed by
`flutter_local_notifications` 23.x.

The demo is self-contained: it calls the delegate directly, so it works before
the plugin's `FlutterCallkitIncoming.setNotificationDelegate()` host hook is
available. Once that hook is available, install the same instance from
`main.dart`:

```dart
await callkitNotifications.initialize();
FlutterCallkitIncoming.setNotificationDelegate(callkitNotifications);
```

The delegate never prompts for permission during initialization. Tap
**Request permission** first on macOS, iOS and web; Android 13+ also needs
`POST_NOTIFICATIONS`. Linux and Windows do not have a runtime permission
prompt. On the web the permission prompt must be triggered by a user gesture,
and notification actions are only shown by Chromium-based browsers.

Platform-specific setup (Windows AppUserModelID/GUID, Linux notification
daemon, web service worker and `flutter_web_plugins`) is documented in the
[main README](../README.md#-host-owned-call-notifications-with-flutter_local_notifications).
