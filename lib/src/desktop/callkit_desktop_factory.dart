// Resolves the desktop backend without pulling `dart:io` into web builds.
export 'callkit_desktop_factory_stub.dart'
    if (dart.library.io) 'callkit_desktop_factory_io.dart';
