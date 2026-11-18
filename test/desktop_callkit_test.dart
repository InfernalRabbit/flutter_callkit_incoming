import 'dart:async';

import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_callkit_incoming/src/desktop/callkit_desktop_controller.dart';
import 'package:flutter_callkit_incoming/src/notifications/callkit_notification_dispatcher.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_notification_delegate.dart';

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
  late FakeCallkitNotificationDelegate notifications;
  late CallkitNotificationDispatcher dispatcher;
  late List<CallEvent?> events;
  late StreamSubscription<CallEvent?> subscription;

  Future<void> flush() => pumpEventQueue();

  Future<void> clearEvents() async {
    // The broadcast stream delivers asynchronously; make sure any pending
    // event from the setup step has arrived before clearing.
    await flush();
    events.clear();
  }

  setUp(() {
    notifications = FakeCallkitNotificationDelegate();
    dispatcher = CallkitNotificationDispatcher(delegate: notifications);
    controller = CallkitDesktopController(notifications: dispatcher);
    events = <CallEvent?>[];
    subscription = controller.onEvent.listen(events.add);
  });

  tearDown(() async {
    await subscription.cancel();
    await controller.dispose();
    await dispatcher.dispose();
    await notifications.dispose();
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

    final CallkitNotificationCall shown = notifications.incomingCalls.single;
    expect(shown.callId, 'call-1');
    expect(shown.callerName, 'Alice');
    expect(shown.handle, '0123456789');
    expect(shown.appName, 'Callkit');
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
    expect(notifications.cancelledCallIds, contains('call-1'));
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
    expect(notifications.cancelledCallIds, contains('call-1'));

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
    expect(notifications.cancelAllCount, 1);
    expect(events, hasLength(2));
    expect(events.every((e) => e is CallEventActionCallDecline), isTrue);
  });

  test('accepted notification action emits ACTION_CALL_ACCEPT', () async {
    await controller.showCallkitIncoming(_params('call-1'));
    await clearEvents();

    notifications.emitAction(
      'call-1',
      CallkitNotificationActionType.accept,
    );
    await flush();

    expect(events.single, isA<CallEventActionCallAccept>());
    expect(
        (events.single! as CallEventActionCallAccept).callKitParams.isAccepted,
        isTrue);
    expect((await controller.activeCalls()).single.isAccepted, isTrue);
    expect(notifications.cancelledCallIds, contains('call-1'));
  });

  test('declined notification action emits ACTION_CALL_DECLINE', () async {
    await controller.showCallkitIncoming(_params('call-1'));
    await clearEvents();

    notifications.emitAction(
      'call-1',
      CallkitNotificationActionType.decline,
    );
    await flush();

    expect(events.single, isA<CallEventActionCallDecline>());
    expect(await controller.activeCalls(), isEmpty);
    expect(notifications.cancelledCallIds, contains('call-1'));
  });

  test('ended notification action emits ACTION_CALL_ENDED', () async {
    await controller.showCallkitIncoming(_params('call-1'));
    await controller.setCallConnected('call-1');
    await clearEvents();

    notifications.emitAction('call-1', CallkitNotificationActionType.end);
    await flush();

    expect(events.single, isA<CallEventActionCallEnded>());
    expect(await controller.activeCalls(), isEmpty);
  });

  test('notification tap re-emits ACTION_CALL_INCOMING while ringing',
      () async {
    await controller.showCallkitIncoming(_params('call-1'));
    await flush();
    await clearEvents();

    notifications.emitAction('call-1', CallkitNotificationActionType.click);
    await flush();

    expect(events.single, isA<CallEventActionCallIncoming>());

    await controller.endCall('call-1');
    await flush();
    await clearEvents();
    notifications.emitAction('call-1', CallkitNotificationActionType.click);
    await flush();
    expect(events, isEmpty);
  });

  test('silenceEvents suppresses events until unsilenced', () async {
    await controller.setSilenceEvents(true);
    await controller.showCallkitIncoming(_params('call-1'));
    await flush();

    expect(await controller.activeCalls(), hasLength(1));
    expect(notifications.incomingCalls.single.callId, 'call-1');
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
    expect(notifications.incomingCalls, isEmpty);

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
    expect(notifications.incomingCalls.single.callId, 'call-1');
    expect(notifications.missedCalls.single.callId, 'call-1');
    expect(notifications.cancelledCallIds, contains('call-1'));
    expect(events, isEmpty);
  });

  test('unknown call ids are ignored by endCall but still hide notification',
      () async {
    await controller.endCall('missing');
    await flush();

    expect(events, isEmpty);
    expect(notifications.cancelledCallIds, contains('missing'));
  });

  test('a controller without a delegate keeps the call state machine working',
      () async {
    final CallkitNotificationDispatcher headless =
        CallkitNotificationDispatcher();
    addTearDown(headless.dispose);
    final CallkitDesktopController withoutNotifications =
        CallkitDesktopController(notifications: headless);
    addTearDown(withoutNotifications.dispose);

    final List<CallEvent?> headlessEvents = <CallEvent?>[];
    final StreamSubscription<CallEvent?> headlessSubscription =
        withoutNotifications.onEvent.listen(headlessEvents.add);
    addTearDown(headlessSubscription.cancel);

    await withoutNotifications.showCallkitIncoming(_params('headless-1'));
    await flush();

    expect(
      (await withoutNotifications.activeCalls()).single.id,
      'headless-1',
    );
    expect(headlessEvents.single, isA<CallEventActionCallIncoming>());
  });

  test('a throwing delegate does not break call state or events', () async {
    notifications.throwOnEveryCall = true;

    await controller.showCallkitIncoming(_params('call-1'));
    await flush();

    expect(await controller.activeCalls(), hasLength(1));
    expect(events.single, isA<CallEventActionCallIncoming>());

    await controller.endCall('call-1');
    await flush();
    expect(events.last, isA<CallEventActionCallDecline>());
  });

  test('mobile-only APIs return safe desktop defaults', () async {
    expect(await controller.getDevicePushTokenVoIP(), isNull);
    expect(await controller.requestNotificationPermission(<String, dynamic>{}),
        isTrue);
    expect(await controller.requestFullIntentPermission(), isFalse);
    expect(await controller.canUseFullScreenIntent(), isFalse);
  });
}
