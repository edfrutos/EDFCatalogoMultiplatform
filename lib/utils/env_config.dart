import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Clase para gestionar las variables de entorno
class EnvConfig {
  static Future<void> load() async {
    await dotenv.load(fileName: '.env');
  }

  // MongoDB
  static String get mongoUri {
    try {
      return dotenv.env['MONGO_URI'] ?? '';
    } catch (e) {
      print('⚠️ Error accediendo a MONGO_URI: $e');
      return '';
    }
  }

  static String get mongoDb {
    try {
      return dotenv.env['MONGO_DB'] ?? '';
    } catch (e) {
      print('⚠️ Error accediendo a MONGO_DB: $e');
      return '';
    }
  }

  // AWS S3
  static String get awsAccessKeyId => dotenv.env['AWS_ACCESS_KEY_ID'] ?? '';
  static String get awsSecretAccessKey =>
      dotenv.env['AWS_SECRET_ACCESS_KEY'] ?? '';
  static String get awsRegion => dotenv.env['AWS_REGION'] ?? 'eu-central-1';
  // Intentar ambos nombres: S3_BUCKET_NAME y BUCKET_NAME
  static String get bucketName =>
      dotenv.env['S3_BUCKET_NAME'] ?? dotenv.env['BUCKET_NAME'] ?? '';
  static bool get useS3 => dotenv.env['USE_S3']?.toLowerCase() == 'true';

  // Email Service (Brevo)
  static String get brevoApiKey => dotenv.env['BREVO_API_KEY'] ?? '';
  static String get brevoSmtpServer =>
      dotenv.env['BREVO_SMTP_SERVER'] ?? 'smtp-relay.brevo.com';
  static int get brevoSmtpPort =>
      int.tryParse(dotenv.env['BREVO_SMTP_PORT'] ?? '587') ?? 587;

  // Google OAuth (opcional)
  static String get googleClientId => dotenv.env['GOOGLE_CLIENT_ID'] ?? '';
  static String get googleClientSecret =>
      dotenv.env['GOOGLE_CLIENT_SECRET'] ?? '';

  /// Validar que las variables críticas estén configuradas
  static bool validate() {
    if (mongoUri.isEmpty || mongoDb.isEmpty) {
      return false;
    }
    if (useS3 && (awsAccessKeyId.isEmpty || awsSecretAccessKey.isEmpty)) {
      return false;
    }
    return true;
  }
}
