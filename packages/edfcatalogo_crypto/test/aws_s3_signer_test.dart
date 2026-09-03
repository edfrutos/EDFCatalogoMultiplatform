import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:edfcatalogo_crypto/aws_s3_signer.dart';
import 'package:test/test.dart';

void main() {
  const signer = AwsS3Signer(
    accessKey: 'AKIAIOSFODNN7EXAMPLE',
    secretKey: 'wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY',
    region: 'eu-central-1',
    bucket: 'edf-test',
  );

  final now = DateTime.utc(2024, 1, 15, 12, 0, 0);

  test('host y fechas son estables', () {
    expect(signer.host, 'edf-test.s3.eu-central-1.amazonaws.com');
    expect(AwsS3Signer.formatDate(now), '20240115');
    expect(AwsS3Signer.formatAmzDate(now), '20240115T120000Z');
  });

  test('hash de payload vacío es el SHA-256 de cero bytes', () {
    expect(
      AwsS3Signer.hashPayload(const []),
      sha256.convert(utf8.encode('')).toString(),
    );
  });

  test('presign coincide con el algoritmo legado (cliente y API)', () {
    const key = 'users/abc/catalogs/1/image/file.jpg';
    final uri = signer.presignedGet(key: key, now: now, expiresInSeconds: 3600);
    expect(uri.toString(), _legacyPresign(signer, key, now, 3600));
    expect(uri.queryParameters['X-Amz-Algorithm'], 'AWS4-HMAC-SHA256');
    expect(uri.queryParameters.containsKey('X-Amz-Signature'), isTrue);
  });

  test('presign quita el slash inicial de la key', () {
    final a = signer.presignedGet(key: 'foo/bar.pdf', now: now);
    final b = signer.presignedGet(key: '/foo/bar.pdf', now: now);
    expect(a.toString(), b.toString());
  });

  test('PUT firma es determinista e incluye host y content-sha256', () {
    final payload = utf8.encode('hello');
    final a = signer.sign(
      method: 'PUT',
      key: 'uploads/a.bin',
      now: now,
      extraHeaders: {'Content-Type': 'application/pdf'},
      payload: payload,
    );
    final b = signer.sign(
      method: 'PUT',
      key: 'uploads/a.bin',
      now: now,
      extraHeaders: {'Content-Type': 'application/pdf'},
      payload: payload,
    );
    expect(a.headers['Authorization'], b.headers['Authorization']);
    expect(a.headers['host'], signer.host);
    expect(a.headers['Content-Type'], 'application/pdf');
    expect(
      a.headers['x-amz-content-sha256'],
      AwsS3Signer.hashPayload(payload),
    );
    expect(a.headers['Authorization']!.contains('SignedHeaders='), isTrue);
    expect(
      a.headers['Authorization']!.contains('content-type'),
      isTrue,
    );
    expect(a.headers['Authorization']!.contains('host'), isTrue);
  });

  test('DELETE firma el host (AWS exige firmar los headers enviados)', () {
    final signed = signer.sign(method: 'DELETE', key: 'uploads/a.bin', now: now);
    expect(signed.headers['host'], signer.host);
    expect(signed.headers.containsKey('x-amz-content-sha256'), isTrue);
    expect(signed.headers['Authorization']!.contains('host'), isTrue);
    expect(signed.url.path, endsWith('uploads/a.bin'));
  });
}

/// Réplica del presign que vivía en s3_service.dart y s3_routes.dart.
String _legacyPresign(
  AwsS3Signer s,
  String key,
  DateTime now,
  int expirationInSeconds,
) {
  final normalizedKey = key.startsWith('/') ? key.substring(1) : key;
  final dateStamp = AwsS3Signer.formatDate(now);
  final amzDate = AwsS3Signer.formatAmzDate(now);
  final host = s.host;
  final credentialScope = '$dateStamp/${s.region}/s3/aws4_request';
  final credential = '${s.accessKey}/$credentialScope';
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
      '${sha256.convert(utf8.encode(canonicalRequest))}';
  List<int> hmac(List<int> key, String data) =>
      Hmac(sha256, key).convert(utf8.encode(data)).bytes;
  final kDate = hmac(utf8.encode('AWS4${s.secretKey}'), dateStamp);
  final kRegion = hmac(kDate, s.region);
  final kService = hmac(kRegion, 's3');
  final kSigning = hmac(kService, 'aws4_request');
  final signature = hmac(kSigning, stringToSign)
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join();
  return Uri.https(host, normalizedKey, {
    ...queryParams,
    'X-Amz-Signature': signature,
  }).toString();
}
