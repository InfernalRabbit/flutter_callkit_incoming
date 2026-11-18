import 'dart:async';

import 'package:flutter_callkit_incoming/entities/entities.dart';

/// Backend contract for the Dart-only desktop implementation.
///
/// This file is platform-neutral (no `dart:io`, no `local_notifier` import) so
/// that `flutter_callkit_incoming.dart` can import it on every platform,
/// including the web, where [callkitDesktopPlatform] resolves to `null`.
abstract class CallkitDesktopPlatform {
  /// Events emitted by the in-memory desktop call registry.
  Stream<CallEvent?> get onEvent;

  Future<void> showCallkitIncoming(CallKitParams params);

  Future<void> showMissCallNotification(CallKitParams params);

  Future<void> hideCallkitIncoming(CallKitParams params);

  Future<void> startCall(CallKitParams params);

  Future<void> muteCall(String id, {bool isMuted = true});

  Future<bool> isMuted(String id);

  Future<void> holdCall(String id, {bool isOnHold = true});

  Future<void> endCall(String id);

  Future<void> setCallConnected(String id);

  Future<void> endAllCalls();

  Future<List<CallKitParams>> activeCalls();

  Future<String?> getDevicePushTokenVoIP();

  Future<bool> setSilenceEvents(bool silence);

  Future<bool> requestNotificationPermission(dynamic data);

  Future<bool> requestFullIntentPermission();

  Future<bool> canUseFullScreenIntent();
}
