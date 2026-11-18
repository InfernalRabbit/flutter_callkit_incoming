import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_callkit_incoming/src/web/callkit_web_engine.dart';
import 'package:flutter_callkit_incoming/src/web/callkit_web_notification_bridge.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeNotificationBridge bridge;
  late ManualClock clock;
  late CallkitWebEngine engine;
  late List<Map<String, dynamic>> events;

  setUp(() {
    bridge = FakeNotificationBridge();
    clock = ManualClock();
    engine = CallkitWebEngine(notificationBridge: bridge, clock: clock);
    events = <Map<String, dynamic>>[];
    engine.events.listen(events.add);
  });

  tearDown(() {
    engine.dispose();
  });

  Future<void> flush() => Future<void>.delayed(Duration.zero);

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
    expect(bridge.shown.keys, contains('call-1'));
    expect(bridge.shown['call-1']!.title, 'Alice');
    expect(clock.pending, hasLength(1));
    expect(clock.pending.single.duration, const Duration(milliseconds: 30000));
  });

  test('showCallkitIncoming replaces an existing call and notification',
      () async {
    await engine.handleMethodCall('showCallkitIncoming', params().toJson());
    await engine.handleMethodCall('showCallkitIncoming', params().toJson());
    await flush();

    expect(bridge.closed, contains('call-1'));
    expect(engine.activeCallParams, hasLength(1));
    expect(events, hasLength(2));
  });

  test('clicking the notification accepts the call', () async {
    await engine.handleMethodCall('showCallkitIncoming', params().toJson());
    await flush();

    bridge.click('call-1');
    await flush();

    expect(events.map((Map<String, dynamic> e) => e['event']), <String>[
      CallEventConstants.actionCallIncoming,
      CallEventConstants.actionCallAccept,
    ]);
    expect(
        (events.last['body'] as Map<dynamic, dynamic>)['isAccepted'], isTrue);
    expect(engine.activeCallParams.single.isAccepted, isTrue);
    expect(bridge.shown, isEmpty);
    // The ring timeout must not fire after the call was accepted.
    clock.firePending();
    await flush();
    expect(
      events.map((Map<String, dynamic> e) => e['event']),
      isNot(contains(CallEventConstants.actionCallTimeout)),
    );
  });

  test('dismissing the notification declines the call', () async {
    await engine.handleMethodCall('showCallkitIncoming', params().toJson());
    await flush();

    bridge.dismiss('call-1');
    await flush();

    expect(events.last['event'], CallEventConstants.actionCallDecline);
    expect(engine.activeCallParams, isEmpty);
    expect(bridge.shown, isEmpty);
  });

  test('endCall declines a ringing call', () async {
    await engine.handleMethodCall('showCallkitIncoming', params().toJson());
    await engine.handleMethodCall('endCall', <String, dynamic>{'id': 'call-1'});
    await flush();

    expect(events.map((Map<String, dynamic> e) => e['event']), <String>[
      CallEventConstants.actionCallIncoming,
      CallEventConstants.actionCallDecline,
    ]);
    expect(engine.activeCallParams, isEmpty);
    expect(clock.pending, isEmpty);
  });

  test('endCall ends an accepted call', () async {
    await engine.handleMethodCall('showCallkitIncoming', params().toJson());
    await flush();
    bridge.click('call-1');
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
    bridge.click('accepted');
    await flush();

    await engine.handleMethodCall('endAllCalls', <Object?>[]);
    await flush();

    final List<dynamic> names =
        events.map((Map<String, dynamic> e) => e['event']).toList();
    expect(names, contains(CallEventConstants.actionCallDecline));
    expect(names, contains(CallEventConstants.actionCallEnded));
    expect(engine.activeCallParams, isEmpty);
    expect(bridge.shown, isEmpty);
  });

  test('hideCallkitIncoming clears the call and emits ended', () async {
    await engine.handleMethodCall('showCallkitIncoming', params().toJson());
    await engine.handleMethodCall('hideCallkitIncoming', params().toJson());
    await flush();

    expect(events.last['event'], CallEventConstants.actionCallEnded);
    expect(engine.activeCallParams, isEmpty);
    expect(bridge.shown, isEmpty);
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
    expect(bridge.shown, isEmpty);
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
    expect(bridge.shown, isEmpty);
  });

  test('callConnected marks the call accepted', () async {
    await engine.handleMethodCall('showCallkitIncoming', params().toJson());
    await flush();

    await engine
        .handleMethodCall('callConnected', <String, dynamic>{'id': 'call-1'});
    await flush();

    expect(events.last['event'], CallEventConstants.actionCallConnected);
    expect(engine.activeCallParams.single.isAccepted, isTrue);
    expect(bridge.shown, isEmpty);
  });

  test('activeCalls returns the in-memory calls as JSON', () async {
    await engine.handleMethodCall(
        'showCallkitIncoming', params(id: 'call-1').toJson());
    await engine.handleMethodCall(
        'showCallkitIncoming', params(id: 'call-2').toJson());
    await flush();
    bridge.click('call-2');
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

  test('denied notification permission keeps the call state machine working',
      () async {
    bridge.permissionValue = 'denied';
    final Object? result =
        await engine.handleMethodCall('showCallkitIncoming', params().toJson());
    await flush();

    expect(result, isTrue);
    expect(engine.activeCallParams, hasLength(1));
    expect(events.single['event'], CallEventConstants.actionCallIncoming);
    expect(bridge.shown, isEmpty);
    expect(await engine.handleMethodCall('requestNotificationPermission', null),
        isFalse);
    expect(
      await engine
          .handleMethodCall('endCall', <String, dynamic>{'id': 'call-1'}),
      isTrue,
    );
  });

  test('unsupported notifications fall back to a headless call state machine',
      () async {
    final CallkitWebEngine headless = CallkitWebEngine(
      notificationBridge: const UnsupportedCallkitWebNotificationBridge(),
      clock: clock,
    );
    addTearDown(headless.dispose);

    expect(headless.isNotificationSupported, isFalse);
    expect(
        await headless.handleMethodCall(
            'showCallkitIncoming', params().toJson()),
        isTrue);
    expect(headless.activeCallParams, hasLength(1));
    expect(headless.activeCallParams.single.id, 'call-1');
    expect(headless.notificationPermission, 'unsupported');
  });

  test('showMissCallNotification emits a callback event when clicked',
      () async {
    final bool shown = await engine.handleMethodCall(
        'showMissCallNotification', params().toJson()) as bool;

    expect(shown, isTrue);
    expect(engine.activeCallParams, isEmpty);

    bridge.click('missed_call-1');
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

    expect(bridge.shown, isEmpty);
    expect(clock.pending, isEmpty);
  });
}

class FakeNotificationBridge implements CallkitWebNotificationBridge {
  FakeNotificationBridge(
      {this.isSupported = true, this.isSecureContext = true});

  @override
  final bool isSupported;

  @override
  final bool isSecureContext;

  String permissionValue = 'granted';

  final Map<String, CallkitWebNotification> shown =
      <String, CallkitWebNotification>{};
  final Map<String, void Function()> clicks = <String, void Function()>{};
  final Map<String, void Function()> dismissals = <String, void Function()>{};
  final List<String> closed = <String>[];
  int permissionRequestCount = 0;

  @override
  String get permission => permissionValue;

  @override
  bool get isPermissionGranted => permissionValue == 'granted';

  @override
  Future<String> requestPermission() async {
    permissionRequestCount++;
    return permissionValue;
  }

  @override
  Future<bool> show(
    CallkitWebNotification notification, {
    void Function()? onClick,
    void Function()? onDismiss,
  }) async {
    if (!isSupported || permissionValue != 'granted') {
      return false;
    }
    shown[notification.id] = notification;
    if (onClick != null) {
      clicks[notification.id] = onClick;
    }
    if (onDismiss != null) {
      dismissals[notification.id] = onDismiss;
    }
    return true;
  }

  @override
  Future<void> close(String id) async {
    closed.add(id);
    shown.remove(id);
    clicks.remove(id);
    dismissals.remove(id);
  }

  @override
  Future<void> closeAll() async {
    for (final String id in shown.keys.toList(growable: false)) {
      await close(id);
    }
  }

  void click(String id) => clicks[id]?.call();

  void dismiss(String id) => dismissals[id]?.call();
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
