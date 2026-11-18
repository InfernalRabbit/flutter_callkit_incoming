import 'dart:async';

import 'package:flutter/services.dart';

import 'callkit_web_engine.dart';

/// Installs the platform side of the "flutter_callkit_incoming" channels used
/// by lib/flutter_callkit_incoming.dart.
///
/// The public Dart API of the plugin talks to two platform channels:
///
/// * the method channel "flutter_callkit_incoming";
/// * the event channel "flutter_callkit_incoming_events".
///
/// [CallkitWebChannelHost] answers those channels on top of an in-memory
/// [CallkitWebEngine]. It works with any [BinaryMessenger]; the web plugin
/// passes the Registrar provided by the Flutter tool (which implements
/// [BinaryMessenger]), while unit tests pass a fake messenger. Because both the
/// method channel handler and the event forwarding use the same abstraction,
/// the exact same code runs in the browser and in tests.
class CallkitWebChannelHost {
  /// Creates a host on top of [messenger].
  CallkitWebChannelHost({
    required BinaryMessenger messenger,
    CallkitWebEngine? engine,
    MethodCodec codec = const StandardMethodCodec(),
  })  : _messenger = messenger,
        _codec = codec,
        engine = engine ?? CallkitWebEngine();

  /// Name of the method channel used by the public Dart API.
  static const String methodChannelName = 'flutter_callkit_incoming';

  /// Name of the event channel used by the public Dart API.
  static const String eventChannelName = 'flutter_callkit_incoming_events';

  final BinaryMessenger _messenger;
  final MethodCodec _codec;

  /// The call state machine driven by this host.
  final CallkitWebEngine engine;

  bool _registered = false;
  MethodChannel? _methodChannel;
  StreamSubscription<Map<String, dynamic>>? _eventSubscription;

  /// Whether [register] already installed the channel handlers.
  bool get isRegistered => _registered;

  /// Installs the method channel and event channel handlers.
  ///
  /// Calling this method more than once is a no-op.
  void register() {
    if (_registered) {
      return;
    }
    _registered = true;
    _methodChannel = MethodChannel(methodChannelName, _codec, _messenger);
    _methodChannel!
        .setMethodCallHandler((MethodCall call) => engine.handleMethodCall(
              call.method,
              call.arguments,
            ));
    _messenger.setMessageHandler(eventChannelName, _handleEventChannelMessage);
  }

  /// Removes the handlers and disposes the engine.
  void dispose() {
    _stopEventForwarding();
    if (_registered) {
      _registered = false;
      _methodChannel?.setMethodCallHandler(null);
      _methodChannel = null;
      _messenger.setMessageHandler(eventChannelName, null);
    }
    engine.dispose();
  }

  Future<ByteData?>? _handleEventChannelMessage(ByteData? message) {
    if (message == null) {
      return null;
    }
    final MethodCall call = _codec.decodeMethodCall(message);
    switch (call.method) {
      case 'listen':
        _startEventForwarding();
        return Future<ByteData?>.value(_codec.encodeSuccessEnvelope(null));
      case 'cancel':
        _stopEventForwarding();
        return Future<ByteData?>.value(_codec.encodeSuccessEnvelope(null));
      default:
        return Future<ByteData?>.value(
          _codec.encodeErrorEnvelope(
            code: 'error',
            message: 'Unknown event channel method ${call.method}',
          ),
        );
    }
  }

  void _startEventForwarding() {
    _stopEventForwarding();
    _eventSubscription = engine.events.listen((Map<String, dynamic> event) {
      _messenger.send(eventChannelName, _codec.encodeSuccessEnvelope(event));
    });
  }

  void _stopEventForwarding() {
    final StreamSubscription<Map<String, dynamic>>? subscription =
        _eventSubscription;
    _eventSubscription = null;
    if (subscription != null) {
      unawaited(subscription.cancel());
    }
  }
}
