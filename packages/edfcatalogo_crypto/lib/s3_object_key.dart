/// Layout canónico de objetos en el bucket S3.
///
/// `users/{userId}/catalogs/{catalogId}/{kind}/{uuid}{ext}`
///
/// [kind] es el nombre del enum FileType (`image`, `document`, `text`,
/// `multimedia`, `other`). Alias en plural (`images`, `documents`) se
/// normalizan para no volver a divergir web vs nativo.
class S3ObjectKey {
  S3ObjectKey._();

  static final _objectId = RegExp(r'ObjectId\("?([^"]+)"?\)');

  /// Extrae el hex de `ObjectId("...")` si viene así; si no, deja el id.
  static String cleanId(String id) {
    final match = _objectId.firstMatch(id);
    return match?.group(1) ?? id;
  }

  /// Carpeta de tipo: `image` (no `images`).
  static String normalizeKind(String kind) {
    final k = kind.trim().toLowerCase();
    switch (k) {
      case 'images':
        return 'image';
      case 'documents':
        return 'document';
      case 'texts':
        return 'text';
      case 'uploads':
      case '':
        return 'other';
      default:
        if (k.contains('/') || k.contains('..')) return 'other';
        return k;
    }
  }

  /// Prefijo sin el fichero: lo que la API pone en `X-Folder`.
  static String prefix({
    required String userId,
    required String catalogId,
    required String kind,
  }) {
    return 'users/${cleanId(userId)}/catalogs/${cleanId(catalogId)}/'
        '${normalizeKind(kind)}';
  }

  /// Key completa, extensión en minúsculas (incluye el punto, o vacío).
  static String build({
    required String userId,
    required String catalogId,
    required String kind,
    required String originalFileName,
    required String uuid,
  }) {
    return '${prefix(userId: userId, catalogId: catalogId, kind: kind)}/'
        '$uuid${extensionOf(originalFileName)}';
  }

  /// `.pdf` / `.jpg` en minúsculas, o `''` si no hay extensión.
  static String extensionOf(String fileName) {
    final name = fileName.split('/').last.split('?').first;
    final i = name.lastIndexOf('.');
    if (i <= 0 || i == name.length - 1) return '';
    return name.substring(i).toLowerCase();
  }
}
