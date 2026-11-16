import 'dart:async';

Future<bool> downloadTextFile({
  required String filename,
  required String content,
}) async {
  throw UnsupportedError('Cannot download file on unsupported platform');
}

Future<String?> downloadBinaryFile({
  required String filename,
  required List<int> bytes,
}) async {
  throw UnsupportedError('Cannot download binary file on unsupported platform');
}
