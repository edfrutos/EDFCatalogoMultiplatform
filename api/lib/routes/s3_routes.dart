import 'dart:typed_data';
import 'package:edfcatalogo_crypto/aws_s3_signer.dart';
import 'package:edfcatalogo_crypto/s3_content_type.dart';
import 'package:edfcatalogo_crypto/s3_object_key.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'package:mime/mime.dart';
import '../config.dart';
import 'helpers.dart';

Router s3Routes() {
  final router = Router();

  // GET /api/s3/presign?key=ruta/al/archivo.jpg
  // Genera una URL pre-firmada de lectura para S3.
  router.get('/presign', (Request req) async {
    if (requireAuth(req) == null) return error('No autorizado', 401);

    final key = req.url.queryParameters['key'] ?? '';
    if (key.isEmpty) return error('key es requerido', 400);

    if (!Config.useS3) {
      // Sin S3 configurado, devolver URL directa sin firma
      final url =
          'https://${Config.s3BucketName}.s3.${Config.awsRegion}.amazonaws.com/$key';
      return ok({'url': url});
    }

    try {
      final url = await _generatePresignedUrl(key);
      return ok({'url': url});
    } catch (e) {
      return error('Error generando URL: $e', 500);
    }
  });

  // POST /api/s3/upload — recibe bytes en body con header X-File-Name
  // Sube un archivo a S3 y devuelve la key y URL.
  router.post('/upload', (Request req) async {
    if (requireAuth(req) == null) return error('No autorizado', 401);

    if (!Config.useS3) return error('S3 no está configurado', 503);

    try {
      final bytes = await req.read().expand((chunk) => chunk).toList();
      if (bytes.isEmpty) return error('Body vacío', 400);

      // El cliente envía X-File-Name percent-encoded (Uri.encodeComponent)
      // porque las cabeceras HTTP solo admiten ISO-8859-1 y los nombres con
      // tildes/ñ en NFD (típico en macOS) rompían el fetch en el navegador.
      final rawFileName = req.headers['x-file-name'] ?? 'file';
      final fileName = Uri.decodeComponent(rawFileName);
      final uuid = const Uuid().v4();
      final userId = req.headers['x-user-id'];
      final catalogId = req.headers['x-catalog-id'];
      final fileType = req.headers['x-file-type'];

      final String s3Key;
      if (userId != null &&
          userId.isNotEmpty &&
          catalogId != null &&
          catalogId.isNotEmpty &&
          fileType != null &&
          fileType.isNotEmpty) {
        s3Key = S3ObjectKey.build(
          userId: userId,
          catalogId: catalogId,
          kind: fileType,
          originalFileName: fileName,
          uuid: uuid,
        );
      } else {
        final folder = req.headers['x-folder'] ?? 'uploads';
        s3Key = '$folder/$uuid${S3ObjectKey.extensionOf(fileName)}';
      }

      final headerType = req.headers['content-type'];
      final String contentType;
      if (S3ContentType.isGeneric(headerType)) {
        final inferred = S3ContentType.fromFileName(fileName);
        contentType = inferred == S3ContentType.octetStream
            ? (lookupMimeType(fileName) ?? S3ContentType.octetStream)
            : inferred;
      } else {
        contentType = headerType!.split(';').first.trim();
      }

      await _uploadToS3(
        key: s3Key,
        bytes: Uint8List.fromList(bytes),
        contentType: contentType,
      );

      final url =
          'https://${Config.s3BucketName}.s3.${Config.awsRegion}.amazonaws.com/$s3Key';
      return ok({'key': s3Key, 'url': url});
    } catch (e) {
      return error('Error subiendo archivo: $e', 500);
    }
  });

  // DELETE /api/s3/delete?key=ruta/al/archivo.jpg
  router.delete('/delete', (Request req) async {
    if (requireAuth(req) == null) return error('No autorizado', 401);

    final key = req.url.queryParameters['key'] ?? '';
    if (key.isEmpty) return error('key es requerido', 400);

    if (!Config.useS3) return ok({'deleted': true});

    try {
      await _deleteFromS3(key);
      return ok({'deleted': true});
    } catch (e) {
      return error('Error eliminando archivo: $e', 500);
    }
  });

  return router;
}

AwsS3Signer _s3Signer() => AwsS3Signer(
      accessKey: Config.awsAccessKeyId,
      secretKey: Config.awsSecretAccessKey,
      region: Config.awsRegion,
      bucket: Config.s3BucketName,
    );

Future<String> _generatePresignedUrl(
  String key, {
  int expirationInSeconds = 3600,
}) async {
  return _s3Signer()
      .presignedGet(
        key: key,
        now: DateTime.now().toUtc(),
        expiresInSeconds: expirationInSeconds,
      )
      .toString();
}

Future<void> _uploadToS3({
  required String key,
  required Uint8List bytes,
  required String contentType,
}) async {
  final signed = _s3Signer().sign(
    method: 'PUT',
    key: key,
    now: DateTime.now().toUtc(),
    extraHeaders: {'Content-Type': contentType},
    payload: bytes,
  );

  final response = await http.put(
    signed.url,
    headers: signed.headers,
    body: bytes,
  );

  if (response.statusCode != 200 && response.statusCode != 201) {
    throw Exception('S3 upload error ${response.statusCode}: ${response.body}');
  }
}

Future<void> _deleteFromS3(String key) async {
  final signed = _s3Signer().sign(
    method: 'DELETE',
    key: key,
    now: DateTime.now().toUtc(),
  );
  await http.delete(signed.url, headers: signed.headers);
}
