// Saving the share card to a file is browser-specific, so the implementation
// is behind a conditional import and tests fall back to the stub.
export 'share_image_stub.dart'
    if (dart.library.js_interop) 'share_image_web.dart';
