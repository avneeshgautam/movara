import 'dart:typed_data';

/// No-op fallback for non-web targets (and the test VM).
class ShareImage {
  const ShareImage();

  bool get isSupported => false;

  Future<bool> save(Uint8List pngBytes, String filename) async => false;

  Future<bool> saveToPhotos(Uint8List pngBytes, String filename) async => false;
}
