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
- [🌐 Web (including WASM)](#-web-including-wasm)
- [📋 Properties](#-properties)
- [📱 Pushkit Setup](#-pushkit---received-voip-and-wake-app-from-terminated-state-ios-only)
- [🎯 Demo](#-demo)

## ⭐ Features

- Show an incoming call
- Start an outgoing call
- Custom UI Android/Callkit for iOS
- Example using Pushkit/VoIP for iOS
- macOS, Windows and Linux support (Dart-only; in-memory call registry plus OS notifications)
- Web support (browser notifications, JavaScript and WebAssembly targets)

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

Desktop support is implemented in Dart on top of
[`local_notifier`](https://pub.dev/packages/local_notifier). There is no
CallKit/ConnectionService equivalent outside Android and iOS, so the plugin
keeps calls in an in-memory registry and shows a best-effort OS notification
instead of a native call screen. The platform entries are declared in this
package with `dartPluginClass: FlutterCallkitIncomingDesktop`, so no extra
configuration or native code is required in the host app.

Platform notes:

- **macOS**: notifications use `NSUserNotification` (deprecated by Apple but
  still functional). Allow notifications for the app in System Settings >
  Notifications; the first notification can trigger the system permission
  prompt.
- **Windows**: toast notifications need an AppUserModelID backed by a Start
  Menu shortcut. The plugin asks `local_notifier` to create that shortcut on
  first use.
- **Linux**: requires `libnotify` (`sudo apt-get install libnotify-dev`) and
  a running notification daemon.

Desktop behaviour:

- `showCallkitIncoming` / `showMissCallNotification` register the call and
  show or replace its notification; `hideCallkitIncoming`, `endCall` and
  `endAllCalls` dismiss it.
- `activeCalls` returns the in-memory registry. It is empty after a restart:
  desktop calls are not persisted and there is no call history integration.
- `onEvent` emits `ACTION_CALL_INCOMING`, `ACTION_CALL_START`,
  `ACTION_CALL_ACCEPT` / `ACTION_CALL_DECLINE` (depending on whether the call
  was answered), `ACTION_CALL_CONNECTED`, `ACTION_CALL_ENDED`,
  `ACTION_CALL_TOGGLE_MUTE` and `ACTION_CALL_TOGGLE_HOLD`.
- Clicking a ringing notification re-emits `ACTION_CALL_INCOMING` so the app
  can bring its own call UI to the front. Notifications have no
  accept/decline buttons: the app must drive those actions from its own UI.
- `onBackgroundMessage`, `acceptCallHandle`, `invokeFlutter` and
  `getDevicePushTokenVoIP` are mobile-only; on desktop they are no-ops (the
  token getter returns `null`).
- `requestNotificationPermission` returns `true`;
  `requestFullIntentPermission` and `canUseFullScreenIntent` return `false`
  (Android-only).

> [!NOTE]
> Desktop does not provide ringing audio, vibration, audio-session handling or
> CallKit-style accept/decline actions. Use your app's own audio and UI layer,
> and treat the notification as advisory.

> [!NOTE]
> The call registry and event stream are identical on all three desktop
> platforms, but the notification layer is native per OS. Build and
> smoke-test Windows and Linux on their own operating systems; a macOS host
> cannot compile or run those desktop targets.

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

## 🌐 Web (including WASM)

The plugin includes a Flutter web implementation that keeps the same public
Dart API. It is written with `package:web` and `dart:js_interop` (no
`dart:html`), so both `flutter build web` and `flutter build web --wasm`
compile.

The web implementation is a browser approximation of the native plugins. It
tracks calls in memory and uses the browser Notification API; it is **not**
CallKit/ConnectionService and cannot ring in the background.

### Behaviour

| Public API | Web behaviour |
|------------|----------------|
| `showCallkitIncoming` | Tracks the call, emits `ACTION_CALL_INCOMING` and shows a browser notification (title = caller name, body = handle). |
| `startCall` | Tracks the outgoing call and emits `ACTION_CALL_START`. No notification is shown. |
| `hideCallkitIncoming` | Closes the notification, forgets the call and emits `ACTION_CALL_ENDED` (same as the Android implementation). |
| `endCall` | Emits `ACTION_CALL_ENDED` for accepted calls and `ACTION_CALL_DECLINE` for ringing calls. |
| `endAllCalls` | Ends every tracked call and closes all notifications. |
| `activeCalls` | Returns the in-memory calls (the list is empty after a page reload). |
| `muteCall`, `holdCall`, `isMuted`, `setCallConnected` | Update the in-memory state and emit `ACTION_CALL_TOGGLE_MUTE`, `ACTION_CALL_TOGGLE_HOLD` and `ACTION_CALL_CONNECTED`. |
| `onEvent` | Same stream and `CallEvent` types as on the native platforms. |
| `requestNotificationPermission` | Calls `Notification.requestPermission()` and returns whether notifications are granted. Call it from a user gesture. |
| `silenceEvents`, `unsilenceEvents` | Stop and restart event emission. |
| `getDevicePushTokenVoIP`, `requestFullIntentPermission`, `canUseFullScreenIntent`, background handlers | Not applicable on the web (null/false/no-op). |

Notification interaction:

- Clicking a call notification accepts the call and emits `ACTION_CALL_ACCEPT`.
- Dismissing a call notification declines the call and emits
  `ACTION_CALL_DECLINE`.
- Ring timeout (`CallKitParams.duration`, 30 000 ms by default) removes the call
  and emits `ACTION_CALL_TIMEOUT`.

### Usage

Ask for the notification permission once, from a user gesture, and then show
calls exactly like on the native platforms:

```dart
final granted = await FlutterCallkitIncoming
    .requestNotificationPermission(<String, dynamic>{});

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

The web plugin also exposes diagnostics that are useful in debug builds:

```dart
import 'package:flutter_callkit_incoming/flutter_callkit_incoming_web.dart';

FlutterCallkitIncomingWeb.isNotificationSupported;
FlutterCallkitIncomingWeb.isSecureContext;
FlutterCallkitIncomingWeb.notificationPermission; // granted/denied/default/unsupported
```

### Requirements and limitations

- The page must be served from a secure context (`https://` or
  `localhost`); browsers reject notifications on plain HTTP origins.
- Notification permission must be granted. If the Notification API is missing
  or the permission was denied, calls are still tracked and events are still
  emitted, but no system notification appears (headless fallback).
- Notifications only exist while the page is open. There is no service worker
  integration, so the plugin cannot wake a closed tab, ring in the background
  or survive a page reload.
- Notifications do not expose Accept/Decline buttons; the browser does not
  support `actions` portably for page notifications.
- No native CallKit UI, audio focus, ringtone or system phone-app integration.
- Call state is per page load and is not shared between tabs.
- Web push is not implemented. Deliver the call with your own transport (for
  example FCM for web) and call `showCallkitIncoming` when a message arrives.

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