import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel('flutter_callkit_incoming');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  final bool isDesktop =
      Platform.isMacOS || Platform.isWindows || Platform.isLinux;

  setUp(() {
    messenger.setMockMethodCallHandler(channel, (methodCall) async => '42');
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('desktop platforms route the public API to the Dart implementation',
      () async {
    if (!isDesktop) {
      return;
    }

    expect(await FlutterCallkitIncoming.getDevicePushTokenVoIP(), isNull);
    expect(await FlutterCallkitIncoming.requestFullIntentPermission(), isFalse);
    expect(await FlutterCallkitIncoming.canUseFullScreenIntent(), isFalse);
    expect(await FlutterCallkitIncoming.requestNotificationPermission(null),
        isTrue);
    expect(await FlutterCallkitIncoming.silenceEvents(), isTrue);
    expect(await FlutterCallkitIncoming.unsilenceEvents(), isTrue);
  });

  test('desktop call registry round-trips through the public API', () async {
    if (!isDesktop) {
      return;
    }

    const params = CallKitParams(
      id: 'public-api-desktop-call',
      nameCaller: 'Alice',
      appName: 'Callkit',
      handle: '0123456789',
      type: 0,
    );

    final incomingEvent = FlutterCallkitIncoming.onEvent.first;
    await FlutterCallkitIncoming.showCallkitIncoming(params);

    final event = await incomingEvent.timeout(const Duration(seconds: 5));
    expect(event, isA<CallEventActionCallIncoming>());
    expect(
      (event! as CallEventActionCallIncoming).callKitParams.id,
      params.id,
    );

    final active = await FlutterCallkitIncoming.activeCalls();
    expect(active.map((call) => call.id), contains(params.id));

    await FlutterCallkitIncoming.endCall(params.id);
    expect(await FlutterCallkitIncoming.activeCalls(), isEmpty);
  });
}
