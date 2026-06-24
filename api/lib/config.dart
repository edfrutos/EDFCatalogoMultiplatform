import 'dart:io';

/// Variables de entorno del servidor API.
/// Lee directamente de Platform.environment (variables de entorno del proceso).
class Config {
  // MongoDB (mismo .env que la app Flutter)
  static String get mongoUri => _env('MONGO_URI');
  static String get mongoDb => _env('MONGO_DB');

  // JWT
  static String get jwtSecret =>
      _env('API_JWT_SECRET', 'dev-secret-cambia-esto-en-produccion');
  static int get jwtExpiryDays =>
      int.tryParse(_env('API_JWT_EXPIRY_DAYS', '7')) ?? 7;

  // AWS S3 (mismo .env que la app Flutter)
  static String get awsAccessKeyId => _env('AWS_ACCESS_KEY_ID');
  static String get awsSecretAccessKey => _env('AWS_SECRET_ACCESS_KEY');
  static String get awsRegion => _env('AWS_REGION', 'eu-central-1');
  static String get s3BucketName {
    final s3 = _env('S3_BUCKET_NAME');
    return s3.isNotEmpty ? s3 : _env('BUCKET_NAME');
  }
  static bool get useS3 => _env('USE_S3').toLowerCase() == 'true';

  // Servidor
  static int get port => int.tryParse(_env('API_PORT', '8080')) ?? 8080;

  /// Orígenes CORS permitidos ('*' para todos, o 'https://midominio.com')
  static String get corsOrigin => _env('API_CORS_ORIGIN', '*');

  static String _env(String key, [String fallback = '']) =>
      Platform.environment[key] ?? fallback;
}
