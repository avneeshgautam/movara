// Saving the share card is platform-specific: the browser downloads a file,
// while iOS hands it to the system share sheet. The stub keeps the analyzer
// happy on platforms with neither.
export 'share_image_stub.dart'
    if (dart.library.js_interop) 'share_image_web.dart'
    if (dart.library.io) 'share_image_native.dart';
