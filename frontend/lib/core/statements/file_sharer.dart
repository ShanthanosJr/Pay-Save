import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

/// Hands a file to the phone's share sheet (save, print, send to a bank).
typedef FileSharer = Future<void> Function(Uint8List bytes, {required String name, required String mimeType});

final fileSharerProvider = Provider<FileSharer>((ref) {
  return (bytes, {required name, required mimeType}) async {
    await SharePlus.instance.share(ShareParams(
      files: [XFile.fromData(bytes, name: name, mimeType: mimeType)],
      fileNameOverrides: [name],
    ));
  };
});
