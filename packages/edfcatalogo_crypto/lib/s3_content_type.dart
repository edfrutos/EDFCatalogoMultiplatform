/// MIME a partir del nombre de archivo (una tabla para app y API).
///
/// Si el cliente manda `application/octet-stream`, Chrome descarga PDFs
/// en vez de abrirlos en el visor: hay que inferir por extensión.
class S3ContentType {
  S3ContentType._();

  static const octetStream = 'application/octet-stream';

  static const Map<String, String> _byExtension = {
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'gif': 'image/gif',
    'webp': 'image/webp',
    'svg': 'image/svg+xml',
    'bmp': 'image/bmp',
    'heic': 'image/heic',
    'heif': 'image/heif',
    'pdf': 'application/pdf',
    'doc': 'application/msword',
    'docx':
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'xls': 'application/vnd.ms-excel',
    'xlsx':
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'ppt': 'application/vnd.ms-powerpoint',
    'pptx':
        'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'txt': 'text/plain',
    'md': 'text/markdown',
    'rtf': 'application/rtf',
    'csv': 'text/csv',
    'mp4': 'video/mp4',
    'mov': 'video/quicktime',
    'webm': 'video/webm',
    'avi': 'video/x-msvideo',
    'mp3': 'audio/mpeg',
    'wav': 'audio/wav',
    'ogg': 'audio/ogg',
    'aac': 'audio/aac',
  };

  /// `file.pdf`, `ruta/file.PDF` o `file.pdf?x=1` → `application/pdf`.
  static String fromFileName(String fileName) {
    final name = fileName.split('/').last.split('?').first;
    final i = name.lastIndexOf('.');
    if (i <= 0 || i == name.length - 1) return octetStream;
    final ext = name.substring(i + 1).toLowerCase();
    return _byExtension[ext] ?? octetStream;
  }

  /// Ausente, vacío o `application/octet-stream` (con o sin charset).
  static bool isGeneric(String? contentType) {
    if (contentType == null) return true;
    final mime = contentType.split(';').first.trim().toLowerCase();
    return mime.isEmpty || mime == octetStream;
  }
}
