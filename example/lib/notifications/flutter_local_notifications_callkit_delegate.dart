import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Identifier used by the action buttons of a call notification.
abstract final class CallkitNotificationActionIds {
  /// The user accepted the call.
  static const String accept = 'accept';

  /// The user declined the call.
  static const String decline = 'decline';

  /// The call was ended from the notification.
  static const String end = 'end';

  /// The notification body was tapped (or the default action was invoked).
  static const String click = 'click';
}

/// The JSON payload stored in every call notification created by
/// [FlutterLocalNotificationsCallkitDelegate].
///
/// Keeping the call id and the action in the payload means notification
/// responses can be routed after the Flutter engine was restarted, when the
/// in-memory notification id registry is empty.
@immutable
class CallkitNotificationPayload {
  /// Creates a payload for [callId] and [action].
  const CallkitNotificationPayload({
    required this.callId,
    required this.action,
  });

  /// Version of the payload format. Bump it when the meaning of the fields
  /// changes so older payloads can be rejected or migrated.
  static const int formatVersion = 1;

  /// Discriminator that keeps this payload distinguishable from payloads used
  /// by unrelated notifications in the same application.
  static const String kind = 'callkit';

  /// The call this notification belongs to.
  final String callId;

  /// The action to report when the payload is parsed back.
  final CallkitNotificationActionType action;

  /// Encodes this payload as JSON.
  String encode() => jsonEncode(<String, Object>{
        'kind': kind,
        'v': formatVersion,
        'callId': callId,
        'action': action.name,
      });

  /// Parses a payload previously produced by [encode].
  ///
  /// Returns null for empty, malformed or unrelated payloads. The parser is
  /// deliberately strict: a notification that was not created by this adapter
  /// must never be turned into a call action.
  static CallkitNotificationPayload? tryParse(String? raw) {
    if (raw == null || raw.isEmpty) {
      return null;
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return null;
    }

    if (decoded is! Map<String, dynamic>) {
      return null;
    }
    if (decoded['kind'] != kind) {
      return null;
    }

    final Object? callId = decoded['callId'];
    if (callId is! String || callId.isEmpty) {
      return null;
    }

    final CallkitNotificationActionType? action = _actionTypeFromName(
      decoded['action'],
    );
    if (action == null) {
      return null;
    }

    return CallkitNotificationPayload(callId: callId, action: action);
  }

  static CallkitNotificationActionType? _actionTypeFromName(Object? value) {
    if (value is! String) {
      return null;
    }
    for (final CallkitNotificationActionType type
        in CallkitNotificationActionType.values) {
      if (type.name == value) {
        return type;
      }
    }
    return null;
  }

  @override
  String toString() => 'CallkitNotificationPayload(callId: $callId, '
      'action: ${action.name})';
}

/// A [CallkitNotificationDelegate] backed by `flutter_local_notifications`.
///
/// The adapter owns notification presentation only. It does not install
/// itself into `FlutterCallkitIncoming`; the host application does that with
/// `FlutterCallkitIncoming.setNotificationDelegate(delegate)` when the
/// notification-delegate host hook is available. Until then the delegate can
/// be used directly, as the example application does.
///
/// Typical lifecycle:
///
/// ```dart
/// final delegate = FlutterLocalNotificationsCallkitDelegate(
///   appName: 'My app',
///   windowsAppUserModelId: 'com.example.myapp',
///   windowsGuid: 'a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d',
/// );
/// await delegate.initialize();
/// await delegate.requestPermissions();
/// // Install with the host hook when available:
/// // FlutterCallkitIncoming.setNotificationDelegate(delegate);
/// ```
///
/// The adapter intentionally targets Android, iOS, macOS, Linux, Windows and
/// web. Mobile applications can keep using the native CallKit /
/// ConnectionService UI and only install this delegate on desktop and web, as
/// the plugin does by default.
class FlutterLocalNotificationsCallkitDelegate
    implements CallkitNotificationDelegate {
  /// Creates a delegate.
  ///
  /// [windowsAppUserModelId] and [windowsGuid] are required because Windows
  /// toast activation does not work without a stable AppUserModelID and a
  /// registered activation GUID. Use values that belong to your application,
  /// not the example values.
  FlutterLocalNotificationsCallkitDelegate({
    required this.appName,
    required this.windowsAppUserModelId,
    required this.windowsGuid,
    this.notificationCategoryId = 'callkit_incoming_call_v1',
    this.androidIcon = '@mipmap/ic_launcher',
    this.androidChannelId = 'callkit_incoming_calls',
    this.androidChannelName = 'Incoming calls',
    this.androidChannelDescription = 'Incoming and missed call notifications',
    this.linuxDefaultActionName = 'Open',
    this.linuxIcon,
    this.windowsIconPath,
    this.acceptActionLabel = 'Accept',
    this.declineActionLabel = 'Decline',
    this.incomingCallText = 'Incoming call',
    this.incomingVideoCallText = 'Incoming video call',
    this.missedCallText = 'Missed call',
    this.cancelOnAction = true,
    this.handleNotificationLaunchDetails = true,
    this.onError,
  }) {
    if (!_isUuid(windowsGuid)) {
      throw ArgumentError.value(
        windowsGuid,
        'windowsGuid',
        'must be a GUID in xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx format',
      );
    }
  }

  static final RegExp _uuidPattern = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
    r'[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  static bool _isUuid(String value) => _uuidPattern.hasMatch(value);

  /// Application name shown by the platforms that support it (macOS, Windows,
  /// Linux and as a subtitle on iOS).
  final String appName;

  /// AppUserModelID registered by the Windows toast activator.
  final String windowsAppUserModelId;

  /// Stable GUID used to register the Windows notification activation
  /// callback. It must not change between application launches.
  final String windowsGuid;

  /// Identifier of the Darwin notification category with the call actions.
  ///
  /// iOS and macOS cache category actions for the lifetime of the install.
  /// When changing [acceptActionLabel], [declineActionLabel] or the action set,
  /// bump the suffix (`_v2`) or users will keep seeing the old actions until
  /// the application is reinstalled.
  final String notificationCategoryId;

  /// Android default small icon.
  final String androidIcon;

  /// Android notification channel id.
  final String androidChannelId;

  /// Android notification channel name.
  final String androidChannelName;

  /// Android notification channel description.
  final String androidChannelDescription;

  /// Label for the default action on Linux.
  final String linuxDefaultActionName;

  /// Optional Linux notification icon (theme name, asset, file path, ...).
  final LinuxNotificationIcon? linuxIcon;

  /// Optional path to the icon file used by Windows toasts.
  final String? windowsIconPath;

  /// Label of the accept action.
  final String acceptActionLabel;

  /// Label of the decline action.
  final String declineActionLabel;

  /// Body text of an incoming audio call.
  final String incomingCallText;

  /// Body text of an incoming video call.
  final String incomingVideoCallText;

  /// Title of a missed-call notification.
  final String missedCallText;

  /// Whether the notification is removed when the user acts on it.
  ///
  /// This is normally desirable. Disable it when the application wants to keep
  /// the call notification visible while it moves to the call screen.
  final bool cancelOnAction;

  /// Whether [initialize] should inspect
  /// [FlutterLocalNotificationsPlugin.getNotificationAppLaunchDetails] and
  /// emit the action that launched the application. This makes cold-start
  /// notification taps work, but costs one platform channel round-trip during
  /// startup.
  final bool handleNotificationLaunchDetails;

  /// Optional error sink. Notification failures are best effort by design:
  /// they are reported here (or printed in debug builds) and never break the
  /// call state machine.
  final void Function(Object error, StackTrace stackTrace)? onError;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  late final StreamController<CallkitNotificationAction> _actionsController =
      StreamController<CallkitNotificationAction>.broadcast(
    onListen: _flushPendingActions,
  );
  final List<CallkitNotificationAction> _pendingActions =
      <CallkitNotificationAction>[];

  final Map<String, int> _notificationIdByCallId = <String, int>{};
  final Map<int, String> _callIdByNotificationId = <int, String>{};

  Future<bool>? _initialization;
  bool _initialized = false;
  bool _disposed = false;

  /// Whether the supported platform adapter has been initialized.
  bool get isInitialized => _initialized;

  /// Actions performed by the user on call notifications.
  ///
  /// Events that arrive before the first listener is attached (for example
  /// from a notification that launched the application) are buffered and
  /// replayed to the first listener.
  @override
  Stream<CallkitNotificationAction> get actions => _actionsController.stream;

  /// Whether `flutter_local_notifications` has an implementation for the
  /// platform the application is currently running on.
  static bool get supportsCurrentPlatform {
    if (kIsWeb) {
      return true;
    }
    return switch (defaultTargetPlatform) {
      TargetPlatform.android ||
      TargetPlatform.iOS ||
      TargetPlatform.macOS ||
      TargetPlatform.linux ||
      TargetPlatform.windows =>
        true,
      TargetPlatform.fuchsia => false,
    };
  }

  /// Initialization settings for every platform supported by the adapter.
  ///
  /// The settings never request permissions during initialization. Call
  /// [requestPermissions] from a user gesture instead.
  InitializationSettings get initializationSettings {
    return InitializationSettings(
      android: AndroidInitializationSettings(androidIcon),
      iOS: _darwinSettings,
      macOS: _darwinSettings,
      linux: LinuxInitializationSettings(
        defaultActionName: linuxDefaultActionName,
        defaultIcon: linuxIcon,
      ),
      windows: WindowsInitializationSettings(
        appName: appName,
        appUserModelId: windowsAppUserModelId,
        guid: windowsGuid,
        iconPath: windowsIconPath,
      ),
      web: const WebInitializationSettings(),
    );
  }

  late final DarwinInitializationSettings _darwinSettings =
      DarwinInitializationSettings(
    requestAlertPermission: false,
    requestBadgePermission: false,
    requestSoundPermission: false,
    requestProvisionalPermission: false,
    requestCriticalPermission: false,
    defaultPresentAlert: true,
    defaultPresentBanner: true,
    defaultPresentList: true,
    defaultPresentSound: true,
    notificationCategories: <DarwinNotificationCategory>[
      DarwinNotificationCategory(
        notificationCategoryId,
        actions: <DarwinNotificationAction>[
          DarwinNotificationAction.plain(
            CallkitNotificationActionIds.accept,
            acceptActionLabel,
            options: const <DarwinNotificationActionOption>{
              DarwinNotificationActionOption.foreground,
            },
          ),
          DarwinNotificationAction.plain(
            CallkitNotificationActionIds.decline,
            declineActionLabel,
            options: const <DarwinNotificationActionOption>{
              DarwinNotificationActionOption.destructive,
            },
          ),
        ],
        options: const <DarwinNotificationCategoryOption>{
          DarwinNotificationCategoryOption.customDismissAction,
        },
      ),
    ],
  );

  /// Initializes `flutter_local_notifications` and processes a cold-start
  /// notification tap.
  ///
  /// Safe to call more than once; concurrent calls share the same future.
  /// Returns false when the platform implementation could not be initialized
  /// (for example when service workers are unavailable on the web).
  Future<bool> initialize() {
    if (_initialized) {
      return Future<bool>.value(true);
    }
    final Future<bool>? pending = _initialization;
    if (pending != null) {
      return pending;
    }

    final Future<bool> future = _initialize();
    _initialization = future;
    return future.whenComplete(() {
      _initialization = null;
    });
  }

  Future<bool> _initialize() async {
    if (_disposed) {
      return false;
    }
    try {
      final bool initialized = await _plugin.initialize(
            settings: initializationSettings,
            onDidReceiveNotificationResponse: handleNotificationResponse,
          ) ??
          true;
      if (!initialized) {
        return false;
      }
      _initialized = true;
      if (handleNotificationLaunchDetails) {
        await _processNotificationAppLaunchDetails();
      }
      return true;
    } catch (error, stackTrace) {
      _reportError(error, stackTrace);
      return false;
    }
  }

  /// Requests notification permission for the current platform.
  ///
  /// The web implementation requires this to be called from a user gesture.
  /// Windows and Linux do not have a runtime notification permission; the
  /// method returns true for them. Android requests `POST_NOTIFICATIONS`
  /// (API 33+). iOS and macOS request alert, badge and sound permissions.
  ///
  /// When [initialize] has not run yet it is called first.
  Future<bool> requestPermissions({
    bool alert = true,
    bool badge = true,
    bool sound = true,
  }) async {
    // Request the browser permission before awaiting anything else: a long
    // async chain can consume the user activation that browsers require for
    // Notification.requestPermission(). The service worker is initialized
    // lazily by the first show() call.
    if (kIsWeb) {
      try {
        final WebFlutterLocalNotificationsPlugin? web =
            _plugin.resolvePlatformSpecificImplementation<
                WebFlutterLocalNotificationsPlugin>();
        return await web?.requestNotificationsPermission() ?? false;
      } catch (error, stackTrace) {
        _reportError(error, stackTrace);
        return false;
      }
    }

    if (!await initialize()) {
      return false;
    }

    try {
      switch (defaultTargetPlatform) {
        case TargetPlatform.android:
          final AndroidFlutterLocalNotificationsPlugin? android =
              _plugin.resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin>();
          return await android?.requestNotificationsPermission() ?? false;
        case TargetPlatform.iOS:
          final IOSFlutterLocalNotificationsPlugin? ios =
              _plugin.resolvePlatformSpecificImplementation<
                  IOSFlutterLocalNotificationsPlugin>();
          return await ios?.requestPermissions(
                alert: alert,
                badge: badge,
                sound: sound,
              ) ??
              false;
        case TargetPlatform.macOS:
          final MacOSFlutterLocalNotificationsPlugin? macOS =
              _plugin.resolvePlatformSpecificImplementation<
                  MacOSFlutterLocalNotificationsPlugin>();
          return await macOS?.requestPermissions(
                alert: alert,
                badge: badge,
                sound: sound,
              ) ??
              false;
        case TargetPlatform.linux:
        case TargetPlatform.windows:
          // Notification permissions are managed by the OS / desktop
          // environment, there is no runtime prompt.
          return true;
        case TargetPlatform.fuchsia:
          return false;
      }
    } catch (error, stackTrace) {
      _reportError(error, stackTrace);
      return false;
    }
  }

  /// Requests Android 14+ `USE_FULL_SCREEN_INTENT` access.
  ///
  /// Returns false on non-Android platforms. Call this only when the app
  /// actually shows full-screen incoming-call notifications.
  Future<bool> requestFullScreenIntentPermission() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return false;
    }
    try {
      final AndroidFlutterLocalNotificationsPlugin? android =
          _plugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      return await android?.requestFullScreenIntentPermission() ?? false;
    } catch (error, stackTrace) {
      _reportError(error, stackTrace);
      return false;
    }
  }

  @override
  Future<void> showIncoming(CallkitNotificationCall call) async {
    if (!await initialize()) {
      return;
    }
    final int id = _notificationIdFor(call.callId);
    try {
      await _plugin.show(
        id: id,
        title: _displayName(call),
        body: _incomingBody(call),
        notificationDetails: _notificationDetails(call, missed: false),
        payload: CallkitNotificationPayload(
          callId: call.callId,
          action: CallkitNotificationActionType.click,
        ).encode(),
      );
    } catch (error, stackTrace) {
      _reportError(error, stackTrace);
    }
  }

  @override
  Future<void> showMissed(CallkitNotificationCall call) async {
    if (!await initialize()) {
      return;
    }
    final int id = _notificationIdFor(call.callId);
    try {
      await _plugin.show(
        id: id,
        title: missedCallText,
        body: _missedBody(call),
        notificationDetails: _notificationDetails(call, missed: true),
        payload: CallkitNotificationPayload(
          callId: call.callId,
          action: CallkitNotificationActionType.click,
        ).encode(),
      );
    } catch (error, stackTrace) {
      _reportError(error, stackTrace);
    }
  }

  @override
  Future<void> cancel(String callId) async {
    final int id =
        _notificationIdByCallId.remove(callId) ?? _stableNotificationId(callId);
    _callIdByNotificationId.remove(id);
    try {
      await _plugin.cancel(id: id);
    } catch (error, stackTrace) {
      _reportError(error, stackTrace);
    }
  }

  @override
  Future<void> cancelAll() async {
    final Set<int> ids = _notificationIdByCallId.values.toSet();
    _notificationIdByCallId.clear();
    _callIdByNotificationId.clear();

    // The in-memory registry is empty after a restart. Ask the platform for
    // active notifications and cancel only the ones carrying our payload, so
    // unrelated application notifications are left untouched.
    try {
      final List<ActiveNotification> active =
          await _plugin.getActiveNotifications();
      for (final ActiveNotification notification in active) {
        final int? id = notification.id;
        if (id != null &&
            CallkitNotificationPayload.tryParse(notification.payload) != null) {
          ids.add(id);
        }
      }
    } catch (_) {
      // getActiveNotifications() is not implemented on every platform
      // (notably Linux). The tracked ids above are still cancelled.
    }

    for (final int id in ids) {
      try {
        await _plugin.cancel(id: id);
      } catch (error, stackTrace) {
        _reportError(error, stackTrace);
      }
    }
  }

  /// Maps a `flutter_local_notifications` response to a delegate action.
  ///
  /// Exposed for tests and for hosts that receive notification responses
  /// through their own plugin instance. Returns null for unrelated
  /// notifications or unsupported action ids.
  CallkitNotificationAction? mapNotificationResponse(
    NotificationResponse response,
  ) {
    final CallkitNotificationPayload? payload =
        CallkitNotificationPayload.tryParse(response.payload);
    final CallkitNotificationPayload? actionPayload =
        CallkitNotificationPayload.tryParse(response.actionId);

    final String? callId = payload?.callId ??
        actionPayload?.callId ??
        _callIdByNotificationId[response.id];
    if (callId == null) {
      return null;
    }

    final CallkitNotificationActionType? type =
        switch (response.notificationResponseType) {
      NotificationResponseType.notificationDismissed =>
        CallkitNotificationActionType.decline,
      NotificationResponseType.selectedNotificationAction =>
        _actionTypeFromId(response.actionId) ??
            _actionFromResponsePayload(
              response,
              payload: payload,
              actionPayload: actionPayload,
            ),
      NotificationResponseType.selectedNotification =>
        payload?.action ?? actionPayload?.action,
    };
    if (type == null) {
      return null;
    }

    return CallkitNotificationAction(callId: callId, type: type);
  }

  /// Handles a response received by `flutter_local_notifications`.
  ///
  /// This is the callback wired into [initialize]; it is public so tests and
  /// applications that manage their own plugin instance can forward responses.
  Future<void> handleNotificationResponse(
    NotificationResponse response, {
    bool cancelNotification = true,
  }) async {
    final CallkitNotificationAction? action = mapNotificationResponse(response);
    if (action == null) {
      return;
    }

    _emit(action);
    if (cancelOnAction && cancelNotification) {
      await cancel(action.callId);
    }
  }

  /// Releases the action stream. The delegate cannot be used afterwards.
  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _pendingActions.clear();
    unawaited(_actionsController.close());
  }

  NotificationDetails _notificationDetails(
    CallkitNotificationCall call, {
    required bool missed,
  }) {
    return NotificationDetails(
      android: _androidDetails(call, missed: missed),
      iOS: _darwinDetails(call, missed: missed),
      macOS: _darwinDetails(call, missed: missed),
      linux: _linuxDetails(call, missed: missed),
      windows: _windowsDetails(call, missed: missed),
      web: _webDetails(call, missed: missed),
    );
  }

  AndroidNotificationDetails _androidDetails(
    CallkitNotificationCall call, {
    required bool missed,
  }) {
    return AndroidNotificationDetails(
      androidChannelId,
      androidChannelName,
      channelDescription: androidChannelDescription,
      importance: Importance.max,
      priority: Priority.high,
      category: missed
          ? AndroidNotificationCategory.missedCall
          : AndroidNotificationCategory.call,
      visibility: NotificationVisibility.public,
      fullScreenIntent: !missed,
      ongoing: !missed,
      autoCancel: missed,
      subText: call.appName,
      // Actions launch the app so the response reaches the main isolate.
      // The delegate does not register a background isolate; a cold-start tap
      // is recovered by [handleNotificationLaunchDetails].
      actions: missed
          ? null
          : <AndroidNotificationAction>[
              AndroidNotificationAction(
                CallkitNotificationActionIds.accept,
                acceptActionLabel,
                showsUserInterface: true,
              ),
              AndroidNotificationAction(
                CallkitNotificationActionIds.decline,
                declineActionLabel,
                showsUserInterface: true,
              ),
            ],
    );
  }

  DarwinNotificationDetails _darwinDetails(
    CallkitNotificationCall call, {
    required bool missed,
  }) {
    return DarwinNotificationDetails(
      presentAlert: true,
      presentBanner: true,
      presentList: true,
      presentSound: true,
      sound: 'default',
      subtitle: call.appName,
      threadIdentifier: 'callkit:${call.callId}',
      categoryIdentifier: missed ? null : notificationCategoryId,
      interruptionLevel:
          missed ? InterruptionLevel.active : InterruptionLevel.timeSensitive,
    );
  }

  LinuxNotificationDetails _linuxDetails(
    CallkitNotificationCall call, {
    required bool missed,
  }) {
    return LinuxNotificationDetails(
      icon: linuxIcon,
      urgency: missed
          ? LinuxNotificationUrgency.normal
          : LinuxNotificationUrgency.critical,
      timeout: missed
          ? const LinuxNotificationTimeout.systemDefault()
          : const LinuxNotificationTimeout.expiresNever(),
      resident: !missed,
      defaultActionName: linuxDefaultActionName,
      actions: missed
          ? const <LinuxNotificationAction>[]
          : <LinuxNotificationAction>[
              LinuxNotificationAction(
                key: CallkitNotificationActionIds.accept,
                label: acceptActionLabel,
              ),
              LinuxNotificationAction(
                key: CallkitNotificationActionIds.decline,
                label: declineActionLabel,
              ),
            ],
    );
  }

  WindowsNotificationDetails _windowsDetails(
    CallkitNotificationCall call, {
    required bool missed,
  }) {
    return WindowsNotificationDetails(
      scenario: missed ? null : WindowsNotificationScenario.incomingCall,
      duration: missed
          ? WindowsNotificationDuration.short
          : WindowsNotificationDuration.long,
      subtitle: call.appName,
      timestamp: DateTime.now(),
      actions: missed
          ? const <WindowsAction>[]
          : <WindowsAction>[
              WindowsAction(
                content: acceptActionLabel,
                arguments: CallkitNotificationPayload(
                  callId: call.callId,
                  action: CallkitNotificationActionType.accept,
                ).encode(),
                buttonStyle: WindowsButtonStyle.success,
              ),
              WindowsAction(
                content: declineActionLabel,
                arguments: CallkitNotificationPayload(
                  callId: call.callId,
                  action: CallkitNotificationActionType.decline,
                ).encode(),
                buttonStyle: WindowsButtonStyle.critical,
              ),
            ],
    );
  }

  WebNotificationDetails _webDetails(
    CallkitNotificationCall call, {
    required bool missed,
  }) {
    return WebNotificationDetails(
      actions: missed
          ? const <WebNotificationAction>[]
          : <WebNotificationAction>[
              WebNotificationAction(
                action: CallkitNotificationActionIds.accept,
                title: acceptActionLabel,
              ),
              WebNotificationAction(
                action: CallkitNotificationActionIds.decline,
                title: declineActionLabel,
              ),
            ],
      requireInteraction: !missed,
      isSilent: false,
      renotify: false,
      timestamp: DateTime.now(),
    );
  }

  String _displayName(CallkitNotificationCall call) {
    final String name = call.callerName.trim();
    if (name.isNotEmpty) {
      return name;
    }
    final String? handle = call.handle;
    if (handle != null && handle.trim().isNotEmpty) {
      return handle;
    }
    return call.appName;
  }

  String _incomingBody(CallkitNotificationCall call) {
    final String label =
        call.isVideo ? incomingVideoCallText : incomingCallText;
    final String? handle = call.handle;
    if (handle == null || handle.trim().isEmpty) {
      return label;
    }
    return '$label • ${handle.trim()}';
  }

  String _missedBody(CallkitNotificationCall call) {
    final String name = _displayName(call);
    final String? handle = call.handle;
    if (handle == null || handle.trim().isEmpty || handle.trim() == name) {
      return name;
    }
    return '$name • ${handle.trim()}';
  }

  int _notificationIdFor(String callId) {
    final int? existing = _notificationIdByCallId[callId];
    if (existing != null) {
      return existing;
    }

    int candidate = _stableNotificationId(callId);
    while (_callIdByNotificationId.containsKey(candidate) &&
        _callIdByNotificationId[candidate] != callId) {
      candidate = candidate == 0x7FFFFFFF ? 0 : candidate + 1;
    }
    _notificationIdByCallId[callId] = candidate;
    _callIdByNotificationId[candidate] = callId;
    return candidate;
  }

  /// Returns a stable, non-negative 31-bit id for [callId].
  ///
  /// FNV-1a is used instead of [String.hashCode] so the same call id maps to
  /// the same notification id across process restarts. Collisions between live
  /// calls are resolved by [_notificationIdFor].
  static int _stableNotificationId(String callId) {
    int hash = 0x811C9DC5;
    for (final int codeUnit in callId.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash & 0x7FFFFFFF;
  }

  /// Resolves the action for a "selected action" response.
  ///
  /// Windows does not expose the action id separately: both [response.payload]
  /// and [response.actionId] contain the JSON arguments of the pressed button.
  /// When the two values are identical the payload itself is authoritative
  /// (which also covers a Windows body click, reported as an action because
  /// the toast carries a launch payload). On iOS, macOS, Linux, Android and
  /// web the action id is a plain identifier and the payload is the base
  /// click payload, so a foreign action id must not fall back to click.
  CallkitNotificationActionType? _actionFromResponsePayload(
    NotificationResponse response, {
    required CallkitNotificationPayload? payload,
    required CallkitNotificationPayload? actionPayload,
  }) {
    if (actionPayload != null &&
        response.actionId != null &&
        response.actionId == response.payload) {
      return actionPayload.action;
    }
    if (actionPayload != null &&
        actionPayload.action != CallkitNotificationActionType.click) {
      return actionPayload.action;
    }
    if (payload != null &&
        payload.action != CallkitNotificationActionType.click) {
      return payload.action;
    }
    return null;
  }

  CallkitNotificationActionType? _actionTypeFromId(String? actionId) {
    return switch (actionId) {
      CallkitNotificationActionIds.accept =>
        CallkitNotificationActionType.accept,
      CallkitNotificationActionIds.decline =>
        CallkitNotificationActionType.decline,
      CallkitNotificationActionIds.end => CallkitNotificationActionType.end,
      _ => null,
    };
  }

  Future<void> _processNotificationAppLaunchDetails() async {
    try {
      final NotificationAppLaunchDetails? details =
          await _plugin.getNotificationAppLaunchDetails();
      final NotificationResponse? response = details?.notificationResponse;
      if (details?.didNotificationLaunchApp == true && response != null) {
        await handleNotificationResponse(response);
      }
    } on UnimplementedError {
      // Linux and some older platform implementations cannot report whether
      // the app was launched from a notification. That is not an error.
    } catch (error, stackTrace) {
      _reportError(error, stackTrace);
    }
  }

  void _emit(CallkitNotificationAction action) {
    if (_disposed || _actionsController.isClosed) {
      return;
    }
    if (_actionsController.hasListener) {
      _actionsController.add(action);
      return;
    }

    // Keep a small bounded queue so an action that launched the application is
    // not lost before the host subscribes to the stream.
    if (_pendingActions.length >= 16) {
      _pendingActions.removeAt(0);
    }
    _pendingActions.add(action);
  }

  void _flushPendingActions() {
    if (_pendingActions.isEmpty) {
      return;
    }
    final List<CallkitNotificationAction> pending =
        List<CallkitNotificationAction>.of(_pendingActions);
    _pendingActions.clear();
    scheduleMicrotask(() {
      if (_disposed || _actionsController.isClosed) {
        return;
      }
      for (final CallkitNotificationAction action in pending) {
        if (_actionsController.hasListener) {
          _actionsController.add(action);
        } else {
          _pendingActions.add(action);
        }
      }
    });
  }

  void _reportError(Object error, StackTrace stackTrace) {
    final void Function(Object, StackTrace)? handler = onError;
    if (handler != null) {
      handler(error, stackTrace);
      return;
    }
    debugPrint(
      'FlutterLocalNotificationsCallkitDelegate: $error\n$stackTrace',
    );
  }
}
