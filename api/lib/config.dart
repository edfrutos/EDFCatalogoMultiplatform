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

  // Email — Brevo API (opcional)
  static String get brevoApiKey => _env('BREVO_API_KEY');

  // Email — SMTP (Gmail u otro servidor)
  static String get smtpHost => _env('SMTP_HOST', 'smtp.gmail.com');
  static int get smtpPort => int.tryParse(_env('SMTP_PORT', '465')) ?? 465;
  static String get smtpUser => _env('SMTP_USER');
  static String get smtpPass => _env('SMTP_PASS');
  static String get smtpFrom => _env('SMTP_FROM');
  // Email de destino para notificaciones de contacto
  static String get notificationEmail {
    final e1 = _env('NOTIFICATION_EMAIL_1');
    return e1.isNotEmpty ? e1 : smtpUser;
  }

  // Servidor
  static int get port => int.tryParse(_env('API_PORT', '8080')) ?? 8080;

  /// Orígenes CORS permitidos ('*' para todos, o 'https://midominio.com')
  static String get corsOrigin => _env('API_CORS_ORIGIN', '*');

  static String _env(String key, [String fallback = '']) =>
      Platform.environment[key] ?? fallback;
}
