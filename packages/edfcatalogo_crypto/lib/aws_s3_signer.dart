import 'dart:convert';

import 'package:crypto/crypto.dart';

/// AWS Signature Version 4 para S3 (PUT/DELETE firmados y GET pre-firmado).
///
/// Una sola implementación para el cliente nativo y la API web.
class AwsS3Signer {
  const AwsS3Signer({
    required this.accessKey,
    required this.secretKey,
    required this.region,
    required this.bucket,
  });

  final String accessKey;
  final String secretKey;
  final String region;
  final String bucket;

  String get host => '$bucket.s3.$region.amazonaws.com';

  static String formatDate(DateTime utc) {
    final d = utc.toUtc();
    return '${d.year}'
        '${d.month.toString().padLeft(2, '0')}'
        '${d.day.toString().padLeft(2, '0')}';
  }

  static String formatAmzDate(DateTime utc) {
    return utc
            .toUtc()
            .toIso8601String()
            .replaceAll('-', '')
            .replaceAll(':', '')
            .split('.')
            .first +
        'Z';
  }

  static String hashPayload(List<int> bytes) => sha256.convert(bytes).toString();

  /// URL GET pre-firmada (query string V4, payload UNSIGNED-PAYLOAD).
  Uri presignedGet({
    required String key,
    required DateTime now,
    int expiresInSeconds = 3600,
  }) {
    final normalizedKey = _normalizeKey(key);
    final utc = now.toUtc();
    final dateStamp = formatDate(utc);
    final amzDate = formatAmzDate(utc);
    final credentialScope = '$dateStamp/$region/s3/aws4_request';
    final credential = '$accessKey/$credentialScope';

    final queryParams = {
      'X-Amz-Algorithm': 'AWS4-HMAC-SHA256',
      'X-Amz-Credential': credential,
      'X-Amz-Date': amzDate,
      'X-Amz-Expires': '$expiresInSeconds',
      'X-Amz-SignedHeaders': 'host',
    };

    final canonicalQueryString = _canonicalQuery(queryParams);
    final canonicalRequest =
        'GET\n/$normalizedKey\n$canonicalQueryString\nhost:$host\n\nhost\nUNSIGNED-PAYLOAD';
    final signature = _sign(
      canonicalRequest: canonicalRequest,
      dateStamp: dateStamp,
      amzDate: amzDate,
      credentialScope: credentialScope,
    );

    return Uri.https(host, normalizedKey, {
      ...queryParams,
      'X-Amz-Signature': signature,
    });
  }

  /// PUT o DELETE con cabecera Authorization.
  SignedS3Request sign({
    required String method,
    required String key,
    required DateTime now,
    Map<String, String> extraHeaders = const {},
    List<int> payload = const [],
  }) {
    final normalizedKey = _normalizeKey(key);
    final utc = now.toUtc();
    final dateStamp = formatDate(utc);
    final amzDate = formatAmzDate(utc);
    final payloadHash = hashPayload(payload);

    final headers = <String, String>{
      ...extraHeaders,
      'host': host,
      'x-amz-date': amzDate,
      'x-amz-content-sha256': payloadHash,
    };

    final credentialScope = '$dateStamp/$region/s3/aws4_request';
    final signedHeaderNames = (headers.keys.map((k) => k.toLowerCase()).toList()
      ..sort());
    final signedHeaders = signedHeaderNames.join(';');
    final canonicalHeaders = (headers.entries.toList()
          ..sort(
            (a, b) =>
                a.key.toLowerCase().compareTo(b.key.toLowerCase()),
          ))
        .map((e) => '${e.key.toLowerCase()}:${e.value.trim()}\n')
        .join();

    final canonicalRequest =
        '${method.toUpperCase()}\n/$normalizedKey\n\n'
        '$canonicalHeaders\n$signedHeaders\n$payloadHash';
    final signature = _sign(
      canonicalRequest: canonicalRequest,
      dateStamp: dateStamp,
      amzDate: amzDate,
      credentialScope: credentialScope,
    );

    final authorization =
        'AWS4-HMAC-SHA256 Credential=$accessKey/$credentialScope, '
        'SignedHeaders=$signedHeaders, Signature=$signature';

    return SignedS3Request(
      url: Uri.https(host, normalizedKey),
      headers: {...headers, 'Authorization': authorization},
    );
  }

  String _sign({
    required String canonicalRequest,
    required String dateStamp,
    required String amzDate,
    required String credentialScope,
  }) {
    final stringToSign =
        'AWS4-HMAC-SHA256\n$amzDate\n$credentialScope\n'
        '${sha256.convert(utf8.encode(canonicalRequest))}';

    final kDate = _hmac(utf8.encode('AWS4$secretKey'), dateStamp);
    final kRegion = _hmac(kDate, region);
    final kService = _hmac(kRegion, 's3');
    final kSigning = _hmac(kService, 'aws4_request');
    return _hmac(kSigning, stringToSign)
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
  }

  static List<int> _hmac(List<int> key, String data) =>
      Hmac(sha256, key).convert(utf8.encode(data)).bytes;

  static String _canonicalQuery(Map<String, String> params) {
    final sorted = params.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    return sorted
        .map(
          (e) =>
              '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}',
        )
        .join('&');
  }

  static String _normalizeKey(String key) {
    var k = key.startsWith('/') ? key.substring(1) : key;
    return k;
  }
}

/// Petición HTTP ya firmada (URL + headers, incluido Authorization).
class SignedS3Request {
  const SignedS3Request({required this.url, required this.headers});

  final Uri url;
  final Map<String, String> headers;
}
