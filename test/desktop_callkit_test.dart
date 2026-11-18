import 'dart:async';

import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_callkit_incoming/src/desktop/callkit_desktop_controller.dart';
import 'package:flutter_callkit_incoming/src/desktop/callkit_desktop_notification.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeNotification implements CallkitDesktopNotification {
  final List<String> shownIds = <String>[];
  final List<CallkitDesktopNotificationKind> shownKinds =
      <CallkitDesktopNotificationKind>[];
  final List<String> hiddenIds = <String>[];
  int hideAllCalls = 0;
  bool disposed = false;

  void Function(String callId)? _onTap;

  @override
  set onTap(void Function(String callId)? handler) => _onTap = handler;

  void tap(String callId) => _onTap?.call(callId);

  @override
  Future<void> show(
    String callId,
    CallKitParams params, {
    required CallkitDesktopNotificationKind kind,
  }) async {
    shownIds.add(callId);
    shownKinds.add(kind);
  }

  @override
  Future<void> hide(String callId) async => hiddenIds.add(callId);

  @override
  Future<void> hideAll() async => hideAllCalls++;

  @override
  Future<void> dispose() async {
    disposed = true;
  }
}

CallKitParams _params(
  String id, {
  String? nameCaller = 'Alice',
  String? handle = '0123456789',
  bool isAccepted = false,
}) {
  return CallKitParams(
    id: id,
    nameCaller: nameCaller,
    appName: 'Callkit',
    handle: handle,
    type: 0,
    isAccepted: isAccepted,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CallkitDesktopController controller;
  late _FakeNotification notifications;
  late List<CallEvent?> events;
  late StreamSubscription<CallEvent?> subscription;

  Future<void> flush() => Future<void>.delayed(Duration.zero);

  Future<void> clearEvents() async {
    // The broadcast stream delivers asynchronously; make sure any pending
    // event from the setup step has arrived before clearing.
    await flush();
    events.clear();
  }

  setUp(() {
    notifications = _FakeNotification();
    controller = CallkitDesktopController(notification: notifications);
    events = <CallEvent?>[];
    subscription = controller.onEvent.listen(events.add);
  });

  tearDown(() async {
    await subscription.cancel();
    await controller.dispose();
  });

  test('desktop registrant entry point is exported from the main library', () {
    // Flutter's generated dart_plugin_registrant.dart imports the package's
    // main library and calls FlutterCallkitIncomingDesktop.registerWith().
    FlutterCallkitIncomingDesktop.registerWith();
    expect(CallkitDesktopController.instance.isRegistered, isTrue);
  });

  test('showCallkitIncoming registers the call, notifies and emits event',
      () async {
    await controller.showCallkitIncoming(_params('call-1'));
    await flush();

    final active = await controller.activeCalls();
    expect(active, hasLength(1));
    expect(active.single.id, 'call-1');
    expect(active.single.nameCaller, 'Alice');
    expect(active.single.isAccepted, isFalse);

    expect(notifications.shownIds, <String>['call-1']);
    expect(
      notifications.shownKinds.single,
      CallkitDesktopNotificationKind.incoming,
    );
    expect(events, hasLength(1));
    expect(events.single, isA<CallEventActionCallIncoming>());
    expect(
      (events.single! as CallEventActionCallIncoming).callKitParams.id,
      'call-1',
    );
  });

  test('endCall removes an unanswered call and emits ACTION_CALL_DECLINE',
      () async {
    await controller.showCallkitIncoming(_params('call-1'));
    await clearEvents();

    await controller.endCall('call-1');
    await flush();

    expect(await controller.activeCalls(), isEmpty);
    expect(notifications.hiddenIds, contains('call-1'));
    expect(events.single, isA<CallEventActionCallDecline>());
  });

  test('setCallConnected marks the call accepted and endCall emits ENDED',
      () async {
    await controller.showCallkitIncoming(_params('call-1'));
    await clearEvents();

    await controller.setCallConnected('call-1');
    await flush();

    expect(events.single, isA<CallEventActionCallConnected>());
    final active = await controller.activeCalls();
    expect(active.single.isAccepted, isTrue);
    expect(notifications.hiddenIds, contains('call-1'));

    await clearEvents();
    await controller.endCall('call-1');
    await flush();

    expect(events.single, isA<CallEventActionCallEnded>());
    final ended = events.single! as CallEventActionCallEnded;
    expect(ended.callKitParams.id, 'call-1');
    expect(ended.callKitParams.isAccepted, isTrue);
  });

  test('endAllCalls clears the registry and emits one event per call',
      () async {
    await controller.showCallkitIncoming(_params('call-1'));
    await controller.showCallkitIncoming(_params('call-2'));
    await clearEvents();

    await controller.endAllCalls();
    await flush();

    expect(await controller.activeCalls(), isEmpty);
    expect(notifications.hideAllCalls, 1);
    expect(events, hasLength(2));
    expect(events.every((e) => e is CallEventActionCallDecline), isTrue);
  });

  test('notification tap re-emits ACTION_CALL_INCOMING while ringing',
      () async {
    await controller.showCallkitIncoming(_params('call-1'));
    await flush();
    await clearEvents();

    notifications.tap('call-1');
    await flush();

    expect(events.single, isA<CallEventActionCallIncoming>());

    await controller.endCall('call-1');
    await flush();
    await clearEvents();
    notifications.tap('call-1');
    await flush();
    expect(events, isEmpty);
  });

  test('silenceEvents suppresses events until unsilenced', () async {
    await controller.setSilenceEvents(true);
    await controller.showCallkitIncoming(_params('call-1'));
    await flush();

    expect(await controller.activeCalls(), hasLength(1));
    expect(notifications.shownIds, <String>['call-1']);
    expect(events, isEmpty);

    await controller.setSilenceEvents(false);
    await controller.endCall('call-1');
    await flush();
    expect(events.single, isA<CallEventActionCallDecline>());
  });

  test('muteCall and holdCall keep state and emit toggle events', () async {
    await controller.showCallkitIncoming(_params('call-1'));
    await clearEvents();

    await controller.muteCall('call-1');
    await flush();
    expect(await controller.isMuted('call-1'), isTrue);
    expect(events.last, isA<CallEventActionCallToggleMute>());

    await controller.holdCall('call-1');
    await flush();
    expect(events.last, isA<CallEventActionCallToggleHold>());

    await controller.muteCall('call-1', isMuted: false);
    await flush();
    expect(await controller.isMuted('call-1'), isFalse);
  });

  test('startCall registers an outgoing call and emits ACTION_CALL_START',
      () async {
    await controller.startCall(_params('outgoing-1'));
    await flush();

    expect(await controller.activeCalls(), hasLength(1));
    expect(events.single, isA<CallEventActionCallStart>());
    expect(notifications.shownIds, isEmpty);

    await clearEvents();
    await controller.endCall('outgoing-1');
    await flush();
    expect(events.single, isA<CallEventActionCallEnded>());
  });

  test('showMissCallNotification dismisses the ringing call and notifies',
      () async {
    await controller.showCallkitIncoming(_params('call-1'));
    await clearEvents();

    await controller.showMissCallNotification(_params('call-1'));
    await flush();

    expect(await controller.activeCalls(), isEmpty);
    expect(notifications.shownIds, <String>['call-1', 'call-1']);
    expect(
      notifications.shownKinds.last,
      CallkitDesktopNotificationKind.missedCall,
    );
    expect(events, isEmpty);
  });

  test('unknown call ids are ignored by endCall but still hide notification',
      () async {
    await controller.endCall('missing');
    await flush();

    expect(events, isEmpty);
    expect(notifications.hiddenIds, contains('missing'));
  });

  test('mobile-only APIs return safe desktop defaults', () async {
    expect(await controller.getDevicePushTokenVoIP(), isNull);
    expect(await controller.requestNotificationPermission(<String, dynamic>{}),
        isTrue);
    expect(await controller.requestFullIntentPermission(), isFalse);
    expect(await controller.canUseFullScreenIntent(), isFalse);
  });
}
