import 'dart:async';

import 'package:flutter_callkit_incoming/entities/entities.dart';

import 'callkit_web_notification_bridge.dart';

/// Abstraction over timers so ring timeouts can be tested without waiting.
abstract class CallkitWebClock {
  /// Schedules [callback] after [duration].
  ///
  /// Returns a function that cancels the pending callback.
  void Function() schedule(Duration duration, void Function() callback);
}

/// [CallkitWebClock] backed by the regular Dart [Timer].
class RealCallkitWebClock implements CallkitWebClock {
  /// Creates a clock that uses [Timer].
  const RealCallkitWebClock();

  @override
  void Function() schedule(Duration duration, void Function() callback) {
    final Timer timer = Timer(duration, callback);
    return timer.cancel;
  }
}

/// In-memory call state machine used by the web implementation of
/// `flutter_callkit_incoming`.
///
/// The engine implements the semantics of the Android implementation of the
/// plugin on top of the browser Notification API:
///
/// * `showCallkitIncoming` stores the call, emits `ACTION_CALL_INCOMING` and
///   asks the browser to show a notification.
/// * `startCall` stores an outgoing call and emits `ACTION_CALL_START`.
/// * `endCall` emits `ACTION_CALL_ENDED` for accepted calls and
///   `ACTION_CALL_DECLINE` for ringing calls, then forgets the call.
/// * `endAllCalls` does the same for every active call.
/// * `activeCalls` returns the current in-memory calls.
/// * clicking a call notification emits `ACTION_CALL_ACCEPT`, dismissing it
///   emits `ACTION_CALL_DECLINE`.
/// * the ring timeout (`CallKitParams.duration`, 30 seconds by default) emits
///   `ACTION_CALL_TIMEOUT`.
///
/// This class intentionally does not import any web-only library so it can be
/// unit tested on the Dart VM.
class CallkitWebEngine {
  /// Creates an engine.
  ///
  /// [notificationBridge] defaults to a bridge that never shows notifications,
  /// [clock] defaults to [RealCallkitWebClock].
  CallkitWebEngine({
    CallkitWebNotificationBridge? notificationBridge,
    CallkitWebClock? clock,
  })  : _notifications = notificationBridge ??
            const UnsupportedCallkitWebNotificationBridge(),
        _clock = clock ?? const RealCallkitWebClock();

  /// Default ring duration used when [CallKitParams.duration] is not set.
  ///
  /// Matches the default used by the Android implementation.
  static const int defaultRingTimeoutMs = 30000;

  final CallkitWebNotificationBridge _notifications;
  final CallkitWebClock _clock;
  final Map<String, _WebCall> _calls = <String, _WebCall>{};
  final StreamController<Map<String, dynamic>> _eventController =
      StreamController<Map<String, dynamic>>.broadcast();

  bool _eventsSilenced = false;
  bool _disposed = false;

  /// Raw event envelopes (`{'event': ..., 'body': ...}`) consumed by the
  /// platform-side event channel.
  Stream<Map<String, dynamic>> get events => _eventController.stream;

  /// The bridge used to show browser notifications.
  CallkitWebNotificationBridge get notificationBridge => _notifications;

  /// Whether the browser exposes the Notification API.
  bool get isNotificationSupported => _notifications.isSupported;

  /// Current browser notification permission.
  String get notificationPermission => _notifications.permission;

  /// Whether event emission is currently silenced.
  bool get areEventsSilenced => _eventsSilenced;

  /// Snapshot of the calls currently tracked by the engine.
  List<CallKitParams> get activeCallParams => _calls.values
      .map((_WebCall call) => call.toCallKitParams())
      .toList(growable: false);

  /// Handles a method call coming from the public Dart API.
  ///
  /// Unknown method names resolve to `null` instead of throwing so that new
  /// (native only) methods do not break web applications.
  Future<dynamic> handleMethodCall(String method, dynamic arguments) async {
    switch (method) {
      case 'showCallkitIncoming':
        return _showCallkitIncoming(arguments);
      case 'showMissCallNotification':
        return _showMissCallNotification(arguments);
      case 'hideCallkitIncoming':
        return _hideCallkitIncoming(arguments);
      case 'startCall':
        return _startCall(arguments);
      case 'muteCall':
        return _setMuted(arguments);
      case 'isMuted':
        return _isMuted(arguments);
      case 'holdCall':
        return _setOnHold(arguments);
      case 'endCall':
        return _endCall(arguments);
      case 'callConnected':
        return _callConnected(arguments);
      case 'endAllCalls':
        return _endAllCalls();
      case 'activeCalls':
        return _activeCalls();
      case 'getDevicePushTokenVoIP':
        return null;
      case 'silenceEvents':
        _eventsSilenced = arguments == true;
        return true;
      case 'requestNotificationPermission':
        return _requestNotificationPermission();
      case 'requestFullIntentPermission':
        // Full screen intents are an Android concept; the browser cannot grant
        // them.
        return false;
      case 'canUseFullScreenIntent':
        return false;
      case 'setAcceptCallHandle':
        // Background/terminated execution is not available on the web.
        return null;
      case 'registerBackgroundHandler':
        return null;
      case 'getBackgroundHandler':
        return 0;
      default:
        return null;
    }
  }

  /// Releases resources held by the engine.
  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    for (final _WebCall call in _calls.values) {
      call.cancelTimeout?.call();
      call.cancelTimeout = null;
    }
    _calls.clear();
    unawaited(_notifications.closeAll());
    unawaited(_eventController.close());
  }

  Future<bool> _showCallkitIncoming(dynamic arguments) async {
    final CallKitParams? params = _asParams(arguments);
    if (params == null) {
      return false;
    }
    await _forgetCall(params.id);
    final _WebCall call = _WebCall(params);
    _calls[params.id] = call;
    _emitEvent(CallEventConstants.actionCallIncoming, call.eventBody());
    await _showNotification(call);
    _scheduleTimeout(call);
    return true;
  }

  Future<bool> _showMissCallNotification(dynamic arguments) async {
    final CallKitParams? params = _asParams(arguments);
    if (params == null) {
      return false;
    }
    final String title = _firstNonEmpty(<String?>[
          params.nameCaller,
          params.appName,
          params.handle,
        ]) ??
        'Missed call';
    final String? handle = params.handle;
    final bool shown = await _notifications.show(
      CallkitWebNotification(
        id: 'missed_${params.id}',
        title: title,
        body: handle == null || handle.isEmpty
            ? 'Missed call'
            : 'Missed call \u2022 $handle',
        tag: 'callkit_missed_${params.id}',
        icon: _iconFor(params),
      ),
      onClick: () => _emitEvent(
        CallEventConstants.actionCallCallback,
        _callBody(params, isAccepted: false),
      ),
    );
    return shown || !_notifications.isSupported;
  }

  Future<bool> _hideCallkitIncoming(dynamic arguments) async {
    final CallKitParams? params = _asParams(arguments);
    if (params == null) {
      return false;
    }
    if (!_calls.containsKey(params.id)) {
      await _notifications.close(params.id);
      return true;
    }
    // The Android implementation sends ACTION_CALL_ENDED when the incoming
    // notification is cleared, mirror that behaviour here.
    await _forgetCall(
      params.id,
      event: CallEventConstants.actionCallEnded,
    );
    return true;
  }

  Future<bool> _startCall(dynamic arguments) async {
    final CallKitParams? params = _asParams(arguments);
    if (params == null) {
      return false;
    }
    await _forgetCall(params.id);
    final _WebCall call = _WebCall(params);
    _calls[params.id] = call;
    _emitEvent(CallEventConstants.actionCallStart, call.eventBody());
    return true;
  }

  Future<bool> _endCall(dynamic arguments) async {
    final String? id = _idFrom(arguments);
    if (id == null) {
      return false;
    }
    final _WebCall? call = _calls[id];
    if (call == null) {
      await _notifications.close(id);
      return true;
    }
    await _forgetCall(
      id,
      event: call.isAccepted
          ? CallEventConstants.actionCallEnded
          : CallEventConstants.actionCallDecline,
    );
    return true;
  }

  Future<bool> _endAllCalls() async {
    final List<String> ids = _calls.keys.toList(growable: false);
    for (final String id in ids) {
      final _WebCall? call = _calls[id];
      if (call == null) {
        continue;
      }
      await _forgetCall(
        id,
        event: call.isAccepted
            ? CallEventConstants.actionCallEnded
            : CallEventConstants.actionCallDecline,
      );
    }
    await _notifications.closeAll();
    return true;
  }

  Future<bool> _callConnected(dynamic arguments) async {
    final String? id = _idFrom(arguments);
    if (id == null) {
      return false;
    }
    final _WebCall? call = _calls[id];
    if (call == null) {
      return true;
    }
    call.isAccepted = true;
    call.cancelTimeout?.call();
    call.cancelTimeout = null;
    await _notifications.close(id);
    _emitEvent(CallEventConstants.actionCallConnected, call.eventBody());
    return true;
  }

  Future<bool> _setMuted(dynamic arguments) async {
    final Map<String, dynamic>? args = _asJson(arguments);
    final String? id = args?['id'] as String?;
    if (id == null) {
      return false;
    }
    final bool isMuted = args?['isMuted'] as bool? ?? true;
    final _WebCall? call = _calls[id];
    if (call != null) {
      call.isMuted = isMuted;
    }
    _emitEvent(
      CallEventConstants.actionCallToggleMute,
      <String, dynamic>{'id': id, 'isMuted': isMuted},
    );
    return true;
  }

  Future<bool> _isMuted(dynamic arguments) async {
    final String? id = _idFrom(arguments);
    if (id == null) {
      return false;
    }
    return _calls[id]?.isMuted ?? false;
  }

  Future<bool> _setOnHold(dynamic arguments) async {
    final Map<String, dynamic>? args = _asJson(arguments);
    final String? id = args?['id'] as String?;
    if (id == null) {
      return false;
    }
    final bool isOnHold = args?['isOnHold'] as bool? ?? true;
    final _WebCall? call = _calls[id];
    if (call != null) {
      call.isOnHold = isOnHold;
    }
    _emitEvent(
      CallEventConstants.actionCallToggleHold,
      <String, dynamic>{'id': id, 'isOnHold': isOnHold},
    );
    return true;
  }

  Future<bool> _requestNotificationPermission() async {
    if (!_notifications.isSupported) {
      return false;
    }
    final String permission = await _notifications.requestPermission();
    return permission == 'granted';
  }

  List<Map<String, dynamic>> _activeCalls() {
    return _calls.values
        .map((_WebCall call) => call.eventBody())
        .toList(growable: false);
  }

  Future<void> _showNotification(_WebCall call) async {
    final CallKitParams params = call.params;
    final String title = _firstNonEmpty(<String?>[
          params.nameCaller,
          params.appName,
          params.handle,
        ]) ??
        'Incoming call';
    final String? handle = params.handle;
    final bool shown = await _notifications.show(
      CallkitWebNotification(
        id: params.id,
        title: title,
        body: handle ?? '',
        tag: 'callkit_${params.id}',
        icon: _iconFor(params),
      ),
      onClick: () => _acceptCall(params.id),
      onDismiss: () => _declineCall(params.id),
    );
    call.notificationShown = shown;
  }

  Future<void> _acceptCall(String id) async {
    final _WebCall? call = _calls[id];
    if (call == null) {
      return;
    }
    call.isAccepted = true;
    call.cancelTimeout?.call();
    call.cancelTimeout = null;
    await _notifications.close(id);
    _emitEvent(CallEventConstants.actionCallAccept, call.eventBody());
  }

  Future<void> _declineCall(String id) async {
    final _WebCall? call = _calls[id];
    if (call == null || call.isAccepted) {
      return;
    }
    await _forgetCall(id, event: CallEventConstants.actionCallDecline);
  }

  Future<void> _forgetCall(String id, {String? event}) async {
    final _WebCall? call = _calls.remove(id);
    if (call == null) {
      await _notifications.close(id);
      return;
    }
    call.cancelTimeout?.call();
    call.cancelTimeout = null;
    await _notifications.close(id);
    if (event != null) {
      _emitEvent(event, call.eventBody());
    }
  }

  void _scheduleTimeout(_WebCall call) {
    final int durationMs = call.params.duration ?? defaultRingTimeoutMs;
    if (durationMs <= 0) {
      return;
    }
    call.cancelTimeout = _clock.schedule(
      Duration(milliseconds: durationMs),
      () {
        final _WebCall? current = _calls[call.id];
        if (current != call || call.isAccepted) {
          return;
        }
        unawaited(
          _forgetCall(call.id, event: CallEventConstants.actionCallTimeout),
        );
      },
    );
  }

  void _emitEvent(String event, Map<String, dynamic> body) {
    if (_eventsSilenced || _disposed || _eventController.isClosed) {
      return;
    }
    _eventController.add(<String, dynamic>{'event': event, 'body': body});
  }

  CallKitParams? _asParams(dynamic arguments) {
    final Map<String, dynamic>? json = _asJson(arguments);
    if (json == null) {
      return null;
    }
    try {
      return CallKitParams.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  String? _idFrom(dynamic arguments) {
    if (arguments is String) {
      return arguments;
    }
    final Map<String, dynamic>? json = _asJson(arguments);
    final String? id = json?['id'] as String?;
    return id;
  }

  Map<String, dynamic>? _asJson(dynamic value) {
    if (value is! Map) {
      return null;
    }
    return _convertMap(value) as Map<String, dynamic>;
  }

  dynamic _convertMap(dynamic value) {
    if (value is Map) {
      return value.map(
        (dynamic key, dynamic item) =>
            MapEntry<String, dynamic>(key.toString(), _convertMap(item)),
      );
    }
    if (value is List) {
      return value.map(_convertMap).toList();
    }
    return value;
  }

  String? _iconFor(CallKitParams params) {
    final String? icon = params.avatar;
    if (icon == null || icon.isEmpty) {
      return null;
    }
    if (icon.startsWith('http://') ||
        icon.startsWith('https://') ||
        icon.startsWith('data:') ||
        icon.startsWith('/')) {
      return icon;
    }
    return null;
  }

  String? _firstNonEmpty(List<String?> values) {
    for (final String? value in values) {
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }
    return null;
  }

  Map<String, dynamic> _callBody(
    CallKitParams params, {
    required bool isAccepted,
  }) {
    final Map<String, dynamic> json = <String, dynamic>{...params.toJson()};
    json['isAccepted'] = isAccepted;
    return json;
  }
}

class _WebCall {
  _WebCall(this.params) : isAccepted = params.isAccepted;

  final CallKitParams params;
  bool isAccepted;
  bool isMuted = false;
  bool isOnHold = false;
  bool notificationShown = false;
  void Function()? cancelTimeout;

  String get id => params.id;

  CallKitParams toCallKitParams() {
    return CallKitParams.fromJson(eventBody());
  }

  Map<String, dynamic> eventBody() {
    final Map<String, dynamic> json = <String, dynamic>{...params.toJson()};
    json['isAccepted'] = isAccepted;
    return json;
  }
}
