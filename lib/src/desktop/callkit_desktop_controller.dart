import 'dart:async';

import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_callkit_incoming/src/notifications/callkit_notification_delegate.dart';
import 'package:flutter_callkit_incoming/src/notifications/callkit_notification_dispatcher.dart';

import 'callkit_desktop_platform.dart';

/// Dart-only implementation of the plugin for macOS, Windows and Linux.
///
/// The desktop platforms do not have an OS-level call UI (CallKit / Connection
/// Service), so this implementation keeps an in-memory registry of active calls
/// and mirrors the mobile event stream:
///
/// * `showCallkitIncoming` registers the call, asks the host application's
///   notification delegate to present it and emits
///   [CallEventActionCallIncoming].
/// * `startCall` registers an outgoing call and emits
///   [CallEventActionCallStart].
/// * `endCall` / `endAllCalls` remove calls, dismiss notifications and emit
///   [CallEventActionCallDecline] for unanswered incoming calls or
///   [CallEventActionCallEnded] for accepted/outgoing calls (same split as
///   Android).
/// * `activeCalls` returns the registry contents.
///
/// Notification presentation is owned by the host application. Install a
/// [CallkitNotificationDelegate] with
/// `FlutterCallkitIncoming.setNotificationDelegate()`. Without one the
/// registry and event stream keep working; only the OS notification is missing.
///
/// All state is process-local: a hot restart or app relaunch starts with an
/// empty registry, and nothing is persisted to disk.
class CallkitDesktopController implements CallkitDesktopPlatform {
  /// Creates a controller.
  ///
  /// [notifications] defaults to the process-wide
  /// [CallkitNotificationDispatcher.instance]. Tests pass their own dispatcher
  /// to install an isolated fake delegate.
  CallkitDesktopController({CallkitNotificationDispatcher? notifications})
      : _notifications =
            notifications ?? CallkitNotificationDispatcher.instance {
    _actionSubscription = _notifications.actions.listen(
      (CallkitNotificationAction action) {
        unawaited(_handleNotificationAction(action));
      },
    );
  }

  /// Shared instance used by the public API on desktop.
  static final CallkitDesktopController instance = CallkitDesktopController();

  final CallkitNotificationDispatcher _notifications;

  final Map<String, _DesktopCall> _calls = <String, _DesktopCall>{};

  final StreamController<CallEvent?> _events =
      StreamController<CallEvent?>.broadcast();

  StreamSubscription<CallkitNotificationAction>? _actionSubscription;

  bool _silenceEvents = false;
  bool _registered = false;

  /// Called by the generated desktop plugin registrant.
  void register() {
    _registered = true;
  }

  /// Whether [register] ran (the generated registrant always runs before
  /// `main()` on macOS/Windows/Linux).
  bool get isRegistered => _registered;

  @override
  Stream<CallEvent?> get onEvent => _events.stream;

  @override
  Future<void> showCallkitIncoming(CallKitParams params) async {
    final call = _DesktopCall(params);
    _calls[params.id] = call;

    await _notifications
        .showIncoming(callkitNotificationCallFromParams(params));
    _emit(CallEventActionCallIncoming(_snapshot(call)));
  }

  @override
  Future<void> showMissCallNotification(CallKitParams params) async {
    // A missed call is no longer an active/ringing call.
    _calls.remove(params.id);
    await _notifications.cancel(params.id);
    await _notifications.showMissed(callkitNotificationCallFromParams(params));
  }

  @override
  Future<void> hideCallkitIncoming(CallKitParams params) {
    return _notifications.cancel(params.id);
  }

  @override
  Future<void> startCall(CallKitParams params) async {
    final call = _DesktopCall(params, isOutgoing: true);
    _calls[params.id] = call;
    _emit(CallEventActionCallStart(_snapshot(call)));
  }

  @override
  Future<void> muteCall(String id, {bool isMuted = true}) async {
    final call = _calls[id];
    if (call != null) {
      call.muted = isMuted;
    }
    // Android emits the toggle event from the platform side even for unknown
    // ids; desktop keeps that contract so existing listeners keep working.
    _emit(CallEventActionCallToggleMute(id, isMuted));
  }

  @override
  Future<bool> isMuted(String id) async => _calls[id]?.muted ?? false;

  @override
  Future<void> holdCall(String id, {bool isOnHold = true}) async {
    final call = _calls[id];
    if (call != null) {
      call.onHold = isOnHold;
    }
    _emit(CallEventActionCallToggleHold(id, isOnHold));
  }

  @override
  Future<void> endCall(String id) async {
    final call = _calls.remove(id);
    await _notifications.cancel(id);
    if (call == null) {
      // Unknown id: match the mobile plugins and stay silent.
      return;
    }
    _emit(_endEvent(call));
  }

  @override
  Future<void> setCallConnected(String id) async {
    final call = _calls[id];
    if (call != null) {
      call.connected = true;
    }
    // The ringing banner is stale once the call is connected. There is no
    // ongoing-call notification on desktop.
    await _notifications.cancel(id);
    if (call != null) {
      _emit(CallEventActionCallConnected(id));
    }
  }

  @override
  Future<void> endAllCalls() async {
    final calls = _calls.values.toList(growable: false);
    _calls.clear();
    await _notifications.cancelAll();
    for (final call in calls) {
      _emit(_endEvent(call));
    }
  }

  @override
  Future<List<CallKitParams>> activeCalls() async {
    return _calls.values.map(_snapshot).toList(growable: false);
  }

  @override
  Future<String?> getDevicePushTokenVoIP() async => null;

  @override
  Future<bool> setSilenceEvents(bool silence) async {
    _silenceEvents = silence;
    return true;
  }

  @override
  Future<bool> requestNotificationPermission(dynamic data) async => true;

  @override
  Future<bool> requestFullIntentPermission() async => false;

  @override
  Future<bool> canUseFullScreenIntent() async => false;

  /// Releases the event stream. Only used by tests; the app-facing singleton
  /// lives for the whole process.
  Future<void> dispose() async {
    final StreamSubscription<CallkitNotificationAction>? subscription =
        _actionSubscription;
    _actionSubscription = null;
    await subscription?.cancel();
    await _notifications.cancelAll();
    await _events.close();
  }

  CallEvent _endEvent(_DesktopCall call) {
    if (call.isAccepted || call.isOutgoing) {
      return CallEventActionCallEnded(_snapshot(call));
    }
    return CallEventActionCallDecline(_snapshot(call));
  }

  Future<void> _handleNotificationAction(
      CallkitNotificationAction action) async {
    final _DesktopCall? call = _calls[action.callId];
    if (call == null) {
      return;
    }
    switch (action.type) {
      case CallkitNotificationActionType.accept:
        await _acceptCall(call);
        break;
      case CallkitNotificationActionType.decline:
        await _declineCall(call);
        break;
      case CallkitNotificationActionType.end:
        await endCall(call.id);
        break;
      case CallkitNotificationActionType.click:
        // Desktop has no native accept/decline buttons, so a click is a
        // request to bring the call to the front: re-emit the incoming event
        // and let the app show its own call UI.
        if (!call.connected) {
          _emit(CallEventActionCallIncoming(_snapshot(call)));
        }
        break;
    }
  }

  Future<void> _acceptCall(_DesktopCall call) async {
    if (!identical(_calls[call.id], call) || call.isAccepted) {
      return;
    }
    call.connected = true;
    await _notifications.cancel(call.id);
    if (!identical(_calls[call.id], call)) {
      return;
    }
    _emit(CallEventActionCallAccept(_snapshot(call)));
  }

  Future<void> _declineCall(_DesktopCall call) async {
    if (!identical(_calls[call.id], call) || call.isAccepted) {
      return;
    }
    _calls.remove(call.id);
    await _notifications.cancel(call.id);
    _emit(CallEventActionCallDecline(_snapshot(call)));
  }

  void _emit(CallEvent event) {
    if (_silenceEvents || _events.isClosed) {
      return;
    }
    _events.add(event);
  }

  CallKitParams _snapshot(_DesktopCall call) {
    final params = call.params;
    if (!call.connected || params.isAccepted) {
      return params;
    }
    // `activeCalls()` and the end events should report the live state, but
    // CallKitParams is immutable, so rebuild it with the updated flag.
    return CallKitParams(
      id: params.id,
      nameCaller: params.nameCaller,
      appName: params.appName,
      avatar: params.avatar,
      handle: params.handle,
      type: params.type,
      duration: params.duration,
      isAccepted: true,
      missedCallNotification: params.missedCallNotification,
      callingNotification: params.callingNotification,
      extra: params.extra,
      headers: params.headers,
      android: params.android,
      ios: params.ios,
    );
  }
}

class _DesktopCall {
  _DesktopCall(this.params, {this.isOutgoing = false});

  final CallKitParams params;
  final bool isOutgoing;

  bool connected = false;
  bool muted = false;
  bool onHold = false;

  String get id => params.id;

  bool get isAccepted => connected || params.isAccepted;
}
