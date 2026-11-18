import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_callkit_incoming/src/notifications/callkit_notification_dispatcher.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_notification_delegate.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeCallkitNotificationDelegate delegate;
  late CallkitNotificationDispatcher dispatcher;

  setUp(() {
    delegate = FakeCallkitNotificationDelegate();
    dispatcher = CallkitNotificationDispatcher(delegate: delegate);
  });

  tearDown(() async {
    // Leave the process-wide dispatcher clean for tests that use the public
    // API in this file or in other test files.
    CallkitNotificationDispatcher.instance.delegate = null;
    await dispatcher.dispose();
    await delegate.dispose();
  });

  CallKitParams params({
    String id = 'call-1',
    String? nameCaller = 'Alice',
    String? appName = 'Callkit',
    String? handle = 'alice@example.com',
    int? type = 0,
    Map<String, dynamic>? extra,
  }) {
    return CallKitParams(
      id: id,
      nameCaller: nameCaller,
      appName: appName,
      handle: handle,
      type: type,
      extra: extra,
    );
  }

  test('public API sets, exposes and clears the delegate', () {
    expect(FlutterCallkitIncoming.notificationDelegate, isNull);

    FlutterCallkitIncoming.setNotificationDelegate(delegate);
    expect(FlutterCallkitIncoming.notificationDelegate, same(delegate));
    expect(FlutterCallkitIncoming.getNotificationDelegate(), same(delegate));

    FlutterCallkitIncoming.clearNotificationDelegate();
    expect(FlutterCallkitIncoming.notificationDelegate, isNull);
    expect(FlutterCallkitIncoming.getNotificationDelegate(), isNull);

    // Clearing an already empty delegate is a no-op.
    FlutterCallkitIncoming.clearNotificationDelegate();
    expect(FlutterCallkitIncoming.notificationDelegate, isNull);
  });

  test('maps CallKitParams onto the delegate call', () async {
    await dispatcher.showIncoming(
      callkitNotificationCallFromParams(
        params(
          type: 1,
          extra: <String, dynamic>{'roomId': 'room-42'},
        ),
      ),
    );

    final CallkitNotificationCall call = delegate.incomingCalls.single;
    expect(call.callId, 'call-1');
    expect(call.callerName, 'Alice');
    expect(call.handle, 'alice@example.com');
    expect(call.appName, 'Callkit');
    expect(call.isVideo, isTrue);
    expect(call.extra, <String, dynamic>{'roomId': 'room-42'});
  });

  test('falls back to sensible call values', () async {
    await dispatcher.showIncoming(
      callkitNotificationCallFromParams(
        params(nameCaller: '  ', appName: null, handle: '  ', type: null),
      ),
    );

    final CallkitNotificationCall call = delegate.incomingCalls.single;
    expect(call.callerName, 'Incoming call');
    expect(call.handle, '  ');
    expect(call.appName, CallkitNotificationCall.defaultAppName);
    expect(call.isVideo, isFalse);
    expect(call.extra, isEmpty);
  });

  test('forwards show, missed, cancel and cancelAll', () async {
    await dispatcher.showIncoming(
      callkitNotificationCallFromParams(params()),
    );
    await dispatcher.showMissed(
      callkitNotificationCallFromParams(params(id: 'missed-1')),
    );
    await dispatcher.cancel('call-1');
    await dispatcher.cancelAll();

    expect(delegate.incomingCalls.single.callId, 'call-1');
    expect(delegate.missedCalls.single.callId, 'missed-1');
    expect(delegate.cancelledCallIds, <String>['call-1']);
    expect(delegate.cancelAllCount, 1);
  });

  test('without a delegate every operation is a logged no-op', () async {
    final CallkitNotificationDispatcher headless =
        CallkitNotificationDispatcher();
    addTearDown(headless.dispose);

    final DebugPrintCallback originalDebugPrint = debugPrint;
    final List<String> logs = <String>[];
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) {
        logs.add(message);
      }
    };
    addTearDown(() => debugPrint = originalDebugPrint);

    await headless.showIncoming(callkitNotificationCallFromParams(params()));
    await headless.showMissed(callkitNotificationCallFromParams(params()));
    await headless.cancel('call-1');
    await headless.cancelAll();

    expect(
      logs.where((String line) =>
          line.contains('No CallkitNotificationDelegate is installed')),
      hasLength(1),
    );
  });

  test('re-publishes actions and follows delegate replacement', () async {
    final List<CallkitNotificationAction> actions =
        <CallkitNotificationAction>[];
    final StreamSubscription<CallkitNotificationAction> subscription =
        dispatcher.actions.listen(actions.add);
    addTearDown(subscription.cancel);

    delegate.emitAction('call-1', CallkitNotificationActionType.accept);
    await pumpEventQueue();
    expect(actions, hasLength(1));
    expect(actions.single.callId, 'call-1');
    expect(actions.single.type, CallkitNotificationActionType.accept);

    final FakeCallkitNotificationDelegate replacement =
        FakeCallkitNotificationDelegate();
    addTearDown(replacement.dispose);
    dispatcher.delegate = replacement;

    // The old delegate is detached.
    delegate.emitAction('call-1', CallkitNotificationActionType.decline);
    await pumpEventQueue();
    expect(actions, hasLength(1));

    replacement.emitAction('call-2', CallkitNotificationActionType.end);
    await pumpEventQueue();
    expect(actions, hasLength(2));
    expect(actions.last.callId, 'call-2');
    expect(actions.last.type, CallkitNotificationActionType.end);
  });

  test('a throwing delegate never breaks the caller', () async {
    delegate.throwOnEveryCall = true;

    final DebugPrintCallback originalDebugPrint = debugPrint;
    final List<String> logs = <String>[];
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) {
        logs.add(message);
      }
    };
    addTearDown(() => debugPrint = originalDebugPrint);

    await dispatcher.showIncoming(callkitNotificationCallFromParams(params()));
    await dispatcher.showMissed(callkitNotificationCallFromParams(params()));
    await dispatcher.cancel('call-1');
    await dispatcher.cancelAll();

    expect(logs.where((String line) => line.contains('failed')), isNotEmpty);
  });
}
