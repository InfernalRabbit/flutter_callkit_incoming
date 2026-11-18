import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_callkit_incoming_example/notifications/flutter_local_notifications_callkit_delegate.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel(
    'dexterous.com/flutter/local_notifications',
  );

  late List<MethodCall> calls;
  late List<Map<Object?, Object?>> activeNotifications;

  FlutterLocalNotificationsCallkitDelegate createDelegate() {
    return FlutterLocalNotificationsCallkitDelegate(
      appName: 'Callkit',
      windowsAppUserModelId: 'com.example.test',
      windowsGuid: 'a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d',
      cancelOnAction: false,
      handleNotificationLaunchDetails: false,
    );
  }

  setUp(() {
    calls = <MethodCall>[];
    activeNotifications = <Map<Object?, Object?>>[];
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    FlutterLocalNotificationsPlatform.instance =
        MacOSFlutterLocalNotificationsPlugin();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      calls.add(call);
      return switch (call.method) {
        'initialize' => true,
        'getNotificationAppLaunchDetails' => null,
        'getActiveNotifications' => activeNotifications,
        _ => null,
      };
    });
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('initialize wires the response handler and show carries the payload',
      () async {
    final FlutterLocalNotificationsCallkitDelegate delegate = createDelegate();
    addTearDown(delegate.dispose);

    expect(await delegate.initialize(), isTrue);
    expect(delegate.isInitialized, isTrue);
    expect(
      calls.map((MethodCall call) => call.method),
      contains('initialize'),
    );

    await delegate.showIncoming(
      const CallkitNotificationCall(
        callId: 'call-1',
        callerName: 'Alice',
        handle: 'alice@example.com',
      ),
    );

    final MethodCall show = calls.lastWhere(
      (MethodCall call) => call.method == 'show',
    );
    final Map<Object?, Object?> arguments =
        show.arguments as Map<Object?, Object?>;
    expect(arguments['id'], isA<int>());
    expect(arguments['title'], 'Alice');
    expect(arguments['body'], contains('alice@example.com'));

    final String payload = arguments['payload']! as String;
    final CallkitNotificationPayload? parsed =
        CallkitNotificationPayload.tryParse(payload);
    expect(parsed, isNotNull);
    expect(parsed!.callId, 'call-1');
    expect(parsed.action, CallkitNotificationActionType.click);

    final Map<Object?, Object?> details =
        arguments['platformSpecifics']! as Map<Object?, Object?>;
    expect(details['categoryIdentifier'], 'callkit_incoming_call_v1');
    expect(details['threadIdentifier'], 'callkit:call-1');
  });

  test('native response callback emits on the actions stream', () async {
    final FlutterLocalNotificationsCallkitDelegate delegate = createDelegate();
    addTearDown(delegate.dispose);
    await delegate.initialize();

    final Future<CallkitNotificationAction> nextAction = delegate.actions.first;
    final String payload = CallkitNotificationPayload(
      callId: 'call-callback',
      action: CallkitNotificationActionType.click,
    ).encode();

    final ByteData message = const StandardMethodCodec().encodeMethodCall(
      MethodCall('didReceiveNotificationResponse', <String, Object?>{
        'notificationId': 123,
        'actionId': 'accept',
        'input': null,
        'payload': payload,
        'notificationResponseType':
            NotificationResponseType.selectedNotificationAction.index,
      }),
    );

    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(channel.name, message, (ByteData? data) {});

    final CallkitNotificationAction action = await nextAction;
    expect(action.callId, 'call-callback');
    expect(action.type, CallkitNotificationActionType.accept);
  });

  test('cancelAll removes tracked and payload-tagged notifications only',
      () async {
    final FlutterLocalNotificationsCallkitDelegate delegate = createDelegate();
    addTearDown(delegate.dispose);
    await delegate.initialize();

    await delegate.showIncoming(
      const CallkitNotificationCall(callId: 'call-tracked', callerName: 'A'),
    );
    final MethodCall show = calls.lastWhere(
      (MethodCall call) => call.method == 'show',
    );
    final int trackedId =
        (show.arguments as Map<Object?, Object?>)['id']! as int;

    const int unrelatedId = 7001;
    const int taggedId = 7002;
    activeNotifications = <Map<Object?, Object?>>[
      <String, Object?>{'id': unrelatedId, 'payload': 'other app payload'},
      <String, Object?>{
        'id': taggedId,
        'payload': CallkitNotificationPayload(
          callId: 'call-tagged',
          action: CallkitNotificationActionType.click,
        ).encode(),
      },
    ];
    calls.clear();

    await delegate.cancelAll();

    final Set<int> cancelled = calls
        .where((MethodCall call) => call.method == 'cancel')
        .map((MethodCall call) => call.arguments! as int)
        .toSet();
    expect(cancelled, contains(trackedId));
    expect(cancelled, contains(taggedId));
    expect(cancelled, isNot(contains(unrelatedId)));
  });

  test('cancel removes the call notification id', () async {
    final FlutterLocalNotificationsCallkitDelegate delegate = createDelegate();
    addTearDown(delegate.dispose);
    await delegate.initialize();

    await delegate.showIncoming(
      const CallkitNotificationCall(callId: 'call-cancel', callerName: 'A'),
    );
    final MethodCall show = calls.lastWhere(
      (MethodCall call) => call.method == 'show',
    );
    final int id = (show.arguments as Map<Object?, Object?>)['id']! as int;
    calls.clear();

    await delegate.cancel('call-cancel');

    final MethodCall cancel = calls.lastWhere(
      (MethodCall call) => call.method == 'cancel',
    );
    expect(cancel.arguments, id);
  });
}
