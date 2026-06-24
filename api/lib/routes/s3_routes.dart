import 'dart:convert';
import 'dart:typed_data';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:crypto/crypto.dart';
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

      final fileName = req.headers['x-file-name'] ?? 'file';
      final folder = req.headers['x-folder'] ?? 'uploads';
      final ext = fileName.contains('.')
          ? fileName.split('.').last.toLowerCase()
          : '';
      final uuid = const Uuid().v4();
      final s3Key = '$folder/$uuid${ext.isNotEmpty ? '.$ext' : ''}';

      final contentType =
          req.headers['content-type'] ??
          lookupMimeType(fileName) ??
          'application/octet-stream';

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

// ── AWS Signature V4 helpers (mismo algoritmo que s3_service.dart) ───────────

List<int> _hmacSha256(List<int> key, String data) =>
    Hmac(sha256, key).convert(utf8.encode(data)).bytes;

String _formatDate(DateTime d) =>
    '${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';

String _formatAmzDate(DateTime d) =>
    d.toIso8601String().replaceAll('-', '').replaceAll(':', '').split('.')[0] +
    'Z';

Future<String> _generatePresignedUrl(
  String key, {
  int expirationInSeconds = 3600,
}) async {
  final normalizedKey = key.startsWith('/') ? key.substring(1) : key;
  final bucket = Config.s3BucketName;
  final region = Config.awsRegion;
  final accessKey = Config.awsAccessKeyId;
  final secretKey = Config.awsSecretAccessKey;

  final now = DateTime.now().toUtc();
  final dateStamp = _formatDate(now);
  final amzDate = _formatAmzDate(now);
  final host = '$bucket.s3.$region.amazonaws.com';
  final credentialScope = '$dateStamp/$region/s3/aws4_request';
  final credential = '$accessKey/$credentialScope';

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
      .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
      .join('&');

  final canonicalRequest =
      'GET\n/$normalizedKey\n$canonicalQueryString\nhost:$host\n\nhost\nUNSIGNED-PAYLOAD';

  final stringToSign =
      'AWS4-HMAC-SHA256\n$amzDate\n$credentialScope\n'
      '${sha256.convert(utf8.encode(canonicalRequest))}';

  final kDate = _hmacSha256(utf8.encode('AWS4$secretKey'), dateStamp);
  final kRegion = _hmacSha256(kDate, region);
  final kService = _hmacSha256(kRegion, 's3');
  final kSigning = _hmacSha256(kService, 'aws4_request');
  final signature = _hmacSha256(kSigning, stringToSign)
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join();

  return Uri.https(host, normalizedKey, {
    ...queryParams,
    'X-Amz-Signature': signature,
  }).toString();
}

Future<void> _uploadToS3({
  required String key,
  required Uint8List bytes,
  required String contentType,
}) async {
  final bucket = Config.s3BucketName;
  final region = Config.awsRegion;
  final accessKey = Config.awsAccessKeyId;
  final secretKey = Config.awsSecretAccessKey;

  final now = DateTime.now().toUtc();
  final dateStamp = _formatDate(now);
  final amzDate = _formatAmzDate(now);
  final host = '$bucket.s3.$region.amazonaws.com';
  final payloadHash = sha256.convert(bytes).toString();

  final headers = {
    'Content-Type': contentType,
    'Host': host,
    'x-amz-content-sha256': payloadHash,
    'x-amz-date': amzDate,
  };

  final signedHeaders = (headers.keys.map((k) => k.toLowerCase()).toList()
    ..sort()).join(';');
  final canonicalHeaders = (headers.entries.toList()
        ..sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase())))
      .map((e) => '${e.key.toLowerCase()}:${e.value}\n')
      .join();

  final canonicalRequest =
      'PUT\n/$key\n\n$canonicalHeaders\n$signedHeaders\n$payloadHash';
  final credentialScope = '$dateStamp/$region/s3/aws4_request';
  final stringToSign =
      'AWS4-HMAC-SHA256\n$amzDate\n$credentialScope\n'
      '${sha256.convert(utf8.encode(canonicalRequest))}';

  final kDate = _hmacSha256(utf8.encode('AWS4$secretKey'), dateStamp);
  final kRegion = _hmacSha256(kDate, region);
  final kService = _hmacSha256(kRegion, 's3');
  final kSigning = _hmacSha256(kService, 'aws4_request');
  final signature = _hmacSha256(kSigning, stringToSign)
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join();

  final authorization =
      'AWS4-HMAC-SHA256 Credential=$accessKey/$credentialScope, '
      'SignedHeaders=$signedHeaders, Signature=$signature';

  final url = Uri.https(host, '/$key');
  final response = await http.put(
    url,
    headers: {
      ...headers,
      'Authorization': authorization,
    },
    body: bytes,
  );

  if (response.statusCode != 200 && response.statusCode != 201) {
    throw Exception('S3 upload error ${response.statusCode}: ${response.body}');
  }
}

Future<void> _deleteFromS3(String key) async {
  final bucket = Config.s3BucketName;
  final region = Config.awsRegion;
  final accessKey = Config.awsAccessKeyId;
  final secretKey = Config.awsSecretAccessKey;

  final normalizedKey = key.startsWith('/') ? key.substring(1) : key;
  final now = DateTime.now().toUtc();
  final dateStamp = _formatDate(now);
  final amzDate = _formatAmzDate(now);
  final host = '$bucket.s3.$region.amazonaws.com';
  final payloadHash = sha256.convert(utf8.encode('')).toString();

  final headers = {
    'Host': host,
    'x-amz-content-sha256': payloadHash,
    'x-amz-date': amzDate,
  };

  final signedHeaders = (headers.keys.map((k) => k.toLowerCase()).toList()
    ..sort()).join(';');
  final canonicalHeaders = (headers.entries.toList()
        ..sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase())))
      .map((e) => '${e.key.toLowerCase()}:${e.value}\n')
      .join();

  final canonicalRequest =
      'DELETE\n/$normalizedKey\n\n$canonicalHeaders\n$signedHeaders\n$payloadHash';
  final credentialScope = '$dateStamp/$region/s3/aws4_request';
  final stringToSign =
      'AWS4-HMAC-SHA256\n$amzDate\n$credentialScope\n'
      '${sha256.convert(utf8.encode(canonicalRequest))}';

  final kDate = _hmacSha256(utf8.encode('AWS4$secretKey'), dateStamp);
  final kRegion = _hmacSha256(kDate, region);
  final kService = _hmacSha256(kRegion, 's3');
  final kSigning = _hmacSha256(kService, 'aws4_request');
  final signature = _hmacSha256(kSigning, stringToSign)
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join();

  final authorization =
      'AWS4-HMAC-SHA256 Credential=$accessKey/$credentialScope, '
      'SignedHeaders=$signedHeaders, Signature=$signature';

  final url = Uri.https(host, '/$normalizedKey');
  await http.delete(url, headers: {...headers, 'Authorization': authorization});
}
