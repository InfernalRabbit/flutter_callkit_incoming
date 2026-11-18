import 'dart:async';

import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';

/// In-memory [CallkitNotificationDelegate] shared by the notification tests.
class FakeCallkitNotificationDelegate implements CallkitNotificationDelegate {
  final List<CallkitNotificationCall> incomingCalls =
      <CallkitNotificationCall>[];
  final List<CallkitNotificationCall> missedCalls = <CallkitNotificationCall>[];
  final List<String> cancelledCallIds = <String>[];
  int cancelAllCount = 0;

  /// When true every notification operation throws, which lets tests assert
  /// that a broken delegate never breaks the call state machine.
  bool throwOnEveryCall = false;

  final StreamController<CallkitNotificationAction> _actions =
      StreamController<CallkitNotificationAction>.broadcast();

  @override
  Stream<CallkitNotificationAction> get actions => _actions.stream;

  /// Simulates an action from the notification UI.
  void emitAction(String callId, CallkitNotificationActionType type) {
    _actions.add(CallkitNotificationAction(callId: callId, type: type));
  }

  @override
  Future<void> showIncoming(CallkitNotificationCall call) async {
    _maybeThrow();
    incomingCalls.add(call);
  }

  @override
  Future<void> showMissed(CallkitNotificationCall call) async {
    _maybeThrow();
    missedCalls.add(call);
  }

  @override
  Future<void> cancel(String callId) async {
    _maybeThrow();
    cancelledCallIds.add(callId);
  }

  @override
  Future<void> cancelAll() async {
    _maybeThrow();
    cancelAllCount++;
  }

  void _maybeThrow() {
    if (throwOnEveryCall) {
      throw StateError('fake delegate failure');
    }
  }

  Future<void> dispose() => _actions.close();
}
