@TestOn('browser')
library;

import 'dart:async';

import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming_web.dart';
import 'package:flutter_callkit_incoming/src/web/browser_callkit_web_notification_bridge.dart';
import 'package:flutter_callkit_incoming/src/web/callkit_web_channel_host.dart';
import 'package:flutter_callkit_incoming/src/web/callkit_web_engine.dart';
import 'package:flutter_callkit_incoming/src/web/callkit_web_notification_bridge.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';

/// End-to-end tests of the web implementation running inside a real browser.
///
/// Run with:
///
///     flutter test --platform chrome test/flutter_callkit_incoming_web_test.dart
///     flutter test --platform chrome --wasm test/flutter_callkit_incoming_web_test.dart
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeNotificationBridge bridge;
  late Registrar registrar;
  late CallkitWebChannelHost host;
  late List<CallEvent?> events;
  StreamSubscription<CallEvent?>? subscription;

  setUp(() {
    bridge = FakeNotificationBridge();
    registrar = Registrar();
    host = CallkitWebChannelHost(
      messenger: registrar,
      engine: CallkitWebEngine(notificationBridge: bridge),
    );
    host.register();
    // The generated web_plugin_registrant.dart performs this call after all
    // plugins have been registered. Without it the engine cannot route
    // framework-to-plugin messages to the registrar.
    registrar.registerMessageHandler();
    events = <CallEvent?>[];
    subscription = FlutterCallkitIncoming.onEvent.listen(events.add);
  });

  tearDown(() async {
    await subscription?.cancel();
    subscription = null;
    host.dispose();
  });

  Future<void> settle() async {
    await pumpEventQueue();
    await Future<void>.delayed(Duration.zero);
    await pumpEventQueue();
  }

  CallKitParams params({String id = 'web-1', int duration = 0}) {
    return CallKitParams(
      id: id,
      nameCaller: 'Alice',
      handle: 'alice@example.com',
      type: 0,
      duration: duration,
    );
  }

  test('the public API drives the web implementation end to end', () async {
    await settle();

    await FlutterCallkitIncoming.showCallkitIncoming(params());
    await settle();

    expect(events.whereType<CallEventActionCallIncoming>(), hasLength(1));
    expect(bridge.shown.keys, contains('web-1'));

    final List<CallKitParams> calls = await FlutterCallkitIncoming.activeCalls();
    expect(calls.single.id, 'web-1');
    expect(calls.single.nameCaller, 'Alice');

    await FlutterCallkitIncoming.endCall('web-1');
    await settle();

    expect(events.whereType<CallEventActionCallDecline>(), hasLength(1));
    expect(events.whereType<CallEventActionCallEnded>(), isEmpty);
    expect(await FlutterCallkitIncoming.activeCalls(), isEmpty);
  });

  test('notification click accepts the call', () async {
    await settle();
    await FlutterCallkitIncoming.showCallkitIncoming(params(id: 'web-2'));
    await settle();

    bridge.click('web-2');
    await settle();

    expect(events.whereType<CallEventActionCallAccept>(), hasLength(1));
    expect(
      (await FlutterCallkitIncoming.activeCalls()).single.isAccepted,
      isTrue,
    );

    await FlutterCallkitIncoming.endCall('web-2');
    await settle();
    expect(events.whereType<CallEventActionCallEnded>(), hasLength(1));
  });

  test('mute, hold and connected round-trip through the channel', () async {
    await settle();
    await FlutterCallkitIncoming.showCallkitIncoming(params(id: 'web-3'));
    await settle();

    await FlutterCallkitIncoming.muteCall('web-3', isMuted: true);
    expect(await FlutterCallkitIncoming.isMuted('web-3'), isTrue);
    await FlutterCallkitIncoming.holdCall('web-3', isOnHold: true);
    await FlutterCallkitIncoming.setCallConnected('web-3');
    await settle();

    expect(events.whereType<CallEventActionCallToggleMute>(), hasLength(1));
    expect(events.whereType<CallEventActionCallToggleHold>(), hasLength(1));
    expect(events.whereType<CallEventActionCallConnected>(), hasLength(1));
    expect(
      (await FlutterCallkitIncoming.activeCalls()).single.isAccepted,
      isTrue,
    );

    await FlutterCallkitIncoming.endAllCalls();
    await settle();
    expect(events.whereType<CallEventActionCallEnded>(), hasLength(1));
    expect(await FlutterCallkitIncoming.activeCalls(), isEmpty);
  });

  test('hideCallkitIncoming clears the notification and ends the call',
      () async {
    await settle();
    await FlutterCallkitIncoming.showCallkitIncoming(params(id: 'web-4'));
    await settle();

    await FlutterCallkitIncoming.hideCallkitIncoming(params(id: 'web-4'));
    await settle();

    expect(events.whereType<CallEventActionCallEnded>(), hasLength(1));
    expect(bridge.shown, isEmpty);
    expect(await FlutterCallkitIncoming.activeCalls(), isEmpty);
  });

  test('silenceEvents suppresses the event stream', () async {
    await settle();
    await FlutterCallkitIncoming.silenceEvents();

    await FlutterCallkitIncoming.showCallkitIncoming(params(id: 'web-5'));
    await settle();
    expect(events, isEmpty);

    await FlutterCallkitIncoming.unsilenceEvents();
    await FlutterCallkitIncoming.endCall('web-5');
    await settle();
    expect(events.whereType<CallEventActionCallDecline>(), hasLength(1));
  });

  test('FlutterCallkitIncomingWeb.registerWith installs the web plugin',
      () async {
    FlutterCallkitIncomingWeb.registerWith(Registrar());

    expect(FlutterCallkitIncomingWeb.isRegistered, isTrue);
    expect(FlutterCallkitIncomingWeb.isNotificationSupported, isTrue);
    expect(
      <String>['granted', 'denied', 'default', 'unsupported'],
      contains(FlutterCallkitIncomingWeb.notificationPermission),
    );
  });

  test('the browser bridge reports permission and never throws', () async {
    final BrowserCallkitWebNotificationBridge bridge =
        BrowserCallkitWebNotificationBridge();

    expect(
      <String>['granted', 'denied', 'default'],
      contains(bridge.permission),
    );
    expect(bridge.isSecureContext, isTrue);

    final bool shown = await bridge.show(
      const CallkitWebNotification(
        id: 'probe',
        title: 'Probe',
        tag: 'callkit_probe',
        silent: true,
        requireInteraction: false,
      ),
    );
    expect(shown, bridge.isPermissionGranted);
    await bridge.closeAll();
  });
}

class FakeNotificationBridge implements CallkitWebNotificationBridge {
  final Map<String, CallkitWebNotification> shown =
      <String, CallkitWebNotification>{};
  final Map<String, void Function()> clicks = <String, void Function()>{};

  @override
  bool get isSupported => true;

  @override
  bool get isSecureContext => true;

  @override
  String get permission => 'granted';

  @override
  bool get isPermissionGranted => true;

  @override
  Future<String> requestPermission() async => 'granted';

  @override
  Future<bool> show(
    CallkitWebNotification notification, {
    void Function()? onClick,
    void Function()? onDismiss,
  }) async {
    shown[notification.id] = notification;
    if (onClick != null) {
      clicks[notification.id] = onClick;
    }
    return true;
  }

  @override
  Future<void> close(String id) async {
    shown.remove(id);
    clicks.remove(id);
  }

  @override
  Future<void> closeAll() async {
    shown.clear();
    clicks.clear();
  }

  void click(String id) => clicks[id]?.call();
}
