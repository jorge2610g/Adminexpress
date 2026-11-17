import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Descarga un archivo de texto desde el navegador. Solo funciona en la web del
/// panel, que es el único destino de Adminexpress.
void adminDownloadTextFile(
  String fileName,
  String content, {
  String mimeType = 'text/csv;charset=utf-8',
}) {
  final blob = web.Blob(
    <JSAny>[content.toJS].toJS,
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
