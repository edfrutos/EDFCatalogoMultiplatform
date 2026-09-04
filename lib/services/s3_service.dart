// ignore_for_file: avoid_print
import 'dart:typed_data';
import 'package:edfcatalogo_crypto/aws_s3_signer.dart';
import 'package:edfcatalogo_crypto/s3_content_type.dart';
import 'package:edfcatalogo_crypto/s3_object_key.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';
import '../utils/env_config.dart';
import '../models/file_type.dart';
import 'api_service.dart';

// dart:io solo disponible en plataformas nativas (File, Directory, Platform)
import 'dart:io' if (dart.library.html) 'package:edfcatalogomultiplatform/utils/io_stub.dart';

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
    // En web no hay sistema de archivos nativo; usar uploadBytes
    if (kIsWeb) {
      throw UnsupportedError(
        'uploadFile no está disponible en web. '
        'Usa S3Service.uploadBytes() con los bytes del file picker.',
      );
    }

    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('Archivo no encontrado: $filePath');
    }

    return uploadBytes(
      bytes: await file.readAsBytes(),
      fileName: path.basename(filePath),
      userId: userId,
      catalogId: catalogId,
      fileType: fileType,
    );
  }

  /// Sube bytes a S3 con la misma key que [uploadFile].
  /// En web delega en la API; en nativo firma PUT contra S3.
  Future<String> uploadBytes({
    required Uint8List bytes,
    required String fileName,
    required String userId,
    required String catalogId,
    required FileType fileType,
  }) async {
    final cleanUserId = S3ObjectKey.cleanId(userId);
    if (cleanUserId != userId) {
      print('⚠️ UserId limpiado: "$userId" -> "$cleanUserId"');
    }
    final cleanCatalogId = S3ObjectKey.cleanId(catalogId);

    print('📤 Iniciando subida de archivo:');
    print('  - Archivo: $fileName');
    print('  - Tipo: ${fileType.name}');
    print('  - Usuario: $cleanUserId');
    print('  - Catálogo: $cleanCatalogId');
    print('  - Bucket: $_bucketName');
    print('  - Region: $_region');
    print('  - USE_S3: $_useS3');
    print('  - Tamaño: ${_formatBytes(bytes.length)}');

    if (!kIsWeb) {
      _assertS3ConfigIfEnabled();
    }
    _validateFileSize(bytes.length, fileType);

    if (kIsWeb) {
      return ApiService.instance.uploadBytes(
        bytes: bytes,
        fileName: fileName,
        userId: cleanUserId,
        catalogId: cleanCatalogId,
        fileType: fileType.name,
        folder: S3ObjectKey.prefix(
          userId: cleanUserId,
          catalogId: cleanCatalogId,
          kind: fileType.name,
        ),
        contentType: S3ContentType.fromFileName(fileName),
      );
    }

    final s3Key = S3ObjectKey.build(
      userId: cleanUserId,
      catalogId: cleanCatalogId,
      kind: fileType.name,
      originalFileName: fileName,
      uuid: const Uuid().v4(),
    );
    print('  - S3 Key: $s3Key');

    if (!_useS3) {
      print('⚠️ USE_S3=false - Simulando subida');
      return _simulateUpload(s3Key: s3Key, fileType: fileType);
    }

    return _uploadBytesToS3(
      bytes: bytes,
      s3Key: s3Key,
      contentType: S3ContentType.fromFileName(fileName),
    );
  }

  void _assertS3ConfigIfEnabled() {
    if (!_useS3) return;
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

  AwsS3Signer get _signer => AwsS3Signer(
        accessKey: _accessKey,
        secretKey: _secretKey,
        region: _region,
        bucket: _bucketName,
      );

  Future<String> _uploadBytesToS3({
    required Uint8List bytes,
    required String s3Key,
    required String contentType,
  }) async {
    try {
      if (_bucketName.isEmpty) {
        throw Exception(
          'BUCKET_NAME está vacío. Por favor, configura BUCKET_NAME en tu archivo .env',
        );
      }

      print('  - Content-Type: $contentType');
      print('  - Bucket Name: $_bucketName');
      print('  - Region: $_region');
      print('  - Host: ${_signer.host}');

      final signed = _signer.sign(
        method: 'PUT',
        key: s3Key,
        now: DateTime.now().toUtc(),
        extraHeaders: {'Content-Type': contentType},
        payload: bytes,
      );

      print('📤 Subiendo a S3...');
      final response = await http.put(
        signed.url,
        headers: signed.headers,
        body: bytes,
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final s3Url = signed.url.toString();
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
    // En web, delegar al servidor API (evita dart:io y CORS)
    // Normalizar la key ANTES de enviar: si llega una URL completa la convertimos
    // en key relativa (users/xxx/...) para que el servidor no la duplique.
    if (kIsWeb) return ApiService.instance.getPresignedUrl(_normalizeKey(key));

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

    final signedUrl = _signer.presignedGet(
      key: normalizedKey,
      now: DateTime.now().toUtc(),
      expiresInSeconds: expirationInSeconds,
    );

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

    if (kIsWeb) {
      await ApiService.instance.deleteS3File(normalizedKey);
      print('✅ Archivo eliminado exitosamente');
      return;
    }

    try {
      final signed = _signer.sign(
        method: 'DELETE',
        key: normalizedKey,
        now: DateTime.now().toUtc(),
      );

      final response = await http.delete(signed.url, headers: signed.headers);

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

  /// Normaliza una key de S3
  String _normalizeKey(String key) {
    // Si ya es una key limpia (sin protocolo) devolverla tal cual
    if (!key.contains('://')) {
      return key.startsWith('/') ? key.substring(1) : key;
    }
    // URL completa (https://bucket.s3.region.amazonaws.com/KEY o s3://bucket/KEY)
    // Parsear con Uri para extraer solo el path — no depende del bucket name
    // ni de que .env esté cargado (seguro en web).
    final uri = Uri.tryParse(key);
    if (uri != null && uri.path.isNotEmpty) {
      final path = uri.path.startsWith('/') ? uri.path.substring(1) : uri.path;
      return path;
    }
    return key;
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

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}
