# Flutter Callkit Incoming

A Flutter plugin to show incoming call in your Flutter app (Custom for Android/Callkit for iOS).

[![pub package](https://img.shields.io/pub/v/flutter_callkit_incoming.svg)](https://pub.dev/packages/flutter_callkit_incoming)
[![pub points](https://img.shields.io/pub/points/flutter_callkit_incoming?label=pub%20points)](https://pub.dev/packages/flutter_callkit_incoming/score)
[![GitHub stars](https://img.shields.io/github/stars/hiennguyen92/flutter_callkit_incoming.svg?style=social)](https://github.com/hiennguyen92/flutter_callkit_incoming/stargazers)
[![GitHub forks](https://img.shields.io/github/forks/hiennguyen92/flutter_callkit_incoming.svg?style=social)](https://github.com/hiennguyen92/flutter_callkit_incoming/network)
[![GitHub license](https://img.shields.io/github/license/hiennguyen92/flutter_callkit_incoming.svg)](https://github.com/hiennguyen92/flutter_callkit_incoming/blob/master/LICENSE)
[![Build Status](https://github.com/hiennguyen92/flutter_callkit_incoming/actions/workflows/main.yml/badge.svg)](https://github.com/hiennguyen92/flutter_callkit_incoming/actions/workflows/main.yml)

## Sponsors

Our top sponsors are shown below!

<a href="https://getstream.io/video/sdk/flutter/tutorial/video-calling/?utm_source=Github&utm_medium=Github_Repo_Content_Ad&utm_content=Developer&utm_campaign=Github_Video&utm_term=flutter_callkit" target="_blank">
  <img width="250px" src="https://stream-blog.s3.amazonaws.com/blog/wp-content/uploads/fc148f0fc75d02841d017bb36e14e388/Stream-logo-with-background-.png"/>
</a>
<br/>
<span>
  <a href="https://getstream.io/video/sdk/flutter/tutorial/video-calling/?utm_source=Github&utm_medium=Github_Repo_Content_Ad&utm_content=Developer&utm_campaign=Github_Video&utm_term=flutter_callkit" target="_blank">Try the Flutter Video Tutorial 📹</a>
</span>
</br>
</br>
<a href="https://www.buymeacoffee.com/hiennguyen92" target="_blank">
  <img src="https://cdn.buymeacoffee.com/buttons/default-orange.png" alt="Buy Me A Coffee" height="41" width="174">
</a>

## 📌 Table of Contents
- [⭐ Features](#-features)
- [🚀 Installation](#-installation)
  - [1. Install Packages](#1-install-packages)
  - [2. Configure Project](#2-configure-project)
    - [Android Configuration](#android)
    - [iOS Configuration](#ios)
    - [Swift Package Manager (SPM) Support](#swift-package-manager-spm-support-flutter-324)
    - [Desktop (macOS / Windows / Linux)](#desktop-macos--windows--linux)
  - [3. Usage](#3-usage)
- [🔔 Call notification delegate (desktop and web)](#-call-notification-delegate-desktop-and-web)
- [🌐 Web (including WASM)](#-web-including-wasm)
- [🔔 Host-owned call notifications with flutter_local_notifications](#-host-owned-call-notifications-with-flutter_local_notifications)
- [📋 Properties](#-properties)
- [📱 Pushkit Setup](#-pushkit---received-voip-and-wake-app-from-terminated-state-ios-only)
- [🎯 Demo](#-demo)

## ⭐ Features

- Show an incoming call
- Start an outgoing call
- Custom UI Android/Callkit for iOS
- Example using Pushkit/VoIP for iOS
- macOS, Windows and Linux support (Dart-only; in-memory call registry, notifications through a host-app delegate)
- Web support (JavaScript and WebAssembly targets, notifications through a host-app delegate)

> [!WARNING]
> ### iOS: ONLY WORKING ON REAL DEVICE
> **Please make sure setup/using [PUSHKIT](https://github.com/hiennguyen92/flutter_callkit_incoming/blob/master/PUSHKIT.md) FOR VOIP**
>
> *Note:* Please do not use on simulator (Callkit framework is not fully supported on simulator for incoming VoIP calls).

## 🚀 Installation

### 1. Install Packages

For version >= v2.5.0, please make sure install and use Java SDK version >= 17 (Android)

**Run this command:**
```bash
flutter pub add flutter_callkit_incoming
```

**Or add to pubspec.yaml:**
```yaml
dependencies:
  flutter_callkit_incoming: ^latest
```

### 2. Configure Project

#### Android

**AndroidManifest.xml:**
```xml
<manifest...>
    ...
    <!-- Using for load image from internet -->
    <uses-permission android:name="android.permission.INTERNET"/>

    <application ...>
        <activity ...
            android:name=".MainActivity"
            android:launchMode="singleInstance"><!-- add this -->
        ...
    </application>
</manifest>
```

**Proguard Rules:**
The following rule needs to be added in the `proguard-rules.pro` to avoid obfuscated keys:
```
-keep class com.hiennv.flutter_callkit_incoming.** { *; }
```

#### iOS

**Info.plist:**
```xml
<key>UIBackgroundModes</key>
<array>
    <string>voip</string>
    <string>remote-notification</string>
    <string>processing</string> <!-- you can add this if needed -->
</array>
```

#### Swift Package Manager (SPM) Support (Flutter 3.24+)

This plugin natively supports Swift Package Manager (SPM). To configure your project to build using SPM instead of CocoaPods, run:

```bash
flutter config --enable-swift-package-manager
```

> [!IMPORTANT]
> Swift Package Manager is highly recommended for modern Flutter projects as CocoaPods is in maintenance mode and will become read-only in December 2026.

#### Desktop (macOS / Windows / Linux)

Desktop support is implemented in Dart. There is no CallKit/ConnectionService
equivalent outside Android and iOS, so the plugin keeps calls in an in-memory
registry of active calls and mirrors the mobile event stream. The platform
entries are declared in this package with
`dartPluginClass: FlutterCallkitIncomingDesktop`, so no extra configuration
or native code is required in the host app.

Desktop behaviour:

- `showCallkitIncoming` registers the call and forwards it to the installed
  `CallkitNotificationDelegate`; `showMissCallNotification`, `endCall`,
  `endAllCalls` and `hideCallkitIncoming` forward the matching
  show/cancel operations.
- Notification presentation and notification permissions belong to the host
  application. See
  [Call notification delegate](#-call-notification-delegate-desktop-and-web).
  Without a delegate the call registry and event stream keep working, but no
  OS notification is shown (the first skipped operation logs a warning).
- `activeCalls` returns the in-memory registry. It is empty after a restart:
  desktop calls are not persisted and there is no call history integration.
- `onEvent` emits `ACTION_CALL_INCOMING`, `ACTION_CALL_START`,
  `ACTION_CALL_ACCEPT` / `ACTION_CALL_DECLINE` (depending on whether the call
  was answered), `ACTION_CALL_CONNECTED`, `ACTION_CALL_ENDED`,
  `ACTION_CALL_TOGGLE_MUTE` and `ACTION_CALL_TOGGLE_HOLD`.
- If the delegate emits a `click` action for a ringing call, the plugin
  re-emits `ACTION_CALL_INCOMING` so the app can bring its own call UI to the
  front. Accept/decline/end actions emitted by the delegate are mapped to the
  regular plugin events (see the delegate section below).
- `onBackgroundMessage`, `acceptCallHandle`, `invokeFlutter` and
  `getDevicePushTokenVoIP` are mobile-only; on desktop they are no-ops (the
  token getter returns `null`).
- `requestNotificationPermission` is a no-op that returns `true` (the
  delegate owns the permission flow); `requestFullIntentPermission` and
  `canUseFullScreenIntent` return `false` (Android-only).

> [!NOTE]
> Desktop does not provide ringing audio, vibration, audio-session handling or
> CallKit-style accept/decline notification buttons by itself. Use your app's
> own audio and UI layer; if your notification stack supports actions, return
> them through `CallkitNotificationDelegate.actions`.

> [!NOTE]
> The call registry and event stream are identical on all three desktop
> platforms. Build and smoke-test Windows and Linux on their own operating
> systems; a macOS host cannot compile or run those desktop targets.

### 3. Usage

#### Import
```dart
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
```

#### Show Incoming Call
```dart
this._currentUuid = _uuid.v4();
CallKitParams callKitParams = CallKitParams(
  id: _currentUuid,
  nameCaller: 'Hien Nguyen',
  appName: 'Callkit',
  avatar: 'https://i.pravatar.cc/100',
  handle: '0123456789',
  type: 0,
  textAccept: 'Accept',
  textDecline: 'Decline',
  missedCallNotification: NotificationParams(
    showNotification: true,
    isShowCallback: true,
    subtitle: 'Missed call',
    callbackText: 'Call back',
  ),
  callingNotification: const NotificationParams(
    showNotification: true,
    isShowCallback: true,
    subtitle: 'Calling...',
    callbackText: 'Hang Up',
  ),
  duration: 30000,
  extra: <String, dynamic>{'userId': '1a2b3c4d'},
  headers: <String, dynamic>{'apiKey': 'Abc@123!', 'platform': 'flutter'},
  android: const AndroidParams(
    isCustomNotification: true,
    isShowLogo: false,
    logoUrl: 'https://i.pravatar.cc/100',
    ringtonePath: 'system_ringtone_default',
    backgroundColor: '#0955fa',
    backgroundUrl: 'https://i.pravatar.cc/500',
    actionColor: '#4CAF50',
    textColor: '#ffffff',
    incomingCallNotificationChannelName: "Incoming Call",
    missedCallNotificationChannelName: "Missed Call",
    isShowCallID: false
  ),
  ios: IOSParams(
    iconName: 'CallKitLogo',
    handleType: 'generic',
    supportsVideo: true,
    maximumCallGroups: 2,
    maximumCallsPerCallGroup: 1,
    audioSessionMode: 'default',
    audioSessionActive: true,
    audioSessionPreferredSampleRate: 44100.0,
    audioSessionPreferredIOBufferDuration: 0.005,
    supportsDTMF: true,
    supportsHolding: true,
    supportsGrouping: false,
    supportsUngrouping: false,
    ringtonePath: 'system_ringtone_default',
  ),
);
await FlutterCallkitIncoming.showCallkitIncoming(callKitParams);
```

> **Note:** For Firebase Message: `@pragma('vm:entry-point')`  
> https://github.com/firebase/flutterfire/blob/master/docs/cloud-messaging/receive.md#apple-platforms-and-android

#### Request Notification Permission (Android 13+/iOS)

For Android 13+, please `requestNotificationPermission` or requestPermission of firebase_messaging before `showCallkitIncoming`:

```dart
await FlutterCallkitIncoming.requestNotificationPermission({
  "title": "Notification permission",
  "rationaleMessagePermission": "Notification permission is required, to show notification.",
  "postNotificationMessageRequired": "Notification permission is required, Please allow notification permission from setting."
});
```

#### Request Full Intent Permission (Android 14+)

For Android 14+, please use `canUseFullScreenIntent` and `requestFullIntentPermission`:

```dart
// Check if can use full screen intent
await FlutterCallkitIncoming.canUseFullScreenIntent();

// Request full intent permission
await FlutterCallkitIncoming.requestFullIntentPermission();
```

#### Show Missed Call Notification
```dart
this._currentUuid = _uuid.v4();
CallKitParams params = CallKitParams(
  id: _currentUuid,
  nameCaller: 'Hien Nguyen',
  handle: '0123456789',
  type: 1,
  missedCallNotification: const NotificationParams(
    showNotification: true,
    isShowCallback: true,
    subtitle: 'Missed call',
    callbackText: 'Call back',
  ),
  android: const AndroidParams(
    isCustomNotification: true,
    isShowCallID: true,
  ),
  extra: <String, dynamic>{'userId': '1a2b3c4d'},
);
await FlutterCallkitIncoming.showMissCallNotification(params);
```

#### Hide Call Notification (Android)
```dart
CallKitParams params = CallKitParams(
  id: _currentUuid,
);
await FlutterCallkitIncoming.hideCallkitIncoming(params);
```

#### Start Outgoing Call
```dart
this._currentUuid = _uuid.v4();
CallKitParams params = CallKitParams(
  id: this._currentUuid,
  nameCaller: 'Hien Nguyen',
  handle: '0123456789',
  type: 1,
  extra: <String, dynamic>{'userId': '1a2b3c4d'},
  ios: IOSParams(handleType: 'generic'),
  callingNotification: const NotificationParams(
    showNotification: true,
    isShowCallback: true,
    subtitle: 'Calling...',
    callbackText: 'Hang Up',
  ),
  android: const AndroidParams(
    isCustomNotification: true,
    isShowCallID: true,
  )
);
await FlutterCallkitIncoming.startCall(params);
```

#### End Call
```dart
// End specific call
await FlutterCallkitIncoming.endCall(this._currentUuid);

// End all calls
await FlutterCallkitIncoming.endAllCalls();
```

#### Get Active Calls

iOS: returns active calls from Callkit (only id), Android: only returns last call

```dart
await FlutterCallkitIncoming.activeCalls();
```

**Output:**
```json
[{"id": "8BAA2B26-47AD-42C1-9197-1D75F662DF78", ...}]
```

#### Set Call Connected

Used to determine Incoming Call or Outgoing Call status in phone book(reset/start timer):

```dart
await FlutterCallkitIncoming.setCallConnected(this._currentUuid);
```

> **Note:** After the call is ACCEPT or startCall, please call this function. Normally it should be called when WebRTC/P2P is established.

#### Get Device Push Token VoIP

iOS: returns deviceToken, Android: returns none

```dart
await FlutterCallkitIncoming.getDevicePushTokenVoIP();
```

**Output:**
```
d6a77ca80c5f09f87f353cdd328ec8d7d34e92eb108d046c91906f27f54949cd
```

> **Important:** Make sure using `SwiftFlutterCallkitIncomingPlugin.sharedInstance?.setDevicePushTokenVoIP(deviceToken)` inside AppDelegate.swift ([Example](https://github.com/hiennguyen92/flutter_callkit_incoming/blob/master/example/ios/Runner/AppDelegate.swift))

```swift
func pushRegistry(_ registry: PKPushRegistry, didUpdate credentials: PKPushCredentials, for type: PKPushType) {
    print(credentials.token)
    let deviceToken = credentials.token.map { String(format: "%02x", $0) }.joined()
    // Save deviceToken to your server
    SwiftFlutterCallkitIncomingPlugin.sharedInstance?.setDevicePushTokenVoIP(deviceToken)
}

func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType) {
    print("didInvalidatePushTokenFor")
    SwiftFlutterCallkitIncomingPlugin.sharedInstance?.setDevicePushTokenVoIP("")
}
```

#### Listen Events
```dart
FlutterCallkitIncoming.onEvent.listen((CallEvent event) {
  switch (event!.event) {
    case Event.actionCallIncoming:
      // TODO: received an incoming call
      break;
    case Event.actionCallStart:
      // TODO: started an outgoing call
      // TODO: show screen calling in Flutter
      break;
    case Event.actionCallAccept:
      // TODO: accepted an incoming call
      // TODO: show screen calling in Flutter
      break;
    case Event.actionCallDecline:
      // TODO: declined an incoming call
      break;
    case Event.actionCallEnded:
      // TODO: ended an incoming/outgoing call
      break;
    case Event.actionCallTimeout:
      // TODO: missed an incoming call
      break;
    case Event.actionCallCallback:
      // TODO: click action `Call back` from missed call notification
      break;
    case Event.actionCallToggleHold:
      // TODO: only iOS
      break;
    case Event.actionCallToggleMute:
      // TODO: only iOS
      break;
    case Event.actionCallToggleDmtf:
      // TODO: only iOS
      break;
    case Event.actionCallToggleGroup:
      // TODO: only iOS
      break;
    case Event.actionCallToggleAudioSession:
      // TODO: only iOS
      break;
    case Event.actionDidUpdateDevicePushTokenVoip:
      // TODO: only iOS
      break;
    case Event.actionCallCustom:
      // TODO: for custom action
      break;
  }
});
```

#### Call from Native (iOS/Android)

**Swift (iOS):**
```swift
var info = [String: Any?]()
info["id"] = "44d915e1-5ff4-4bed-bf13-c423048ec97a"
info["nameCaller"] = "Hien Nguyen"
info["handle"] = "0123456789"
info["type"] = 1
// ... set more data
SwiftFlutterCallkitIncomingPlugin.sharedInstance?.showCallkitIncoming(flutter_callkit_incoming.Data(args: info), fromPushKit: true)

// Please make sure call `completion()` at the end of the pushRegistry(......, completion: @escaping () -> Void)
// or `DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { completion() }`
// if you don't call completion() in pushRegistry(......, completion: @escaping () -> Void), there may be app crash by system when receiving VoIP
```

**Kotlin (Android):**
```kotlin
FlutterCallkitIncomingPlugin.getInstance().showIncomingNotification(...)
```

**Alternative Swift approach:**
```swift
let data = flutter_callkit_incoming.Data(id: "44d915e1-5ff4-4bed-bf13-c423048ec97a", nameCaller: "Hien Nguyen", handle: "0123456789", type: 0)
data.nameCaller = "Johnny"
data.extra = ["user": "abc@123", "platform": "ios"]
// ... set more data
SwiftFlutterCallkitIncomingPlugin.sharedInstance?.showCallkitIncoming(data, fromPushKit: true)
```

**Objective-C:**
```objc
#if __has_include(<flutter_callkit_incoming/flutter_callkit_incoming-Swift.h>)
#import <flutter_callkit_incoming/flutter_callkit_incoming-Swift.h>
#else
#import "flutter_callkit_incoming-Swift.h"
#endif

Data * data = [[Data alloc]initWithId:@"44d915e1-5ff4-4bed-bf13-c423048ec97a" nameCaller:@"Hien Nguyen" handle:@"0123456789" type:1];
[data setNameCaller:@"Johnny"];
[data setExtra:@{ @"userId" : @"HelloXXXX", @"key2" : @"value2"}];
// ... set more data
[SwiftFlutterCallkitIncomingPlugin.sharedInstance showCallkitIncoming:data fromPushKit:YES];
```

**Send Custom Event from Native:**

**Swift:**
```swift
SwiftFlutterCallkitIncomingPlugin.sharedInstance?.sendEventCustom(body: ["customKey": "customValue"])
```

**Kotlin:**
```kotlin
FlutterCallkitIncomingPlugin.getInstance().sendEventCustom(body: Map<String, Any>)
```

#### Call API when Accept/Decline/End/Timeout
#### Setup for Missed call notification(iOS)

**AppDelegate.swift:**
```swift
@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate, PKPushRegistryDelegate, CallkitIncomingAppDelegate {
    
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)
        
        // Setup VOIP
        let mainQueue = DispatchQueue.main
        let voipRegistry: PKPushRegistry = PKPushRegistry(queue: mainQueue)
        voipRegistry.delegate = self
        voipRegistry.desiredPushTypes = [PKPushType.voIP]

        // Use if using WebRTC
        // RTCAudioSession.sharedInstance().useManualAudio = true
        // RTCAudioSession.sharedInstance().isAudioEnabled = false

        //Add for Missed call notification
        if #available(iOS 10.0, *) {
          UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
        }
        
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    // Add for Missed call notification(show notification when foreground)
    override func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler:
                                   @escaping (UNNotificationPresentationOptions) -> Void) {
        
        CallkitNotificationManager.shared.userNotificationCenter(center, willPresent: notification, withCompletionHandler: completionHandler)
    }
    
    // Add for Missed call notification(action when click callback in missed notification)
    override func userNotificationCenter(_ center: UNUserNotificationCenter,
                                         didReceive response: UNNotificationResponse,
                                         withCompletionHandler completionHandler: @escaping () -> Void) {
        if response.actionIdentifier == CallkitNotificationManager.CALLBACK_ACTION {
            let data = response.notification.request.content.userInfo as? [String: Any]
            SwiftFlutterCallkitIncomingPlugin.sharedInstance?.sendCallbackEvent(data)
        }
        completionHandler()
    }

    // Func Call API for Accept
    func onAccept(_ call: Call, _ action: CXAnswerCallAction) {
        let json = ["action": "ACCEPT", "data": call.data.toJSON()] as [String: Any]
        print("LOG: onAccept")
        self.performRequest(parameters: json) { result in
            switch result {
            case .success(let data):
                print("Received data: \(data)")
                // Make sure call action.fulfill() when you are done (connected WebRTC - Start counting seconds)
                action.fulfill()
            case .failure(let error):
                print("Error: \(error.localizedDescription)")
            }
        }
    }
    
    // Func Call API for Decline
    func onDecline(_ call: Call, _ action: CXEndCallAction) {
        let json = ["action": "DECLINE", "data": call.data.toJSON()] as [String: Any]
        print("LOG: onDecline")
        self.performRequest(parameters: json) { result in
            switch result {
            case .success(let data):
                print("Received data: \(data)")
                // Make sure call action.fulfill() when you are done
                action.fulfill()
            case .failure(let error):
                print("Error: \(error.localizedDescription)")
            }
        }
    }
    
    // Func Call API for End
    func onEnd(_ call: Call, _ action: CXEndCallAction) {
        let json = ["action": "END", "data": call.data.toJSON()] as [String: Any]
        print("LOG: onEnd")
        self.performRequest(parameters: json) { result in
            switch result {
            case .success(let data):
                print("Received data: \(data)")
                // Make sure call action.fulfill() when you are done
                action.fulfill()
            case .failure(let error):
                print("Error: \(error.localizedDescription)")
            }
        }
    }
    
    func onTimeOut(_ call: Call) {
        let json = ["action": "TIMEOUT", "data": call.data.toJSON()] as [String: Any]
        print("LOG: onTimeOut")
        self.performRequest(parameters: json) { result in
            switch result {
            case .success(let data):
                print("Received data: \(data)")
            case .failure(let error):
                print("Error: \(error.localizedDescription)")
            }
        }
    }

    func didActivateAudioSession(_ audioSession: AVAudioSession) {
        // Use if using WebRTC
        // RTCAudioSession.sharedInstance().audioSessionDidActivate(audioSession)
        // RTCAudioSession.sharedInstance().isAudioEnabled = true
    }
    
    func didDeactivateAudioSession(_ audioSession: AVAudioSession) {
        // Use if using WebRTC
        // RTCAudioSession.sharedInstance().audioSessionDidDeactivate(audioSession)
        // RTCAudioSession.sharedInstance().isAudioEnabled = false
    }
}
```

> **Please check full example:** [Example](https://github.com/hiennguyen92/flutter_callkit_incoming/blob/master/example/ios/Runner/AppDelegate.swift)
**Create MMainApplication.kt in your source directory **

**MainApplication.kt:**
```kotlin
import android.app.Application
import android.os.Bundle
import android.content.Context
import android.content.Intent
import android.util.Log
import com.hiennv.flutter_callkit_incoming.CallkitEventCallback
import com.hiennv.flutter_callkit_incoming.FlutterCallkitIncomingPlugin
import io.flutter.embedding.android.FlutterActivity
import org.json.JSONObject
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL

private const val BASE_URL = "https://your-url/"
private const val TAG = "com.medeet.app.MainApplication"


class MainApplication : Application() {  // or FlutterApplication


  private var callkitEventCallback = object: CallkitEventCallback{
    override fun onCallEvent(event: CallkitEventCallback.CallEvent, callData: Bundle) {
      when (event) {
        CallkitEventCallback.CallEvent.ACCEPT -> {
          // Save accepted call id to SharedPreferences
          Log.d(TAG, "onAccept - Kotlin")

        }
        CallkitEventCallback.CallEvent.DECLINE -> {
          Log.d(TAG, "on Decline - Kotlin")
          val extra = callData.getSerializable("EXTRA_CALLKIT_EXTRA") as? HashMap<String, Any?>
          Log.d(TAG, "on Decline - $extra")
          sendDeclineCall(extra)
        }
        else -> {
          // Handle other cases or do nothing
        }
      }

    }
  }

  //Replace with your custom integration
  private fun sendDeclineCall(extra: HashMap<String, Any?>?) {
    // Read access token from SharedPreferences
    val prefs = applicationContext.getSharedPreferences(
      "FlutterSharedPreferences", Context.MODE_PRIVATE
    )
    val accessToken = prefs.getString("flutter.native_access_token", null)

    if (accessToken.isNullOrEmpty()) {
      Log.d(TAG, "declineCall - No access token found")
      return
    }
    val jsonBody = JSONObject((extra ?: emptyMap<String, Any?>()) as Map<*, *>)


    Log.d(TAG, "declineCall - body: $jsonBody")

    // Send request on background thread
    Thread {
      try {
        val url = URL("$BASE_URL/declineCall")
        val connection = url.openConnection() as HttpURLConnection
        connection.requestMethod = "POST"
        connection.setRequestProperty("Content-Type", "application/json")
        connection.setRequestProperty("Accept", "application/json")
        connection.setRequestProperty("Authorization", "Bearer $accessToken")
        connection.doOutput = true

        val writer = OutputStreamWriter(connection.outputStream)
        writer.write(jsonBody.toString())
        writer.flush()
        writer.close()
        val responseCode = connection.responseCode
        Log.d(TAG, "declineCall - Response status: $responseCode")
        connection.disconnect()
      } catch (e: Exception) {
        Log.e(TAG, "declineCall - Request error: ${e.message}")
      }
    }.start()
  }

  override fun onCreate() {
    super.onCreate()
    FlutterCallkitIncomingPlugin.registerEventCallback(callkitEventCallback)

  }
}
```
***Add this to your app level build file***
```
   defaultConfig {
     
      ......
        //Replace with your package name e.g "com.example.app.MainApplication"
        manifestPlaceholders["applicationName"] = "com.example.flutter_callkit_incoming_example.MainApplication"

    }
```

***Point ${applicationName} at your new class in Android manifest***
```
 <application
        ....
        android:name="${applicationName}"
         <activity
        

```
> **Please check full example:** [Example](https://github.com/hiennguyen92/flutter_callkit_incoming/blob/master/example/android/app/src/main/kotlin/com/example/flutter_callkit_incoming_example/MainActivity.kt
)

## 🔔 Call notification delegate (desktop and web)

On macOS, Windows, Linux and the web the plugin does not ship its own
notification stack. It forwards call notification presentation to the host
application through `CallkitNotificationDelegate`, which is exported from
`package:flutter_callkit_incoming/flutter_callkit_incoming.dart`.

Install a delegate before the first call:

```dart
import 'dart:async';

import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';

class MyCallNotificationDelegate implements CallkitNotificationDelegate {
  final StreamController<CallkitNotificationAction> _actions =
      StreamController<CallkitNotificationAction>.broadcast();

  @override
  Stream<CallkitNotificationAction> get actions => _actions.stream;

  @override
  Future<void> showIncoming(CallkitNotificationCall call) async {
    // Show a ringing notification for call.callId. Use call.callerName,
    // call.handle, call.appName, call.isVideo and call.extra.
  }

  @override
  Future<void> showMissed(CallkitNotificationCall call) async {
    // Show a missed-call notification (optional; a host may ignore it).
  }

  @override
  Future<void> cancel(String callId) async {
    // Remove the notification for callId. Must be a no-op when absent.
  }

  @override
  Future<void> cancelAll() async {
    // Remove every call notification created by the delegate.
  }

  void accept(String callId) {
    _actions.add(CallkitNotificationAction(
      callId: callId,
      type: CallkitNotificationActionType.accept,
    ));
  }
}

void main() {
  FlutterCallkitIncoming.setNotificationDelegate(
    MyCallNotificationDelegate(),
  );
}
```

### Delegate contract

| Member | When the plugin calls it |
|--------|--------------------------|
| `showIncoming(CallkitNotificationCall call)` | `showCallkitIncoming` on desktop/web. Should show (or replace) a ringing notification identified by `call.callId`. |
| `showMissed(CallkitNotificationCall call)` | `showMissCallNotification` on desktop/web. A host may ignore missed-call notifications. |
| `cancel(String callId)` | `hideCallkitIncoming`, `endCall`, `setCallConnected` and internal cleanup. Must be a no-op when no notification exists. |
| `cancelAll()` | `endAllCalls` and engine shutdown on desktop/web. |
| `actions` | Listened to by the plugin as soon as the delegate is installed. Return a **broadcast** stream. |

`CallkitNotificationCall` contains:

| Field | Description |
|-------|-------------|
| `callId` | Stable call identifier; use it as the notification identifier so repeated shows replace each other. |
| `callerName` | Caller name, falling back to the handle/app name and then `Incoming call`. |
| `handle` | Phone number, e-mail or other handle, when available. |
| `appName` | Application name; falls back to `CallkitNotificationCall.defaultAppName`. |
| `isVideo` | `true` for a video call (`CallKitParams.type == 1`). |
| `extra` | The call's `CallKitParams.extra` map (empty when not set). |

The delegate owns notification channels, permission requests and the actual
system UI. `FlutterCallkitIncoming.requestNotificationPermission()` is a no-op
returning `true` on desktop/web.

### Delegate actions

Emit `CallkitNotificationAction` values from the `actions` stream when the
user interacts with a notification. The plugin maps them to the same events as
the native implementations:

| Action | Plugin event |
|--------|--------------|
| `CallkitNotificationActionType.accept` | `ACTION_CALL_ACCEPT`; the call is marked accepted and its notification is cancelled. |
| `CallkitNotificationActionType.decline` | `ACTION_CALL_DECLINE`; the ringing call is removed. |
| `CallkitNotificationActionType.end` | `ACTION_CALL_ENDED` for accepted/outgoing calls; `ACTION_CALL_DECLINE` for calls that are still ringing. |
| `CallkitNotificationActionType.click` | `ACTION_CALL_INCOMING` while the call is ringing, so the app can show its own call UI. On the web, clicking a missed-call notification emits `ACTION_CALL_CALLBACK`. |

### Managing the delegate

```dart
FlutterCallkitIncoming.setNotificationDelegate(delegate); // install / replace
final current = FlutterCallkitIncoming.notificationDelegate; // read
final same = FlutterCallkitIncoming.getNotificationDelegate(); // read (method form)
FlutterCallkitIncoming.clearNotificationDelegate(); // remove
```

### Limitations

- The delegate is only used on macOS, Windows, Linux and the web. Android and
  iOS keep using their native notification implementations.
- **Without a delegate no OS notification is shown.** Call state, ring
  timeouts and the event stream keep working; the first skipped notification
  operation logs a clear warning.
- The plugin does not request notification permissions, create channels or
  keep a notification registry of its own.
- Exceptions thrown by the delegate (including its `actions` stream) are
  caught and logged; they never break the call state machine.
- The web delegate is subject to browser rules: serve the page from a secure
  context, request permission from a user gesture and keep the page open for
  notifications to render.

## 🌐 Web (including WASM)

The plugin includes a Flutter web implementation that keeps the same public
Dart API and compiles for both `flutter build web` and
`flutter build web --wasm`.

The web implementation is a browser approximation of the native plugins. It
tracks calls in memory; call notification presentation is delegated to the
host application (see
[Call notification delegate](#-call-notification-delegate-desktop-and-web)).
It is **not** CallKit/ConnectionService and cannot ring in the background.

### Behaviour

| Public API | Web behaviour |
|------------|----------------|
| `showCallkitIncoming` | Tracks the call, emits `ACTION_CALL_INCOMING` and calls `CallkitNotificationDelegate.showIncoming`. |
| `startCall` | Tracks the outgoing call and emits `ACTION_CALL_START`. No notification is shown. |
| `hideCallkitIncoming` | Cancels the notification, forgets the call and emits `ACTION_CALL_ENDED` (same as the Android implementation). |
| `endCall` | Emits `ACTION_CALL_ENDED` for accepted calls and `ACTION_CALL_DECLINE` for ringing calls, then cancels the notification. |
| `endAllCalls` | Ends every tracked call and calls `CallkitNotificationDelegate.cancelAll`. |
| `activeCalls` | Returns the in-memory calls (the list is empty after a page reload). |
| `muteCall`, `holdCall`, `isMuted`, `setCallConnected` | Update the in-memory state and emit `ACTION_CALL_TOGGLE_MUTE`, `ACTION_CALL_TOGGLE_HOLD` and `ACTION_CALL_CONNECTED`. |
| `onEvent` | Same stream and `CallEvent` types as on the native platforms. Delegate actions are translated into these events. |
| `requestNotificationPermission` | No-op that returns `true`; notification permission belongs to the host delegate. |
| `silenceEvents`, `unsilenceEvents` | Stop and restart event emission. |
| `getDevicePushTokenVoIP`, `requestFullIntentPermission`, `canUseFullScreenIntent`, background handlers | Not applicable on the web (null/false/no-op). |

Notification interaction when the installed delegate emits actions:

- `accept` accepts the call and emits `ACTION_CALL_ACCEPT`.
- `decline` declines the call and emits `ACTION_CALL_DECLINE`. A notification
  dismissal is the delegate's decision: return `decline` from the dismissal
  handler if that is the desired behaviour.
- `click` on a ringing call re-emits `ACTION_CALL_INCOMING` (it no longer
  accepts the call implicitly); on a missed-call notification it emits
  `ACTION_CALL_CALLBACK`.
- Ring timeout (`CallKitParams.duration`, 30 000 ms by default) removes the call
  and emits `ACTION_CALL_TIMEOUT`.

### Usage

Install a notification delegate once, then show calls exactly like on the
native platforms:

```dart
FlutterCallkitIncoming.setNotificationDelegate(MyCallNotificationDelegate());

FlutterCallkitIncoming.onEvent.listen((event) {
  // ACTION_CALL_INCOMING, ACTION_CALL_ACCEPT, ACTION_CALL_DECLINE, ...
});

await FlutterCallkitIncoming.showCallkitIncoming(
  const CallKitParams(
    id: 'call-1',
    nameCaller: 'Alice',
    handle: 'alice@example.com',
    type: 0,
  ),
);
```

`FlutterCallkitIncomingWeb` only exposes registration diagnostics:

```dart
import 'package:flutter_callkit_incoming/flutter_callkit_incoming_web.dart';

FlutterCallkitIncomingWeb.isRegistered;
```

### Requirements and limitations

- There is no built-in browser notification implementation any more. The host
  delegate must use the browser Notification API (or an in-app overlay) and
  handle its restrictions: secure context, permission from a user gesture and
  the page staying open.
- Without a delegate the call state machine and event stream still work, but
  no system notification appears (headless fallback).
- Notifications only exist while the page is open. There is no service worker
  integration, so the plugin cannot wake a closed tab, ring in the background
  or survive a page reload.
- Notification action buttons depend on the delegate and on what the browser
  supports; the plugin only reacts to the `CallkitNotificationAction` values
  the delegate emits.
- No native CallKit UI, audio focus, ringtone or system phone-app integration.
- Call state is per page load and is not shared between tabs.
- Web push is not implemented. Deliver the call with your own transport (for
  example FCM for web) and call `showCallkitIncoming` when a message arrives.

## 🔔 Host-owned call notifications with flutter_local_notifications

The plugin does not depend on a notification package. The example ships a
production-oriented adapter,
[flutter_local_notifications_callkit_delegate.dart](example/lib/notifications/flutter_local_notifications_callkit_delegate.dart),
that implements `CallkitNotificationDelegate` with
[`flutter_local_notifications`](https://pub.dev/packages/flutter_local_notifications)
23.x. It is application code: copy it into your app (or a shared package) and
add the dependency to **your app**, not to `flutter_callkit_incoming`.

### Setup

Add the dependency to the application `pubspec.yaml`:

```yaml
dependencies:
  flutter_local_notifications: ^23.0.3
  # Any Flutter app that uses a web plugin needs this SDK dependency;
  # flutter_local_notifications_web itself does not declare it.
  flutter_web_plugins:
    sdk: flutter
```

Create and initialize the delegate, request permission from a user gesture,
and listen to the actions it reports:

```dart
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';

// Copy the adapter from example/lib/notifications/ into your app.
import 'notifications/flutter_local_notifications_callkit_delegate.dart';

final delegate = FlutterLocalNotificationsCallkitDelegate(
  appName: 'My app',
  windowsAppUserModelId: 'com.example.myapp',
  windowsGuid: 'a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d',
);

await delegate.initialize();          // never prompts by itself
await delegate.requestPermissions();  // call from a user gesture

// Once the host hook is available (the example is self-contained until then):
// FlutterCallkitIncoming.setNotificationDelegate(delegate);

delegate.actions.listen((action) async {
  switch (action.type) {
    case CallkitNotificationActionType.accept:
      await FlutterCallkitIncoming.setCallConnected(action.callId);
    case CallkitNotificationActionType.decline:
    case CallkitNotificationActionType.end:
      await FlutterCallkitIncoming.endCall(action.callId);
    case CallkitNotificationActionType.click:
      // Bring the app / call screen to the front.
      break;
  }
});

await delegate.showIncoming(
  const CallkitNotificationCall(
    callId: 'call-1',
    callerName: 'Alice',
    handle: 'alice@example.com',
  ),
);
```

`initialize()` builds `AndroidInitializationSettings`,
`DarwinInitializationSettings` (iOS/macOS),
`LinuxInitializationSettings`, `WindowsInitializationSettings` and
`WebInitializationSettings`. It does not request permissions. The delegate
implements `showIncoming`, `showMissed`, `cancel` and `cancelAll` from the
contract, puts `callId` and the action into the notification payload, and maps
notification taps, accept, decline, end and dismissal back to `actions`.

### Platform notes

| Platform | Initialization | Permission helper | Actions |
|----------|----------------|-------------------|---------|
| Android | `AndroidInitializationSettings` | `POST_NOTIFICATIONS` on API 33+; `requestFullScreenIntentPermission()` for Android 14+ | Accept/decline actions; the native CallKit-style screen remains the default on mobile. |
| iOS | `DarwinInitializationSettings` | Alert, badge and sound permissions | Notification category with Accept/Decline; categories are cached per install. |
| macOS | `DarwinInitializationSettings` | Alert, badge and sound permissions | Notification category with Accept/Decline. |
| Linux | `LinuxInitializationSettings` | No runtime prompt | Freedesktop actions where the notification daemon supports them; critical urgency for ringing calls. |
| Windows | `WindowsInitializationSettings` | No runtime prompt | `incomingCall` toast scenario with Accept/Decline buttons; requires a stable AppUserModelID and activation GUID. |
| Web | `WebInitializationSettings` | `requestNotificationsPermission()` from a user gesture | Actions in Chromium-based browsers; Firefox/Safari ignore them. |

- **Web**: the page must be served from HTTPS or localhost. The plugin
  registers a service worker from
  `assets/packages/flutter_local_notifications_web/web/notifications_service_worker.js`,
  so keep the web build's asset bundling enabled. Both JavaScript and
  `--wasm` builds are supported. Call `requestPermissions()` from a click
  handler; browsers may reject prompts that are not tied to a user gesture.
- **iOS/macOS**: the notification category actions are installed once per app
  install. If you change the labels or the action set, bump
  `notificationCategoryId` (the adapter defaults to
  `callkit_incoming_call_v1`) or users will keep the old actions until the
  app is reinstalled.
- **Android**: notification channels are immutable after creation. Changing
  importance, sound or vibration requires a new channel id. Full-screen
  incoming-call notifications also need `USE_FULL_SCREEN_INTENT` on Android
  14+; the example keeps using the plugin's native call screen on mobile.
- **Windows**: toast activation is registered through the AppUserModelID and
  GUID passed to the delegate. Use values that belong to your app and keep the
  GUID stable across releases. The adapter encodes the action into each
  button's arguments because Windows activation does not expose the action id
  separately.
- **Linux**: requires a running notification daemon (libnotify/D-Bus). Action
  support depends on the daemon; servers that do not support actions still
  show the notification and report a body click as `click`.
- `cancel(callId)` removes that call's notification. `cancelAll()` only
  removes notifications carrying this adapter's payload; it does not call
  `FlutterLocalNotificationsPlugin.cancelAll()` and therefore leaves unrelated
  app notifications alone. After a process restart the adapter rediscovers
  active call notifications from their payload on platforms that implement
  `getActiveNotifications()`; Linux does not, so cancel ringing calls before
  the process exits there.

See
[notifications_demo_page.dart](example/lib/notifications/notifications_demo_page.dart)
for a self-contained demo (permission request, incoming/video/missed calls,
cancel and action logging).

## 📋 Properties

### Main Properties

| Property | Description | Default |
|----------|-------------|---------|
| **`id`** | UUID identifier for each call. UUID should be unique for every call and when the call is ended, the same UUID for that call to be used. Suggest using [uuid](https://pub.dev/packages/uuid). ACCEPT ONLY UUID | Required |
| **`nameCaller`** | Caller's name | _None_ |
| **`appName`** | App's name. Used for display inside Callkit (iOS). | App Name, `Deprecated for iOS > 14, default using App name` |
| **`avatar`** | Avatar's URL used for display for Android. `/android/src/main/res/drawable-xxxhdpi/ic_default_avatar.png` | _None_ |
| **`handle`** | Phone number/Email/Any | _None_ |
| **`type`** | 0 - Audio Call, 1 - Video Call | `0` |
| **`duration`** | Incoming call/Outgoing call display time (second). If the time is over, the call will be missed | `30000` |
| **`textAccept`** | Text `Accept` used in Android | `Accept` |
| **`textDecline`** | Text `Decline` used in Android | `Decline` |
| **`extra`** | Any data added to the event when received | `{}` |
| **`headers`** | Any data for custom header avatar/background image | `{}` |
| **`missedCallNotification`** | Android data needed to customize Missed Call Notification | Below |
| **`callingNotification`** | Android data needed to customize Calling Notification | Below |
| **`android`** | Android data needed to customize UI | Below |
| **`ios`** | iOS data needed | Below |

### Missed Call Notification

| Property | Description | Default |
|----------|-------------|---------|
| **`subtitle`** | Text `Missed Call` used in Android/iOS (show in missed call notification) | `Missed Call` |
| **`callbackText`** | Text `Call back` used in Android/iOS (show in missed call notification action) | `Call back` |
| **`showNotification`** | Show missed call notification when timeout | `true` |
| **`isShowCallback`** | Show callback action from missed call notification | `true` |

### Calling Notification

| Property | Description | Default |
|----------|-------------|---------|
| **`subtitle`** | Text used in Android (show in calling notification) | `Calling...` |
| **`callbackText`** | Text used in Android (show in calling notification action) | `Hang Up` |
| **`showNotification`** | Show calling notification when start call/accept call | `true` |
| **`isShowCallback`** | Show hang up action from calling notification | `true` |

### Android

| Property | Description | Default |
|----------|-------------|---------|
| **`isCustomNotification`** | Using custom notifications | `false` |
| **`isCustomSmallExNotification`** | Using custom notification small on some devices clipped out in Android | `false` |
| **`isShowLogo`** | Show logo app inside full screen. `/android/src/main/res/drawable-xxxhdpi/ic_logo.png` | `false` |
| **`logoUrl`** | Logo app inside full screen. Example: http://... https://... or "assets/abc.png" | _None_ |
| **`ringtonePath`** | File name of a ringtone ex: `ringtone_default`. Put file into `/android/app/src/main/res/raw/ringtone_default.mp3` | `system_ringtone_default` <br>using ringtone default of the phone |
| **`backgroundColor`** | Incoming call screen background color | `#0955fa` |
| **`backgroundUrl`** | Using image background for Incoming call screen. Example: http://... https://... or "assets/abc.png" | _None_ |
| **`actionColor`** | Color used in button/text on notification | `#4CAF50` |
| **`textColor`** | Color used for the text in full screen notification | `#ffffff` |
| **`incomingCallNotificationChannelName`** | Notification channel name of incoming call | `Incoming call` |
| **`missedCallNotificationChannelName`** | Notification channel name of missed call | `Missed call` |
| **`isShowCallID`** | Show call id app inside full screen/notification | `false` |
| **`isShowFullLockedScreen`** | Show full screen on Locked Screen (please make sure call `requestFullIntentPermission` for Android 14+) | `true` |

### iOS

| Property | Description | Default |
|----------|-------------|---------|
| **`iconName`** | App's Icon. Used for display inside Callkit (iOS) | `CallKitLogo` <br> using from `Images.xcassets/CallKitLogo` |
| **`handleType`** | Type handle call `generic`, `number`, `email`, Recommended to use `generic` for more reasonable callkit display | `generic` |
| **`supportsVideo`** | | `true` |
| **`maximumCallGroups`** | | `2` |
| **`maximumCallsPerCallGroup`** | | `1` |
| **`audioSessionMode`** | | _None_, `gameChat`, `measurement`, `moviePlayback`, `spokenAudio`, `videoChat`, `videoRecording`, `voiceChat`, `voicePrompt` |
| **`audioSessionActive`** | | `true` |
| **`audioSessionPreferredSampleRate`** | | `44100.0` |
| **`audioSessionPreferredIOBufferDuration`** | | `0.005` |
| **`supportsDTMF`** | | `true` |
| **`supportsHolding`** | | `true` |
| **`supportsGrouping`** | | `true` |
| **`supportsUngrouping`** | | `true` |
| **`ringtonePath`** | Add file to root project xcode `/ios/Runner/Ringtone.caf` and Copy Bundle Resources (Build Phases) | `Ringtone.caf`<br>`system_ringtone_default` <br>using ringtone default of the phone |

## 📁 Source Code

Please checkout repo GitHub:
- [https://github.com/hiennguyen92/flutter_callkit_incoming](https://github.com/hiennguyen92/flutter_callkit_incoming)
- [Example](https://github.com/hiennguyen92/flutter_callkit_incoming/blob/master/example/lib/main.dart)

## 📱 Pushkit - Received VoIP and Wake App from Terminated State (iOS Only)

Please check [PUSHKIT.md](https://github.com/hiennguyen92/flutter_callkit_incoming/blob/master/PUSHKIT.md) for setup Pushkit for iOS.

## 📋 Todo

- [X] Run background / background execution support (implemented via self-managed Telecom service & didActivate background replay cache)
- [X] Swift Package Manager (SPM) support
- [ ] Simplify the setup process
- [X] Custom notification for iOS (Missing notification)
- [X] Keep notification when calling

## 🎯 Demo

### Demo Illustration

### Images

<table>
  <tr>
    <td><strong>iOS (Lockscreen)</strong></td>
    <td><strong>iOS (Full Screen)</strong></td>
    <td><strong>iOS (Alert)</strong></td>
  </tr>
  <tr>
    <td>
      <img src="https://raw.githubusercontent.com/hiennguyen92/flutter_callkit_incoming/master/images/image1.png" width="220" alt="iOS Lockscreen">
    </td>
    <td>
      <img src="https://raw.githubusercontent.com/hiennguyen92/flutter_callkit_incoming/master/images/image2.png" width="220" alt="iOS Full Screen">
    </td>
    <td>
      <img src="https://raw.githubusercontent.com/hiennguyen92/flutter_callkit_incoming/master/images/image3.png" width="220" alt="iOS Alert">
    </td>
  </tr>
  <tr>
    <td><strong>Android (Lockscreen) - Audio</strong></td>
    <td><strong>Android (Alert) - Audio</strong></td>
    <td><strong>Android (Lockscreen) - Video</strong></td>
  </tr>
  <tr>
    <td>
      <img src="https://raw.githubusercontent.com/hiennguyen92/flutter_callkit_incoming/master/images/image4.jpg" width="220" alt="Android Lockscreen Audio">
    </td>
    <td>
      <img src="https://raw.githubusercontent.com/hiennguyen92/flutter_callkit_incoming/master/images/image5.jpg" width="220" alt="Android Alert Audio">
    </td>
    <td>
      <img src="https://raw.githubusercontent.com/hiennguyen92/flutter_callkit_incoming/master/images/image6.jpg" width="220" alt="Android Lockscreen Video">
    </td>
  </tr>
  <tr>
    <td><strong>Android (Alert) - Video</strong></td>
    <td><strong>isCustomNotification: false</strong></td>
    <td></td>
  </tr>
  <tr>
    <td>
      <img src="https://raw.githubusercontent.com/hiennguyen92/flutter_callkit_incoming/master/images/image7.jpg" width="220" alt="Android Alert Video">
    </td>
    <td>
      <img src="https://raw.githubusercontent.com/hiennguyen92/flutter_callkit_incoming/master/images/image8.jpg" width="220" alt="Custom Notification False">
    </td>
    <td></td>
  </tr>
</table> 