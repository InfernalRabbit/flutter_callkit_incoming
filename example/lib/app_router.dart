import 'package:flutter/material.dart';
import 'package:flutter_callkit_incoming_example/calling_page.dart';
import 'package:flutter_callkit_incoming_example/home_page.dart';
import 'package:flutter_callkit_incoming_example/notifications/flutter_local_notifications_callkit_delegate.dart';
import 'package:flutter_callkit_incoming_example/notifications/notifications_demo_page.dart';

class AppRoute {
  static const homePage = '/home_page';

  static const callingPage = '/calling_page';

  static const notificationsPage = '/notifications_page';

  static Route<Object>? generateRoute(
    RouteSettings settings, {
    FlutterLocalNotificationsCallkitDelegate? notificationDelegate,
  }) {
    switch (settings.name) {
      case homePage:
        return MaterialPageRoute(
          builder: (_) => HomePage(notificationDelegate: notificationDelegate),
          settings: settings,
        );
      case callingPage:
        return MaterialPageRoute(
          builder: (_) => const CallingPage(),
          settings: settings,
        );
      case notificationsPage:
        if (notificationDelegate == null) {
          return null;
        }
        return MaterialPageRoute(
          builder: (_) => NotificationsDemoPage(
            delegate: notificationDelegate,
          ),
          settings: settings,
        );
      default:
        return null;
    }
  }
}
