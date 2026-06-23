import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';
import '../utils/env_config.dart';
import '../models/file_type.dart';

/// Entrada interna de caché para URLs pre-firmadas de S3.
/// Las URLs expiran en 3600s por defecto; cacheamos con 300s de margen.
class _CachedPresignedUrl {
  final String url;
  final DateTime expiresAt;
  _CachedPresignedUrl(this.url, this.expiresAt);
  bool get isValid => DateTime.now().isBefore(expiresAt);
}

/// Servicio para gestionar la subida y descarga de archivos en AWS S3
class S3Service {
  static final S3Service _instance = S3Service._internal();
  factory S3Service() => _instance;
  static S3Service get shared => _instance;

  final String _accessKey;
  final String _secretKey;
  final String _region;
  final String _bucketName;
  final bool _useS3;

  // Límites de tamaño de archivo (en bytes)
  static const int maxImageSize = 20 * 1024 * 1024; // 20 MB
  static const int maxDocumentSize = 50 * 1024 * 1024; // 50 MB
  static const int maxMultimediaSize = 300 * 1024 * 1024; // 300 MB

  /// Caché en memoria de URLs pre-firmadas.
  /// Evita regenerarlas en cada rebuild — las imágenes/archivos se reutilizan
  /// de la caché de disco de CachedNetworkImage porque la URL no cambia.
  static final Map<String, _CachedPresignedUrl> _presignedUrlCache = {};

  S3Service._internal()
    : _accessKey = EnvConfig.awsAccessKeyId,
      _secretKey = EnvConfig.awsSecretAccessKey,
      _region = EnvConfig.awsRegion,
      _bucketName = EnvConfig.bucketName,
      _useS3 = EnvConfig.useS3 {
    print('🔧 S3Service inicializado:');
    print('  - Bucket: $_bucketName');
    print('  - Region: $_region');
    print('  - USE_S3: $_useS3');
  }

  // MARK: - Caché

  /// Invalida la URL cacheada para una clave de S3 específica.
  /// Llamar después de borrar o reemplazar un archivo.
  static void invalidatePresignedUrl(String key) =>
      _presignedUrlCache.remove(key);

  /// Limpia toda la caché de URLs pre-firmadas (útil al cerrar sesión).
  static void clearPresignedUrlCache() => _presignedUrlCache.clear();

  // MARK: - File Upload

  /// Sube un archivo a S3
  /// [filePath] - Ruta local del archivo
  /// [userId] - ID del usuario propietario
  /// [catalogId] - ID del catálogo
  /// [fileType] - Tipo de archivo
  /// Retorna la URL pública del archivo en S3
  Future<String> uploadFile({
    required String filePath,
    required String userId,
    required String catalogId,
    required FileType fileType,
  }) async {
    // Limpiar el userId antes de usarlo
    final cleanUserId = _cleanUserId(userId);
    if (cleanUserId != userId) {
      print('⚠️ UserId limpiado: "$userId" -> "$cleanUserId"');
    }

    print('📤 Iniciando subida de archivo:');
    print('  - Archivo: ${path.basename(filePath)}');
    print('  - Tipo: ${fileType.name}');
    print('  - Usuario: $cleanUserId');
    print('  - Catálogo: $catalogId');
    print('  - Bucket: $_bucketName');
    print('  - Region: $_region');
    print('  - USE_S3: $_useS3');

    // Validar configuración de S3
    if (_useS3) {
      if (_bucketName.isEmpty) {
        throw Exception(
          'BUCKET_NAME no está configurado en las variables de entorno. '
          'Verifica tu archivo .env',
        );
      }
      if (_accessKey.isEmpty || _secretKey.isEmpty) {
        throw Exception(
          'AWS_ACCESS_KEY_ID o AWS_SECRET_ACCESS_KEY no están configurados. '
          'Verifica tu archivo .env',
        );
      }
    }

    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('Archivo no encontrado: $filePath');
    }

    final fileSize = await file.length();
    print('  - Tamaño: ${_formatBytes(fileSize)}');

    _validateFileSize(fileSize, fileType);

    // Usar el userId limpio
    final s3Key = _generateS3Key(
      userId: cleanUserId,
      catalogId: catalogId,
      fileType: fileType,
      originalFileName: path.basename(filePath),
    );

    print('  - S3 Key: $s3Key');

    if (!_useS3) {
      print('⚠️ USE_S3=false - Simulando subida');
      return _simulateUpload(s3Key: s3Key, fileType: fileType);
    }

    return await _uploadToS3(file: file, s3Key: s3Key);
  }

  /// Sube el archivo real a S3
  Future<String> _uploadToS3({
    required File file,
    required String s3Key,
  }) async {
    try {
      // Validar que el bucket name no esté vacío
      if (_bucketName.isEmpty) {
        throw Exception(
          'BUCKET_NAME está vacío. Por favor, configura BUCKET_NAME en tu archivo .env',
        );
      }

      final fileBytes = await file.readAsBytes();
      final contentType = _detectContentType(file.path);

      print('  - Content-Type: $contentType');
      print('  - Bucket Name: $_bucketName');
      print('  - Region: $_region');

      final host = '$_bucketName.s3.$_region.amazonaws.com';
      print('  - Host: $host');

      final url = Uri.https(host, s3Key);
      print('  - URL completa: $url');
      final now = DateTime.now().toUtc();
      final dateStamp = _formatDate(now);
      final amzDate = _formatAmzDate(now);

      // Calcular el hash SHA256 del contenido del payload
      final payloadHash = sha256.convert(fileBytes).toString();

      // IMPORTANTE: El header 'host' DEBE estar incluido en la firma
      // AWS requiere que todos los headers presentes en la petición estén firmados
      final headers = <String, String>{
        'host': host, // Header host DEBE estar incluido en la firma
        'Content-Type': contentType,
        'x-amz-date': amzDate,
        'x-amz-content-sha256':
            payloadHash, // Header requerido para AWS Signature V4
      };

      final authorization = _generateAuthorization(
        method: 'PUT',
        uri: s3Key,
        headers: headers,
        payload: base64.encode(fileBytes),
        dateStamp: dateStamp,
        amzDate: amzDate,
        payloadHash: payloadHash, // Pasar el hash del payload
      );

      headers['Authorization'] = authorization;

      print('📤 Subiendo a S3...');
      final response = await http.put(url, headers: headers, body: fileBytes);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final s3Url = url.toString();
        print('✅ Archivo subido exitosamente: $s3Url');
        return s3Url;
      } else {
        throw Exception(
          'Error al subir archivo: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      print('❌ Error al subir archivo: $e');
      rethrow;
    }
  }

  /// Simula una subida (cuando USE_S3=false)
  String _simulateUpload({required String s3Key, required FileType fileType}) {
    final baseUrl = 'https://$_bucketName.s3.$_region.amazonaws.com/$s3Key';
    print('⚠️ Simulación: URL sería $baseUrl');
    return baseUrl;
  }

  // MARK: - URL Generation

  /// Genera una URL pre-firmada para descargar un archivo.
  ///
  /// Las URLs se cachean en memoria durante (expirationInSeconds - 300) segundos
  /// para evitar regenerar la firma en cada rebuild de widget y permitir que
  /// CachedNetworkImage reutilice su caché de disco.
  Future<Uri> getPresignedUrl({
    required String key,
    int expirationInSeconds = 3600,
  }) async {
    final normalizedKey = _normalizeKey(key);

    // ── Revisar caché en memoria ──────────────────────────────────────────────
    final cached = _presignedUrlCache[normalizedKey];
    if (cached != null && cached.isValid) {
      return Uri.parse(cached.url);
    }
    // ─────────────────────────────────────────────────────────────────────────

    if (!_useS3) {
      return Uri.https('$_bucketName.s3.$_region.amazonaws.com', normalizedKey);
    }

    final now = DateTime.now().toUtc();
    final dateStamp = _formatDate(now);
    final amzDate = _formatAmzDate(now);
    final host = '$_bucketName.s3.$_region.amazonaws.com';
    final credentialScope = '$dateStamp/$_region/s3/aws4_request';
    final credential = '$_accessKey/$credentialScope';

    final queryParams = {
      'X-Amz-Algorithm': 'AWS4-HMAC-SHA256',
      'X-Amz-Credential': credential,
      'X-Amz-Date': amzDate,
      'X-Amz-Expires': '$expirationInSeconds',
      'X-Amz-SignedHeaders': 'host',
    };

    final sortedQuery = queryParams.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final canonicalQueryString = sortedQuery
        .map(
          (e) =>
              '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}',
        )
        .join('&');

    final canonicalRequest =
        'GET\n/$normalizedKey\n$canonicalQueryString\nhost:$host\n\nhost\nUNSIGNED-PAYLOAD';

    final stringToSign =
        'AWS4-HMAC-SHA256\n$amzDate\n$credentialScope\n'
        '${sha256.convert(utf8.encode(canonicalRequest)).toString()}';

    final kDate = _hmacSha256(utf8.encode('AWS4$_secretKey'), dateStamp);
    final kRegion = _hmacSha256(kDate, _region);
    final kService = _hmacSha256(kRegion, 's3');
    final kSigning = _hmacSha256(kService, 'aws4_request');
    final signature = _hmacSha256(
      kSigning,
      stringToSign,
    ).map((b) => b.toRadixString(16).padLeft(2, '0')).join();

    final signedUrl = Uri.https(host, normalizedKey, {
      ...queryParams,
      'X-Amz-Signature': signature,
    });

    // ── Guardar en caché con TTL conservador (300s de margen antes de expirar) ─
    final cacheTtl = Duration(
      seconds: (expirationInSeconds - 300).clamp(60, expirationInSeconds),
    );
    _presignedUrlCache[normalizedKey] = _CachedPresignedUrl(
      signedUrl.toString(),
      DateTime.now().add(cacheTtl),
    );
    // ─────────────────────────────────────────────────────────────────────────

    print('✅ URL pre-firmada generada (expira en ${expirationInSeconds}s)');
    return signedUrl;
  }

  // MARK: - File Deletion

  /// Elimina un archivo de S3
  Future<void> deleteFile(String key) async {
    final normalizedKey = _normalizeKey(key);
    print('🗑️ Eliminando archivo: $normalizedKey');

    // Invalidar caché al eliminar
    _presignedUrlCache.remove(normalizedKey);

    if (!_useS3) {
      print('⚠️ USE_S3=false - Simulando eliminación');
      return;
    }

    try {
      final url = Uri.https(
        '$_bucketName.s3.$_region.amazonaws.com',
        normalizedKey,
      );
      final now = DateTime.now().toUtc();
      final dateStamp = _formatDate(now);
      final amzDate = _formatAmzDate(now);

      final headers = <String, String>{
        'Date': dateStamp,
        'x-amz-date': amzDate,
      };

      final authorization = _generateAuthorization(
        method: 'DELETE',
        uri: normalizedKey,
        headers: headers,
        payload: '',
        dateStamp: dateStamp,
        amzDate: amzDate,
      );

      headers['Authorization'] = authorization;

      final response = await http.delete(url, headers: headers);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        print('✅ Archivo eliminado exitosamente');
      } else {
        throw Exception(
          'Error al eliminar archivo: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      print('❌ Error eliminando archivo: $e');
      rethrow;
    }
  }

  // MARK: - Helpers

  /// Limpia el userId de formato ObjectId(...)
  String _cleanUserId(String userId) {
    // Si el userId contiene ObjectId("..."), extraer solo el ID
    final objectIdMatch = RegExp(r'ObjectId\("?([^"]+)"?\)').firstMatch(userId);
    if (objectIdMatch != null) {
      return objectIdMatch.group(1)!;
    }
    // Si ya es un ID limpio, devolverlo tal cual
    return userId;
  }

  /// Genera una key única para S3
  String _generateS3Key({
    required String userId, // userId ya debería estar limpio desde uploadFile
    required String catalogId,
    required FileType fileType,
    required String originalFileName,
  }) {
    // Limpiar el userId para asegurar que no contenga formato ObjectId(...)
    // (por si acaso viene sin limpiar desde otros métodos)
    final cleanUserId = _cleanUserId(userId);
    // También limpiar catalogId por si acaso
    final cleanCatalogId = _cleanUserId(catalogId);
    final uuid = const Uuid().v4();
    final extension = path.extension(originalFileName);
    final fileTypeFolder = fileType.name; // image, document, multimedia

    return 'users/$cleanUserId/catalogs/$cleanCatalogId/$fileTypeFolder/$uuid$extension';
  }

  /// Normaliza una key de S3
  String _normalizeKey(String key) {
    // Strip full HTTPS URL prefix
    final httpsPrefix = 'https://$_bucketName.s3.$_region.amazonaws.com/';
    if (key.startsWith(httpsPrefix)) {
      return key.substring(httpsPrefix.length);
    }
    // Strip S3 URI prefix
    return key
        .replaceFirst('s3://$_bucketName/', '')
        .replaceFirst('/$_bucketName/', '');
  }

  /// Valida el tamaño del archivo según su tipo
  void _validateFileSize(int size, FileType type) {
    int maxSize;
    switch (type) {
      case FileType.image:
        maxSize = maxImageSize;
        break;
      case FileType.document:
        maxSize = maxDocumentSize;
        break;
      case FileType.text:
        maxSize =
            maxDocumentSize; // Los archivos de texto usan el mismo límite que documentos
        break;
      case FileType.multimedia:
        maxSize = maxMultimediaSize;
        break;
      case FileType.other:
        maxSize = maxMultimediaSize; // Usar el límite más grande para "otros"
        break;
    }

    if (size > maxSize) {
      throw Exception(
        'El archivo excede el tamaño máximo permitido: ${_formatBytes(maxSize)}',
      );
    }
  }

  /// Detecta el Content-Type basado en la extensión del archivo
  String _detectContentType(String filePath) {
    final ext = path.extension(filePath).toLowerCase().replaceFirst('.', '');

    const contentTypes = {
      // Imágenes
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'gif': 'image/gif',
      'webp': 'image/webp',
      'svg': 'image/svg+xml',
      'bmp': 'image/bmp',
      // Documentos
      'pdf': 'application/pdf',
      'doc': 'application/msword',
      'docx':
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'xls': 'application/vnd.ms-excel',
      'xlsx':
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'txt': 'text/plain',
      // Multimedia
      'mp4': 'video/mp4',
      'mov': 'video/quicktime',
      'mp3': 'audio/mpeg',
      'wav': 'audio/wav',
    };

    return contentTypes[ext] ?? 'application/octet-stream';
  }

  /// Genera la autorización AWS Signature V4
  String _generateAuthorization({
    required String method,
    required String uri,
    required Map<String, String> headers,
    required String payload,
    required String dateStamp,
    required String amzDate,
    String? payloadHash,
  }) {
    // Si no se proporciona payloadHash, calcularlo desde el payload
    final contentHash =
        payloadHash ?? sha256.convert(base64.decode(payload)).toString();
    // Implementación simplificada de AWS Signature V4
    // Nota: Para producción, usar un paquete dedicado o implementación completa
    final canonicalUri = '/$uri';
    final canonicalQueryString = '';
    final canonicalHeaders =
        headers.entries
            .map((e) => '${e.key.toLowerCase()}:${e.value.trim()}\n')
            .toList()
          ..sort();
    final signedHeaders = headers.keys.map((k) => k.toLowerCase()).toList()
      ..sort();

    // Para el canonical request, usar el hash del payload directamente (no codificar payload como string)
    final canonicalRequest =
        '$method\n$canonicalUri\n$canonicalQueryString\n${canonicalHeaders.join()}\n${signedHeaders.join(';')}\n$contentHash';

    final algorithm = 'AWS4-HMAC-SHA256';
    final credentialScope = '$dateStamp/$_region/s3/aws4_request';
    final stringToSign =
        '$algorithm\n$amzDate\n$credentialScope\n${sha256.convert(utf8.encode(canonicalRequest)).toString()}';

    final kDate = _hmacSha256(utf8.encode('AWS4$_secretKey'), dateStamp);
    final kRegion = _hmacSha256(kDate, _region);
    final kService = _hmacSha256(kRegion, 's3');
    final kSigning = _hmacSha256(kService, 'aws4_request');
    final signature = _hmacSha256(kSigning, stringToSign);

    return '$algorithm Credential=$_accessKey/$credentialScope, SignedHeaders=${signedHeaders.join(';')}, Signature=${signature.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';
  }

  List<int> _hmacSha256(List<int> key, String data) {
    final hmac = Hmac(sha256, key);
    return hmac.convert(utf8.encode(data)).bytes;
  }

  String _formatDate(DateTime date) {
    return '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
  }

  String _formatAmzDate(DateTime date) {
    return '${date.toIso8601String().replaceAll('-', '').replaceAll(':', '').split('.')[0]}Z';
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}
