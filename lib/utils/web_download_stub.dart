/// Stub para plataformas no-web.
library;

class WebDownload {
  static void downloadBytes(List<int> bytes, String fileName, String mimeType) {
    throw UnsupportedError('WebDownload solo disponible en web');
  }

  static void downloadString(String content, String fileName, String mimeType) {
    throw UnsupportedError('WebDownload solo disponible en web');
  }
}
