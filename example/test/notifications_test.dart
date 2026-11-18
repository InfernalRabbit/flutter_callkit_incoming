import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_callkit_incoming_example/notifications/flutter_local_notifications_callkit_delegate.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

FlutterLocalNotificationsCallkitDelegate _delegate({
  bool cancelOnAction = false,
}) {
  return FlutterLocalNotificationsCallkitDelegate(
    appName: 'Callkit',
    windowsAppUserModelId: 'com.example.test',
    windowsGuid: 'a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d',
    cancelOnAction: cancelOnAction,
    handleNotificationLaunchDetails: false,
  );
}

String _payload(
  String callId,
  CallkitNotificationActionType action,
) {
  return CallkitNotificationPayload(callId: callId, action: action).encode();
}

void main() {
  group('CallkitNotificationPayload', () {
    test('round-trips call id and action', () {
      for (final CallkitNotificationActionType action
          in CallkitNotificationActionType.values) {
        final CallkitNotificationPayload payload = CallkitNotificationPayload(
          callId: 'call-123',
          action: action,
        );
        final CallkitNotificationPayload? parsed =
            CallkitNotificationPayload.tryParse(payload.encode());

        expect(parsed, isNotNull);
        expect(parsed!.callId, 'call-123');
        expect(parsed.action, action);
      }
    });

    test('rejects malformed, foreign and incomplete payloads', () {
      expect(CallkitNotificationPayload.tryParse(null), isNull);
      expect(CallkitNotificationPayload.tryParse(''), isNull);
      expect(CallkitNotificationPayload.tryParse('not json'), isNull);
      expect(CallkitNotificationPayload.tryParse('[]'), isNull);
      expect(CallkitNotificationPayload.tryParse('{}'), isNull);
      expect(
        CallkitNotificationPayload.tryParse(
          '{"kind":"other","callId":"x","action":"accept"}',
        ),
        isNull,
      );
      expect(
        CallkitNotificationPayload.tryParse(
          '{"kind":"callkit","callId":"","action":"accept"}',
        ),
        isNull,
      );
      expect(
        CallkitNotificationPayload.tryParse(
          '{"kind":"callkit","callId":"x","action":"unknown"}',
        ),
        isNull,
      );
    });
  });

  group('response mapping', () {
    late FlutterLocalNotificationsCallkitDelegate delegate;

    setUp(() {
      delegate = _delegate();
    });

    tearDown(() {
      delegate.dispose();
    });

    test('notification tap maps to click', () {
      final CallkitNotificationAction? action =
          delegate.mapNotificationResponse(
        NotificationResponse(
          notificationResponseType:
              NotificationResponseType.selectedNotification,
          id: 1,
          payload: _payload(
            'call-1',
            CallkitNotificationActionType.click,
          ),
        ),
      );

      expect(action, isNotNull);
      expect(action!.callId, 'call-1');
      expect(action.type, CallkitNotificationActionType.click);
    });

    test('Darwin/Linux/Android action id maps to accept/decline/end', () {
      for (final (String actionId, CallkitNotificationActionType expected)
          in <(String, CallkitNotificationActionType)>[
        ('accept', CallkitNotificationActionType.accept),
        ('decline', CallkitNotificationActionType.decline),
        ('end', CallkitNotificationActionType.end),
      ]) {
        final CallkitNotificationAction? action =
            delegate.mapNotificationResponse(
          NotificationResponse(
            notificationResponseType:
                NotificationResponseType.selectedNotificationAction,
            id: 1,
            actionId: actionId,
            payload: _payload(
              'call-1',
              CallkitNotificationActionType.click,
            ),
          ),
        );

        expect(action, isNotNull, reason: actionId);
        expect(action!.type, expected, reason: actionId);
      }
    });

    test('Windows body click reported as an action maps to click', () {
      final String payload = _payload(
        'call-win-body',
        CallkitNotificationActionType.click,
      );
      final CallkitNotificationAction? action =
          delegate.mapNotificationResponse(
        NotificationResponse(
          notificationResponseType:
              NotificationResponseType.selectedNotificationAction,
          id: 3,
          actionId: payload,
          payload: payload,
        ),
      );

      expect(action, isNotNull);
      expect(action!.callId, 'call-win-body');
      expect(action.type, CallkitNotificationActionType.click);
    });

    test('Windows-style action payload maps to accept', () {
      final String payload = _payload(
        'call-2',
        CallkitNotificationActionType.accept,
      );
      final CallkitNotificationAction? action =
          delegate.mapNotificationResponse(
        NotificationResponse(
          notificationResponseType:
              NotificationResponseType.selectedNotificationAction,
          id: 2,
          actionId: payload,
          payload: payload,
        ),
      );

      expect(action, isNotNull);
      expect(action!.callId, 'call-2');
      expect(action.type, CallkitNotificationActionType.accept);
    });

    test('dismiss maps to decline', () {
      final CallkitNotificationAction? action =
          delegate.mapNotificationResponse(
        NotificationResponse(
          notificationResponseType:
              NotificationResponseType.notificationDismissed,
          id: 1,
          payload: _payload(
            'call-3',
            CallkitNotificationActionType.click,
          ),
        ),
      );

      expect(action, isNotNull);
      expect(action!.callId, 'call-3');
      expect(action.type, CallkitNotificationActionType.decline);
    });

    test('unknown action id and foreign payloads are ignored', () {
      expect(
        delegate.mapNotificationResponse(
          const NotificationResponse(
            notificationResponseType:
                NotificationResponseType.selectedNotificationAction,
            id: 1,
            actionId: 'reply',
            payload: '{"kind":"other","callId":"call-1","action":"click"}',
          ),
        ),
        isNull,
      );
      expect(
        delegate.mapNotificationResponse(
          const NotificationResponse(
            notificationResponseType:
                NotificationResponseType.selectedNotification,
            id: 1,
            payload: 'some other app payload',
          ),
        ),
        isNull,
      );
    });
  });

  group('delegate lifecycle', () {
    test('emits actions and replays early actions to the first listener',
        () async {
      final FlutterLocalNotificationsCallkitDelegate delegate = _delegate();
      addTearDown(delegate.dispose);

      final NotificationResponse response = NotificationResponse(
        notificationResponseType:
            NotificationResponseType.selectedNotificationAction,
        id: 1,
        actionId: 'accept',
        payload: _payload(
          'call-early',
          CallkitNotificationActionType.click,
        ),
      );

      // The action arrives before main() subscribes (cold-start flow).
      await delegate.handleNotificationResponse(response);

      final Future<CallkitNotificationAction> firstAction =
          delegate.actions.first;
      final CallkitNotificationAction action = await firstAction;

      expect(action.callId, 'call-early');
      expect(action.type, CallkitNotificationActionType.accept);
    });

    test('platform settings expose categories and per-platform options', () {
      final FlutterLocalNotificationsCallkitDelegate delegate = _delegate();
      addTearDown(delegate.dispose);

      final InitializationSettings settings = delegate.initializationSettings;

      expect(settings.android, isNotNull);
      expect(settings.web, isNotNull);
      expect(settings.linux?.defaultActionName, 'Open');
      expect(settings.windows?.appName, 'Callkit');
      expect(settings.windows?.appUserModelId, 'com.example.test');
      expect(settings.windows?.guid, startsWith('a1b2c3d4'));

      final List<DarwinNotificationCategory> categories =
          settings.macOS!.notificationCategories;
      expect(categories, hasLength(1));
      expect(categories.single.identifier, 'callkit_incoming_call_v1');
      expect(
        categories.single.actions.map(
          (DarwinNotificationAction action) => action.identifier,
        ),
        <String>['accept', 'decline'],
      );
      expect(
        categories.single.options,
        contains(DarwinNotificationCategoryOption.customDismissAction),
      );
    });
  });
}
