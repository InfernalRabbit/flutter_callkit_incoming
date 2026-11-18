/// Placeholder implementation for platforms without `dart:io` (web).
///
/// The class exists only so that the name is always exported from
/// `package:flutter_callkit_incoming/flutter_callkit_incoming.dart`; the
/// generated desktop registrant never calls it on web.
class FlutterCallkitIncomingDesktop {
  const FlutterCallkitIncomingDesktop._();

  /// No-op: desktop platforms are not available on the web.
  static void registerWith() {}
}
