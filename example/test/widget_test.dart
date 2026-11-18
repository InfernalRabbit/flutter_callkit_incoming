import 'package:flutter/material.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_callkit_incoming_example/notifications/flutter_local_notifications_callkit_delegate.dart';
import 'package:flutter_callkit_incoming_example/notifications/notifications_demo_page.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders the notification delegate demo and logs actions',
      (WidgetTester tester) async {
    final FlutterLocalNotificationsCallkitDelegate delegate =
        FlutterLocalNotificationsCallkitDelegate(
      appName: 'Callkit',
      windowsAppUserModelId: 'com.example.test',
      windowsGuid: 'a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d',
      cancelOnAction: false,
      handleNotificationLaunchDetails: false,
    );
    addTearDown(delegate.dispose);

    await tester.pumpWidget(
      MaterialApp(home: NotificationsDemoPage(delegate: delegate)),
    );

    expect(find.text('Call notifications'), findsOneWidget);
    expect(find.text('Incoming call'), findsOneWidget);
    expect(find.text('Missed call'), findsOneWidget);
    expect(find.text('Request permission'), findsOneWidget);

    await delegate.handleNotificationResponse(
      NotificationResponse(
        notificationResponseType:
            NotificationResponseType.selectedNotificationAction,
        id: 1,
        actionId: 'accept',
        payload: CallkitNotificationPayload(
          callId: 'call-widget-test',
          action: CallkitNotificationActionType.click,
        ).encode(),
      ),
    );
    await tester.pump();

    expect(find.textContaining('accept'), findsOneWidget);
    expect(find.textContaining('call-widget-test'), findsOneWidget);
  });
}
