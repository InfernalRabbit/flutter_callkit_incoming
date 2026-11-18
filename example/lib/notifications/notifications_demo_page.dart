import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_callkit_incoming_example/notifications/flutter_local_notifications_callkit_delegate.dart';
import 'package:uuid/uuid.dart';

/// Small, self-contained demo of [FlutterLocalNotificationsCallkitDelegate].
///
/// The page does not depend on the plugin's notification host hook: it calls
/// the delegate directly and listens to its actions stream. Once
/// `FlutterCallkitIncoming.setNotificationDelegate` is available, installing the
/// delegate is a one-line change in `main.dart`; this page keeps working either
/// way.
class NotificationsDemoPage extends StatefulWidget {
  const NotificationsDemoPage({super.key, required this.delegate});

  final FlutterLocalNotificationsCallkitDelegate delegate;

  @override
  State<NotificationsDemoPage> createState() => _NotificationsDemoPageState();
}

class _NotificationsDemoPageState extends State<NotificationsDemoPage> {
  static const Uuid _uuid = Uuid();

  final List<String> _events = <String>[];
  StreamSubscription<CallkitNotificationAction>? _actionsSubscription;
  String? _lastCallId;

  @override
  void initState() {
    super.initState();
    _actionsSubscription = widget.delegate.actions.listen(_onAction);
  }

  @override
  void dispose() {
    _actionsSubscription?.cancel();
    super.dispose();
  }

  void _onAction(CallkitNotificationAction action) {
    if (!mounted) {
      return;
    }
    setState(() {
      _events.insert(
        0,
        '${DateTime.now().toIso8601String()}  ${action.type.name}  '
        '${action.callId}',
      );
      if (action.type == CallkitNotificationActionType.decline ||
          action.type == CallkitNotificationActionType.end) {
        _lastCallId = null;
      }
    });
  }

  void _addEvent(String event) {
    if (!mounted) {
      return;
    }
    setState(() {
      _events.insert(0, '${DateTime.now().toIso8601String()}  $event');
    });
  }

  Future<void> _requestPermissions() async {
    final bool granted = await widget.delegate.requestPermissions();
    _addEvent('Permission request: ${granted ? 'granted' : 'not granted'}');
  }

  Future<void> _showIncomingCall() async {
    final String callId = _uuid.v4();
    _lastCallId = callId;
    await widget.delegate.showIncoming(
      CallkitNotificationCall(
        callId: callId,
        callerName: 'Hien Nguyen',
        handle: '0123456789',
        appName: 'Callkit',
        extra: <String, dynamic>{'userId': '1a2b3c4d'},
      ),
    );
    _addEvent('showIncoming($callId)');
  }

  Future<void> _showIncomingVideoCall() async {
    final String callId = _uuid.v4();
    _lastCallId = callId;
    await widget.delegate.showIncoming(
      CallkitNotificationCall(
        callId: callId,
        callerName: 'Hien Nguyen',
        handle: '0123456789',
        appName: 'Callkit',
        isVideo: true,
        extra: <String, dynamic>{'userId': '1a2b3c4d'},
      ),
    );
    _addEvent('showIncoming(video, $callId)');
  }

  Future<void> _showMissedCall() async {
    final String callId = _lastCallId ?? _uuid.v4();
    await widget.delegate.showMissed(
      CallkitNotificationCall(
        callId: callId,
        callerName: 'Hien Nguyen',
        handle: '0123456789',
        appName: 'Callkit',
        extra: <String, dynamic>{'userId': '1a2b3c4d'},
      ),
    );
    _addEvent('showMissed($callId)');
  }

  Future<void> _cancelLast() async {
    final String? callId = _lastCallId;
    if (callId == null) {
      _addEvent('No call notification to cancel');
      return;
    }
    await widget.delegate.cancel(callId);
    _lastCallId = null;
    _addEvent('cancel($callId)');
  }

  Future<void> _cancelAll() async {
    await widget.delegate.cancelAll();
    _lastCallId = null;
    _addEvent('cancelAll()');
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Call notifications')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'flutter_local_notifications callkit delegate',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'This demo shows incoming and missed call notifications '
                      'through the delegate and logs the actions reported by '
                      'the operating system. On mobile the plugin keeps its '
                      'native CallKit/ConnectionService UI; the delegate is '
                      'most useful on desktop and web.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                ElevatedButton.icon(
                  onPressed: _requestPermissions,
                  icon: const Icon(Icons.notifications_active),
                  label: const Text('Request permission'),
                ),
                ElevatedButton.icon(
                  onPressed: _showIncomingCall,
                  icon: const Icon(Icons.call),
                  label: const Text('Incoming call'),
                ),
                ElevatedButton.icon(
                  onPressed: _showIncomingVideoCall,
                  icon: const Icon(Icons.videocam),
                  label: const Text('Incoming video call'),
                ),
                ElevatedButton.icon(
                  onPressed: _showMissedCall,
                  icon: const Icon(Icons.phone_missed),
                  label: const Text('Missed call'),
                ),
                OutlinedButton.icon(
                  onPressed: _cancelLast,
                  icon: const Icon(Icons.close),
                  label: const Text('Cancel last'),
                ),
                OutlinedButton.icon(
                  onPressed: _cancelAll,
                  icon: const Icon(Icons.clear_all),
                  label: const Text('Cancel all'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Actions / events', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Expanded(
              child: _events.isEmpty
                  ? Center(
                      child: Text(
                        'Tap a notification action to see it here.',
                        style: theme.textTheme.bodySmall,
                      ),
                    )
                  : ListView.builder(
                      itemCount: _events.length,
                      itemBuilder: (BuildContext context, int index) {
                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.chevron_right, size: 18),
                          title: Text(_events[index]),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
