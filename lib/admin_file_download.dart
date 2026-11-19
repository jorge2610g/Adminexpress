import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Descarga un archivo binario (por ejemplo, un PNG) desde el navegador.
void adminDownloadBytesFile(
  String fileName,
  Uint8List bytes, {
  String mimeType = 'application/octet-stream',
}) {
  final blob = web.Blob(
    <JSAny>[bytes.toJS].toJS,
    web.BlobPropertyBag(type: mimeType),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
  anchor.href = url;
  anchor.download = fileName;
  anchor.style.display = 'none';
  web.document.body?.appendChild(anchor);
  anchor.click();
  anchor.remove();
  web.URL.revokeObjectURL(url);
}

/// Comparte una imagen con el menú de compartir del teléfono o del navegador.
/// Devuelve false si el navegador no permite compartir archivos.
Future<bool> adminShareImage({
  required String fileName,
  required Uint8List bytes,
  required String title,
  required String text,
}) async {
  try {
    final file = web.File(
      <JSAny>[bytes.toJS].toJS,
      fileName,
      web.FilePropertyBag(type: 'image/png'),
    );
    final data = web.ShareData(
      files: <web.File>[file].toJS,
      title: title,
      text: text,
    );
    if (!web.window.navigator.canShare(data)) return false;
    await web.window.navigator.share(data).toDart;
    return true;
  } catch (_) {
    return false;
  }
}

/// Comparte solo el enlace. Devuelve false si el navegador no lo permite.
Future<bool> adminShareLink({
  required String title,
  required String url,
}) async {
  try {
    final data = web.ShareData(title: title, url: url);
    if (!web.window.navigator.canShare(data)) return false;
    await web.window.navigator.share(data).toDart;
    return true;
  } catch (_) {
    return false;
  }
}
