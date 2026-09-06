// Notifications differ per platform: the browser has its own API and cannot
// wake a closed tab, while iOS schedules them at the OS level. The stub keeps
// the analyzer and the test VM happy.
export 'water_notifications_stub.dart'
    if (dart.library.js_interop) 'water_notifications_web.dart'
    if (dart.library.io) 'water_notifications_native.dart';
