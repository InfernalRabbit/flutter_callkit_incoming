import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_callkit_incoming/src/web/callkit_web_channel_host.dart';
import 'package:flutter_callkit_incoming/src/web/callkit_web_engine.dart';
import 'package:flutter_callkit_incoming/src/web/callkit_web_notification_bridge.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const StandardMethodCodec codec = StandardMethodCodec();
  late FakePlatformMessenger messenger;
  late FakeNotificationBridge bridge;
  late CallkitWebChannelHost host;

  setUp(() {
    messenger = FakePlatformMessenger();
    bridge = FakeNotificationBridge();
    host = CallkitWebChannelHost(
      messenger: messenger,
      engine: CallkitWebEngine(notificationBridge: bridge),
    );
  });

  tearDown(() {
    host.dispose();
  });

  Future<dynamic> invoke(String method, [dynamic arguments]) async {
    final ByteData? reply = await messenger.deliver(
      CallkitWebChannelHost.methodChannelName,
      codec.encodeMethodCall(MethodCall(method, arguments)),
    );
    if (reply == null) {
      return null;
    }
    return codec.decodeEnvelope(reply);
  }

  Future<void> startListening() async {
    final ByteData? reply = await messenger.deliver(
      CallkitWebChannelHost.eventChannelName,
      codec.encodeMethodCall(const MethodCall('listen')),
    );
    expect(reply, isNotNull);
    expect(codec.decodeEnvelope(reply!), isNull);
  }

  Future<void> cancelListening() async {
    final ByteData? reply = await messenger.deliver(
      CallkitWebChannelHost.eventChannelName,
      codec.encodeMethodCall(const MethodCall('cancel')),
    );
    expect(reply, isNotNull);
  }

  List<Map<String, dynamic>> forwardedEvents() {
    return messenger.sentToFramework
        .where((({String channel, ByteData? data}) message) =>
            message.channel == CallkitWebChannelHost.eventChannelName &&
            message.data != null)
        .map((({String channel, ByteData? data}) message) {
      final Map<Object?, Object?> decoded =
          codec.decodeEnvelope(message.data!) as Map<Object?, Object?>;
      return decoded.map(
        (Object? key, Object? value) =>
            MapEntry<String, dynamic>(key.toString(), value),
      );
    }).toList(growable: false);
  }

  Future<void> flush() => Future<void>.delayed(Duration.zero);

  CallKitParams params({String id = 'call-1'}) {
    return CallKitParams(
      id: id,
      nameCaller: 'Alice',
      handle: 'alice@example.com',
      type: 0,
      duration: 0,
    );
  }

  test('register installs handlers only once', () async {
    host.register();
    host.register();

    expect(host.isRegistered, isTrue);
    expect(messenger.handlerCount, 2);
  });

  test('method channel drives the call state machine', () async {
    host.register();

    expect(await invoke('showCallkitIncoming', params().toJson()), isTrue);
    expect(host.engine.activeCallParams.single.id, 'call-1');

    final List<dynamic> calls = await invoke('activeCalls') as List<dynamic>;
    expect(calls, hasLength(1));
    expect((calls.single as Map<dynamic, dynamic>)['id'], 'call-1');

    expect(await invoke('endCall', <String, dynamic>{'id': 'call-1'}), isTrue);
    expect(host.engine.activeCallParams, isEmpty);
  });

  test('events are encoded as method channel envelopes after listen', () async {
    host.register();
    await startListening();

    await invoke('showCallkitIncoming', params().toJson());
    await flush();

    final List<Map<String, dynamic>> events = forwardedEvents();
    expect(events, hasLength(1));
    expect(events.single['event'], CallEventConstants.actionCallIncoming);

    final Map<String, dynamic> body =
        (events.single['body'] as Map<dynamic, dynamic>)
            .cast<String, dynamic>();
    expect(body['id'], 'call-1');
    expect(CallKitParams.fromJson(body).nameCaller, 'Alice');
  });

  test('events are not forwarded before listen and stop after cancel',
      () async {
    host.register();

    await invoke('showCallkitIncoming', params().toJson());
    await flush();
    expect(forwardedEvents(), isEmpty);

    await startListening();
    await invoke('showCallkitIncoming', params(id: 'call-2').toJson());
    await flush();
    expect(forwardedEvents(), hasLength(1));
    expect(
      (forwardedEvents().single['body'] as Map<dynamic, dynamic>)['id'],
      'call-2',
    );

    await cancelListening();
    await invoke('showCallkitIncoming', params(id: 'call-3').toJson());
    await flush();
    expect(forwardedEvents(), hasLength(1));
  });

  test('endAllCalls finishes every tracked call', () async {
    host.register();
    await startListening();

    await invoke('showCallkitIncoming', params(id: 'call-1').toJson());
    await invoke('showCallkitIncoming', params(id: 'call-2').toJson());
    await invoke('endAllCalls');
    await flush();

    expect(host.engine.activeCallParams, isEmpty);
    expect(
      forwardedEvents().map((Map<String, dynamic> event) => event['event']),
      containsAll(<String>[
        CallEventConstants.actionCallDecline,
        CallEventConstants.actionCallIncoming,
      ]),
    );
  });

  test('mute and hold calls round-trip through the method channel', () async {
    host.register();

    await invoke('showCallkitIncoming', params().toJson());
    await invoke('muteCall', <String, dynamic>{'id': 'call-1', 'isMuted': true});
    expect(
      await invoke('isMuted', <String, dynamic>{'id': 'call-1'}),
      isTrue,
    );
    expect(
      await invoke('holdCall', <String, dynamic>{'id': 'call-1', 'isOnHold': true}),
      isTrue,
    );
  });

  test('silenceEvents round-trips', () async {
    host.register();
    await startListening();

    expect(await invoke('silenceEvents', true), isTrue);
    await invoke('showCallkitIncoming', params().toJson());
    await flush();
    expect(forwardedEvents(), isEmpty);
  });

  test('unknown event channel methods return an error envelope', () async {
    host.register();
    final ByteData? reply = await messenger.deliver(
      CallkitWebChannelHost.eventChannelName,
      codec.encodeMethodCall(const MethodCall('unexpected')),
    );
    expect(reply, isNotNull);
    expect(
      () => codec.decodeEnvelope(reply!),
      throwsA(isA<PlatformException>()),
    );
  });

  test('dispose removes the handlers', () async {
    host.register();
    await startListening();
    host.dispose();

    expect(host.isRegistered, isFalse);
    expect(messenger.handlerCount, 0);
    expect(await invoke('activeCalls'), isNull);
    expect(forwardedEvents(), isEmpty);
  });
}

class FakePlatformMessenger implements BinaryMessenger {
  final Map<String, MessageHandler> handlers = <String, MessageHandler>{};
  final List<({String channel, ByteData? data})> sentToFramework =
      <({String channel, ByteData? data})>[];

  int get handlerCount => handlers.length;

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
