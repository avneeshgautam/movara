// Browser notification access, behind a conditional import so the app still
// compiles (and tests still run) off the web.
export 'water_notifications_stub.dart'
    if (dart.library.js_interop) 'water_notifications_web.dart';
