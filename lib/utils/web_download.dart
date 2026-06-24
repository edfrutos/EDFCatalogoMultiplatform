/// Descarga de archivos en Flutter Web mediante AnchorElement + Blob URL.
/// Importar con condicional:
///   import 'web_download_stub.dart'
///       if (dart.library.html) 'web_download.dart';
library;

import 'dart:convert' show utf8;
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

class WebDownload {
  /// Descarga bytes como archivo en el browser.
  static void downloadBytes(List<int> bytes, String fileName, String mimeType) {
    final blob = html.Blob([bytes], mimeType);
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download', fileName)
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  /// Descarga un String (CSV, JSON, etc.) como archivo.
  /// El String se codifica explícitamente a UTF-8 para que el Blob
  /// tenga la codificación correcta sin usar el parámetro 'endings'
  /// (que solo acepta 'transparent'/'native', no charset names).
  static void downloadString(String content, String fileName, String mimeType) {
    final bytes = utf8.encode(content);
    final blob = html.Blob([bytes], mimeType);
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download', fileName)
      ..click();
    html.Url.revokeObjectUrl(url);
  }
}
