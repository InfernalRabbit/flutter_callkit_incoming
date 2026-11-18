import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_callkit_incoming/src/notifications/callkit_notification_delegate.dart';
import 'package:flutter_callkit_incoming/src/notifications/callkit_notification_dispatcher.dart';
import 'package:flutter_callkit_incoming/src/web/callkit_web_engine.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_notification_delegate.dart';

void main() {
  late FakeCallkitNotificationDelegate delegate;
  late CallkitNotificationDispatcher dispatcher;
  late ManualClock clock;
  late CallkitWebEngine engine;
  late List<Map<String, dynamic>> events;

  setUp(() {
    delegate = FakeCallkitNotificationDelegate();
    dispatcher = CallkitNotificationDispatcher(delegate: delegate);
    clock = ManualClock();
    engine = CallkitWebEngine(notifications: dispatcher, clock: clock);
    events = <Map<String, dynamic>>[];
    engine.events.listen(events.add);
  });

  tearDown(() async {
    engine.dispose();
    await dispatcher.dispose();
    await delegate.dispose();
  });

  Future<void> flush() => pumpEventQueue();

  CallKitParams params({
    String id = 'call-1',
    int? duration,
    bool isAccepted = false,
  }) {
    return CallKitParams(
      id: id,
      nameCaller: 'Alice',
      handle: 'alice@example.com',
      type: 0,
      duration: duration,
      isAccepted: isAccepted,
    );
  }

  List<String> eventNames() => events
      .map((Map<String, dynamic> event) => event['event'] as String)
      .toList();

  test('showCallkitIncoming tracks the call, emits incoming and notifies',
      () async {
    final Object? result = await engine.handleMethodCall(
      'showCallkitIncoming',
      params().toJson(),
    );
    await flush();

    expect(result, isTrue);
    expect(engine.activeCallParams.map((CallKitParams p) => p.id), <String>[
      'call-1',
    ]);
    expect(events, hasLength(1));
    expect(events.single['event'], CallEventConstants.actionCallIncoming);
    expect((events.single['body'] as Map<dynamic, dynamic>)['id'], 'call-1');
    final CallkitNotificationCall shown = delegate.incomingCalls.single;
    expect(shown.callId, 'call-1');
    expect(shown.callerName, 'Alice');
    expect(shown.handle, 'alice@example.com');
    expect(clock.pending, hasLength(1));
    expect(clock.pending.single.duration, const Duration(milliseconds: 30000));
  });

  test('showCallkitIncoming replaces an existing call and notification',
      () async {
    await engine.handleMethodCall('showCallkitIncoming', params().toJson());
    await engine.handleMethodCall('showCallkitIncoming', params().toJson());
    await flush();

    expect(delegate.cancelledCallIds, contains('call-1'));
    expect(engine.activeCallParams, hasLength(1));
    expect(events, hasLength(2));
  });

  test('clicking the notification re-emits ACTION_CALL_INCOMING', () async {
    await engine.handleMethodCall('showCallkitIncoming', params().toJson());
    await flush();

    delegate.emitAction('call-1', CallkitNotificationActionType.click);
    await flush();

    expect(eventNames(), <String>[
      CallEventConstants.actionCallIncoming,
      CallEventConstants.actionCallIncoming,
    ]);
    expect(engine.activeCallParams.single.isAccepted, isFalse);
  });

  test('accept action accepts the call and emits ACTION_CALL_ACCEPT', () async {
    await engine.handleMethodCall('showCallkitIncoming', params().toJson());
    await flush();

    delegate.emitAction('call-1', CallkitNotificationActionType.accept);
    await flush();

    expect(eventNames(), <String>[
      CallEventConstants.actionCallIncoming,
      CallEventConstants.actionCallAccept,
    ]);
    expect(
        (events.last['body'] as Map<dynamic, dynamic>)['isAccepted'], isTrue);
    expect(engine.activeCallParams.single.isAccepted, isTrue);
    expect(delegate.cancelledCallIds, contains('call-1'));
    // The ring timeout must not fire after the call was accepted.
    clock.firePending();
    await flush();
    expect(eventNames(), isNot(contains(CallEventConstants.actionCallTimeout)));
  });

  test('decline action declines the call', () async {
    await engine.handleMethodCall('showCallkitIncoming', params().toJson());
    await flush();

    delegate.emitAction('call-1', CallkitNotificationActionType.decline);
    await flush();

    expect(events.last['event'], CallEventConstants.actionCallDecline);
    expect(engine.activeCallParams, isEmpty);
    expect(delegate.cancelledCallIds, contains('call-1'));
  });

  test('end action ends an accepted call with ACTION_CALL_ENDED', () async {
    await engine.handleMethodCall('showCallkitIncoming', params().toJson());
    await flush();
    delegate.emitAction('call-1', CallkitNotificationActionType.accept);
    await flush();

    delegate.emitAction('call-1', CallkitNotificationActionType.end);
    await flush();

    expect(events.last['event'], CallEventConstants.actionCallEnded);
    expect(engine.activeCallParams, isEmpty);
  });

  test('endCall declines a ringing call', () async {
    await engine.handleMethodCall('showCallkitIncoming', params().toJson());
    await engine.handleMethodCall('endCall', <String, dynamic>{'id': 'call-1'});
    await flush();

    expect(eventNames(), <String>[
      CallEventConstants.actionCallIncoming,
      CallEventConstants.actionCallDecline,
    ]);
    expect(engine.activeCallParams, isEmpty);
    expect(clock.pending, isEmpty);
  });

  test('endCall ends an accepted call', () async {
    await engine.handleMethodCall('showCallkitIncoming', params().toJson());
    await flush();
    delegate.emitAction('call-1', CallkitNotificationActionType.accept);
    await flush();

    await engine.handleMethodCall('endCall', <String, dynamic>{'id': 'call-1'});
    await flush();

    expect(events.last['event'], CallEventConstants.actionCallEnded);
    expect(engine.activeCallParams, isEmpty);
  });

  test('endAllCalls finishes accepted and ringing calls', () async {
    await engine.handleMethodCall(
        'showCallkitIncoming', params(id: 'ringing').toJson());
    await engine.handleMethodCall(
        'showCallkitIncoming', params(id: 'accepted').toJson());
    await flush();
    delegate.emitAction('accepted', CallkitNotificationActionType.accept);
    await flush();

    await engine.handleMethodCall('endAllCalls', <Object?>[]);
    await flush();

    final List<String> names = eventNames();
    expect(names, contains(CallEventConstants.actionCallDecline));
    expect(names, contains(CallEventConstants.actionCallEnded));
    expect(engine.activeCallParams, isEmpty);
    expect(delegate.cancelAllCount, 1);
  });

  test('hideCallkitIncoming clears the call and emits ended', () async {
    await engine.handleMethodCall('showCallkitIncoming', params().toJson());
    await engine.handleMethodCall('hideCallkitIncoming', params().toJson());
    await flush();

    expect(events.last['event'], CallEventConstants.actionCallEnded);
    expect(engine.activeCallParams, isEmpty);
    expect(delegate.cancelledCallIds, contains('call-1'));
  });

  test('ring timeout emits ACTION_CALL_TIMEOUT and clears the call', () async {
    await engine.handleMethodCall(
        'showCallkitIncoming', params(duration: 1500).toJson());
    await flush();

    expect(clock.pending.single.duration, const Duration(milliseconds: 1500));
    clock.firePending();
    await flush();

    expect(events.last['event'], CallEventConstants.actionCallTimeout);
    expect(engine.activeCallParams, isEmpty);
    expect(delegate.cancelledCallIds, contains('call-1'));
  });

  test('duration <= 0 disables the ring timeout', () async {
    await engine.handleMethodCall(
        'showCallkitIncoming', params(duration: 0).toJson());
    await flush();

    expect(clock.pending, isEmpty);
    expect(engine.activeCallParams, hasLength(1));
  });

  test('startCall emits ACTION_CALL_START without a notification', () async {
    final Object? result =
        await engine.handleMethodCall('startCall', params().toJson());
    await flush();

    expect(result, isTrue);
    expect(events.single['event'], CallEventConstants.actionCallStart);
    expect(engine.activeCallParams, hasLength(1));
    expect(delegate.incomingCalls, isEmpty);
  });

  test('callConnected marks the call accepted', () async {
    await engine.handleMethodCall('showCallkitIncoming', params().toJson());
    await flush();

    await engine
        .handleMethodCall('callConnected', <String, dynamic>{'id': 'call-1'});
    await flush();

    expect(events.last['event'], CallEventConstants.actionCallConnected);
    expect(engine.activeCallParams.single.isAccepted, isTrue);
    expect(delegate.cancelledCallIds, contains('call-1'));
  });

  test('activeCalls returns the in-memory calls as JSON', () async {
    await engine.handleMethodCall(
        'showCallkitIncoming', params(id: 'call-1').toJson());
    await engine.handleMethodCall(
        'showCallkitIncoming', params(id: 'call-2').toJson());
    await flush();
    delegate.emitAction('call-2', CallkitNotificationActionType.accept);
    await flush();

    final List<Map<String, dynamic>> calls = (await engine.handleMethodCall(
        'activeCalls', null)) as List<Map<String, dynamic>>;

    expect(calls.map((Map<String, dynamic> c) => c['id']), <String>[
      'call-1',
      'call-2',
    ]);
    expect(calls[0]['isAccepted'], isFalse);
    expect(calls[1]['isAccepted'], isTrue);
    expect(CallKitParams.fromJson(calls[1]).id, 'call-2');
  });

  test('mute and hold update state and emit toggle events', () async {
    await engine.handleMethodCall('showCallkitIncoming', params().toJson());
    await flush();

    expect(
      await engine
          .handleMethodCall('isMuted', <String, dynamic>{'id': 'call-1'}),
      isFalse,
    );

    await engine.handleMethodCall(
        'muteCall', <String, dynamic>{'id': 'call-1', 'isMuted': true});
    expect(
      await engine
          .handleMethodCall('isMuted', <String, dynamic>{'id': 'call-1'}),
      isTrue,
    );
    await engine.handleMethodCall(
        'holdCall', <String, dynamic>{'id': 'call-1', 'isOnHold': true});
    await flush();

    expect(events.last['event'], CallEventConstants.actionCallToggleHold);
    expect((events.last['body'] as Map<dynamic, dynamic>)['isOnHold'], isTrue);
    expect(
      events.map((Map<String, dynamic> e) => e['event']),
      contains(CallEventConstants.actionCallToggleMute),
    );
  });

  test('silenceEvents suppresses event emission', () async {
    await engine.handleMethodCall('silenceEvents', true);
    await engine.handleMethodCall('showCallkitIncoming', params().toJson());
    await flush();

    expect(engine.activeCallParams, hasLength(1));
    expect(events, isEmpty);

    await engine.handleMethodCall('silenceEvents', false);
    await engine.handleMethodCall('endCall', <String, dynamic>{'id': 'call-1'});
    await flush();
    expect(events.single['event'], CallEventConstants.actionCallDecline);
  });

  test('without a delegate the engine is a headless call state machine',
      () async {
    final CallkitNotificationDispatcher headlessDispatcher =
        CallkitNotificationDispatcher();
    addTearDown(headlessDispatcher.dispose);
    final CallkitWebEngine headless = CallkitWebEngine(
      notifications: headlessDispatcher,
      clock: clock,
    );
    addTearDown(headless.dispose);
    final List<Map<String, dynamic>> headlessEvents = <Map<String, dynamic>>[];
    headless.events.listen(headlessEvents.add);

    expect(headless.isNotificationDelegateInstalled, isFalse);
    expect(
        await headless.handleMethodCall(
            'showCallkitIncoming', params().toJson()),
        isTrue);
    await flush();

    expect(headless.activeCallParams, hasLength(1));
    expect(headless.activeCallParams.single.id, 'call-1');
    expect(
        headlessEvents.single['event'], CallEventConstants.actionCallIncoming);
    expect(
      await headless.handleMethodCall('requestNotificationPermission', null),
      isTrue,
    );
  });

  test('showMissCallNotification emits a callback event when clicked',
      () async {
    final bool shown = await engine.handleMethodCall(
        'showMissCallNotification', params().toJson()) as bool;

    expect(shown, isTrue);
    expect(engine.activeCallParams, isEmpty);
    expect(delegate.missedCalls.single.callId, 'call-1');

    delegate.emitAction('call-1', CallkitNotificationActionType.click);
    await flush();

    expect(events.single['event'], CallEventConstants.actionCallCallback);
  });

  test('unknown methods resolve to null', () async {
    expect(await engine.handleMethodCall('setAudioRoute', null), isNull);
    expect(
        await engine.handleMethodCall('endNativeSubsystemOnly', null), isNull);
  });

  test('dispose releases pending timers and notifications', () async {
    await engine.handleMethodCall('showCallkitIncoming', params().toJson());
    await flush();
    engine.dispose();
    await flush();

    expect(delegate.cancelAllCount, 1);
    expect(clock.pending, isEmpty);
  });
}

class ManualClock implements CallkitWebClock {
  final List<({Duration duration, void Function() callback})> pending =
      <({Duration duration, void Function() callback})>[];

  @override
  void Function() schedule(Duration duration, void Function() callback) {
    final ({Duration duration, void Function() callback}) entry =
        (duration: duration, callback: callback);
    pending.add(entry);
    return () => pending.remove(entry);
  }

  void firePending() {
    for (final ({Duration duration, void Function() callback}) entry
        in pending.toList(growable: false)) {
      pending.remove(entry);
      entry.callback();
    }
  }
}
