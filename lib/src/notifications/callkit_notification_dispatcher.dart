import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';

import 'callkit_notification_delegate.dart';

/// Builds the delegate-facing description of [params].
///
/// Used by the desktop and web implementations so that both platforms hand
/// the host application an identical [CallkitNotificationCall].
CallkitNotificationCall callkitNotificationCallFromParams(
    CallKitParams params) {
  final String callerName = _nonEmpty(params.nameCaller) ??
      _nonEmpty(params.handle) ??
      _nonEmpty(params.appName) ??
      'Incoming call';

  return CallkitNotificationCall(
    callId: params.id,
    callerName: callerName,
    handle: params.handle,
    appName:
        _nonEmpty(params.appName) ?? CallkitNotificationCall.defaultAppName,
    isVideo: params.type == 1,
    extra: params.extra ?? const <String, dynamic>{},
  );
}

String? _nonEmpty(String? value) {
  final String? trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }
  return trimmed;
}

/// Routes call notification presentation to the host application's
/// [CallkitNotificationDelegate].
///
/// On macOS, Windows, Linux and the web the plugin does not own a notification
/// stack. Instead every show/missed/cancel operation is forwarded to the
/// delegate installed with
/// `FlutterCallkitIncoming.setNotificationDelegate()`.
///
/// When no delegate is installed the operations are no-ops: calls are still
/// tracked and events are still emitted, only the OS notification is missing.
/// The first skipped operation logs a warning so the misconfiguration is easy
/// to spot.
///
/// [actions] is a broadcast stream that re-publishes the installed delegate's
/// [CallkitNotificationDelegate.actions]. The desktop controller and the web
/// engine listen to it and translate the actions into the regular plugin
/// events.
class CallkitNotificationDispatcher {
  /// Creates a dispatcher, optionally installing [delegate] immediately.
  ///
  /// Production code uses [instance]. The constructor is exposed so tests can
  /// isolate the delegate from the process-wide singleton.
  CallkitNotificationDispatcher({CallkitNotificationDelegate? delegate})
      : _delegate = delegate {
    _subscribe(delegate);
  }

  /// Process-wide dispatcher used by the plugin.
  static final CallkitNotificationDispatcher instance =
      CallkitNotificationDispatcher();

  final StreamController<CallkitNotificationAction> _actions =
      StreamController<CallkitNotificationAction>.broadcast();

  StreamSubscription<CallkitNotificationAction>? _actionSubscription;

  CallkitNotificationDelegate? _delegate;
  bool _missingDelegateLogged = false;

  /// The delegate currently installed by the host application, if any.
  CallkitNotificationDelegate? get delegate => _delegate;

  /// Whether a delegate is installed.
  bool get isDelegateInstalled => _delegate != null;

  /// Actions emitted by the installed delegate.
  ///
  /// The stream stays open when the delegate is cleared or replaced.
  Stream<CallkitNotificationAction> get actions => _actions.stream;

  /// Installs [delegate] (or removes it when [delegate] is `null`).
  set delegate(CallkitNotificationDelegate? delegate) {
    if (identical(delegate, _delegate)) {
      return;
    }
    unawaited(_actionSubscription?.cancel());
    _actionSubscription = null;
    _delegate = delegate;
    _missingDelegateLogged = false;
    _subscribe(delegate);
  }

  /// Shows a ringing incoming-call notification.
  Future<void> showIncoming(CallkitNotificationCall call) {
    return _run(
      'showIncoming(${call.callId})',
      (CallkitNotificationDelegate delegate) => delegate.showIncoming(call),
    );
  }

  /// Shows a missed-call notification.
  Future<void> showMissed(CallkitNotificationCall call) {
    return _run(
      'showMissed(${call.callId})',
      (CallkitNotificationDelegate delegate) => delegate.showMissed(call),
    );
  }

  /// Removes the notification for [callId].
  Future<void> cancel(String callId) {
    return _run(
      'cancel($callId)',
      (CallkitNotificationDelegate delegate) => delegate.cancel(callId),
    );
  }

  /// Removes every notification created through the delegate.
  Future<void> cancelAll() {
    return _run(
      'cancelAll',
      (CallkitNotificationDelegate delegate) => delegate.cancelAll(),
    );
  }

  /// Releases the action subscription and closes the action stream.
  ///
  /// Only tests and application shutdown should call this; the plugin uses
  /// [instance] for the whole process lifetime.
  Future<void> dispose() async {
    final StreamSubscription<CallkitNotificationAction>? subscription =
        _actionSubscription;
    _actionSubscription = null;
    _delegate = null;
    await subscription?.cancel();
    await _actions.close();
  }

  Future<void> _run(
    String operation,
    Future<void> Function(CallkitNotificationDelegate delegate) action,
  ) async {
    final CallkitNotificationDelegate? delegate = _delegate;
    if (delegate == null) {
      _logMissingDelegate();
      return;
    }
    try {
      await action(delegate);
    } catch (error) {
      // Notification presentation is advisory: a broken delegate must never
      // break the call registry or the event stream.
      debugPrint(
        '[flutter_callkit_incoming] notification delegate $operation failed: '
        '$error',
      );
    }
  }

  void _subscribe(CallkitNotificationDelegate? delegate) {
    if (delegate == null) {
      return;
    }
    try {
      _actionSubscription = delegate.actions.listen(
        _actions.add,
        onError: (Object error, StackTrace stackTrace) {
          debugPrint(
            '[flutter_callkit_incoming] notification delegate actions stream '
            'failed: $error',
          );
        },
      );
    } catch (error) {
      // A single-subscription stream that was already listened to cannot be
      // observed again. Do not let that break platform registration.
      debugPrint(
        '[flutter_callkit_incoming] could not listen to notification delegate '
        'actions: $error',
      );
    }
  }

  void _logMissingDelegate() {
    if (_missingDelegateLogged) {
      return;
    }
    _missingDelegateLogged = true;
    debugPrint(
      '[flutter_callkit_incoming] No CallkitNotificationDelegate is installed; '
      'call notifications are disabled on this platform. Call state and events '
      'keep working. Install a delegate with '
      'FlutterCallkitIncoming.setNotificationDelegate(...).',
    );
  }
}
