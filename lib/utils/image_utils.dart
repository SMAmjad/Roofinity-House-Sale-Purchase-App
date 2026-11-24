import 'dart:io';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

int _tempCounter = 0;

/// Re-encodes [file] as a JPEG in the temp folder. Each call gets its own
/// file name, so parallel calls never overwrite each other.
Future<File> compressImage(File file, {int quality = 70}) async {
  final dir = await getTemporaryDirectory();
  final name = 'img_${DateTime.now().microsecondsSinceEpoch}_${_tempCounter++}.jpg';
  final targetPath = p.join(dir.path, name);

  final compressed = await FlutterImageCompress.compressAndGetFile(
    file.absolute.path,
    targetPath,
    quality: quality,
    format: CompressFormat.jpeg,
  );
  if (compressed == null) {
    throw FileSystemException('Could not compress image', file.path);
  }
  return File(compressed.path);
}

/// HEIC/HEIF photos (common on newer phones) cannot be read by the AI model,
/// so they are converted to high-quality JPEG first. Other files are returned
/// unchanged.
Future<File> ensureReadableImage(File file) async {
  final ext = p.extension(file.path).toLowerCase();
  if (ext == '.heic' || ext == '.heif') {
    return compressImage(file, quality: 95);
  }
  return file;
}
