@TestOn('browser')
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming_web.dart';
import 'package:flutter_callkit_incoming/src/web/browser_callkit_web_notification_bridge.dart';
import 'package:flutter_callkit_incoming/src/web/callkit_web_channel_host.dart';
import 'package:flutter_callkit_incoming/src/web/callkit_web_engine.dart';
import 'package:flutter_callkit_incoming/src/web/callkit_web_notification_bridge.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';

/// Browser smoke tests for the web implementation.
///
/// The Flutter web test harness does not expose the browser Notification API
/// (the runtime reports it as unavailable), and it does not route framework
/// platform messages to a plugin registrar. These tests therefore validate the
/// web-only code paths that can run in that environment:
///
/// * the browser notification bridge falls back gracefully;
/// * the channel host speaks the standard method/event channel protocol;
/// * FlutterCallkitIncoming.onEvent decodes platform events.
///
/// Run with:
///
///     flutter test --platform chrome test/flutter_callkit_incoming_web_test.dart
///     flutter test --platform chrome --wasm test/flutter_callkit_incoming_web_test.dart
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const StandardMethodCodec codec = StandardMethodCodec();

  test('browser notification bridge degrades gracefully', () async {
    final BrowserCallkitWebNotificationBridge bridge =
        BrowserCallkitWebNotificationBridge();

    debugPrint('web notification support: ${bridge.isSupported}');
    debugPrint('web notification permission: ${bridge.permission}');

    if (!bridge.isSupported) {
      expect(bridge.permission, 'unsupported');
      expect(await bridge.requestPermission(), 'unsupported');
      expect(
        await bridge.show(
          const CallkitWebNotification(id: 'probe', title: 'Probe'),
        ),
        isFalse,
      );
    } else {
      expect(
        <String>['granted', 'denied', 'default'],
        contains(bridge.permission),
      );
      if (!bridge.isPermissionGranted) {
        expect(
          await bridge.show(
            const CallkitWebNotification(id: 'probe', title: 'Probe'),
          ),
          isFalse,
        );
      }
    }
    await bridge.closeAll();
  });

  test('FlutterCallkitIncomingWeb.registerWith installs the web plugin',
      () async {
    FlutterCallkitIncomingWeb.registerWith(Registrar());

    expect(FlutterCallkitIncomingWeb.isRegistered, isTrue);
    expect(
      <String>['granted', 'denied', 'default', 'unsupported'],
      contains(FlutterCallkitIncomingWeb.notificationPermission),
    );
  });

  test('channel host round-trips method calls and events', () async {
    final FakePlatformMessenger messenger = FakePlatformMessenger();
    final FakeNotificationBridge bridge = FakeNotificationBridge();
    final CallkitWebChannelHost host = CallkitWebChannelHost(
      messenger: messenger,
      engine: CallkitWebEngine(notificationBridge: bridge),
    );
    host.register();
    addTearDown(host.dispose);

    expect(
      await messenger.deliver(
        CallkitWebChannelHost.eventChannelName,
        codec.encodeMethodCall(const MethodCall('listen')),
      ),
      isNotNull,
    );

    final ByteData? result = await messenger.deliver(
      CallkitWebChannelHost.methodChannelName,
      codec.encodeMethodCall(MethodCall(
        'showCallkitIncoming',
        const CallKitParams(
          id: 'chrome-1',
          nameCaller: 'Alice',
          handle: 'alice@example.com',
          type: 0,
          duration: 0,
        ).toJson(),
      )),
    );

    expect(codec.decodeEnvelope(result!), isTrue);
    expect(host.engine.activeCallParams.single.id, 'chrome-1');
    expect(bridge.shown.keys, contains('chrome-1'));

    await Future<void>.delayed(Duration.zero);

    final List<Map<String, dynamic>> events = <Map<String, dynamic>>[];
    for (final ({String channel, ByteData? data}) message
        in messenger.sentToFramework) {
      if (message.channel == CallkitWebChannelHost.eventChannelName &&
          message.data != null) {
        final Map<Object?, Object?> decoded =
            codec.decodeEnvelope(message.data!) as Map<Object?, Object?>;
        events.add(decoded.map(
          (Object? key, Object? value) =>
              MapEntry<String, dynamic>(key.toString(), value),
        ));
      }
    }
    expect(events, hasLength(1));
    expect(events.single['event'], CallEventConstants.actionCallIncoming);
    expect(
      (events.single['body'] as Map<dynamic, dynamic>)['id'],
      'chrome-1',
    );
  });

  test('onEvent decodes platform event envelopes', () async {
    final List<CallEvent?> events = <CallEvent?>[];
    final StreamSubscription<CallEvent?> subscription =
        FlutterCallkitIncoming.onEvent.listen(events.add);
    addTearDown(subscription.cancel);

    await Future<void>.delayed(Duration.zero);

    final ByteData envelope = codec.encodeSuccessEnvelope(<String, dynamic>{
      'event': CallEventConstants.actionCallIncoming,
      'body': <String, dynamic>{
        'id': 'pushed-1',
        'nameCaller': 'Pushed',
        'handle': 'pushed@example.com',
        'type': 0,
        'isAccepted': false,
      },
    });
    ServicesBinding.instance.channelBuffers.push(
      'flutter_callkit_incoming_events',
      envelope,
      (ByteData? response) {},
    );
    await Future<void>.delayed(Duration.zero);

    expect(events, hasLength(1));
    expect(events.single, isA<CallEventActionCallIncoming>());
    expect(
      (events.single! as CallEventActionCallIncoming).callKitParams.id,
      'pushed-1',
    );
  });
}

class FakePlatformMessenger implements BinaryMessenger {
  final Map<String, MessageHandler> handlers = <String, MessageHandler>{};
  final List<({String channel, ByteData? data})> sentToFramework =
      <({String channel, ByteData? data})>[];

  @override
  Future<ByteData?>? send(String channel, ByteData? message) {
    sentToFramework.add((channel: channel, data: message));
    return Future<ByteData?>.value(null);
  }

  @override
  void setMessageHandler(String channel, MessageHandler? handler) {
    if (handler == null) {
      handlers.remove(channel);
    } else {
      handlers[channel] = handler;
    }
  }

  Future<ByteData?> deliver(String channel, ByteData? message) async {
    final MessageHandler? handler = handlers[channel];
    if (handler == null) {
      return null;
    }
    final Future<ByteData?>? response = handler(message);
    if (response == null) {
      return null;
    }
    return response;
  }

  @override
  Future<void> handlePlatformMessage(
    String channel,
    ByteData? data,
    PlatformMessageResponseCallback? callback,
  ) async {
    final ByteData? response = await deliver(channel, data);
    callback?.call(response);
  }
}

class FakeNotificationBridge implements CallkitWebNotificationBridge {
  final Map<String, CallkitWebNotification> shown =
      <String, CallkitWebNotification>{};

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
    return true;
  }

  @override
  Future<void> close(String id) async {
    shown.remove(id);
  }

  @override
  Future<void> closeAll() async {
    shown.clear();
  }
}
