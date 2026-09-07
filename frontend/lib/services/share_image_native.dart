import 'dart:io';
import 'dart:typed_data';

import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Hands the finished card to the system share sheet.
///
/// On iOS this is what "save" means: the sheet offers Save Image, Messages,
/// Instagram and the rest. Writing straight to the photo library instead
/// would need photo-library permission and would skip sharing entirely,
/// which is the main thing you would want to do with a run card.
class ShareImage {
  const ShareImage();

  bool get isSupported => true;

  Future<bool> save(Uint8List pngBytes, String filename) async {
    try {
      // The share sheet needs a real file, so stage it in the cache
      // directory. iOS clears that on its own, so there is nothing to tidy.
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$filename');
      await file.writeAsBytes(pngBytes, flush: true);

      final result = await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'image/png')],
          subject: 'My run on Movara',
        ),
      );
      // Dismissing the sheet is a deliberate choice, not a failure.
      return result.status != ShareResultStatus.unavailable;
    } catch (_) {
      return false;
    }
  }
  /// Writes the image straight into the system photo library. Needs
  /// NSPhotoLibraryAddUsageDescription in Info.plist; iOS shows the add-photo
  /// permission prompt on first use.
  Future<bool> saveToPhotos(Uint8List pngBytes, String filename) async {
    try {
      await Gal.putImageBytes(pngBytes, name: filename);
      return true;
    } on GalException {
      // Permission refused, or the library rejected the write.
      return false;
    } catch (_) {
      return false;
    }
  }
}