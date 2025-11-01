/// Tipos de archivo soportados
enum FileType { image, document, text, multimedia, other }

/// Extensiones de archivos para cada tipo
class FileTypeExtensions {
  static const List<String> imageExtensions = [
    'jpg',
    'jpeg',
    'png',
    'gif',
    'bmp',
    'webp',
    'svg',
    'heic',
    'heif',
  ];

  static const List<String> documentExtensions = [
    'pdf',
    'doc',
    'docx',
    'xls',
    'xlsx',
    'ppt',
    'pptx',
    'txt',
    'rtf',
    'odt',
    'ods',
    'odp',
  ];

  static const List<String> multimediaExtensions = [
    'mp4',
    'avi',
    'mov',
    'wmv',
    'flv',
    'webm',
    'mkv',
    'mp3',
    'wav',
    'ogg',
    'aac',
    'flac',
  ];

  /// Detectar el tipo de archivo según su extensión
  static FileType? fromExtension(String? extension) {
    if (extension == null) return null;
    final ext = extension.toLowerCase().replaceAll('.', '');

    if (imageExtensions.contains(ext)) return FileType.image;
    if (documentExtensions.contains(ext)) return FileType.document;
    if (multimediaExtensions.contains(ext)) return FileType.multimedia;

    return null;
  }

  /// Obtener la extensión de un nombre de archivo
  static String? getExtension(String fileName) {
    final parts = fileName.split('.');
    if (parts.length < 2) return null;
    return parts.last.toLowerCase();
  }

  /// Obtener el tipo de archivo desde un nombre de archivo o URL
  static FileType? fromFileName(String fileName) {
    final extension = getExtension(fileName);
    return fromExtension(extension);
  }
}
